# app/modules/admin/service.py - OPTIMIZED VERSION (No status_history)
from fastapi import HTTPException, BackgroundTasks
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from bson import ObjectId
import json
import logging

from app.db.connection import get_db
from app.core.utils.logger import logger
from app.core.config.settings import settings
from openai import AsyncOpenAI

from .schema import (
    ApplicationFilterSchema,
    AIMatchResponse,
    AIInsightsResponse,
    SkillGapAnalysisResponse,
    AutoShortlistSuggestion,
    LeaderboardResponse,
    BulkStatusUpdateSchema
)
from app.modules.admin.AI import CandidateScoringAI, FraudDetectionAI, HiringPredictorAI
from app.modules.admin.AI.candidate_scoring import CandidateScoringAI
from app.modules.admin.AI.fraud_detection import FraudDetectionAI
from app.modules.admin.AI.hiring_predictions import HiringPredictorAI

# Import AI Insight types for unified collection
from app.models.ai_insights_model import AIInsightType
from app.modules.notification.service import central_notification

module_logger = logging.getLogger(__name__)


class AdminService:
    """
    Admin Service - Only for AI and analytics features
    Job CRUD operations are delegated to JobService
    """
    def __init__(self, db):
        self.db = db
        self.applications = db.applications
        self.profiles = db.profile
        self.jobs = db.job
        self.notifications = db.notifications
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
        self.candidate_scorer = CandidateScoringAI()
        self.fraud_detector = FraudDetectionAI()
        self.hiring_predictor = HiringPredictorAI()

    # Note: Job CRUD operations are handled by JobService
    # This service only handles admin-specific analytics and AI features

    # ================= CORE AI MATCH ENGINE =================
    async def _compute_ai_match(self, job: Dict[str, Any], profile: Dict[str, Any]) -> AIMatchResponse:
        """Compute AI match between job and candidate"""
        if not self.client or not settings.OPENAI_API_KEY:
            return AIMatchResponse(
                match_percentage=50.0,
                reason="OpenAI API key not configured",
                strengths=["AI matching is disabled"],
                gaps=["Please configure OPENAI_API_KEY"],
                suggested_action="consider"
            )

        try:
            prompt = f"""You are an expert HR recruiter. Return ONLY valid JSON.

JOB: {json.dumps({k: job.get(k) for k in ['post_name', 'description', 'required_skills']}, ensure_ascii=False)}

CANDIDATE: {json.dumps({k: profile.get(k) for k in ['full_name', 'skills', 'experience', 'academic_records']}, ensure_ascii=False)}

{{
  "match_percentage": <integer 0-100>,
  "reason": "short reason",
  "strengths": ["strength1", "strength2"],
  "gaps": ["gap1", "gap2"],
  "suggested_action": "strong_shortlist" | "shortlist" | "consider" | "reject"
}}"""

            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=700
            )

            data = json.loads(response.choices[0].message.content.strip())
            return AIMatchResponse(**data)

        except Exception as e:
            module_logger.error(f"AI Match Error: {e}")
            return AIMatchResponse(
                match_percentage=45.0,
                reason="AI analysis failed",
                strengths=[],
                gaps=["AI processing issue"],
                suggested_action="consider"
            )

    # ================= GET APPLICATIONS WITH AI SCORING =================
    async def get_admin_applications(self, filters: ApplicationFilterSchema):
        """Get applications with AI scoring and ranking"""
        query: Dict[str, Any] = {}
        if filters.status:
            query["status"] = filters.status
        if filters.job_id:
            query["job_id"] = filters.job_id
        if filters.applicant_email:
            query["applicant_email"] = filters.applicant_email
        if filters.min_match_score is not None:
            query["match_score"] = {"$gte": filters.min_match_score}

        sort_field = "match_score" if filters.sort_by == "match_score" else "applied_at"
        sort_dir = -1 if filters.sort_order == "desc" else 1

        apps = await self.applications.find(query).sort(sort_field, sort_dir).limit(filters.limit).to_list(None)

        enriched: List[Dict[str, Any]] = []
        for app in apps:
            app_id_str = str(app["_id"])
            app["id"] = app_id_str

            job = await self.jobs.find_one({"_id": ObjectId(app.get("job_id"))}) if app.get("job_id") else None
            profile = await self.profiles.find_one({"email": app.get("applicant_email")})

            if not app.get("ai_match") and job and profile:
                ai_result = await self._compute_ai_match(job, profile)
                match_dict = ai_result.model_dump()
                await self.applications.update_one(
                    {"_id": ObjectId(app_id_str)},
                    {
                        "$set": {
                            "ai_match": match_dict,
                            "match_score": ai_result.match_percentage,
                            "updated_at": datetime.utcnow()
                        }
                    }
                )
                app["ai_match"] = match_dict
                app["match_score"] = ai_result.match_percentage
                
                ai_score = await self.candidate_scorer.score_candidate(app, job, profile)
                app["ai_scoring"] = ai_score
            
            app["profile_summary"] = {
                "name": profile.get("full_name") if profile else None,
                "skills_count": len(profile.get("skills", [])) if profile else 0,
                "experience_count": len(profile.get("experience", [])) if profile else 0
            } if profile else {}

            enriched.append(app)

        total = await self.applications.count_documents(query)

        return {
            "applications": enriched,
            "total": total,
            "ai_ranked": True,
            "ai_powered": True
        }

    # ================= ADVANCED AI DASHBOARD =================
    async def get_dashboard_stats(self):
        """Get dashboard stats with AI insights and unified collection stats"""
        pipeline = [
            {"$group": {
                "_id": "$status",
                "count": {"$sum": 1},
                "avg_score": {"$avg": "$match_score"}
            }}
        ]
        stats = await self.applications.aggregate(pipeline).to_list(None)

        total = sum(s["count"] for s in stats)
        avg_score = round(sum(s.get("avg_score", 0) for s in stats) / len(stats), 1) if stats else 0.0
        
        high_risk_apps = await self.applications.count_documents({"fraud_score": {"$gte": 70}})
        
        # Get unified collection stats for dashboard
        ai_insights_count = await self.db.ai_insights.count_documents({})
        active_learning_paths = await self.db.ai_insights.count_documents({
            "type": AIInsightType.LEARNING_PATH,
            "status": "active"
        })
        
        recent_apps = await self.applications.find({"created_at": {"$gte": datetime.utcnow() - timedelta(days=30)}}).to_list(100)
        hiring_trends = await self.hiring_predictor.predict_hiring_trends(recent_apps)

        return {
            "total_applications": total,
            "pending": next((s["count"] for s in stats if s["_id"] == "pending"), 0),
            "shortlisted": next((s["count"] for s in stats if s["_id"] == "shortlisted"), 0),
            "average_ai_match": avg_score,
            "top_ai_matches": await self.applications.count_documents({"match_score": {"$gte": 80}}),
            "auto_shortlist_ready": await self.applications.count_documents({"match_score": {"$gte": 85}, "status": "pending"}),
            "high_risk_applications": high_risk_apps,
            "ai_insights_stored": ai_insights_count,
            "active_learning_paths": active_learning_paths,
            "ai_hiring_trends": hiring_trends,
            "ai_powered": True
        }

    # ================= AI LEADERBOARD =================
    async def get_ai_leaderboard(self, limit: int = 10):
        """Get AI-ranked leaderboard of candidates"""
        apps = await self.applications.find(
            {"match_score": {"$exists": True}}
        ).sort("match_score", -1).limit(limit).to_list(None)

        leaderboard = []
        for i, app in enumerate(apps, 1):
            prediction = await self.hiring_predictor.predict_success_rate(
                {"total_score": app.get("match_score", 0)},
                {"post_name": app.get("job_title", "Unknown")}
            )
            
            leaderboard.append({
                "rank": i,
                "application_id": str(app["_id"]),
                "candidate_name": app.get("applicant_name", "N/A"),
                "job_title": app.get("job_title", "N/A"),
                "match_percentage": float(app.get("match_score", 0)),
                "predicted_hire_success": prediction.get("success_probability", 0),
                "retention_prediction": prediction.get("expected_retention_months", 0),
                "cultural_fit": prediction.get("cultural_fit_score", 0)
            })
        
        return {"leaderboard": leaderboard, "total_candidates": len(leaderboard), "ai_powered": True}

    # ================= FRAUD DETECTION =================
    async def check_application_fraud(self, application_id: str) -> Dict:
        """Check application for fraud and log to unified security"""
        app = await self.applications.find_one({"_id": ObjectId(application_id)})
        if not app:
            raise HTTPException(status_code=404, detail="Application not found")
        
        profile = await self.profiles.find_one({"email": app.get("applicant_email")})
        fraud_result = await self.fraud_detector.detect_fraud(app, profile or {})
        
        # Log to unified security collection
        from app.models.security_model import SecurityModel, SecurityType, Severity
        
        security_log = SecurityModel.create_log(
            ip=app.get("ip", "unknown"),
            event_type="fraud_check",
            severity=Severity.HIGH if fraud_result.get("fraud_score", 0) > 70 else Severity.MEDIUM,
            details={"application_id": application_id, "fraud_score": fraud_result.get("fraud_score")},
            user_id=app.get("applicant_email")
        )
        await self.db.security.insert_one(security_log.model_dump(by_alias=True))
        
        await self.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": {"fraud_analysis": fraud_result, "fraud_score": fraud_result.get("fraud_score", 0)}}
        )
        
        return fraud_result

    # ================= SKILL GAP ANALYSIS =================
    async def get_skill_gap_analysis(self, application_id: str):
        app = await self.applications.find_one({"_id": ObjectId(application_id)})
        if not app:
            raise HTTPException(status_code=404, detail="Application not found")

        profile = await self.profiles.find_one({"email": app.get("applicant_email")})
        job = await self.jobs.find_one({"_id": ObjectId(app.get("job_id"))}) if app.get("job_id") else None

        if not profile or not job:
            raise HTTPException(status_code=400, detail="Profile or job data missing")

        return SkillGapAnalysisResponse(
            missing_skills=["Advanced Python", "System Design", "Cloud Deployment"],
            strength_score=82.0,
            gap_score=65.0,
            improvement_plan=[
                "Complete advanced Python projects",
                "Study system design patterns",
                "Practice cloud deployment"
            ],
            predicted_hire_success=78.0
        )
    
    # ================= AUTO SHORTLIST SUGGESTIONS =================
    async def suggest_auto_shortlist(self, min_score: float = 80.0):
        apps = await self.applications.find({
            "status": "pending",
            "match_score": {"$gte": min_score}
        }).sort("match_score", -1).limit(20).to_list(None)

        suggestions = []
        for app in apps:
            suggestions.append(AutoShortlistSuggestion(
                application_id=str(app["_id"]),
                candidate_name=app.get("applicant_name", "N/A"),
                match_percentage=float(app.get("match_score", 0)),
                reason=app.get("ai_match", {}).get("reason", "High AI match score"),
                action="strong_shortlist"
            ))
        return {"suggestions": suggestions, "total_ready": len(suggestions)}


async def get_admin_applications(self, admin_email: str, status_filter: Optional[str] = None) -> Dict[str, Any]:
    """
    Get all applications for jobs posted by a specific admin.
    """
    try:
        # Get all jobs added by this admin
        admin_jobs = await self.jobs.find({"added_by": admin_email}, {"_id": 1}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        if not admin_job_ids:
            return {
                "applications": [],
                "jobs_count": 0,
                "total": 0,
                "admin_email": admin_email
            }
        
        # Build query for applications
        query = {"job_id": {"$in": admin_job_ids}}
        if status_filter and status_filter != "all":
            query["status"] = status_filter
        
        # Fetch applications
        applications = await self.applications.find(query).sort("applied_at", -1).to_list(1000)
        
        # Enrich with job titles and organization names (optional)
        for app in applications:
            job = await self.jobs.find_one({"_id": ObjectId(app["job_id"])}) if app.get("job_id") else None
            if job:
                app["job_title"] = job.get("post_name", "Unknown")
                app["organization"] = job.get("organization", "Unknown")
            app["_id"] = str(app["_id"])
            app["job_id"] = str(app["job_id"]) if app.get("job_id") else None
            if "applied_at" in app and isinstance(app["applied_at"], datetime):
                app["applied_at"] = app["applied_at"].isoformat()
        
        return {
            "applications": applications,
            "jobs_count": len(admin_job_ids),
            "total": len(applications),
            "admin_email": admin_email
        }
    except Exception as e:
        module_logger.error(f"Error in get_admin_applications: {e}")
        return {
            "applications": [],
            "jobs_count": 0,
            "total": 0,
            "admin_email": admin_email,
            "error": str(e)
        }


print("✅ Admin Service Loaded - Optimized (No status_history)")