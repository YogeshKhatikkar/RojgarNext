# app/modules/admin/routes.py - COMPLETE FIXED VERSION
from fastapi import APIRouter, Depends, HTTPException, Query, Body, BackgroundTasks, UploadFile, File, Form
from typing import Optional, List
from bson import ObjectId
from datetime import datetime
import json
import logging

from app.core.services.dependencies import role_required
from app.db.connection import get_db
from .service import AdminService
from app.modules.jobs.service import JobService
from app.modules.jobs.schema import JobCreateSchema, ApplicationStatusUpdateSchema
from app.core.services.cloudinary import upload_to_cloudinary
from app.modules.notification.service import central_notification
from app.core.services.cloudinary import upload_private_file

logger = logging.getLogger(__name__)

router = APIRouter()

async def get_admin_service(db=Depends(get_db)):
    return AdminService(db)

async def get_job_service(db=Depends(get_db)):
    return JobService(db)


# ====================== ADD JOB ENDPOINTS ======================

# app/modules/admin/routes.py - REGULAR ADD JOB (without file)

@router.post("/add-job")
async def add_admin_job(
    job_data: dict = Body(...),
    background_tasks: BackgroundTasks = None,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Admin adds a new job - Direct JSON endpoint"""
    try:
        # Get admin email from user
        admin_email = user.get("email")
        if not admin_email:
            user_id = user.get("user_id")
            if user_id:
                auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
                if auth_user:
                    admin_email = auth_user.get("email")
        
        # Add added_by field
        job_data["added_by"] = admin_email or "admin@rojgarnext.com"
        
        from app.modules.jobs.schema import JobCreateSchema
        job_data_model = JobCreateSchema(**job_data)
        logger.info(f"✅ Job data validated: {job_data_model.post_name}")
        
    except Exception as e:
        logger.error(f"❌ Validation error: {e}")
        raise HTTPException(status_code=422, detail=f"Validation error in job data: {str(e)}")
    
    from app.modules.jobs.service import JobService
    job_service = JobService(db)
    
    if background_tasks is None:
        background_tasks = BackgroundTasks()
    
    return await job_service.add_job(job_data_model, background_tasks, None, user)


@router.post("/add-job-with-file")
async def add_admin_job_with_file(
    background_tasks: BackgroundTasks,
    job_data: str = Form(...),
    attachments: Optional[List[UploadFile]] = File(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Admin adds job with file attachments"""
    try:
        job_dict = json.loads(job_data)
        
        # Get admin email from user
        admin_email = user.get("email")
        if not admin_email:
            user_id = user.get("user_id")
            if user_id:
                auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
                if auth_user:
                    admin_email = auth_user.get("email")
        
        # Add added_by field
        job_dict["added_by"] = admin_email or "admin@rojgarnext.com"
        
        job_data_model = JobCreateSchema(**job_dict)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON in job_data field")
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Validation error in job data: {str(e)}")
    
    job_service = JobService(db)
    return await job_service.add_job(job_data_model, background_tasks, attachments, user)


# app/modules/admin/routes.py - FIXED upload endpoint

@router.post("/add-job-with-advertisement")
async def add_admin_job_with_advertisement(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    job_data: str = Form(...),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    Admin adds job with advertisement file upload - WITH FILE SIZE VALIDATION
    """
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Advertisement file is required")
    
    # ✅ FIXED: Correct way to get file size in FastAPI
    MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB
    
    # Read file content to check size
    file_content = await file.read()
    file_size = len(file_content)
    
    # Reset file position for later upload
    await file.seek(0)
    
    if file_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max size: {MAX_FILE_SIZE // (1024*1024)}MB, Your file: {file_size // (1024*1024)}MB"
        )
    
    try:
        job_dict = json.loads(job_data)
        
        # Get admin email from user
        admin_email = user.get("email")
        if not admin_email:
            user_id = user.get("user_id")
            if user_id and ObjectId.is_valid(user_id):
                auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
                if auth_user:
                    admin_email = auth_user.get("email")
        
        job_dict["added_by"] = admin_email or "admin@rojgarnext.com"
        
        logger.info("=" * 60)
        logger.info(f"📝 Adding job with advertisement - Admin: {admin_email}")
        logger.info(f"   Job Title: {job_dict.get('post_name')}")
        logger.info(f"   Organization: {job_dict.get('organization')}")
        logger.info(f"   File: {file.filename}")
        logger.info(f"   Size: {file_size // 1024} KB")
        logger.info("=" * 60)
        
        from app.modules.jobs.schema import JobCreateSchema
        from app.core.services.cloudinary import upload_private_file
        
        job_data_model = JobCreateSchema(**job_dict)
        job_dict_for_insert = job_data_model.model_dump(exclude_none=True, by_alias=True)
        
        # Handle location
        use_current_location = job_dict_for_insert.get("use_current_location", False)
        
        if use_current_location:
            from app.models.job_model import get_admin_current_location
            admin_location = await get_admin_current_location(admin_email, db)
            if admin_location:
                job_dict_for_insert["job_location"] = admin_location
                logger.info(f"📍 Using admin's current location: {admin_location.get('location_name')}")
        
        # Insert job to get ID
        result = await db.job.insert_one(job_dict_for_insert)
        job_id = str(result.inserted_id)
        
        logger.info(f"📝 Job created with ID: {job_id}")
        
        # Upload file as PRIVATE
        upload_result = await upload_private_file(
            file=file,
            folder="jobs/advertisements",
            job_id=job_id,
            organization=job_dict.get("organization", "company"),
            post_name=job_dict.get("post_name", "job")
        )
        
        # Update job with advertisement URLs
        update_data = {
            "advertisement_url": upload_result["url"],
            "advertisement_download_url": upload_result["download_url"],
            "advertisement_name": file.filename,
            "advertisement_storage": upload_result.get("storage", "cloudinary"),
            "advertisement_public_id": upload_result.get("public_id"),
            "advertisement_resource_type": upload_result.get("resource_type", "raw"),
            "advertisement_is_public": False,
            "advertisement_is_pdf": upload_result.get("is_pdf", False),
            "advertisement_folder_path": upload_result.get("folder_path"),
            "advertisement_file_size": file_size,
        }
        
        await db.job.update_one(
            {"_id": ObjectId(job_id)},
            {"$set": update_data}
        )
        
        logger.info(f"✅ Job {job_id} updated with advertisement")
        
        # Get the complete job document
        job_doc = await db.job.find_one({"_id": ObjectId(job_id)})
        
        # Send notifications
        publisher_role = user.get("role", "admin").lower()
        if publisher_role == "custom_admin":
            publisher_role = "customadmin"
        
        from app.modules.notification.service import central_notification
        await central_notification.notify_new_job(job_doc, background_tasks, publisher_role=publisher_role)
        
        return {
            "success": True,
            "message": "Job added successfully with private advertisement",
            "job_id": job_id,
            "job_title": job_dict.get('post_name'),
            "advertisement_url": upload_result["url"],
            "advertisement_download_url": upload_result["download_url"],
            "file_size_kb": file_size // 1024,
            "is_pdf": upload_result.get("is_pdf", False)
        }
        
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid JSON: {str(e)}")
    except Exception as e:
        logger.error(f"Error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed: {str(e)}")
# ====================== JOB MANAGEMENT ENDPOINTS ======================

@router.get("/jobs")
async def get_admin_jobs(
    status: Optional[str] = Query(None, pattern="^(open|closed|filled)$"),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Get all jobs posted by the logged-in admin"""
    try:
        admin_email = user.get("email")
        
        if not admin_email:
            user_id = user.get("user_id")
            if user_id:
                auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
                if auth_user:
                    admin_email = auth_user.get("email")
        
        if not admin_email:
            raise HTTPException(status_code=400, detail="Admin email not found")
        
        logger.info(f"🔍 Fetching jobs for admin: {admin_email}")
        
        job_service = JobService(db)
        return await job_service.get_admin_jobs(admin_email)
        
    except Exception as e:
        logger.error(f"❌ Error in get_admin_jobs: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/jobs/{job_id}")
async def get_admin_job_detail(
    job_id: str,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Get single job details"""
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    admin_email = user.get("email")
    if not admin_email:
        user_id = user.get("user_id")
        if user_id:
            auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
            if auth_user:
                admin_email = auth_user.get("email")
    
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    if job.get("added_by") != admin_email and user.get("role") != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    job["_id"] = str(job["_id"])
    if "created_at" in job and job["created_at"]:
        job["created_at"] = job["created_at"].isoformat() if isinstance(job["created_at"], datetime) else job["created_at"]
    
    applications_count = await db.applications.count_documents({"job_id": job_id})
    job["applications_count"] = applications_count
    
    return job


@router.put("/jobs/{job_id}")
async def update_admin_job(
    job_id: str,
    job_data: dict = Body(...),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Update existing job"""
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    admin_email = user.get("email")
    if not admin_email:
        user_id = user.get("user_id")
        if user_id:
            auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
            if auth_user:
                admin_email = auth_user.get("email")
    
    if job.get("added_by") != admin_email and user.get("role") != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    job_service = JobService(db)
    return await job_service.update_job(job_id, job_data, admin_email, user.get("role", "").lower())


@router.delete("/jobs/{job_id}")
async def delete_admin_job(
    job_id: str,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Delete job and all associated applications"""
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    admin_email = user.get("email")
    if not admin_email:
        user_id = user.get("user_id")
        if user_id:
            auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
            if auth_user:
                admin_email = auth_user.get("email")
    
    if job.get("added_by") != admin_email and user.get("role") != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    job_service = JobService(db)
    return await job_service.delete_job(job_id, admin_email, user.get("role", "").lower())


# ====================== APPLICATION MANAGEMENT ENDPOINTS ======================

@router.get("/applications")
async def get_admin_applications(
    status: Optional[str] = Query(None, pattern="^(pending|shortlisted|interview|offered|rejected)$"),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Get all applications for jobs posted by the logged-in admin"""
    try:
        admin_email = user.get("email")
        if not admin_email:
            user_id = user.get("user_id")
            if user_id:
                auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
                if auth_user:
                    admin_email = auth_user.get("email")
        
        if not admin_email:
            raise HTTPException(status_code=400, detail="Admin email not found")
        
        job_service = JobService(db)
        return await job_service.get_admin_applications(admin_email, status)
        
    except Exception as e:
        logger.error(f"Error in get_admin_applications: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# app/modules/admin/routes.py - UPDATE APPLICATION STATUS ENDPOINT

@router.put("/applications/{application_id}/status")
async def update_application_status(
    application_id: str,
    status: str = Query(..., pattern="^(pending|shortlisted|interview|offered|rejected|submitted|pending_verification|verification_successful|verification_rejected)$"),
    notes: Optional[str] = None,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    Update application status - ONLY changes application status, not payment verification
    Sends notifications to BOTH user and admin
    """
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
    admin_email = user.get("email")
    if not admin_email:
        user_id = user.get("user_id")
        if user_id:
            auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
            if auth_user:
                admin_email = auth_user.get("email")
    
    # Permission check
    if job and job.get("added_by") != admin_email and user.get("role") != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    old_status = application.get("status", "unknown")
    
    # Update only application status
    update_data = {
        "status": status,
        "last_status_update": datetime.utcnow(),
        "last_updated_by": admin_email,
        "updated_at": datetime.utcnow()
    }
    
    if notes:
        update_data["admin_notes"] = notes
    
    result = await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Application not found or status unchanged")
    
    # ✅ SEND NOTIFICATION TO BOTH USER AND ADMIN
    try:
        from app.modules.notification.service import central_notification
        
        # Send to user (applicant)
        applicant_email = application.get("applicant_email")
        if applicant_email:
            status_messages = {
                "shortlisted": "🎉 Congratulations! You have been shortlisted for this position.",
                "interview": "📞 Great news! You have been selected for an interview.",
                "offered": "🎊 Congratulations! You have received a job offer.",
                "rejected": "📝 Thank you for your interest. Your application has not been selected.",
                "submitted": "✅ Your application document has been submitted successfully.",
                "pending_verification": "⏳ Your payment is pending verification. Please wait for admin approval.",
                "verification_successful": "✅ Your payment has been verified successfully! Application submitted.",
                "verification_rejected": "❌ Your payment verification was rejected. Please re-apply with correct payment details."
            }
            
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title=f"Application Status: {status.upper()}",
                message=status_messages.get(status, f"Your application status has been updated to {status}."),
                metadata={"application_id": application_id, "job_title": job.get("post_name") if job else "", "old_status": old_status, "new_status": status},
                send_email=True,
                send_websocket=True
            )
            
            logger.info(f"📧 Status notification sent to applicant: {applicant_email}")
        
        # Send to admin (job poster)
        admin_email = job.get("added_by") if job else None
        if admin_email:
            await central_notification.send_notification(
                user_ids=[admin_email],
                notification_type="admin_alert",
                title=f"📋 Application Status Changed: {job.get('post_name', 'Job') if job else 'Job'}",
                message=f"Application by {application.get('applicant_name', 'Candidate')} changed from {old_status} to {status}",
                metadata={"application_id": application_id, "applicant_email": applicant_email, "old_status": old_status, "new_status": status},
                send_email=True,
                send_websocket=True
            )
            logger.info(f"📧 Status notification sent to admin: {admin_email}")
            
    except Exception as e:
        logger.error(f"Failed to send status notification: {e}")
    
    return {
        "success": True,
        "message": f"Application status updated from {old_status} to {status}",
        "application_id": application_id,
        "status": status,
        "old_status": old_status,
        "updated_by": admin_email
    }


@router.post("/applications/bulk-status")
async def bulk_update_status(
    application_ids: List[str] = Body(...),
    status: str = Body(...),
    notes: Optional[str] = Body(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Bulk update application statuses"""
    if not application_ids:
        raise HTTPException(status_code=400, detail="No applications selected")
    
    job_service = JobService(db)
    updated_count = 0
    
    for app_id in application_ids:
        if ObjectId.is_valid(app_id):
            try:
                status_data = ApplicationStatusUpdateSchema(status=status, notes=notes)
                await job_service.update_application_status(app_id, status_data, user)
                updated_count += 1
            except Exception as e:
                logger.error(f"Failed to update {app_id}: {e}")
    
    return {
        "updated_count": updated_count,
        "status": status,
        "notifications_sent": updated_count
    }


@router.get("/applications/fast-search")
async def fast_search_applications(
    query: str = Query(..., min_length=1, description="Search by email or job title"),
    status: Optional[str] = Query(None, pattern="^(pending|shortlisted|interview|offered|rejected)$"),
    limit: int = Query(20, ge=1, le=100),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """ULTRA FAST: Search applications by email or job title"""
    try:
        admin_email = user.get("email")
        if not admin_email:
            user_id = user.get("user_id")
            if user_id:
                auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
                if auth_user:
                    admin_email = auth_user.get("email")
        
        if not admin_email:
            raise HTTPException(status_code=400, detail="Admin email not found")
        
        admin_jobs = await db.job.find({"added_by": admin_email}, {"_id": 1}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        if not admin_job_ids:
            return {"applications": [], "total": 0}
        
        search_query = {
            "job_id": {"$in": admin_job_ids},
            "$or": [
                {"applicant_email": {"$regex": query, "$options": "i"}},
                {"job_title": {"$regex": query, "$options": "i"}},
                {"applicant_name": {"$regex": query, "$options": "i"}}
            ]
        }
        
        if status:
            search_query["status"] = status
        
        apps = await db.applications.find(search_query).sort("applied_at", -1).limit(limit).to_list(limit)
        
        results = []
        for app in apps:
            results.append({
                "_id": str(app["_id"]),
                "job_title": app.get("job_title", ""),
                "organization": app.get("organization", ""),
                "applicant_name": app.get("applicant_name", ""),
                "applicant_email": app.get("applicant_email", ""),
                "status": app.get("status", "pending"),
                "match_score": app.get("match_score", 0),
                "applied_at": app.get("applied_at").isoformat() if app.get("applied_at") else None,
            })
        
        return {
            "applications": results,
            "total": len(results),
            "search_query": query
        }
        
    except Exception as e:
        logger.error(f"Error in fast_search_applications: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/applications/{application_id}/detail")
async def get_application_detail(
    application_id: str,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Get detailed application data including user profile"""
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    admin_email = user.get("email")
    if not admin_email:
        user_id = user.get("user_id")
        if user_id:
            auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
            if auth_user:
                admin_email = auth_user.get("email")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))}) if application.get("job_id") else None
    if job and job.get("added_by") != admin_email and user.get("role") != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    applicant_email = application.get("applicant_email")
    profile = await db.profile.find_one({"email": applicant_email}) if applicant_email else None
    user_auth = await db.auth.find_one({"email": applicant_email}) if applicant_email else None
    
    application["_id"] = str(application["_id"])
    application["job_id"] = str(application["job_id"]) if application.get("job_id") else None
    
    if "applied_at" in application and application["applied_at"]:
        if isinstance(application["applied_at"], datetime):
            application["applied_at"] = application["applied_at"].isoformat()
    
    return {
        "application": application,
        "user_profile": {
            "_id": str(profile["_id"]) if profile else None,
            "full_name": profile.get("full_name") if profile else None,
            "phone": profile.get("phone") if profile else None,
            "skills": profile.get("skills", []) if profile else [],
            "experience": profile.get("experience", []) if profile else [],
            "academic_records": profile.get("academic_records", []) if profile else [],
            "summary": profile.get("summary") if profile else None,
            "resume_url": profile.get("additional_details", {}).get("resume_url") if profile else None
        } if profile else None,
        "user_auth": {
            "email": user_auth.get("email") if user_auth else None,
            "name": user_auth.get("name") if user_auth else None,
            "is_email_verified": user_auth.get("is_email_verified") if user_auth else False
        } if user_auth else None,
        "job": {
            "_id": str(job["_id"]),
            "post_name": job.get("post_name"),
            "organization": job.get("organization"),
            "location": job.get("location"),
            "job_type": job.get("job_type"),
            "description": job.get("description")
        } if job else None
    }


# ====================== AI ENDPOINTS ======================

@router.get("/ai/dashboard")
async def get_admin_ai_dashboard(
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Get AI-powered dashboard statistics"""
    try:
        admin_email = user.get("email")
        if not admin_email:
            user_id = user.get("user_id")
            if user_id:
                auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
                if auth_user:
                    admin_email = auth_user.get("email")
        
        if not admin_email:
            raise HTTPException(status_code=400, detail="Admin email not found")
        
        admin_jobs = await db.job.find({"added_by": admin_email}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        total_applications = 0
        pending_applications = 0
        shortlisted_applications = 0
        interview_applications = 0
        offered_applications = 0
        rejected_applications = 0
        
        if admin_job_ids:
            total_applications = await db.applications.count_documents({"job_id": {"$in": admin_job_ids}})
            pending_applications = await db.applications.count_documents({"job_id": {"$in": admin_job_ids}, "status": "pending"})
            shortlisted_applications = await db.applications.count_documents({"job_id": {"$in": admin_job_ids}, "status": "shortlisted"})
            interview_applications = await db.applications.count_documents({"job_id": {"$in": admin_job_ids}, "status": "interview"})
            offered_applications = await db.applications.count_documents({"job_id": {"$in": admin_job_ids}, "status": "offered"})
            rejected_applications = await db.applications.count_documents({"job_id": {"$in": admin_job_ids}, "status": "rejected"})
        
        from datetime import timedelta
        last_30_days = datetime.utcnow() - timedelta(days=30)
        recent_apps = await db.applications.count_documents({
            "job_id": {"$in": admin_job_ids},
            "created_at": {"$gte": last_30_days}
        }) if admin_job_ids else 0
        
        pipeline = []
        if admin_job_ids:
            pipeline = [
                {"$match": {"job_id": {"$in": admin_job_ids}}},
                {"$group": {"_id": "$job_title", "count": {"$sum": 1}}},
                {"$sort": {"count": -1}},
                {"$limit": 5}
            ]
            top_jobs = await db.applications.aggregate(pipeline).to_list(5)
        else:
            top_jobs = []
        
        return {
            "total_applications": total_applications,
            "pending_applications": pending_applications,
            "shortlisted_applications": shortlisted_applications,
            "interview_applications": interview_applications,
            "offered_applications": offered_applications,
            "rejected_applications": rejected_applications,
            "auto_shortlist_ready": pending_applications,
            "high_risk_applications": 0,
            "trend_direction": "increasing" if recent_apps > 50 else "stable",
            "predicted_next_30_days": recent_apps * 2,
            "top_job_categories": [{"category": job["_id"], "count": job["count"]} for job in top_jobs],
            "admin_jobs_count": len(admin_jobs)
        }
        
    except Exception as e:
        logger.error(f"Error in AI dashboard: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/ai/applications/ranked")
async def get_ranked_applications(
    limit: int = Query(50, ge=1, le=200),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Get AI-ranked applications"""
    try:
        admin_email = user.get("email")
        if not admin_email:
            user_id = user.get("user_id")
            if user_id:
                auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
                if auth_user:
                    admin_email = auth_user.get("email")
        
        if not admin_email:
            raise HTTPException(status_code=400, detail="Admin email not found")
        
        admin_jobs = await db.job.find({"added_by": admin_email}, {"_id": 1}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        if not admin_job_ids:
            return {"ranked_applications": [], "total": 0}
        
        applications = await db.applications.find({
            "job_id": {"$in": admin_job_ids}
        }).sort("match_score", -1).limit(limit).to_list(limit)
        
        ranked_apps = []
        for app in applications:
            ranked_apps.append({
                "application_id": str(app["_id"]),
                "candidate_name": app.get("applicant_name", "N/A"),
                "candidate_email": app.get("applicant_email", "N/A"),
                "job_title": app.get("job_title", "N/A"),
                "match_score": app.get("match_score", 0),
                "status": app.get("status", "pending"),
                "applied_at": app.get("applied_at").isoformat() if app.get("applied_at") else None
            })
        
        return {
            "ranked_applications": ranked_apps,
            "total": len(ranked_apps),
            "ai_ranked": True
        }
        
    except Exception as e:
        logger.error(f"Error in ranked applications: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ====================== TEST ENDPOINTS ======================

@router.get("/test-google-drive")
async def test_google_drive_connection(
    user=Depends(role_required(["admin", "superadmin"]))
):
    """Test Google Drive connection"""
    from app.core.services.google_drive import google_drive_service
    
    result = await google_drive_service.test_connection()
    return result


# app/modules/admin/routes.py - Add this endpoint

@router.post("/add-job-bulk")
async def add_admin_job_bulk(
    job_data: dict = Body(...),
    background_tasks: BackgroundTasks = None,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Admin adds a new job with BULK notifications (FAST)"""
    try:
        admin_email = user.get("email")
        if not admin_email:
            user_id = user.get("user_id")
            if user_id:
                auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
                if auth_user:
                    admin_email = auth_user.get("email")
        
        job_data["added_by"] = admin_email or "admin@rojgarnext.com"
        
        from app.modules.jobs.schema import JobCreateSchema
        job_data_model = JobCreateSchema(**job_data)
        
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Validation error: {str(e)}")
    
    from app.modules.jobs.service import JobService
    job_service = JobService(db)
    
    if background_tasks is None:
        background_tasks = BackgroundTasks()
    
    return await job_service.add_job(job_data_model, background_tasks, None, user)


@router.get("/pending-payments")
async def get_pending_payments(
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """List all payments with verification_status = 'pending'."""
    from bson import ObjectId

    pending = await db.payments.find({"verification_status": "pending"}).to_list(100)
    for p in pending:
        p["_id"] = str(p["_id"])
        # fetch job title for display
        job = await db.job.find_one({"_id": ObjectId(p["job_id"])})
        p["job_title"] = job.get("post_name") if job else "Unknown"
        if "transaction_date" in p and p["transaction_date"]:
            p["transaction_date"] = p["transaction_date"].isoformat()
    return {"payments": pending}


# app/modules/admin/routes.py - UPDATED verify-payment endpoint

@router.post("/verify-payment/{application_id}")
async def admin_verify_payment(
    application_id: str,
    action: str = Query(..., pattern="^(approve|reject)$"),
    notes: Optional[str] = Query(None),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Admin approves or rejects a pending payment verification.
    Updates application directly - NO payments table.
    Sends notifications to BOTH user and admin with BELL ICON updates.
    """
    from app.modules.notification.service import central_notification
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(400, "Invalid application ID")
    
    # Try job application first
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    application_type = "job"
    
    if not application:
        application = await db.services.find_one({"_id": ObjectId(application_id)})
        application_type = "service"
    
    if not application:
        raise HTTPException(404, "Application not found")
    
    if application.get("payment_verification_status") != "pending":
        return {
            "success": False,
            "message": f"Payment already {application.get('payment_verification_status')}"
        }
    
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(400, "Admin email missing")
    
    user_email = application.get("applicant_email") or application.get("user_email")
    amount = application.get("payment_amount", 0)
    transaction_id = application.get("transaction_id")
    job_id = application.get("job_id")
    service_id = application.get("service_id")
    job_title = application.get("job_title", "Job Application")
    service_name = application.get("service_name", "Service")
    job_poster_email = application.get("added_by") if application_type == "job" else None
    
    if action == "approve":
        # ✅ Update application directly
        if application_type == "job":
            await db.applications.update_one(
                {"_id": ObjectId(application_id)},
                {
                    "$set": {
                        "payment_verification_status": "approved",
                        "status": "verification_successful",
                        "payment_verified_by": admin_email,
                        "payment_verified_at": datetime.utcnow(),
                        "verification_notes": notes if notes else "Payment approved by admin",
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            status_msg = "verification_successful"
            title = f"✅ Payment Verified Successfully: {job_title}"
            message = f"Your payment of ₹{amount} for '{job_title}' has been verified successfully. Your application is now submitted."
        else:
            await db.services.update_one(
                {"_id": ObjectId(application_id)},
                {
                    "$set": {
                        "payment_verification_status": "approved",
                        "status": "approved",
                        "payment_verified_by": admin_email,
                        "payment_verified_at": datetime.utcnow(),
                        "verification_notes": notes if notes else "Payment approved by admin",
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            status_msg = "approved"
            title = f"✅ Service Payment Verified: {service_name}"
            message = f"Your payment of ₹{amount} for '{service_name}' has been verified successfully."
        
        # Send notification to USER
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=application_id,
            metadata={
                "status": status_msg,
                "amount": amount,
                "transaction_id": transaction_id,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        logger.info(f"📧 Payment approval notification sent to user: {user_email}")
        
        # Send notification to ADMIN (job poster)
        if job_poster_email and job_poster_email != admin_email:
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title="💰 Payment Approved",
                message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been APPROVED by {admin_email}.",
                related_id=application_id,
                metadata={
                    "status": "payment_approved",
                    "amount": amount,
                    "job_title": job_title,
                    "applicant_email": user_email,
                    "approved_by": admin_email,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"📧 Payment approval notification sent to admin: {job_poster_email}")
        
        # Send notification to ALL CUSTOMADMINS
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title="💰 Payment Approved",
                    message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been APPROVED by {admin_email}",
                    related_id=application_id,
                    metadata={
                        "status": "payment_approved",
                        "amount": amount,
                        "job_title": job_title,
                        "applicant_email": user_email,
                        "approved_by": admin_email,
                        "show_blue_bell": True
                    },
                    send_email=True,
                    send_websocket=True
                )
                logger.info(f"📧 Payment approval notification sent to customadmin: {ca_email}")
        
        return_message = "Payment approved successfully. Payment verification COMPLETED."
        
    else:  # reject
        if not notes:
            notes = "Payment rejected by admin - Please contact support"
        
        if application_type == "job":
            await db.applications.update_one(
                {"_id": ObjectId(application_id)},
                {
                    "$set": {
                        "payment_verification_status": "rejected",
                        "status": "verification_rejected",
                        "payment_verified_by": admin_email,
                        "payment_verified_at": datetime.utcnow(),
                        "rejection_reason": notes,
                        "verification_notes": notes,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            status_msg = "verification_rejected"
            title = f"❌ Payment Verification Failed: {job_title}"
            message = f"Your payment of ₹{amount} for '{job_title}' has been REJECTED.\nReason: {notes}"
        else:
            await db.services.update_one(
                {"_id": ObjectId(application_id)},
                {
                    "$set": {
                        "payment_verification_status": "rejected",
                        "status": "rejected",
                        "payment_verified_by": admin_email,
                        "payment_verified_at": datetime.utcnow(),
                        "rejection_reason": notes,
                        "verification_notes": notes,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            status_msg = "rejected"
            title = f"❌ Service Payment Failed: {service_name}"
            message = f"Your payment of ₹{amount} for '{service_name}' has been REJECTED.\nReason: {notes}"
        
        # Send notification to USER
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=application_id,
            metadata={
                "status": status_msg,
                "amount": amount,
                "rejection_reason": notes,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        logger.info(f"📧 Payment rejection notification sent to user: {user_email}")
        
        # Send notification to ADMIN (job poster)
        if job_poster_email and job_poster_email != admin_email:
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title="💰 Payment Rejected",
                message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been REJECTED by {admin_email}.\nReason: {notes}",
                related_id=application_id,
                metadata={
                    "status": "payment_rejected",
                    "amount": amount,
                    "job_title": job_title,
                    "applicant_email": user_email,
                    "rejected_by": admin_email,
                    "rejection_reason": notes,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"📧 Payment rejection notification sent to admin: {job_poster_email}")
        
        # Send notification to ALL CUSTOMADMINS
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title="💰 Payment Rejected",
                    message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been REJECTED by {admin_email}.\nReason: {notes}",
                    related_id=application_id,
                    metadata={
                        "status": "payment_rejected",
                        "amount": amount,
                        "job_title": job_title,
                        "applicant_email": user_email,
                        "rejected_by": admin_email,
                        "rejection_reason": notes,
                        "show_blue_bell": True
                    },
                    send_email=True,
                    send_websocket=True
                )
                logger.info(f"📧 Payment rejection notification sent to customadmin: {ca_email}")
        
        return_message = f"Payment rejected. Payment verification FAILED. Reason: {notes}"
    
    return {
        "success": True,
        "message": return_message,
        "application_id": application_id,
        "action": action,
        "notes": notes,
        "application_status_updated": True,
        "notifications_sent": True
    }


@router.get("/pending-payments")
async def get_pending_payments(
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Get pending payment verifications from applications/services
    """
    # Get pending job applications
    job_pending = await db.applications.find({
        "payment_verification_status": "pending"
    }).to_list(100)
    
    # Get pending service applications
    service_pending = await db.services.find({
        "payment_verification_status": "pending"
    }).to_list(100)
    
    # Format job applications
    job_results = []
    for app in job_pending:
        job = await db.job.find_one({"_id": ObjectId(app["job_id"])}) if app.get("job_id") else None
        job_results.append({
            "id": str(app["_id"]),
            "type": "job",
            "user_email": app.get("applicant_email"),
            "user_name": app.get("applicant_name", "Unknown"),
            "job_title": app.get("job_title", "Job"),
            "organization": app.get("organization", ""),
            "amount": app.get("payment_amount", 0),
            "transaction_id": app.get("transaction_id", "N/A"),
            "screenshot_url": app.get("payment_receipt_url"),
            "status": app.get("status", "pending_verification"),
            "created_at": app.get("created_at")
        })
    
    # Format service applications
    service_results = []
    for app in service_pending:
        service_results.append({
            "id": str(app["_id"]),
            "type": "service",
            "user_email": app.get("user_email"),
            "user_name": app.get("user_name", "Unknown"),
            "service_name": app.get("service_name", "Service"),
            "sub_service_name": app.get("sub_service_name", ""),
            "amount": app.get("payment_amount", 0),
            "transaction_id": app.get("transaction_id", "N/A"),
            "screenshot_url": app.get("screenshot_url") or app.get("payment_receipt_url"),
            "status": app.get("status", "pending_verification"),
            "created_at": app.get("created_at")
        })
    
    return {
        "payments": job_results + service_results,
        "total": len(job_results) + len(service_results)
    }

print("✅ Admin Routes Loaded - Delegates to centralized JobService")