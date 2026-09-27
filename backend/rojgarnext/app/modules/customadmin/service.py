# app/modules/customadmin/service.py - COMPLETE UPDATED VERSION
# ✅ Full Job CRUD via JobService
# ✅ Application Management
# ✅ User Management (Read-only)
# ✅ Reports
# ✅ All original functionality preserved

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
    Handles customadmin-specific operations
    """
    
    def __init__(self, db):
        self.db = db
        self.auth = db.auth
        self.profile = db.profile
        self.job = db.job
        self.applications = db.applications
        self.notifications = db.notifications
        self.job_service = JobService(db)

    # ============================================================
    # DASHBOARD STATS
    # ============================================================
    
    async def get_dashboard_stats(self, admin_email: str) -> Dict:
        """
        Get dashboard statistics for custom admin
        """
        admin_jobs = await self.job.find({"added_by": admin_email}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        if admin_job_ids:
            apps_query = {"job_id": {"$in": admin_job_ids}}
        else:
            apps_query = {"_id": None}
        
        # Get counts by status
        total_applications = await self.applications.count_documents(apps_query)
        pending_applications = await self.applications.count_documents({
            **apps_query, "status": "pending"
        })
        shortlisted_applications = await self.applications.count_documents({
            **apps_query, "status": "shortlisted"
        })
        interview_applications = await self.applications.count_documents({
            **apps_query, "status": "interview"
        })
        offered_applications = await self.applications.count_documents({
            **apps_query, "status": "offered"
        })
        rejected_applications = await self.applications.count_documents({
            **apps_query, "status": "rejected"
        })
        submitted_applications = await self.applications.count_documents({
            **apps_query, "status": "submitted"
        })
        
        # Calculate average match score
        avg_match_score = 0
        if total_applications > 0:
            pipeline = [
                {"$match": apps_query},
                {"$group": {"_id": None, "avg": {"$avg": "$match_score"}}}
            ]
            result = await self.applications.aggregate(pipeline).to_list(1)
            if result and result[0].get("avg"):
                avg_match_score = round(result[0]["avg"], 1)
        
        # Recent applications (last 7 days)
        last_7_days = datetime.utcnow() - timedelta(days=7)
        recent_applications = await self.applications.count_documents({
            **apps_query, 
            "applied_at": {"$gte": last_7_days}
        })
        
        # Top jobs by applications
        top_jobs = []
        if admin_job_ids:
            pipeline = [
                {"$match": {"job_id": {"$in": admin_job_ids}}},
                {"$group": {
                    "_id": "$job_title", 
                    "count": {"$sum": 1}
                }},
                {"$sort": {"count": -1}},
                {"$limit": 5}
            ]
            top_jobs_result = await self.applications.aggregate(pipeline).to_list(5)
            top_jobs = [
                {"title": item["_id"], "applications": item["count"]}
                for item in top_jobs_result
            ]
        
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
            "top_jobs": top_jobs,
            "admin_email": admin_email,
            "role": "custom_admin"
        }

    # ============================================================
    # JOB MANAGEMENT (Delegated to JobService)
    # ============================================================
    
    async def add_job(
        self, 
        job_data: Dict, 
        admin_email: str, 
        background_tasks: BackgroundTasks
    ) -> Dict:
        """
        Add new job - delegates to JobService which sends notifications
        """
        dummy_user = {
            "email": admin_email,
            "name": admin_email.split('@')[0] if admin_email else "Custom Admin",
            "role": "customadmin"
        }
        
        # Set defaults
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
        job_data.setdefault("job_type", "private")
        job_data.setdefault("color_type", "blue")
        
        # Handle apply with us
        apply_url = job_data.get("apply_with_us_url")
        if apply_url and str(apply_url).strip() and str(apply_url).strip() != '#':
            job_data["has_apply_with_us"] = True
        
        # Set timestamps
        job_data["created_at"] = datetime.utcnow().isoformat()
        job_data["updated_at"] = datetime.utcnow().isoformat()
        job_data["status"] = "open"
        
        # Validate with schema
        job_schema = JobCreateSchema(**job_data)
        
        # Call JobService
        result = await self.job_service.add_job(
            job_data=job_schema,
            background_tasks=background_tasks,
            attachments=None,
            current_user=dummy_user
        )
        
        return result

    async def get_admin_jobs(self, admin_email: str) -> Dict:
        """
        Get all jobs posted by this admin - Delegates to JobService
        """
        return await self.job_service.get_admin_jobs(admin_email)

    async def get_job_detail(self, job_id: str, admin_email: str) -> Dict:
        """
        Get single job details with permission check
        """
        job = await self.job_service.get_job(job_id)
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        return job

    async def update_job(
        self, 
        job_id: str, 
        job_data: Dict, 
        admin_email: str
    ) -> Dict:
        """
        Update existing job - Delegates to JobService
        """
        job = await self.job.find_one({"_id": ObjectId(job_id)})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        # ✅ FIX: Call JobService.update_job with correct signature
        return await self.job_service.update_job(
            job_id, 
            job_data, 
            admin_email, 
            "customadmin"
        )

    async def delete_job(self, job_id: str, admin_email: str) -> Dict:
        """
        Delete job - Delegates to JobService
        """
        job = await self.job.find_one({"_id": ObjectId(job_id)})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        # ✅ FIX: Call JobService.delete_job with correct signature
        return await self.job_service.delete_job(
            job_id, 
            admin_email, 
            "customadmin"
        )

    # ============================================================
    # APPLICATION MANAGEMENT
    # ============================================================
    
    async def get_admin_applications(
        self, 
        admin_email: str, 
        status_filter: Optional[str] = None
    ) -> Dict:
        """
        Get all applications for admin's jobs - Delegates to JobService
        """
        return await self.job_service.get_admin_applications(
            admin_email, 
            status_filter
        )

    async def get_application_detail(
        self, 
        application_id: str, 
        admin_email: str
    ) -> Dict:
        """
        Get single application with full details
        """
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")
        
        application = await self.applications.find_one({
            "_id": ObjectId(application_id)
        })
        
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        # Verify permission
        job = await self.job.find_one({
            "_id": ObjectId(application.get("job_id"))
        })
        
        if not job or job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Get candidate info
        candidate_email = application.get("applicant_email")
        profile = await self.profile.find_one(
            {"email": candidate_email}
        ) if candidate_email else None
        auth_user = await self.auth.find_one(
            {"email": candidate_email}
        ) if candidate_email else None
        
        # Serialize
        application["_id"] = str(application["_id"])
        application["job_id"] = str(application["job_id"])
        
        if application.get("applied_at") and isinstance(application["applied_at"], datetime):
            application["applied_at"] = application["applied_at"].isoformat()
        if application.get("created_at") and isinstance(application["created_at"], datetime):
            application["created_at"] = application["created_at"].isoformat()
        
        if profile:
            profile["_id"] = str(profile["_id"])
        if job:
            job["_id"] = str(job["_id"])
        
        return {
            "application": application,
            "candidate_profile": profile,
            "user_auth": auth_user,
            "job": job
        }

    async def update_application_status(
        self,
        application_id: str,
        status: str,
        notes: Optional[str],
        admin_email: str
    ) -> Dict:
        """
        Update application status with notifications
        """
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")
        
        # Get application
        application = await self.applications.find_one({
            "_id": ObjectId(application_id)
        })
        
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        # Verify admin access
        job = await self.job.find_one({
            "_id": ObjectId(application.get("job_id"))
        })
        
        if job and job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        
        old_status = application.get("status", "unknown")
        
        # Update
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
            raise HTTPException(
                status_code=404,
                detail="Application not found or status unchanged"
            )
        
        # Send notifications
        await central_notification.notify_status_update(
            application_id=application_id,
            new_status=status,
            notes=notes,
            updated_by_email=admin_email
        )
        
        return {
            "success": True,
            "message": f"Status updated from {old_status} to {status}",
            "application_id": application_id,
            "old_status": old_status,
            "new_status": status
        }

    async def bulk_update_status(
        self,
        application_ids: List[str],
        status: str,
        notes: Optional[str],
        admin_email: str
    ) -> Dict:
        """
        Bulk update application statuses
        """
        valid_ids = [aid for aid in application_ids if ObjectId.is_valid(aid)]
        
        if not valid_ids:
            raise HTTPException(status_code=400, detail="No valid application IDs")
        
        updated_count = 0
        failed_ids = []
        
        for app_id in valid_ids:
            try:
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
                
                await central_notification.notify_status_update(
                    application_id=app_id,
                    new_status=status,
                    notes=notes,
                    updated_by_email=admin_email
                )
            except Exception as e:
                module_logger.error(f"Failed to update {app_id}: {e}")
                failed_ids.append(app_id)
        
        return {
            "success": True,
            "updated_count": updated_count,
            "failed_count": len(failed_ids),
            "failed_ids": failed_ids,
            "status": status
        }

    # ============================================================
    # USER MANAGEMENT (Read-only)
    # ============================================================
    
    async def search_users(self, query: str, limit: int = 20) -> Dict:
        """
        Search users - read-only access
        """
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
        """
        Get user profile details - read-only
        """
        profile = await self.profile.find_one({"email": email})
        if not profile:
            raise HTTPException(status_code=404, detail="User not found")
        profile["_id"] = str(profile["_id"])
        return profile

    # ============================================================
    # REPORTS
    # ============================================================
    
    async def generate_report(
        self, 
        report_type: str, 
        admin_email: str
    ) -> Dict:
        """
        Generate various reports
        """
        admin_jobs = await self.job.find(
            {"added_by": admin_email},
            {"_id": 1}
        ).to_list(1000)
        
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        if report_type == "applications":
            if admin_job_ids:
                pipeline = [
                    {"$match": {"job_id": {"$in": admin_job_ids}}},
                    {"$group": {"_id": "$status", "count": {"$sum": 1}}}
                ]
                stats = await self.applications.aggregate(pipeline).to_list(10)
            else:
                stats = []
            
            return {
                "report_type": "applications",
                "generated_at": datetime.utcnow().isoformat(),
                "status_breakdown": {
                    item["_id"]: item["count"] for item in stats
                },
                "total_applications": sum(
                    item["count"] for item in stats
                )
            }
        
        elif report_type == "jobs":
            jobs = await self.job.find(
                {"added_by": admin_email}
            ).to_list(1000)
            
            return {
                "report_type": "jobs",
                "generated_at": datetime.utcnow().isoformat(),
                "total_jobs": len(jobs),
                "jobs": [
                    {
                        "id": str(job["_id"]),
                        "title": job.get("post_name"),
                        "status": job.get("status"),
                        "created_at": (
                            job.get("created_at").isoformat()
                            if isinstance(job.get("created_at"), datetime)
                            else job.get("created_at")
                        )
                    }
                    for job in jobs[:20]
                ]
            }
        
        else:
            raise HTTPException(
                status_code=400,
                detail="Invalid report type. Use 'applications' or 'jobs'"
            )


print("✅ Custom Admin Service Loaded - Full CRUD + Application Management")
print("   ✅ Job CRUD delegated to JobService")
print("   ✅ Application management")
print("   ✅ User search (read-only)")
print("   ✅ Reports generation")