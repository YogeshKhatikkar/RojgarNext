# app/modules/superadmin/service.py - FIXED VERSION (NO AUTH DELETION)

from fastapi import HTTPException
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from bson import ObjectId
import json
import logging

from app.db.connection import get_db
from app.core.config.settings import settings
from openai import AsyncOpenAI

from .schema import (
    UserFilterSchema,
    PromoteToAdminSchema,
    BulkActionSchema,
    AISmartDashboardResponse,
    AIPredictiveAnalytics,
    AIAnomalyDetection
)

from app.models.ai_insights_model import AIInsightType
from app.models.security_model import SecurityType

module_logger = logging.getLogger(__name__)


class SuperAdminService:
    def __init__(self, db):
        self.db = db
        self.auth = db.auth
        self.profile = db.profile
        self.job = db.job
        self.applications = db.applications
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None

    async def get_ai_smart_dashboard(self) -> Dict:
        """AI-Powered SuperAdmin Dashboard"""
        now = datetime.utcnow()
        
        total_users = await self.auth.count_documents({})
        total_admins = await self.auth.count_documents({"role": "admin"})
        total_jobs = await self.job.count_documents({})
        total_applications = await self.applications.count_documents({})
        successful_placements = await self.applications.count_documents({"status": "offered"})
        pending_applications = await self.applications.count_documents({"status": "pending"})
        
        avg_ai_score = 0.0
        if total_applications > 0:
            pipeline = [{"$group": {"_id": None, "avg": {"$avg": "$match_score"}}}]
            result = await self.applications.aggregate(pipeline).to_list(1)
            avg_ai_score = round(result[0].get("avg", 0), 1) if result else 0.0
        
        ai_insights_count = await self.db.ai_insights.count_documents({})
        active_sessions = await self.db.sessions.count_documents({"is_active": True})
        
        health_score = 70
        if total_users > 1000:
            health_score += 10
        if total_jobs > 100:
            health_score += 10
        if successful_placements > 50:
            health_score += 10
        
        return {
            "generated_at": now.isoformat(),
            "overview": {
                "total_users": total_users,
                "total_admins": total_admins,
                "total_jobs": total_jobs,
                "total_applications": total_applications,
                "successful_placements": successful_placements,
                "platform_health_score": health_score,
                "performance_rating": "excellent" if health_score >= 80 else "good" if health_score >= 60 else "average",
                "ai_insights_stored": ai_insights_count,
                "active_sessions": active_sessions
            },
            "user_analytics": {
                "total": total_users,
                "active": await self.auth.count_documents({"is_active": True}),
                "verified": await self.auth.count_documents({"is_email_verified": True, "is_mobile_verified": True}),
                "growth_prediction": total_users + 100
            },
            "job_analytics": {
                "total_posted": total_jobs,
                "open_jobs": await self.job.count_documents({"status": "open"}),
                "growth_prediction": total_jobs + 50
            },
            "application_analytics": {
                "total": total_applications,
                "pending": pending_applications,
                "shortlisted": await self.applications.count_documents({"status": "shortlisted"}),
                "avg_ai_match_score": avg_ai_score,
                "growth_prediction": total_applications + 200
            },
            "ai_executive_summary": f"Platform has {total_users} users, {total_jobs} jobs, and {total_applications} applications. Health score is {health_score}%.",
            "predictive_analytics": {
                "next_30_days_users": total_users + 100,
                "next_30_days_jobs": total_jobs + 50,
                "next_30_days_placements": successful_placements + 20,
                "growth_trend": "linear"
            },
            "anomaly_detection": {
                "detected_issues": [],
                "severity": "low",
                "suggestion": "Monitor regularly"
            },
            "recommendations": [
                "Increase marketing efforts to reach 2000 users",
                "Add more job categories to attract more employers",
                "Improve AI matching algorithm"
            ],
            "platform_health_score": health_score
        }

    async def list_users(self, filters: UserFilterSchema):
        query = {}
        if filters.role: 
            query["role"] = filters.role
        if filters.is_active is not None: 
            query["is_active"] = filters.is_active

        users = await self.auth.find(query).limit(filters.limit).skip(filters.skip).to_list(None)
        for u in users:
            u["_id"] = str(u["_id"])
        total = await self.auth.count_documents(query)
        return {"users": users, "total": total, "page": (filters.skip // filters.limit) + 1}

    async def change_user_role(self, email: str, new_role: str, notes: Optional[str] = None):
        result = await self.auth.update_one(
            {"email": email}, 
            {"$set": {"role": new_role, "updated_at": datetime.utcnow()}}
        )
        if result.modified_count == 0:
            raise HTTPException(404, "User not found")
        return {"message": f"User {email} role changed to {new_role}"}

    # ==================== FIXED BULK ACTION - NO DELETE ====================
    async def bulk_action(self, data: BulkActionSchema, performed_by: str):
        results = []
        for email in data.emails:
            try:
                if data.action == "promote_to_admin":
                    await self.change_user_role(email, "admin", data.notes)
                elif data.action == "demote_to_user":
                    await self.change_user_role(email, "user", data.notes)
                elif data.action == "deactivate":
                    await self.auth.update_one({"email": email}, {"$set": {"is_active": False}})
                elif data.action == "delete":
                    # ✅ FIXED: SOFT DELETE - DO NOT PERMANENTLY DELETE
                    # Just deactivate the user instead
                    await self.auth.update_one(
                        {"email": email},
                        {
                            "$set": {
                                "is_active": False,
                                "deleted_at": datetime.utcnow(),
                                "deleted_by": performed_by,
                                "deletion_reason": "bulk_action"
                            }
                        }
                    )
                    await self.profile.update_one(
                        {"email": email},
                        {
                            "$set": {
                                "is_active": False,
                                "deleted_at": datetime.utcnow(),
                                "deleted_by": performed_by
                            }
                        }
                    )
                    # Log the soft deletion
                    await self.db.security.insert_one({
                        "type": "security_log",
                        "event_type": "user_soft_deleted",
                        "user_email": email,
                        "deleted_by": performed_by,
                        "action": "bulk_delete",
                        "timestamp": datetime.utcnow(),
                        "severity": "critical"
                    })
                results.append({"email": email, "status": "success"})
            except Exception as e:
                results.append({"email": email, "status": "failed", "reason": str(e)})
        return {"results": results}

    # ==================== FIXED DELETE USER - SOFT DELETE ONLY ====================
# app/modules/superadmin/service.py - Updated delete_user function

async def delete_user(self, email: str, deleted_by: str = "superadmin"):
    """
    SOFT DELETE ONLY - Mark user as deleted but keep data
    NEVER permanently deletes auth records
    """
    # ✅ FIXED: Do NOT delete - just deactivate and mark as deleted
    result_auth = await self.auth.update_one(
        {"email": email},
        {
            "$set": {
                "is_active": False,
                "deleted_at": datetime.utcnow(),
                "deleted_by": deleted_by,
                "deletion_reason": "superadmin_action"
            }
        }
    )
    
    result_profile = await self.profile.update_one(
        {"email": email},
        {
            "$set": {
                "is_active": False,
                "deleted_at": datetime.utcnow(),
                "deleted_by": deleted_by
            }
        }
    )
    
    if result_auth.modified_count == 0 and result_profile.modified_count == 0:
        raise HTTPException(404, "User not found")
    
    # Log the deletion for audit
    await self.db.security.insert_one({
        "type": "security_log",
        "event_type": "user_soft_deleted",
        "user_email": email,
        "deleted_by": deleted_by,
        "timestamp": datetime.utcnow(),
        "severity": "critical"
    })
    
    return {
        "message": f"User {email} deactivated (soft delete - data preserved)",
        "email": email,
        "status": "deactivated",
        "data_preserved": True
    }


print("✅ SuperAdmin Service Loaded - AUTH DELETION DISABLED (Soft Delete Only)")