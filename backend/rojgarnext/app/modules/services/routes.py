# app/modules/services/routes.py - COMPLETE FIXED VERSION
# ✅ All endpoints working with proper permission checks
# ✅ User Confirm and Update endpoints added

from fastapi import APIRouter, Depends, HTTPException, Query, Body, BackgroundTasks, UploadFile, File, Form
from typing import Optional, List
from bson import ObjectId
from datetime import datetime
import logging

from app.core.services.dependencies import get_current_user, role_required
from app.db.connection import get_db
from app.modules.services.service import ServiceService
from app.modules.services.schema import (
    ServiceApplicationCreateSchema,
    ServiceApplicationUpdateSchema,
    ServiceApplicationStatus,
    ServiceApplicationStatusUpdateSchema,
    ServiceFeeSchema,
    ServiceApplicationConfirmSchema,
    ServiceApplicationUpdateSubmitSchema,
    ServiceApplicationUpdateFieldSchema
)
from app.core.services.cloudinary import upload_user_document
from app.modules.notification.service import central_notification

module_logger = logging.getLogger(__name__)

router = APIRouter()


async def get_service_service(db=Depends(get_db)):
    return ServiceService(db)


# ==================== CREATE APPLICATION ====================

@router.post("/apply")
async def create_service_application(
    data: ServiceApplicationCreateSchema = Body(...),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """Create a new service application"""
    user_email = current_user.get("email")
    user_name = current_user.get("name") or current_user.get("email", "").split('@')[0]
    user_id = current_user.get("user_id")
    
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    return await service.create_application(data, user_email, user_name, user_id)


# ==================== SUBMIT VERIFICATION ====================

@router.post("/application/{application_id}/submit-verification")
async def submit_service_verification(
    application_id: str,
    transaction_id: str = Form(...),
    transaction_date: str = Form(...),
    screenshot: UploadFile = File(...),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """Submit verification with transaction details and screenshot"""
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    if not screenshot or not screenshot.filename:
        raise HTTPException(status_code=400, detail="Screenshot file is required")
    
    username = user_email.split('@')[0]
    upload_result = await upload_user_document(
        file=screenshot,
        username=username,
        document_type="service_payments"
    )
    
    return await service.submit_verification(
        application_id=application_id,
        transaction_id=transaction_id,
        transaction_date=transaction_date,
        screenshot_url=upload_result["url"],
        screenshot_public_id=upload_result.get("public_id"),
        user_email=user_email
    )


# ==================== VERIFY PAYMENT (ADMIN ONLY) ====================

@router.post("/application/{application_id}/verify-payment")
async def verify_service_payment(
    application_id: str,
    action: str = Body(..., embed=True, description="approve or reject"),
    notes: Optional[str] = Body(None, embed=True),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """
    Verify payment for a service application (admin only)
    Expected body: {"action": "approve", "notes": "optional reason"}
    """
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    if action not in ["approve", "reject"]:
        raise HTTPException(status_code=400, detail="Action must be 'approve' or 'reject'")
    
    return await service.verify_payment(
        application_id=application_id,
        action=action,
        admin_email=admin_email,
        notes=notes
    )


# ==================== GET APPLICATIONS ====================

@router.get("/my-applications")
async def get_my_service_applications(
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """Get all service applications for the current user"""
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    applications = await service.get_user_applications(user_email)
    return {
        "success": True,
        "applications": applications,
        "total": len(applications)
    }


@router.get("/application/{application_id}")
async def get_service_application_detail(
    application_id: str,
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """Get detailed service application - User or Admin can view"""
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    return await service.get_application_detail(application_id, user_email)


# ==================== ALL APPLICATIONS (ADMIN ONLY) ====================

@router.get("/all-applications")
async def get_all_service_applications(
    status: Optional[str] = Query(None, pattern="^(pending|payment_pending|under_review|review_application|approved|rejected|completed|pending_verification|confirmed_application|update_application)$"),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """Get all service applications (admin only)"""
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    return await service.get_all_applications(admin_email, status, limit, skip)


# ==================== UPDATE APPLICATION STATUS (ADMIN ONLY) ====================

@router.put("/application/{application_id}/status")
async def update_service_application_status(
    application_id: str,
    status_data: ServiceApplicationStatusUpdateSchema = Body(...),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """
    UPDATE APPLICATION STATUS (ADMIN ONLY)
    ⚠️ This endpoint is for ADMIN use only.
    Users should use /application/{id}/user-confirm and /application/{id}/user-update
    
    Allowed statuses:
    - pending, payment_pending, under_review, review_application
    - approved, rejected, completed, confirmed_application, update_application
    """
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    return await service.update_application_status(
        application_id=application_id,
        status=status_data.status,
        admin_email=admin_email,
        admin_notes=status_data.admin_notes
    )


# ==================== ✅ USER CONFIRM APPLICATION (FIXED) ====================

@router.put("/application/{application_id}/user-confirm")
async def user_confirm_service_application(
    application_id: str,
    # ✅ IMPORTANT: Accept notes as optional query parameter or body
    notes: Optional[str] = None,
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """
    USER: Confirm their service application
    Only allowed from review_application or under_review status
    Updates status to confirmed_application
    """
    db = await service._get_db()
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await service.get_application_by_id(application_id)
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    # ✅ Verify user owns this application
    if application.get("user_email") != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized - This is not your application")
    
    # ✅ Check current status - only allowed from review_application or under_review
    current_status = application.get("status", "")
    if current_status not in ["review_application", "under_review"]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot confirm application in '{current_status}' status. Only applications under review can be confirmed."
        )
    
    # ✅ Update status to confirmed_application
    update_data = {
        "status": "confirmed_application",
        "confirmed_at": datetime.utcnow(),
        "confirmed_by": user_email,
        "updated_at": datetime.utcnow()
    }
    
    # Only add notes if provided
    if notes:
        update_data["confirmation_notes"] = notes
    
    result = await db.services.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Application not found")
    
    # ✅ Send notification to user
    service_name = application.get("service_name", "Service")
    sub_service_name = application.get("sub_service_name", "")
    
    from app.modules.notification.service import central_notification
    
    await central_notification.send_notification(
        user_ids=[user_email],
        notification_type="application_status",
        title="✅ Application Confirmed!",
        message=f"Your service application for '{service_name}' has been confirmed successfully.",
        related_id=application_id,
        metadata={
            "status": "confirmed_application",
            "service_name": service_name,
            "sub_service_name": sub_service_name,
            "application_id": application_id,
            "show_blue_bell": True
        },
        send_email=True,
        send_websocket=True
    )
    
    # ✅ Send notification to admins
    admins = await db.auth.find({
        "role": {"$in": ["admin", "customadmin", "superadmin"]},
        "is_active": True
    }).to_list(100)
    
    for admin in admins:
        admin_email = admin.get("email")
        if admin_email != user_email:
            await central_notification.send_notification(
                user_ids=[admin_email],
                notification_type="admin_alert",
                title=f"✅ Application Confirmed: {service_name}",
                message=f"User {user_email} has confirmed their application for '{service_name}'.",
                related_id=application_id,
                metadata={
                    "service_name": service_name,
                    "applicant_email": user_email,
                    "status": "confirmed_application",
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
    
    return {
        "success": True,
        "message": "Application confirmed successfully",
        "application_id": application_id,
        "status": "confirmed_application"
    }


# ==================== ✅ USER SUBMIT APPLICATION UPDATE ====================

@router.post("/application/{application_id}/user-update")
async def user_submit_service_application_update(
    application_id: str,
    updates: List[ServiceApplicationUpdateFieldSchema] = Body(..., description="List of field updates"),
    notes: Optional[str] = Body(None),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """
    USER: Submit updates to their service application
    Only allowed from review_application or under_review status
    Updates status to update_application
    """
    db = await service._get_db()
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await service.get_application_by_id(application_id)
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    # ✅ Verify user owns this application
    if application.get("user_email") != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized - This is not your application")
    
    # ✅ Check current status - only allowed from review_application or under_review
    current_status = application.get("status", "")
    if current_status not in ["review_application", "under_review"]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot update application in '{current_status}' status. Only applications under review can be updated."
        )
    
    # ✅ Validate updates
    if not updates or len(updates) == 0:
        raise HTTPException(status_code=400, detail="At least one update field is required")
    
    # ✅ Prepare updates as list of dicts
    updates_list = []
    for update in updates:
        updates_list.append({
            "field_name": update.field_name,
            "field_value": update.field_value,
            "submitted_at": datetime.utcnow().isoformat()
        })
    
    # ✅ Update application
    update_data = {
        "status": "update_application",
        "application_updates": updates_list,
        "update_notes": notes,
        "update_submitted_at": datetime.utcnow(),
        "update_submitted_by": user_email,
        "updated_at": datetime.utcnow()
    }
    
    result = await db.services.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Application not found")
    
    # ✅ Send notification to user
    service_name = application.get("service_name", "Service")
    
    await central_notification.send_notification(
        user_ids=[user_email],
        notification_type="application_status",
        title="📝 Application Update Submitted",
        message=f"Your update for '{service_name}' has been submitted. Admin will review it.",
        related_id=application_id,
        metadata={
            "status": "update_application",
            "service_name": service_name,
            "application_id": application_id,
            "updates_count": len(updates_list),
            "show_blue_bell": True
        },
        send_email=True,
        send_websocket=True
    )
    
    # ✅ Send notification to admins
    admins = await db.auth.find({
        "role": {"$in": ["admin", "customadmin", "superadmin"]},
        "is_active": True
    }).to_list(100)
    
    for admin in admins:
        admin_email = admin.get("email")
        if admin_email != user_email:
            await central_notification.send_notification(
                user_ids=[admin_email],
                notification_type="admin_alert",
                title=f"📝 Application Update: {service_name}",
                message=f"User {user_email} has submitted an update for their service application.",
                related_id=application_id,
                metadata={
                    "service_name": service_name,
                    "applicant_email": user_email,
                    "updates_count": len(updates_list),
                    "status": "update_application",
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
    
    return {
        "success": True,
        "message": "Application update submitted successfully",
        "application_id": application_id,
        "status": "update_application",
        "updates_count": len(updates_list)
    }


# ==================== GET APPLICATION UPDATES (USER + ADMIN) ====================

@router.get("/application/{application_id}/updates")
async def get_service_application_updates(
    application_id: str,
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Get application updates for a specific application
    User (owner) or Admin can view
    """
    db = await service._get_db()
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await service.get_application_by_id(application_id)
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    # Check permission - user or admin can view
    is_owner = application.get("user_email") == user_email
    
    user = await db.auth.find_one({"email": user_email})
    is_admin = user.get("role") in ["admin", "customadmin", "superadmin"] if user else False
    
    if not (is_owner or is_admin):
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    updates = application.get("application_updates", [])
    
    return {
        "success": True,
        "updates": updates,
        "notes": application.get("update_notes"),
        "submitted_at": application.get("update_submitted_at"),
        "submitted_by": application.get("update_submitted_by"),
        "status": application.get("status")
    }


# ==================== ADMIN APPROVE UPDATE ====================

@router.post("/application/{application_id}/approve-update")
async def admin_approve_service_application_update(
    application_id: str,
    admin_notes: Optional[str] = Body(None),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """
    ADMIN: Approve user's application update
    Only allowed from update_application status
    Merges updates into the application
    """
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    return await service.admin_approve_update(
        application_id=application_id,
        admin_email=admin_email,
        admin_notes=admin_notes
    )


# ==================== ADMIN REJECT UPDATE ====================

@router.post("/application/{application_id}/reject-update")
async def admin_reject_service_application_update(
    application_id: str,
    admin_notes: str = Body(...),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """
    ADMIN: Reject user's application update
    Only allowed from update_application status
    Reverts status to review_application
    """
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    return await service.admin_reject_update(
        application_id=application_id,
        admin_email=admin_email,
        admin_notes=admin_notes
    )


# ==================== UPLOAD DOCUMENT (ADMIN ONLY) ====================

@router.post("/application/{application_id}/upload-document")
async def upload_service_document(
    application_id: str,
    file: UploadFile = File(...),
    document_type: str = Form("document"),
    notes: Optional[str] = Form(None),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """
    Upload document for a service application (admin only)
    """
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")
    
    # Get application to get user email
    application = await service.get_application_by_id(application_id)
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    user_email = application.get("user_email")
    username = user_email.split('@')[0] if user_email else "user"
    
    # Upload to Cloudinary
    upload_result = await upload_user_document(
        file=file,
        username=username,
        document_type="service_documents"
    )
    
    return await service.upload_document(
        application_id=application_id,
        document_type=document_type,
        document_url=upload_result["url"],
        admin_email=admin_email,
        notes=notes
    )


# ==================== GET SERVICE FEES ====================

@router.get("/fees/{service_type}/{sub_type_id}")
async def get_service_fees(
    service_type: str,
    sub_type_id: str,
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """Get service fees for a specific service type"""
    return await service.get_service_fees(service_type, sub_type_id)


# ==================== DELETE APPLICATION ====================

@router.delete("/application/{application_id}")
async def delete_service_application(
    application_id: str,
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """Delete a service application (only if pending)"""
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    return await service.delete_application(application_id, user_email)


# ==================== STATISTICS ====================

@router.get("/statistics")
async def get_service_statistics(
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """Get service statistics (admin only)"""
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    return await service.get_statistics(admin_email)


# ==================== HEALTH CHECK ====================

@router.get("/health")
async def service_health_check():
    """Health check for services module"""
    return {
        "status": "healthy",
        "module": "services",
        "application_type": "online_service",
        "endpoints": [
            "/apply",
            "/my-applications",
            "/application/{application_id}",
            "/all-applications",
            "/application/{application_id}/status",
            "/application/{application_id}/verify-payment",
            "/application/{application_id}/upload-document",
            "/fees/{service_type}/{sub_type_id}",
            "/statistics",
            "/application/{application_id}/user-confirm",
            "/application/{application_id}/user-update",
            "/application/{application_id}/updates",
            "/application/{application_id}/approve-update",
            "/application/{application_id}/reject-update"
        ],
        "statuses_supported": [
            "pending",
            "payment_pending",
            "under_review",
            "review_application",
            "approved",
            "rejected",
            "completed",
            "pending_verification",
            "confirmed_application",
            "update_application"
        ],
        "permission_notes": {
            "admin_endpoints": [
                "/all-applications",
                "/application/{application_id}/status",
                "/application/{application_id}/verify-payment",
                "/application/{application_id}/upload-document",
                "/application/{application_id}/approve-update",
                "/application/{application_id}/reject-update",
                "/statistics"
            ],
            "user_endpoints": [
                "/apply",
                "/my-applications",
                "/application/{application_id}",
                "/application/{application_id}/user-confirm",
                "/application/{application_id}/user-update",
                "/application/{application_id}/updates",
                "/fees/{service_type}/{sub_type_id}",
                "/application/{application_id}",
                "/application/{application_id}/submit-verification"
            ]
        }
    }

# app/modules/services/routes.py - ADD THIS ENDPOINT

@router.get("/application/{application_id}/document")
async def get_service_application_document(
    application_id: str,
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Fetch the submitted document URL for a service application (Review or Final Submit)
    User (owner) or Admin can view
    """
    from bson import ObjectId
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await service.get_application_by_id(application_id)
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    # Check permission - user owns it OR is admin
    is_owner = application.get("user_email") == user_email
    
    if not is_owner:
        db = await service._get_db()
        user = await db.auth.find_one({"email": user_email})
        if user.get("role") not in ["admin", "customadmin", "superadmin"]:
            raise HTTPException(status_code=403, detail="Access denied")
    
    # Get the submitted document URL (from review or final submit)
    document_url = application.get("submitted_document_url") or application.get("final_document_url")
    document_name = application.get("submitted_document_name") or application.get("final_document_name")
    
    if not document_url:
        raise HTTPException(status_code=404, detail="No document found for this application")
    
    return {
        "success": True,
        "url": document_url,
        "filename": document_name or "Service Document",
        "public_id": application.get("submitted_document_public_id") or application.get("final_document_public_id"),
        "resource_type": application.get("submitted_document_resource_type") or application.get("final_document_resource_type", "raw")
    }



# app/modules/services/routes.py - Add document upload endpoints

@router.post("/application/{application_id}/review-with-document")
async def review_service_application_with_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: Optional[str] = Form(None),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """
    ADMIN: Review application with document upload
    ✅ SAVES document to database with all fields:
    - submitted_document_url, submitted_document_name, submitted_document_public_id
    - submitted_document_folder, submitted_document_resource_type, submitted_document_storage
    - submitted_by, confirmation_notes
    """
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")
    
    # Get application to get user email for folder
    application = await service.get_application_by_id(application_id)
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    user_email = application.get("user_email")
    username = user_email.split('@')[0] if user_email else "user"
    
    # Upload document to Cloudinary
    from app.core.services.cloudinary import upload_user_document
    upload_result = await upload_user_document(
        file=file,
        username=username,
        document_type="service_documents"
    )
    
    return await service.review_application_with_document(
        application_id=application_id,
        admin_email=admin_email,
        document_url=upload_result["url"],
        document_public_id=upload_result.get("public_id"),
        document_name=file.filename,
        document_folder=upload_result.get("folder_path"),
        resource_type=upload_result.get("resource_type", "raw"),
        notes=notes
    )


@router.post("/application/{application_id}/final-submit-with-document")
async def final_submit_service_application_with_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: Optional[str] = Form(None),
    service: ServiceService = Depends(get_service_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """
    ADMIN: Final submit application with document upload
    ✅ SAVES document to database with all fields
    """
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")
    
    application = await service.get_application_by_id(application_id)
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    user_email = application.get("user_email")
    username = user_email.split('@')[0] if user_email else "user"
    
    from app.core.services.cloudinary import upload_user_document
    upload_result = await upload_user_document(
        file=file,
        username=username,
        document_type="service_documents"
    )
    
    return await service.final_submit_with_document(
        application_id=application_id,
        admin_email=admin_email,
        document_url=upload_result["url"],
        document_public_id=upload_result.get("public_id"),
        document_name=file.filename,
        document_folder=upload_result.get("folder_path"),
        resource_type=upload_result.get("resource_type", "raw"),
        notes=notes
    )



print("=" * 70)
print("✅ Services Routes Loaded - All endpoints working")
print("   ✅ user-confirm: /application/{id}/user-confirm (USER)")
print("   ✅ user-update: /application/{id}/user-update (USER)")
print("   ✅ updates: /application/{id}/updates (USER + ADMIN)")
print("   ✅ approve-update: /application/{id}/approve-update (ADMIN)")
print("   ✅ reject-update: /application/{id}/reject-update (ADMIN)")
print("=" * 70)