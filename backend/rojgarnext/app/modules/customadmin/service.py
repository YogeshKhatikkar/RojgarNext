# app/modules/customadmin/service.py - OPTIMIZED VERSION (No status_history)

from fastapi import HTTPException, BackgroundTasks
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from bson import ObjectId
import logging

from app.db.connection import get_db
from app.modules.jobs.service import JobService
from app.modules.jobs.schema import JobCreateSchema, ApplicationStatusUpdateSchema
from app.modules.notification.service import central_notification

module_logger = logging.getLogger(__name__)


class CustomAdminService:
    """
    Custom Admin Service - All job operations delegated to JobService
    NO status_history - Only stores latest status
    """
    
    def __init__(self, db):
        self.db = db
        self.auth = db.auth
        self.profile = db.profile
        self.job = db.job
        self.applications = db.applications
        self.notifications = db.notifications
        self.job_service = JobService(db)

    # ====================== DASHBOARD STATS ======================
    async def get_dashboard_stats(self, admin_email: str) -> Dict:
        """Get dashboard statistics for custom admin"""
        admin_jobs = await self.job.find({"added_by": admin_email}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        if admin_job_ids:
            apps_query = {"job_id": {"$in": admin_job_ids}}
        else:
            apps_query = {"_id": None}
        
        total_applications = await self.applications.count_documents(apps_query)
        pending_applications = await self.applications.count_documents({**apps_query, "status": "pending"})
        shortlisted_applications = await self.applications.count_documents({**apps_query, "status": "shortlisted"})
        interview_applications = await self.applications.count_documents({**apps_query, "status": "interview"})
        offered_applications = await self.applications.count_documents({**apps_query, "status": "offered"})
        rejected_applications = await self.applications.count_documents({**apps_query, "status": "rejected"})
        submitted_applications = await self.applications.count_documents({**apps_query, "status": "submitted"})
        
        avg_match_score = 0
        if total_applications > 0:
            pipeline = [{"$match": apps_query}, {"$group": {"_id": None, "avg": {"$avg": "$match_score"}}}]
            result = await self.applications.aggregate(pipeline).to_list(1)
            if result and result[0].get("avg"):
                avg_match_score = round(result[0]["avg"], 1)
        
        last_7_days = datetime.utcnow() - timedelta(days=7)
        recent_applications = await self.applications.count_documents({
            **apps_query, "applied_at": {"$gte": last_7_days}
        })
        
        return {
            "total_jobs": len(admin_jobs),
            "total_applications": total_applications,
            "pending_applications": pending_applications,
            "shortlisted_applications": shortlisted_applications,
            "interview_applications": interview_applications,
            "offered_applications": offered_applications,
            "rejected_applications": rejected_applications,
            "submitted_applications": submitted_applications,
            "avg_match_score": avg_match_score,
            "recent_applications_7d": recent_applications,
            "admin_email": admin_email,
            "role": "custom_admin"
        }

    # ====================== JOB MANAGEMENT (Delegated to JobService) ======================
    
    async def add_job(self, job_data: Dict, admin_email: str, background_tasks: BackgroundTasks) -> Dict:
        """Add new job - delegates to JobService which sends notifications"""
        dummy_user = {
            "email": admin_email, 
            "name": admin_email.split('@')[0],
            "role": "customadmin"
        }
        
        job_data.setdefault("required_skills", [])
        job_data.setdefault("nice_to_have_skills", [])
        job_data.setdefault("benefits", [])
        job_data.setdefault("tags", [])
        job_data.setdefault("attachments", [])
        job_data.setdefault("multiple_posts", [])
        job_data.setdefault("geolocation", [0, 0])
        job_data.setdefault("job_level", "mid")
        job_data.setdefault("experience_min_years", 0)
        job_data.setdefault("salary_currency", "INR")
        
        apply_url = job_data.get("apply_with_us_url")
        if apply_url and str(apply_url).strip() and str(apply_url).strip() != '#':
            job_data["has_apply_with_us"] = True
        
        job_data["created_at"] = datetime.utcnow().isoformat()
        job_data["updated_at"] = datetime.utcnow().isoformat()
        job_data["status"] = "open"
        
        job_schema = JobCreateSchema(**job_data)
        
        result = await self.job_service.add_job(
            job_data=job_schema,
            background_tasks=background_tasks,
            attachments=None,
            current_user=dummy_user
        )
        
        return result

    async def get_admin_jobs(self, admin_email: str) -> Dict:
        """Get all jobs posted by this admin - Delegates to JobService"""
        return await self.job_service.get_admin_jobs(admin_email)

    async def get_job_detail(self, job_id: str, admin_email: str) -> Dict:
        """Get single job details - Delegates to JobService"""
        job = await self.job_service.get_job(job_id)
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        return job

    async def update_job(self, job_id: str, job_data: Dict, admin_email: str) -> Dict:
        """Update existing job - Delegates to JobService"""
        job = await self.job.find_one({"_id": ObjectId(job_id)})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        return await self.job_service.update_job(job_id, job_data, admin_email, "customadmin")

    async def delete_job(self, job_id: str, admin_email: str) -> Dict:
        """Delete job - Delegates to JobService"""
        job = await self.job.find_one({"_id": ObjectId(job_id)})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        return await self.job_service.delete_job(job_id, admin_email, "customadmin")

    # ====================== APPLICATION MANAGEMENT ======================
    
    async def get_admin_applications(self, admin_email: str, status_filter: Optional[str] = None) -> Dict:
        """Get all applications for admin's jobs - Delegates to JobService"""
        return await self.job_service.get_admin_applications(admin_email, status_filter)

    async def get_application_detail(self, application_id: str, admin_email: str) -> Dict:
        """Get single application with full details"""
        application = await self.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        job = await self.job.find_one({"_id": ObjectId(application.get("job_id"))})
        if not job or job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        
        candidate_email = application.get("applicant_email")
        profile = await self.profile.find_one({"email": candidate_email}) if candidate_email else None
        auth_user = await self.auth.find_one({"email": candidate_email}) if candidate_email else None
        
        application["_id"] = str(application["_id"])
        application["job_id"] = str(application["job_id"])
        
        return {
            "application": application,
            "candidate_profile": profile,
            "user_auth": auth_user,
            "job": job
        }

    async def update_application_status(self, application_id: str, status: str, notes: Optional[str], admin_email: str) -> Dict:
        """
        Update application status - NO status_history
        Only stores latest status with last updated info
        """
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")
        
        # Get application to verify access
        application = await self.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        # Verify admin has access
        job = await self.job.find_one({"_id": ObjectId(application.get("job_id"))})
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Update only status fields - NO history array
        update_data = {
            "status": status,
            "last_status_update": datetime.utcnow(),
            "last_updated_by": admin_email,
            "updated_at": datetime.utcnow()
        }
        
        if notes:
            update_data["admin_notes"] = notes
        
        result = await self.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Application not found or status unchanged")
        
        # Send notification to user
        await central_notification.notify_status_update(
            application_id=application_id,
            new_status=status,
            notes=notes,
            updated_by_email=admin_email
        )
        
        return {"message": f"Status updated to {status}"}

    async def bulk_update_status(self, application_ids: List[str], status: str, notes: Optional[str], admin_email: str) -> Dict:
        """Bulk update application statuses - NO status_history"""
        valid_ids = [aid for aid in application_ids if ObjectId.is_valid(aid)]
        if not valid_ids:
            raise HTTPException(status_code=400, detail="No valid application IDs")
        
        updated_count = 0
        for app_id in valid_ids:
            try:
                # Update each application individually
                await self.applications.update_one(
                    {"_id": ObjectId(app_id)},
                    {
                        "$set": {
                            "status": status,
                            "last_status_update": datetime.utcnow(),
                            "last_updated_by": admin_email,
                            "updated_at": datetime.utcnow(),
                            "admin_notes": notes if notes else None
                        }
                    }
                )
                updated_count += 1
                
                # Send notification for each
                await central_notification.notify_status_update(
                    application_id=app_id,
                    new_status=status,
                    notes=notes,
                    updated_by_email=admin_email
                )
            except Exception as e:
                module_logger.error(f"Failed to update {app_id}: {e}")
        
        return {"updated_count": updated_count, "status": status}

    # ====================== USER MANAGEMENT ======================
    
    async def search_users(self, query: str, limit: int = 20) -> Dict:
        """Search users - read-only access"""
        users = await self.auth.find({
            "$or": [
                {"email": {"$regex": query, "$options": "i"}},
                {"name": {"$regex": query, "$options": "i"}},
                {"mobile": {"$regex": query, "$options": "i"}}
            ]
        }).limit(limit).to_list(limit)
        
        user_list = []
        for user in users:
            user_list.append({
                "_id": str(user["_id"]),
                "name": user.get("name", ""),
                "email": user.get("email", ""),
                "mobile": user.get("mobile", ""),
                "role": user.get("role", "user"),
                "is_active": user.get("is_active", True),
                "is_email_verified": user.get("is_email_verified", False),
                "is_mobile_verified": user.get("is_mobile_verified", False),
            })
        
        return {"users": user_list, "total": len(user_list)}

    async def get_user_profile(self, email: str) -> Dict:
        """Get user profile details - read-only"""
        profile = await self.profile.find_one({"email": email})
        if not profile:
            raise HTTPException(status_code=404, detail="User not found")
        profile["_id"] = str(profile["_id"])
        return profile

    # ====================== REPORTS ======================
    
    async def generate_report(self, report_type: str, admin_email: str) -> Dict:
        """Generate various reports"""
        admin_jobs = await self.job.find({"added_by": admin_email}, {"_id": 1}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        if report_type == "applications":
            if admin_job_ids:
                pipeline = [{"$match": {"job_id": {"$in": admin_job_ids}}}, {"$group": {"_id": "$status", "count": {"$sum": 1}}}]
                stats = await self.applications.aggregate(pipeline).to_list(10)
            else:
                stats = []
            
            return {
                "report_type": "applications",
                "generated_at": datetime.utcnow().isoformat(),
                "status_breakdown": {item["_id"]: item["count"] for item in stats},
                "total_applications": sum(item["count"] for item in stats)
            }
        elif report_type == "jobs":
            jobs = await self.job.find({"added_by": admin_email}).to_list(1000)
            return {
                "report_type": "jobs",
                "generated_at": datetime.utcnow().isoformat(),
                "total_jobs": len(jobs),
                "jobs": [{"id": str(job["_id"]), "title": job.get("post_name")} for job in jobs[:20]]
            }
        else:
            raise HTTPException(status_code=400, detail="Invalid report type. Use 'applications' or 'jobs'")


print("✅ Custom Admin Service Loaded - Optimized (No status_history)")