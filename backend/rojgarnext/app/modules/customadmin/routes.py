# app/modules/customadmin/routes.py - COMPLETE FIXED VERSION
# WITH FULL BELL NOTIFICATION FOR ALL ACTIONS
# ✅ FIXED: submit-document and final-submit-with-document now properly save document URLs

from fastapi import APIRouter, Depends, HTTPException, Query, Body, BackgroundTasks, UploadFile, File, Form
from typing import Optional, List
from bson import ObjectId
from datetime import datetime
import json
import logging

from app.core.services.dependencies import get_current_user
from app.db.connection import get_db
from .service import CustomAdminService
from app.modules.jobs.service import JobService
from app.modules.jobs.schema import JobCreateSchema, ApplicationStatusUpdateSchema
from app.modules.notification.service import central_notification
from app.core.services.cloudinary import upload_to_cloudinary, upload_user_document, upload_private_file
from app.core.services.cloudinary import delete_from_cloudinary

logger = logging.getLogger(__name__)

# ✅ ROUTER MUST BE DEFINED AT TOP LEVEL
router = APIRouter()


async def get_customadmin_service(db=Depends(get_db)):
    return CustomAdminService(db)


def custom_admin_required(current_user=Depends(get_current_user)):
    """Check if user has customadmin access (case-insensitive)"""
    user_role = current_user.get("role", "").lower()
    allowed_roles = ["customadmin", "custom_admin", "admin", "superadmin"]
    if user_role not in allowed_roles:
        raise HTTPException(
            status_code=403, 
            detail=f"Access denied. Required roles: customadmin, Your role: {user_role}"
        )
    return current_user


@router.get("/verify-access")
async def verify_customadmin_access(user=Depends(custom_admin_required)):
    return {"has_access": True, "role": user.get("role", "").lower(), "message": "Custom Admin access granted"}


@router.get("/dashboard")
async def get_customadmin_dashboard(
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_dashboard_stats(admin_email)


@router.get("/stats")
async def get_customadmin_stats(
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_dashboard_stats(admin_email)


@router.get("/jobs")
async def get_customadmin_jobs(
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_admin_jobs(admin_email)


@router.get("/jobs/{job_id}")
async def get_customadmin_job_detail(
    job_id: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_job_detail(job_id, admin_email)


@router.post("/jobs")
async def add_customadmin_job(
    job_data: dict = Body(...),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    job_data["added_by"] = admin_email
    job_data["created_at"] = datetime.utcnow().isoformat()
    job_data["updated_at"] = datetime.utcnow().isoformat()
    job_data["status"] = "open"
    
    job_data.setdefault("geolocation", [0, 0])
    job_data.setdefault("required_skills", [])
    job_data.setdefault("nice_to_have_skills", [])
    job_data.setdefault("benefits", [])
    job_data.setdefault("tags", [])
    job_data.setdefault("attachments", [])
    job_data.setdefault("multiple_posts", [])
    job_data.setdefault("job_level", "mid")
    job_data.setdefault("salary_currency", "INR")
    job_data.setdefault("experience_min_years", 0)
    job_data.setdefault("post_date", datetime.utcnow().strftime("%Y-%m-%d"))
    
    apply_url = job_data.get("apply_with_us_url")
    if apply_url and str(apply_url).strip() and str(apply_url).strip() != '#':
        job_data["has_apply_with_us"] = True
    
    logger.info(f"✅ Custom Admin adding job - Email: {admin_email}")
    logger.info(f"📝 Job: {job_data.get('post_name')}")
    
    return await service.add_job(job_data, admin_email, background_tasks)


@router.put("/jobs/{job_id}")
async def update_customadmin_job(
    job_id: str,
    job_data: dict = Body(...),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.update_job(job_id, job_data, admin_email)


@router.delete("/jobs/{job_id}")
async def delete_customadmin_job(
    job_id: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.delete_job(job_id, admin_email)


# ====================== UPLOAD ADVERTISEMENT ENDPOINT ======================

@router.post("/jobs/upload-advertisement")
async def customadmin_upload_advertisement(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    job_data: str = Form(...),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """CustomAdmin upload job advertisement - WITH FILE SIZE VALIDATION"""
    
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Advertisement file is required")
    
    logger.info("=" * 60)
    logger.info(f"📤 CustomAdmin Upload Advertisement")
    logger.info(f"   Admin: {admin_email}")
    logger.info(f"   File: {file.filename}")
    logger.info("=" * 60)
    
    MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB
    
    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)
    
    if file_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max size: {MAX_FILE_SIZE // (1024*1024)}MB, Your file: {file_size // (1024*1024)}MB"
        )
    
    try:
        job_dict = json.loads(job_data)
        job_dict["added_by"] = admin_email
        job_dict["created_at"] = datetime.utcnow().isoformat()
        job_dict["updated_at"] = datetime.utcnow().isoformat()
        job_dict["status"] = "open"
        job_dict["required_skills"] = job_dict.get("required_skills", [])
        
        apply_url = job_dict.get("apply_with_us_url")
        if apply_url and str(apply_url).strip() and str(apply_url).strip() != '#':
            job_dict["has_apply_with_us"] = True
        
        use_current_location = job_dict.get("use_current_location", False)
        
        if use_current_location:
            from app.models.job_model import get_admin_current_location
            admin_location = await get_admin_current_location(admin_email, db)
            if admin_location:
                job_dict["job_location"] = admin_location
                logger.info(f"📍 Using admin's current location: {admin_location.get('location_name')}")
        
        result = await db.job.insert_one(job_dict)
        job_id = str(result.inserted_id)
        
        logger.info(f"📝 Job created with ID: {job_id}")
        
        upload_result = await upload_private_file(
            file=file,
            folder="jobs/advertisements",
            job_id=job_id,
            organization=job_dict.get("organization", "company"),
            post_name=job_dict.get("post_name", "job")
        )
        
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
        
        job_doc = await db.job.find_one({"_id": ObjectId(job_id)})
        
        publisher_role = user.get("role", "customadmin").lower()
        if publisher_role == "custom_admin":
            publisher_role = "customadmin"
        
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
        logger.error(f"Upload error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to add job: {str(e)}")


# ====================== APPLICATION MANAGEMENT ======================

@router.get("/applications")
async def get_customadmin_applications(
    status: Optional[str] = Query(None, pattern="^(all|pending|shortlisted|interview|offered|rejected|submitted|review_application|final_submitted)$"),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_admin_applications(admin_email, status)


@router.get("/applications/{application_id}")
async def get_customadmin_application_detail(
    application_id: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_application_detail(application_id, admin_email)


@router.put("/applications/{application_id}/status")
async def update_customadmin_application_status(
    application_id: str,
    status: str = Query(..., pattern="^(pending|shortlisted|interview|offered|rejected|submitted|review_application|final_submit)$"),
    notes: Optional[str] = Query(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    Update application status with BELL NOTIFICATION
    Supports: pending, shortlisted, interview, offered, rejected, submitted, review_application, final_submit
    """
    admin_email = user.get("email")
    admin_name = user.get("name", "Admin")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    if job.get("added_by") != admin_email:
        raise HTTPException(status_code=403, detail="Access denied")
    
    old_status = application.get("status", "unknown")
    applicant_email = application.get("applicant_email")
    
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
    
    # Status messages for user
    status_messages = {
        "shortlisted": "🎉 Congratulations! You have been shortlisted for this position.",
        "interview": "📞 Great news! You have been selected for an interview.",
        "offered": "🎊 Congratulations! You have received a job offer.",
        "rejected": "📝 Thank you for your interest. Your application has not been selected.",
        "submitted": "✅ Your application document has been submitted successfully.",
        "review_application": "📋 Your application is under review. Please wait for further updates.",
        "final_submit": "✅ Your application has been FINAL SUBMITTED!",
        "pending_verification": "⏳ Your payment is pending verification. Please wait for admin approval.",
        "verification_successful": "✅ Your payment has been verified successfully!",
        "verification_rejected": "❌ Your payment verification was rejected."
    }
    
    # Send BELL notification to applicant
    if applicant_email:
        await central_notification.send_notification(
            user_ids=[applicant_email],
            notification_type="application_status",
            title=f"Application Status: {status.upper()}",
            message=status_messages.get(status, f"Your application status has been updated to {status} by {admin_name}."),
            related_id=application_id,
            metadata={
                "application_id": application_id,
                "job_title": job.get("post_name"),
                "old_status": old_status,
                "new_status": status,
                "admin_notes": notes,
                "admin_name": admin_name,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        logger.info(f"🔔 BLUE bell notification sent to applicant: {applicant_email}")
    
    # Send notification to job poster
    job_poster_email = job.get("added_by")
    if job_poster_email and job_poster_email != admin_email:
        await central_notification.send_notification(
            user_ids=[job_poster_email],
            notification_type="admin_alert",
            title=f"Application Status Updated: {status.upper()}",
            message=f"Application by {applicant_email} for '{job.get('post_name', 'Job')}' has been updated to {status} by {admin_name}.",
            related_id=application_id,
            metadata={
                "job_title": job.get("post_name"),
                "applicant_email": applicant_email,
                "old_status": old_status,
                "new_status": status,
                "admin_name": admin_name,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        logger.info(f"🔔 BLUE bell notification sent to job poster: {job_poster_email}")
    
    return {
        "success": True,
        "message": f"Application status updated from {old_status} to {status}",
        "application_id": application_id,
        "status": status,
        "old_status": old_status,
        "updated_by": admin_email,
        "notifications_sent": True
    }


# ==================== REVIEW APPLICATION STATUS UPDATE ====================

@router.put("/applications/{application_id}/review-status")
async def customadmin_review_application_status(
    application_id: str,
    notes: Optional[str] = Query(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    CustomAdmin ONLY: Update application status to REVIEW_APPLICATION
    No document upload required - just status change with BELL NOTIFICATION
    """
    admin_email = user.get("email")
    admin_name = user.get("name", "Admin")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    logger.info("=" * 60)
    logger.info(f"📋 REVIEW APPLICATION STATUS UPDATE")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Admin Email: {admin_email}")
    logger.info("=" * 60)
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    try:
        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        
        old_status = application.get("status", "unknown")
        applicant_email = application.get("applicant_email")
        
        # ✅ PRESERVE existing document URL if already uploaded
        existing_doc_url = application.get("submitted_document_url")
        
        update_data = {
            "status": "review_application",
            "last_status_update": datetime.utcnow(),
            "last_updated_by": admin_email,
            "updated_at": datetime.utcnow(),
            "admin_notes": notes if notes else f"Application moved to review stage by {admin_name}"
        }
        
        # ✅ If document already exists, make sure it's preserved
        if existing_doc_url:
            update_data["submitted_document_url"] = existing_doc_url
            logger.info(f"📄 Preserved existing document URL: {existing_doc_url}")
        
        update_result = await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )
        
        logger.info(f"✅ Application status updated from {old_status} to 'review_application'")
        
        # Send BELL notification to user
        if applicant_email:
            user_title = f"📋 Application Under Review: {job.get('post_name', 'Job')}"
            user_message = f"Your application for '{job.get('post_name', 'Job')}' at {job.get('organization', 'Company')} is now under REVIEW by {admin_name}.\n\n"
            user_message += "The admin is reviewing your documents. You will be notified once the review is complete."
            if notes:
                user_message += f"\n\nAdmin Notes: {notes}"
            
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title=user_title,
                message=user_message,
                related_id=application_id,
                metadata={
                    "job_title": job.get("post_name"),
                    "status": "review_application",
                    "admin_notes": notes,
                    "admin_name": admin_name,
                    "show_blue_bell": True,
                    "submitted_document_url": existing_doc_url
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 BLUE bell notification sent to user: {applicant_email}")
        
        # Send notification to job poster
        job_poster_email = job.get("added_by")
        if job_poster_email and job_poster_email != admin_email:
            admin_title = f"📋 Application Under Review: {job.get('post_name', 'Job')}"
            admin_message = f"Application from {applicant_email} for '{job.get('post_name', 'Job')}' is now under REVIEW by {admin_name}."
            if notes:
                admin_message += f"\n\nNotes: {notes}"
            
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title=admin_title,
                message=admin_message,
                related_id=application_id,
                metadata={
                    "job_title": job.get("post_name"),
                    "applicant_email": applicant_email,
                    "status": "review_application",
                    "admin_notes": notes,
                    "admin_name": admin_name,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 BLUE bell notification sent to job poster: {job_poster_email}")
        
        return {
            "success": True,
            "message": f"Application status updated from {old_status} to review_application",
            "application_id": application_id,
            "status": "review_application",
            "old_status": old_status,
            "admin_notes": notes,
            "notifications_sent": True,
            "submitted_document_url": existing_doc_url
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in review status: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


# ==================== SUBMIT DOCUMENT - FIXED ====================

@router.post("/applications/{application_id}/submit-document")
async def customadmin_submit_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: Optional[str] = Form(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    CustomAdmin ONLY: Submit document for review with BELL NOTIFICATION
    ✅ FIXED: Properly saves submitted_document_url to application
    """
    admin_email = user.get("email")
    admin_name = user.get("name", "Admin")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    logger.info("=" * 60)
    logger.info(f"📤 SUBMIT DOCUMENT FOR REVIEW")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Admin Email: {admin_email}")
    logger.info(f"   File: {file.filename if file else 'No file'}")
    logger.info("=" * 60)
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")
    
    allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}"
        )
    
    try:
        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        applicant_email = application.get("applicant_email")
        if not applicant_email:
            raise HTTPException(status_code=404, detail="Applicant email not found")
        
        username = applicant_email.split('@')[0]
        
        job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        
        await file.seek(0)
        
        # ✅ UPLOAD TO CLOUDINARY
        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="applications"
        )
        
        logger.info(f"✅ File uploaded to Cloudinary: {upload_result['url']}")
        logger.info(f"   Public ID: {upload_result.get('public_id')}")
        logger.info(f"   File Name: {file.filename}")
        
        old_status = application.get("status", "unknown")
        
        # ✅ CRITICAL FIX: Save ALL document fields to application
        update_data = {
            "status": "review_application",  # Changed to review_application
            "last_status_update": datetime.utcnow(),
            "last_updated_by": admin_email,
            "updated_at": datetime.utcnow(),
            # ✅ THESE ARE THE CRITICAL FIELDS - MUST BE SAVED
            "submitted_document_url": upload_result["url"],
            "submitted_document_name": file.filename,
            "submitted_document_storage": upload_result.get("storage", "cloudinary"),
            "submitted_document_public_id": upload_result.get("public_id"),
            "submitted_document_resource_type": upload_result.get("resource_type", "raw"),
            "submitted_document_folder": upload_result.get("folder_path"),
            "submitted_at": datetime.utcnow(),
            "submitted_by": admin_email,
            "admin_notes": notes if notes else None
        }
        
        # Update the application
        result = await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )
        
        if result.modified_count == 0:
            logger.error(f"❌ Failed to update application {application_id}")
            raise HTTPException(status_code=500, detail="Failed to update application with document")
        
        # ✅ VERIFY the update by fetching the application again
        updated_app = await db.applications.find_one({"_id": ObjectId(application_id)})
        if updated_app:
            saved_url = updated_app.get("submitted_document_url")
            logger.info(f"✅ VERIFIED: submitted_document_url = {saved_url}")
            if saved_url is None:
                logger.error("❌ CRITICAL: submitted_document_url is still None after update!")
        
        logger.info(f"✅ Application {application_id} updated with document URL: {upload_result['url']}")
        logger.info(f"✅ Status changed from {old_status} to 'review_application'")
        
        # ==================== SEND BELL NOTIFICATION TO USER ====================
        if applicant_email:
            user_title = f"📄 Document Submitted: {job.get('post_name', 'Job')}"
            user_message = f"Your document '{file.filename}' has been submitted successfully by {admin_name} for the position '{job.get('post_name', 'Job')}' at {job.get('organization', 'Company')}."
            if notes:
                user_message += f"\n\nAdmin Notes: {notes}"
            
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title=user_title,
                message=user_message,
                related_id=application_id,
                metadata={
                    "job_title": job.get("post_name"),
                    "document_name": file.filename,
                    "admin_name": admin_name,
                    "admin_notes": notes,
                    "show_blue_bell": True,
                    "status": "review_application",
                    "submitted_document_url": upload_result["url"]
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 BLUE bell notification sent to user: {applicant_email}")
        
        # Send notification to job poster
        job_poster_email = job.get("added_by")
        if job_poster_email and job_poster_email != admin_email:
            admin_title = f"📄 Document Submitted for {job.get('post_name', 'Job')}"
            admin_message = f"Document '{file.filename}' has been submitted by {admin_name} for application from {applicant_email}"
            if notes:
                admin_message += f"\n\nNotes: {notes}"
            
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title=admin_title,
                message=admin_message,
                related_id=application_id,
                metadata={
                    "job_title": job.get("post_name"),
                    "applicant_email": applicant_email,
                    "document_name": file.filename,
                    "admin_name": admin_name,
                    "admin_notes": notes,
                    "show_blue_bell": True,
                    "submitted_document_url": upload_result["url"]
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 BLUE bell notification sent to job poster: {job_poster_email}")
        
        # Send notification to all customadmins
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title=f"📄 Document Submitted for {job.get('post_name', 'Job')}",
                    message=f"Document submitted by {admin_name} for application from {applicant_email}",
                    related_id=application_id,
                    metadata={
                        "job_title": job.get("post_name"),
                        "applicant_email": applicant_email,
                        "admin_name": admin_name,
                        "show_blue_bell": True,
                        "submitted_document_url": upload_result["url"]
                    },
                    send_email=True,
                    send_websocket=True
                )
                logger.info(f"🔔 BLUE bell notification sent to customadmin: {ca_email}")
        
        return {
            "success": True,
            "message": "Document submitted successfully! BLUE bell notifications sent.",
            "application_id": application_id,
            "submitted_document_url": upload_result["url"],
            "submitted_document_name": file.filename,
            "admin_notes": notes,
            "notifications_sent": True,
            "status": "review_application"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error submitting document: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


# ==================== FINAL SUBMIT WITH DOCUMENT - FIXED ====================

@router.post("/applications/{application_id}/final-submit-with-document")
async def customadmin_final_submit_with_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: Optional[str] = Form(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    CustomAdmin ONLY: FINAL SUBMIT application with document
    ✅ FIXED: Properly saves final_document_url to application
    """
    admin_email = user.get("email")
    admin_name = user.get("name", "Admin")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    logger.info("=" * 60)
    logger.info(f"📤 FINAL SUBMIT WITH DOCUMENT")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Admin Email: {admin_email}")
    logger.info(f"   File: {file.filename}")
    logger.info("=" * 60)
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")
    
    allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}"
        )
    
    try:
        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        applicant_email = application.get("applicant_email")
        if not applicant_email:
            raise HTTPException(status_code=404, detail="Applicant email not found")
        
        username = applicant_email.split('@')[0]
        
        job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Delete old document from Cloudinary if exists
        old_public_id = application.get("submitted_document_public_id")
        if old_public_id:
            old_resource_type = application.get("submitted_document_resource_type", "raw")
            await delete_from_cloudinary(old_public_id, old_resource_type)
            logger.info(f"🗑️ Old document deleted: {old_public_id}")
        
        await file.seek(0)
        
        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="applications"
        )
        
        logger.info(f"✅ NEW file uploaded to Cloudinary: {upload_result['url']}")
        logger.info(f"   Public ID: {upload_result.get('public_id')}")
        logger.info(f"   File Name: {file.filename}")
        
        old_status = application.get("status", "unknown")
        
        # ✅ CRITICAL FIX: Save ALL document fields to application
        update_data = {
            "status": "final_submitted",
            "last_status_update": datetime.utcnow(),
            "last_updated_by": admin_email,
            "updated_at": datetime.utcnow(),
            # ✅ THESE ARE THE CRITICAL FIELDS
            "submitted_document_url": upload_result["url"],
            "submitted_document_name": file.filename,
            "submitted_document_storage": upload_result.get("storage", "cloudinary"),
            "submitted_document_public_id": upload_result.get("public_id"),
            "submitted_document_resource_type": upload_result.get("resource_type", "raw"),
            "submitted_document_folder": upload_result.get("folder_path"),
            "submitted_at": datetime.utcnow(),
            "submitted_by": admin_email,
            "final_submitted_at": datetime.utcnow(),
            "final_submitted_by": admin_email,
            "final_document_url": upload_result["url"],  # Also save separately for clarity
            "final_document_name": file.filename,
            "admin_notes": notes if notes else "Final submitted"
        }
        
        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )
        
        # ✅ VERIFY the update
        updated_app = await db.applications.find_one({"_id": ObjectId(application_id)})
        if updated_app:
            saved_url = updated_app.get("submitted_document_url")
            logger.info(f"✅ VERIFIED: submitted_document_url = {saved_url}")
        
        logger.info(f"✅ Application {application_id} updated with final document URL: {upload_result['url']}")
        logger.info(f"✅ Status changed from {old_status} to 'final_submitted'")
        
        # ==================== SEND NOTIFICATIONS ====================
        
        # Send to user
        if applicant_email:
            user_title = f"✅ FINAL SUBMISSION: {job.get('post_name', 'Job')}"
            user_message = f"Your FINAL document '{file.filename}' has been submitted successfully by {admin_name} for the position '{job.get('post_name', 'Job')}' at {job.get('organization', 'Company')}.\n\nThis is your FINAL submission. No further changes are allowed."
            if notes:
                user_message += f"\n\nAdmin Notes: {notes}"
            
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title=user_title,
                message=user_message,
                related_id=application_id,
                metadata={
                    "job_title": job.get("post_name"),
                    "document_name": file.filename,
                    "admin_name": admin_name,
                    "admin_notes": notes,
                    "is_final": True,
                    "show_blue_bell": True,
                    "status": "final_submitted",
                    "final_document_url": upload_result["url"]
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 BLUE bell notification sent to user: {applicant_email}")
        
        # Send to job poster
        job_poster_email = job.get("added_by")
        if job_poster_email and job_poster_email != admin_email:
            admin_title = f"✅ FINAL DOCUMENT Submitted for {job.get('post_name', 'Job')}"
            admin_message = f"FINAL document '{file.filename}' has been submitted by {admin_name} for application from {applicant_email}.\n\nThis is the FINAL submission."
            if notes:
                admin_message += f"\n\nNotes: {notes}"
            
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title=admin_title,
                message=admin_message,
                related_id=application_id,
                metadata={
                    "job_title": job.get("post_name"),
                    "applicant_email": applicant_email,
                    "document_name": file.filename,
                    "admin_name": admin_name,
                    "admin_notes": notes,
                    "is_final": True,
                    "show_blue_bell": True,
                    "final_document_url": upload_result["url"]
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 BLUE bell notification sent to job poster: {job_poster_email}")
        
        # Send to all customadmins
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title="✅ FINAL DOCUMENT Submitted",
                    message=f"FINAL document submitted by {admin_name} for application from {applicant_email} for '{job.get('post_name', 'Job')}'",
                    related_id=application_id,
                    metadata={
                        "job_title": job.get("post_name"),
                        "applicant_email": applicant_email,
                        "admin_name": admin_name,
                        "is_final": True,
                        "show_blue_bell": True,
                        "final_document_url": upload_result["url"]
                    },
                    send_email=True,
                    send_websocket=True
                )
                logger.info(f"🔔 BLUE bell notification sent to customadmin: {ca_email}")
        
        return {
            "success": True,
            "message": "FINAL application document submitted successfully! BLUE bell notifications sent.",
            "application_id": application_id,
            "status": "final_submitted",
            "old_status": old_status,
            "final_document_url": upload_result["url"],
            "submitted_document_url": upload_result["url"],
            "document_name": file.filename,
            "admin_notes": notes,
            "old_document_deleted": old_public_id is not None,
            "notifications_sent": True
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in final submit: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


# ==================== BULK STATUS UPDATE ====================

@router.post("/applications/bulk-status")
async def bulk_update_customadmin_status(
    application_ids: List[str] = Body(...),
    status: str = Body(...),
    notes: Optional[str] = Body(None),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.bulk_update_status(application_ids, status, notes, admin_email)


# ====================== USER MANAGEMENT ======================

@router.get("/users/search")
async def search_customadmin_users(
    query: str = Query(..., min_length=1),
    limit: int = Query(20, ge=1, le=100),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    return await service.search_users(query, limit)


@router.get("/users/{email}")
async def get_customadmin_user_profile(
    email: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    return await service.get_user_profile(email)


# ====================== REPORTS ======================

@router.get("/reports/{report_type}")
async def generate_customadmin_report(
    report_type: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.generate_report(report_type, admin_email)


# ====================== NOTIFICATIONS ======================

@router.get("/notifications/count")
async def get_customadmin_notification_count(
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    user_id = user.get("user_id")
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID not found")
    count = await db.notifications.count_documents({"user_id": user_id, "read": False})
    return {"unread_count": count}


@router.get("/notifications")
async def get_customadmin_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    user_id = user.get("user_id")
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID not found")
    notifications = await db.notifications.find({"user_id": user_id}).sort("created_at", -1).skip(skip).limit(limit).to_list(limit)
    for n in notifications:
        n["_id"] = str(n["_id"])
        if n.get("created_at"):
            n["created_at"] = n["created_at"].isoformat()
    return {"notifications": notifications, "total": len(notifications)}


@router.post("/notifications/mark-read/{notification_id}")
async def mark_customadmin_notification_read(
    notification_id: str,
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    user_id = user.get("user_id")
    if not ObjectId.is_valid(notification_id):
        raise HTTPException(status_code=400, detail="Invalid notification ID")
    result = await db.notifications.update_one(
        {"_id": ObjectId(notification_id), "user_id": user_id}, 
        {"$set": {"read": True}}
    )
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"success": True, "message": "Notification marked as read"}


# ====================== SETTINGS ======================

@router.get("/settings")
async def get_customadmin_settings(
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    profile = await db.profile.find_one({"email": admin_email})
    return {"email": admin_email, "name": user.get("name"), "role": "customadmin", "profile": profile}


@router.put("/settings")
async def update_customadmin_settings(
    settings_data: dict = Body(...),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    await db.profile.update_one(
        {"email": admin_email}, 
        {"$set": {"admin_settings": settings_data, "updated_at": datetime.utcnow()}}, 
        upsert=True
    )
    return {"message": "Settings updated successfully"}


# ====================== PENDING PAYMENTS ======================

@router.get("/pending-payments")
async def customadmin_get_pending_payments(
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Get all pending payment verifications for custom admin"""
    from bson import ObjectId
    
    pending = await db.payments.find({"verification_status": "pending"}).to_list(100)
    for p in pending:
        p["_id"] = str(p["_id"])
        job = await db.job.find_one({"_id": ObjectId(p["job_id"])})
        p["job_title"] = job.get("post_name") if job else "Unknown"
        if "transaction_date" in p and p["transaction_date"]:
            p["transaction_date"] = p["transaction_date"].isoformat()
    return {"payments": pending}


@router.post("/verify-payment/{payment_id}")
async def customadmin_verify_payment(
    payment_id: str,
    action: str = Query(..., pattern="^(approve|reject)$"),
    notes: Optional[str] = Query(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    CustomAdmin approves or rejects a pending payment verification
    """
    from app.models.payment_model import PaymentStatus
    from app.modules.notification.service import central_notification
    from bson import ObjectId
    from datetime import datetime

    if not ObjectId.is_valid(payment_id):
        raise HTTPException(400, "Invalid payment ID")

    payment = await db.payments.find_one({"_id": ObjectId(payment_id)})
    if not payment:
        raise HTTPException(404, "Payment record not found")

    if payment.get("verification_status") != "pending":
        return {
            "success": False,
            "message": f"Payment already {payment.get('verification_status')}"
        }

    admin_email = user.get("email")
    admin_name = user.get("name", "Admin")
    
    if not admin_email:
        raise HTTPException(400, "Admin email missing")

    application_id = payment.get("application_id")
    job_id = payment.get("job_id")
    user_email = payment.get("user_email")
    amount = payment.get("amount", 0)
    
    job = await db.job.find_one({"_id": ObjectId(job_id)}) if job_id else None
    job_title = job.get("post_name", "Job Application") if job else "Job Application"
    job_poster_email = job.get("added_by") if job else None

    if action == "approve":
        # Update payment
        await db.payments.update_one(
            {"_id": ObjectId(payment_id)},
            {
                "$set": {
                    "verification_status": "approved",
                    "payment_status": PaymentStatus.COMPLETED.value,
                    "paid_at": datetime.utcnow(),
                    "verified_by": admin_email,
                    "verified_at": datetime.utcnow(),
                    "verification_notes": notes if notes else "Payment approved by admin"
                }
            }
        )
        
        # Update application
        if application_id and ObjectId.is_valid(application_id):
            await db.applications.update_one(
                {"_id": ObjectId(application_id)},
                {
                    "$set": {
                        "payment_verification_status": "approved",
                        "status": "verification_successful",
                        "last_status_update": datetime.utcnow(),
                        "last_updated_by": admin_email,
                        "payment_verified_by": admin_email,
                        "payment_verified_at": datetime.utcnow(),
                        "payment_verification_notes": notes if notes else "Payment approved by admin",
                        "updated_at": datetime.utcnow()
                    }
                }
            )
        
        # Notify user
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title="✅ Payment Verified Successfully!",
            message=f"Your payment of ₹{amount} for '{job_title}' has been verified successfully by {admin_name}.",
            related_id=application_id,
            metadata={
                "status": "verification_successful",
                "amount": amount,
                "job_title": job_title,
                "admin_name": admin_name,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        
        # Notify job poster
        if job_poster_email and job_poster_email != admin_email:
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title="💰 Payment Approved",
                message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been APPROVED by {admin_name}.",
                related_id=application_id,
                metadata={
                    "status": "payment_approved",
                    "amount": amount,
                    "job_title": job_title,
                    "applicant_email": user_email,
                    "admin_name": admin_name,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
        
        # Notify all customadmins
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title="💰 Payment Approved",
                    message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been APPROVED by {admin_name}",
                    related_id=application_id,
                    metadata={
                        "status": "payment_approved",
                        "amount": amount,
                        "job_title": job_title,
                        "applicant_email": user_email,
                        "admin_name": admin_name,
                        "show_blue_bell": True
                    },
                    send_email=True,
                    send_websocket=True
                )

        message = "Payment approved successfully"
        
    else:  # reject
        if not notes:
            notes = "Payment rejected by admin - Please contact support"
            
        await db.payments.update_one(
            {"_id": ObjectId(payment_id)},
            {
                "$set": {
                    "verification_status": "rejected",
                    "payment_status": PaymentStatus.FAILED.value,
                    "verified_by": admin_email,
                    "verified_at": datetime.utcnow(),
                    "verification_notes": notes,
                    "rejection_reason": notes
                }
            }
        )
        
        if application_id and ObjectId.is_valid(application_id):
            await db.applications.update_one(
                {"_id": ObjectId(application_id)},
                {
                    "$set": {
                        "payment_verification_status": "rejected",
                        "status": "verification_rejected",
                        "last_status_update": datetime.utcnow(),
                        "last_updated_by": admin_email,
                        "payment_verified_by": admin_email,
                        "payment_verified_at": datetime.utcnow(),
                        "payment_rejection_reason": notes,
                        "payment_verification_notes": notes,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
        
        # Notify user
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title="❌ Payment Verification Failed",
            message=f"Your payment of ₹{amount} for '{job_title}' has been REJECTED by {admin_name}.\n\nReason: {notes}",
            related_id=application_id,
            metadata={
                "status": "verification_rejected",
                "amount": amount,
                "job_title": job_title,
                "admin_name": admin_name,
                "rejection_reason": notes,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        
        # Notify job poster
        if job_poster_email and job_poster_email != admin_email:
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title="💰 Payment Rejected",
                message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been REJECTED by {admin_name}.\nReason: {notes}",
                related_id=application_id,
                metadata={
                    "status": "payment_rejected",
                    "amount": amount,
                    "job_title": job_title,
                    "applicant_email": user_email,
                    "admin_name": admin_name,
                    "rejection_reason": notes,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
        
        # Notify all customadmins
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title="💰 Payment Rejected",
                    message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been REJECTED by {admin_name}.\nReason: {notes}",
                    related_id=application_id,
                    metadata={
                        "status": "payment_rejected",
                        "amount": amount,
                        "job_title": job_title,
                        "applicant_email": user_email,
                        "admin_name": admin_name,
                        "rejection_reason": notes,
                        "show_blue_bell": True
                    },
                    send_email=True,
                    send_websocket=True
                )

        message = f"Payment rejected. Reason: {notes}"

    return {
        "success": True,
        "message": message,
        "payment_id": payment_id,
        "action": action,
        "notes": notes,
        "application_status_updated": True,
        "notifications_sent": True
    }


# ==================== END OF FILE ====================

print("✅ Custom Admin Routes Loaded - All actions send BLUE bell notifications")