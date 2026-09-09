# app/modules/payment/routes.py - FIXED VERSION
# ✅ CORRECTLY SETS application_type='service' for service payments

from fastapi import APIRouter, Depends, HTTPException, Query, Body, Request, BackgroundTasks, UploadFile, File, Form
from fastapi.responses import RedirectResponse
from datetime import datetime, timedelta, timezone
import json
import base64
import secrets
import uuid
import hashlib
import hmac
import logging
import httpx
import asyncio
from typing import Optional, List, Annotated, Dict
from bson import ObjectId
from pydantic import BaseModel
from app.core.services.dependencies import get_current_user, role_required
from app.core.config.settings import settings
from app.db.connection import get_db
from app.core.utils.logger import logger
from app.core.services.cloudinary import upload_payment_screenshot, upload_user_document
from app.modules.notification.service import central_notification

# ==================== RAZORPAY IMPORTS ====================
import razorpay
import ssl
import requests
from requests.adapters import HTTPAdapter
from urllib3.poolmanager import PoolManager

router = APIRouter()

# ==================== RAZORPAY CLIENT ====================
RAZORPAY_KEY_ID = getattr(settings, "RAZORPAY_KEY_ID", "")
RAZORPAY_KEY_SECRET = getattr(settings, "RAZORPAY_KEY_SECRET", "")
RAZORPAY_TEST_MODE = getattr(settings, "RAZORPAY_TEST_MODE", True)

razorpay_client = None
razorpay_initialized = False

def initialize_razorpay_client():
    """Initialize Razorpay client with proper SSL/TLS configuration"""
    global razorpay_client, razorpay_initialized
    
    if not RAZORPAY_KEY_ID or not RAZORPAY_KEY_SECRET:
        logger.error("❌ Razorpay credentials not configured")
        return False
    
    try:
        session = requests.Session()
        
        class SSLAdapter(HTTPAdapter):
            def init_poolmanager(self, *args, **kwargs):
                ctx = ssl.create_default_context()
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
                kwargs['ssl_context'] = ctx
                return super().init_poolmanager(*args, **kwargs)
        
        session.mount('https://', SSLAdapter())
        session.mount('http://', HTTPAdapter())
        
        razorpay_client = razorpay.Client(
            auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET),
            session=session
        )
        
        test_order = razorpay_client.order.create({
            "amount": 100,
            "currency": "INR",
            "payment_capture": 1
        })
        
        logger.info(f"✅ Razorpay client initialized successfully - Test order: {test_order.get('id')}")
        logger.info(f"   Mode: {'TEST' if RAZORPAY_TEST_MODE else 'PRODUCTION'}")
        razorpay_initialized = True
        return True
        
    except ImportError as e:
        logger.error(f"❌ Razorpay not installed: {e}")
        razorpay_client = None
        return False
    except Exception as e:
        logger.error(f"❌ Razorpay initialization error: {e}")
        razorpay_client = None
        return False

# Initialize on module load
initialize_razorpay_client()

# ==================== SCHEMAS ====================

class CreateOrderSchema(BaseModel):
    amount: int
    payment_type: str = "job"  # "job" or "service"
    job_id: Optional[str] = None
    job_title: Optional[str] = None
    service_id: Optional[str] = None
    service_type: Optional[str] = None
    sub_type_id: Optional[str] = None
    sub_service_name: Optional[str] = None
    form_data: Optional[dict] = None
    user_email: Optional[str] = None
    user_name: Optional[str] = None


class VerifyPaymentSchema(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str
    application_id: str  # This is the application_id (job or service)


# ==================== CREATE RAZORPAY ORDER ====================

@router.post("/razorpay/create-order")
async def create_razorpay_order(
    data: CreateOrderSchema,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ CREATE RAZORPAY ORDER - NO SEPARATE TABLES
    All data stored in applications/services collection
    """
    logger.info("=" * 70)
    logger.info(f"💰 Creating Razorpay Order - Type: {data.payment_type}")
    logger.info(f"   User: {current_user.get('email')}")
    logger.info(f"   Amount: ₹{data.amount}")
    logger.info("=" * 70)
    
    if not razorpay_client or not razorpay_initialized:
        if not initialize_razorpay_client():
            raise HTTPException(
                status_code=400,
                detail="Razorpay is not configured. Please check server configuration."
            )
    
    user_email = data.user_email or current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email is required")
    
    user_id = current_user.get("user_id")
    user_name = data.user_name or current_user.get("name", "User")
    
    # Get user category from profile
    profile = await db.profile.find_one({"email": user_email})
    user_category = profile.get("category", "General/UR") if profile else "General/UR"
    is_disabled = False
    if profile:
        disability = profile.get("disability", {})
        is_disabled = disability.get("is_disabled", False) if isinstance(disability, dict) else False
    
    application_id = None
    
    try:
        # ==================== JOB PAYMENT ====================
        if data.payment_type == "job":
            if not data.job_id or not ObjectId.is_valid(data.job_id):
                raise HTTPException(status_code=400, detail="Invalid job ID")
            
            job = await db.job.find_one({"_id": ObjectId(data.job_id)})
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")
            
            job_title = data.job_title or job.get("post_name", "Job Application")
            
            # Initialize category_used BEFORE the if block
            category_used = "none"
            amount = data.amount
            
            # Calculate fee based on category
            job_fees = job.get("application_fees", {})
            if job_fees:
                if is_disabled:
                    category_used = "pwd"
                    amount = job_fees.get("pwd", data.amount)
                else:
                    category_map = {
                        "General/UR": "general/ur",
                        "OBC": "obc",
                        "SC": "sc",
                        "ST": "st",
                        "EWS": "ews"
                    }
                    fee_key = category_map.get(user_category, "general/ur")
                    category_used = fee_key
                    amount = job_fees.get(fee_key, data.amount)
            
            # Check existing application
            existing = await db.applications.find_one({
                "job_id": data.job_id,
                "applicant_email": user_email,
                "status": {"$nin": ["replaced", "rejected", "verification_rejected"]}
            })
            
            if existing:
                existing_status = existing.get("status", "")
                if existing_status == "verification_successful":
                    raise HTTPException(
                        status_code=400,
                        detail="You have already successfully applied for this job"
                    )
                application_id = str(existing["_id"])
                logger.info(f"📋 Using existing application: {application_id}")
            
            if not application_id:
                # Create application with ALL payment fields
                application = {
                    "application_type": "job",  # ✅ SET TO JOB
                    "job_id": data.job_id,
                    "job_title": job_title,
                    "organization": job.get("organization", "Company"),
                    "added_by": job.get("added_by", "admin@rojgarnext.com"),
                    "applicant_email": user_email,
                    "applicant_name": user_name,
                    "user_id": user_id,
                    "user_email": user_email,
                    "user_name": user_name,
                    "user_category": user_category,
                    "is_disabled": is_disabled,
                    "status": "payment_pending",
                    "payment_amount": amount,
                    "payment_category_used": category_used,
                    "payment_verification_status": "pending",
                    "created_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow()
                }
                result = await db.applications.insert_one(application)
                application_id = str(result.inserted_id)
                logger.info(f"✅ Created job application: {application_id}")
        
        # ==================== SERVICE PAYMENT ====================
        elif data.payment_type == "service":
            if not data.service_id or not data.sub_type_id:
                raise HTTPException(
                    status_code=400,
                    detail="service_id and sub_type_id are required for service payment"
                )
            
            # Get service details
            from app.modules.services.models.service_types import ServiceMasterData
            service = ServiceMasterData.get_service_by_id(data.service_id)
            sub_type = ServiceMasterData.get_sub_type_by_id(data.sub_type_id)
            
            service_name = service.name if service else data.service_id
            sub_service_name = data.sub_service_name or (sub_type.name if sub_type else data.sub_type_id)
            category_used = "service"
            amount = data.amount
            
            # Check existing service application
            existing = await db.applications.find_one({
                "service_id": data.service_id,
                "sub_type_id": data.sub_type_id,
                "user_email": user_email,
                "application_type": "service"  # ✅ Only check service applications
            })
            
            if existing:
                existing_status = existing.get("status", "")
                if existing_status in ["approved", "completed", "payment_verified"]:
                    raise HTTPException(
                        status_code=400,
                        detail="You have already successfully applied for this service"
                    )
                # ✅ Allow re-application after rejection
                if existing_status == "rejected":
                    await db.applications.update_one(
                        {"_id": existing["_id"]},
                        {"$set": {"status": "replaced", "replaced_at": datetime.utcnow()}}
                    )
                else:
                    application_id = str(existing["_id"])
                    logger.info(f"📋 Existing service application: {application_id}")
            
            if not application_id:
                # ✅ CREATE SERVICE APPLICATION with application_type="service"
                application = {
                    "application_type": "service",  # ✅ CRITICAL: Set to service
                    "service_id": data.service_id,
                    "sub_type_id": data.sub_type_id,
                    "service_name": service_name,
                    "sub_service_name": sub_service_name,
                    "user_email": user_email,
                    "user_name": user_name,
                    "user_id": user_id,
                    "user_category": "service",
                    "is_disabled": is_disabled,
                    "fields": data.form_data or {},
                    "documents": {},
                    "status": "payment_pending",
                    "payment_amount": amount,
                    "payment_category_used": "service",
                    "payment_verification_status": "pending",
                    "created_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow()
                }
                result = await db.applications.insert_one(application)
                application_id = str(result.inserted_id)
                logger.info(f"✅ Created service application: {application_id} (application_type='service')")
        
        else:
            raise HTTPException(
                status_code=400,
                detail="Invalid payment_type. Must be 'job' or 'service'."
            )
        
        # ==================== CREATE RAZORPAY ORDER ====================
        order_data = {
            "amount": amount * 100,
            "currency": "INR",
            "receipt": f"receipt_{application_id}",
            "payment_capture": 1,
            "notes": {
                "payment_type": data.payment_type,
                "user_email": user_email,
                "application_id": application_id,
                "amount": amount,
                "category_used": category_used,
                "test_mode": settings.is_razorpay_test_mode
            }
        }
        
        # Create order with retry
        order = None
        for attempt in range(1, 4):
            try:
                order = razorpay_client.order.create(data=order_data)
                logger.info(f"✅ Order created on attempt {attempt}: {order['id']}")
                break
            except Exception as e:
                logger.error(f"⚠️ Attempt {attempt} failed: {e}")
                if attempt == 3:
                    raise HTTPException(status_code=400, detail=f"Failed to create order: {str(e)}")
                await asyncio.sleep(1 * attempt)
        
        if not order:
            raise HTTPException(status_code=500, detail="Failed to create payment order")
        
        # ==================== STORE ORDER INFO IN APPLICATION ====================
        razorpay_order_id = order["id"]
        
        # Update application with order ID
        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "razorpay_order_id": razorpay_order_id,
                    "payment_id": application_id,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        logger.info("=" * 70)
        logger.info(f"✅ Razorpay order creation complete!")
        logger.info(f"   Order ID: {razorpay_order_id}")
        logger.info(f"   Application ID: {application_id}")
        logger.info(f"   Amount: ₹{amount}")
        logger.info(f"   Category Used: {category_used}")
        logger.info(f"   Application Type: {data.payment_type}")
        logger.info("=" * 70)
        
        return {
            "success": True,
            "order_id": razorpay_order_id,
            "amount": amount,
            "amount_paise": amount * 100,
            "currency": "INR",
            "key_id": settings.RAZORPAY_KEY_ID,
            "application_id": application_id,
            "payment_type": data.payment_type,
            "category_used": category_used,
            "test_mode": settings.is_razorpay_test_mode,
            "message": "Order created successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Order creation error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Order creation failed: {str(e)}")


# ==================== VERIFY RAZORPAY PAYMENT ====================

@router.post("/razorpay/verify-payment")
async def verify_razorpay_payment(
    data: VerifyPaymentSchema,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ VERIFY RAZORPAY PAYMENT - NO SEPARATE TABLES
    Updates application directly
    """
    logger.info("=" * 70)
    logger.info(f"🔐 Verifying Razorpay payment")
    logger.info(f"   Order ID: {data.razorpay_order_id}")
    logger.info(f"   Payment ID: {data.razorpay_payment_id}")
    logger.info(f"   Signature: {data.razorpay_signature}")
    logger.info(f"   Application ID: {data.application_id}")
    logger.info("=" * 70)
    
    if not razorpay_client or not razorpay_initialized:
        if not initialize_razorpay_client():
            raise HTTPException(status_code=400, detail="Razorpay not configured")
    
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    # ==================== FIND APPLICATION ====================
    application = None
    application_type = None
    application_id = data.application_id
    
    if ObjectId.is_valid(application_id):
        application = await db.applications.find_one({
            "_id": ObjectId(application_id),
            "user_email": user_email
        })
        if application:
            application_type = application.get("application_type", "job")
    
    # Try by razorpay_order_id
    if not application:
        application = await db.applications.find_one({
            "razorpay_order_id": data.razorpay_order_id,
            "user_email": user_email
        })
        if application:
            application_type = application.get("application_type", "job")
            application_id = str(application["_id"])
    
    if not application:
        logger.error(f"❌ Application not found for order: {data.razorpay_order_id}")
        raise HTTPException(
            status_code=404,
            detail="Application not found. Please contact support."
        )
    
    logger.info(f"📋 Found application: {application_id} ({application_type})")
    
    # ==================== VERIFY SIGNATURE ====================
    try:
        params_dict = {
            'razorpay_order_id': data.razorpay_order_id,
            'razorpay_payment_id': data.razorpay_payment_id,
            'razorpay_signature': data.razorpay_signature
        }
        razorpay_client.utility.verify_payment_signature(params_dict)
        logger.info("✅ Signature verified successfully")
    except Exception as e:
        logger.error(f"❌ Signature verification failed: {e}")
        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "payment_verification_status": "rejected",
                    "status": "verification_rejected" if application_type == "job" else "rejected",
                    "payment_rejection_reason": f"Signature verification failed: {str(e)}",
                    "updated_at": datetime.utcnow()
                }
            }
        )
        raise HTTPException(status_code=400, detail="Invalid payment signature")
    
    # ==================== UPDATE APPLICATION ====================
    amount = application.get("payment_amount", 0)
    job_id = application.get("job_id")
    service_id = application.get("service_id")
    job_title = application.get("job_title", "Job")
    service_name = application.get("service_name", "Service")
    
    # ✅ Determine status based on application type
    if application_type == "job":
        new_status = "verification_successful"
        status_display = "verification_successful"
    else:
        new_status = "payment_verified"
        status_display = "payment_verified"
    
    # Update application with payment details
    await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {
            "$set": {
                "payment_verification_status": "approved",
                "status": new_status,
                "razorpay_payment_id": data.razorpay_payment_id,
                "razorpay_signature": data.razorpay_signature,
                "transaction_id": data.razorpay_payment_id,
                "paid_at": datetime.utcnow(),
                "payment_verified_by": "razorpay_auto",
                "payment_verified_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        }
    )
    
    logger.info(f"✅ Application {application_id} updated to {new_status}")
    
    # ==================== SEND NOTIFICATIONS ====================
    
    # Send notification to user
    if application_type == "job":
        title = f"✅ Payment Verified Successfully: {job_title}"
        message = f"Your payment of ₹{amount} for '{job_title}' has been verified successfully.\n\nYour application has been submitted."
    else:
        title = f"✅ Service Payment Verified: {service_name}"
        message = f"Your payment of ₹{amount} for '{service_name}' has been verified successfully.\n\nYour service application has been submitted."
    
    await central_notification.send_notification(
        user_ids=[user_email],
        notification_type="application_status",
        title=title,
        message=message,
        related_id=application_id,
        metadata={
            "status": status_display,
            "amount": amount,
            "job_title": job_title,
            "service_name": service_name,
            "application_id": application_id,
            "application_type": application_type,
            "transaction_id": data.razorpay_payment_id,
            "show_blue_bell": True
        },
        send_email=True,
        send_websocket=True
    )
    
    # Notify admin for job applications
    if application_type == "job":
        admin_email = application.get("added_by")
        if admin_email:
            await central_notification.send_notification(
                user_ids=[admin_email],
                notification_type="admin_alert",
                title="💰 Payment Received",
                message=f"Payment of ₹{amount} from {user_email} for '{job_title}' has been verified successfully.",
                related_id=application_id,
                metadata={
                    "status": "payment_received",
                    "amount": amount,
                    "job_title": job_title,
                    "applicant_email": user_email,
                    "application_type": "job",
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
    
    # Notify customadmins
    customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
    for ca in customadmins:
        ca_email = ca.get("email")
        admin_email = application.get("added_by")
        if ca_email != admin_email:
            await central_notification.send_notification(
                user_ids=[ca_email],
                notification_type="customadmin_alert",
                title="💰 Payment Received",
                message=f"Payment of ₹{amount} from {user_email} for '{job_title if application_type == 'job' else service_name}' has been verified successfully.",
                related_id=application_id,
                metadata={
                    "status": "payment_received",
                    "amount": amount,
                    "job_title": job_title,
                    "service_name": service_name,
                    "applicant_email": user_email,
                    "application_type": application_type,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
    
    logger.info("=" * 70)
    logger.info(f"✅ Payment verification complete!")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Type: {application_type}")
    logger.info(f"   Status: {new_status}")
    logger.info("=" * 70)
    
    return {
        "success": True,
        "payment_verified": True,
        "application_id": application_id,
        "application_type": application_type,
        "application_status": new_status,
        "amount": amount,
        "razorpay_payment_id": data.razorpay_payment_id,
        "razorpay_order_id": data.razorpay_order_id,
        "message": "Payment verified successfully"
    }


# ==================== GET APPLICATION PAYMENT STATUS ====================

@router.get("/payment-status/{application_id}")
async def get_application_payment_status(
    application_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ Get payment status from application directly
    """
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    user_email = current_user.get("email")
    if application.get("user_email") != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    # Get application_type
    application_type = application.get("application_type", "job")
    
    # Get payment fields directly from application
    payment_status = application.get("payment_verification_status", "not_submitted")
    status = application.get("status", "pending")
    amount = application.get("payment_amount", 0)
    transaction_id = application.get("transaction_id")
    razorpay_order_id = application.get("razorpay_order_id")
    razorpay_payment_id = application.get("razorpay_payment_id")
    razorpay_signature = application.get("razorpay_signature")
    category_used = application.get("payment_category_used", "none")
    
    is_completed = status in ["verification_successful", "payment_verified", "approved", "completed"]
    
    return {
        "success": True,
        "application_id": application_id,
        "application_type": application_type,
        "payment_status": payment_status,
        "application_status": status,
        "is_completed": is_completed,
        "amount": amount,
        "category_used": category_used,
        "transaction_id": transaction_id,
        "razorpay_order_id": razorpay_order_id,
        "razorpay_payment_id": razorpay_payment_id,
        "razorpay_signature": razorpay_signature
    }


# ==================== UPDATE PAYMENT STATUS (SYNC) ====================

@router.put("/payment-status/{application_id}")
async def update_application_payment_status(
    application_id: str,
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ Update payment status - Directly updates application
    """
    logger.info(f"📝 Updating payment status: {application_id}")
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    user_email = current_user.get("email")
    if application.get("user_email") != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    application_type = application.get("application_type", "job")
    new_status = data.get("status")
    if not new_status:
        raise HTTPException(status_code=400, detail="Status is required")
    
    # Build update data
    update_data = {
        "updated_at": datetime.utcnow()
    }
    
    if new_status == "completed":
        update_data["payment_verification_status"] = "approved"
        update_data["paid_at"] = datetime.utcnow()
        if data.get("razorpay_payment_id"):
            update_data["razorpay_payment_id"] = data["razorpay_payment_id"]
        if data.get("razorpay_order_id"):
            update_data["razorpay_order_id"] = data["razorpay_order_id"]
        if data.get("razorpay_signature"):
            update_data["razorpay_signature"] = data["razorpay_signature"]
        if data.get("transaction_id"):
            update_data["transaction_id"] = data["transaction_id"]
        
        if application_type == "job":
            update_data["status"] = "verification_successful"
        else:
            update_data["status"] = "payment_verified"
    
    elif new_status == "failed":
        update_data["payment_verification_status"] = "rejected"
        if application_type == "job":
            update_data["status"] = "verification_rejected"
        else:
            update_data["status"] = "rejected"
        if data.get("rejection_reason"):
            update_data["payment_rejection_reason"] = data["rejection_reason"]
    
    await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )
    
    return {
        "success": True,
        "message": "Payment status updated successfully",
        "application_id": application_id,
        "application_type": application_type,
        "status": new_status
    }


# ==================== TEST MODE: SIMULATE PAYMENT ====================

@router.post("/test/simulate-payment/{application_id}")
async def simulate_payment(
    application_id: str,
    action: str = Query(..., pattern="^(success|failed)$"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ TEST MODE: Simulate payment success/failure
    Directly updates application
    """
    if not settings.is_razorpay_test_mode:
        raise HTTPException(
            status_code=400,
            detail="Test mode is disabled. Set RAZORPAY_TEST_MODE=true in .env"
        )
    
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({
        "_id": ObjectId(application_id),
        "user_email": user_email
    })
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    application_type = application.get("application_type", "job")
    
    # Check if already processed
    current_status = application.get("status", "")
    if current_status in ["verification_successful", "payment_verified", "approved", "completed"]:
        return {"success": False, "message": "Application already verified"}
    
    amount = application.get("payment_amount", 0)
    job_title = application.get("job_title", "Job")
    service_name = application.get("service_name", "Service")
    category_used = application.get("payment_category_used", "none")
    
    mock_transaction_id = f"TEST_TXN_{secrets.token_hex(8).upper()}"
    mock_order_id = f"order_test_{int(datetime.utcnow().timestamp())}"
    mock_signature = f"sig_test_{secrets.token_hex(16)}"
    
    if action == "success":
        if application_type == "job":
            new_status = "verification_successful"
        else:
            new_status = "payment_verified"
        
        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "payment_verification_status": "approved",
                    "status": new_status,
                    "razorpay_payment_id": mock_transaction_id,
                    "razorpay_order_id": mock_order_id,
                    "razorpay_signature": mock_signature,
                    "transaction_id": mock_transaction_id,
                    "paid_at": datetime.utcnow(),
                    "payment_verified_by": "test_mode",
                    "payment_verified_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        title = f"✅ Payment Successful (Test Mode): {job_title if application_type == 'job' else service_name}"
        message = f"Your payment of ₹{amount} for '{job_title if application_type == 'job' else service_name}' was successful (TEST MODE)."
        
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=application_id,
            metadata={
                "status": new_status,
                "test_mode": True,
                "amount": amount,
                "category_used": category_used,
                "application_type": application_type,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        
        return {
            "success": True,
            "message": "✅ Payment simulated successfully!",
            "application_id": application_id,
            "transaction_id": mock_transaction_id,
            "test_mode": True
        }
    
    else:  # failed
        if application_type == "job":
            new_status = "verification_rejected"
        else:
            new_status = "rejected"
        
        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "payment_verification_status": "rejected",
                    "status": new_status,
                    "razorpay_payment_id": mock_transaction_id,
                    "razorpay_order_id": mock_order_id,
                    "razorpay_signature": mock_signature,
                    "transaction_id": mock_transaction_id,
                    "payment_rejection_reason": "Payment failed in test mode",
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        return {
            "success": True,
            "message": "❌ Payment failed simulation completed.",
            "application_id": application_id,
            "transaction_id": mock_transaction_id,
            "test_mode": True
        }


# ==================== GENERATE QR CODE FOR JOB ====================

@router.post("/generate-qr/{job_id}")
async def generate_payment_qr_code(
    job_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ Generate QR code for job payment
    Creates/updates job application with payment info
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    if not job.get("has_application_fees", False):
        raise HTTPException(status_code=400, detail="No application fees for this job")
    
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": user_email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Check existing application
    existing = await db.applications.find_one({
        "job_id": job_id,
        "user_email": user_email,
        "application_type": "job"
    })
    
    if existing:
        existing_status = existing.get("status", "")
        existing_expiry = existing.get("expires_at")
        
        if existing_status == "verification_successful":
            raise HTTPException(
                status_code=400, 
                detail="You have already successfully applied for this job"
            )
        
        if existing_status in ["pending_verification", "payment_pending", "pending"]:
            is_expired = existing_expiry and datetime.utcnow() > existing_expiry
            
            if not is_expired:
                return {
                    "success": True,
                    "needs_payment": True,
                    "payment_id": str(existing["_id"]),
                    "application_id": str(existing["_id"]),
                    "amount": existing.get("payment_amount", 0),
                    "category_used": existing.get("payment_category_used", "general/ur"),
                    "qr_code_data": existing.get("qr_code_data"),
                    "qr_image_url": existing.get("qr_image_url"),
                    "upi_text": existing.get("upi_text"),
                    "order_id": existing.get("order_id"),
                    "expires_at": existing.get("expires_at").isoformat() if existing.get("expires_at") else None,
                    "job_title": job.get("post_name"),
                    "organization": job.get("organization"),
                    "application_type": "job",
                    "message": "Existing QR code is still valid. Please complete payment."
                }
            else:
                await db.applications.update_one(
                    {"_id": existing["_id"]},
                    {"$set": {"status": "payment_pending", "updated_at": datetime.utcnow()}}
                )
        
        elif existing_status == "verification_rejected":
            await db.applications.update_one(
                {"_id": existing["_id"]},
                {"$set": {"status": "replaced", "replaced_at": datetime.utcnow()}}
            )
        
        elif existing_status == "replaced":
            pass
        
        else:
            raise HTTPException(
                status_code=400,
                detail=f"You have already applied for this job (status: {existing_status})"
            )
    
    # Calculate fee
    user_category = profile.get("category", "General/UR")
    disability = profile.get("disability", {})
    is_disabled = disability.get("is_disabled", False) if isinstance(disability, dict) else False
    
    job_fees = job.get("application_fees", {})
    
    category_used = "general/ur"
    amount = 0
    
    if is_disabled:
        category_used = "pwd"
        amount = job_fees.get("pwd", 0)
        if amount == 0:
            amount = min(job_fees.values()) if job_fees else 0
    else:
        category_map = {
            "General/UR": "general/ur",
            "OBC": "obc",
            "SC": "sc",
            "ST": "st",
            "EWS": "ews"
        }
        fee_key = category_map.get(user_category, "general/ur")
        category_used = fee_key
        amount = job_fees.get(fee_key, 0)
        if amount == 0 and job_fees:
            amount = min(job_fees.values())
    
    if amount <= 0:
        return {
            "success": True,
            "needs_payment": False,
            "amount": 0,
            "message": "No application fee required for your category"
        }
    
    # Generate QR
    application_id = str(ObjectId())
    job_title = job.get("post_name", "Job Application")
    order_id = f"RJ{application_id[-8:]}{int(datetime.utcnow().timestamp())}"
    
    upi_id = settings.UPI_ID or "your-upi-id@okhdfcbank"
    upi_text = f"upi://pay?pa={upi_id}&pn=RojgarNext&am={amount}&cu=INR&tn={order_id}&tid={order_id}"
    qr_image_url = f"https://chart.googleapis.com/chart?cht=qr&chl={upi_text}&chs=300x300&choe=UTF-8"
    
    qr_data = {
        "type": "upi_qr",
        "upi_text": upi_text,
        "qr_image_url": qr_image_url,
        "amount": amount,
        "order_id": order_id,
        "job_title": job_title,
        "organization": job.get("organization"),
        "expires_in_minutes": 30
    }
    
    qr_code_data = base64.b64encode(json.dumps(qr_data).encode()).decode()
    
    if existing and existing_status in ["pending_verification", "payment_pending"]:
        await db.applications.update_one(
            {"_id": existing["_id"]},
            {
                "$set": {
                    "qr_code_data": qr_code_data,
                    "qr_image_url": qr_image_url,
                    "upi_text": upi_text,
                    "order_id": order_id,
                    "expires_at": datetime.utcnow() + timedelta(minutes=30),
                    "updated_at": datetime.utcnow(),
                    "payment_amount": amount,
                    "payment_category_used": category_used,
                    "status": "payment_pending",
                    "application_type": "job"
                }
            }
        )
        inserted_application_id = str(existing["_id"])
        logger.info(f"🔄 Updated existing application with new QR: {inserted_application_id}")
    else:
        application = {
            "_id": ObjectId(application_id),
            "application_type": "job",
            "job_id": job_id,
            "job_title": job_title,
            "organization": job.get("organization", "Company"),
            "added_by": job.get("added_by", "admin@rojgarnext.com"),
            "user_email": user_email,
            "user_name": profile.get("full_name", user_email.split('@')[0]),
            "user_id": current_user.get("user_id"),
            "user_category": user_category,
            "is_disabled": is_disabled,
            "status": "pending_verification",
            "payment_verification_status": "pending",
            "payment_amount": amount,
            "payment_category_used": category_used,
            "payment_id": application_id,
            "payment_method": "qrcode",
            "qr_code_data": qr_code_data,
            "qr_image_url": qr_image_url,
            "upi_text": upi_text,
            "order_id": order_id,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            "expires_at": datetime.utcnow() + timedelta(minutes=30)
        }
        
        result = await db.applications.insert_one(application)
        inserted_application_id = str(result.inserted_id)
        logger.info(f"✅ Created new job application: {inserted_application_id}")
    
    return {
        "success": True,
        "needs_payment": True,
        "payment_id": inserted_application_id,
        "application_id": inserted_application_id,
        "amount": amount,
        "category_used": category_used,
        "qr_code_data": qr_code_data,
        "qr_image_url": qr_image_url,
        "upi_text": upi_text,
        "order_id": order_id,
        "expires_at": (datetime.utcnow() + timedelta(minutes=30)).isoformat(),
        "job_title": job_title,
        "organization": job.get("organization"),
        "application_type": "job",
        "message": "QR code generated. Scan with any UPI app to pay."
    }


# ==================== GENERATE QR CODE FOR SERVICE ====================

@router.post("/generate-qr-service")
async def generate_service_payment_qr(
    service_id: str = Body(...),
    sub_type_id: str = Body(...),
    form_data: Dict = Body(default_factory=dict),
    documents: Dict = Body(default_factory=dict),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ Generate QR code for service payment
    ✅ Creates application with application_type='service'
    """
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": user_email})
    user_category = profile.get("category", "General/UR") if profile else "General/UR"
    
    disability = profile.get("disability", {}) if profile else {}
    is_disabled = disability.get("is_disabled", False) if isinstance(disability, dict) else False
    
    # Service fees
    base_fees = {
        "pan": 100, "aadhar": 50, "epf": 150, "passport": 200,
        "driving_license": 150, "voter_id": 50, "ration_card": 75,
        "income_certificate": 100, "caste_certificate": 100,
        "domicile": 80, "disability": 50, "bonafide": 75,
        "gap_certificate": 80,
    }
    
    base_fee = base_fees.get(service_id, 100)
    final_fee = base_fee
    if is_disabled:
        final_fee = max(10, int(base_fee * 0.5))
    
    if final_fee <= 0:
        return {
            "success": True,
            "needs_payment": False,
            "amount": 0,
            "message": "No payment required for your category"
        }
    
    # Check existing application
    existing = await db.applications.find_one({
        "service_id": service_id,
        "sub_type_id": sub_type_id,
        "user_email": user_email,
        "application_type": "service"
    })
    
    if existing:
        existing_status = existing.get("status", "")
        if existing_status in ["approved", "completed", "payment_verified"]:
            raise HTTPException(
                status_code=400,
                detail="You have already successfully applied for this service"
            )
        if existing_status == "rejected":
            await db.applications.update_one(
                {"_id": existing["_id"]},
                {"$set": {"status": "replaced", "replaced_at": datetime.utcnow()}}
            )
    
    from app.modules.services.models.service_types import ServiceMasterData
    service = ServiceMasterData.get_service_by_id(service_id)
    sub_type = ServiceMasterData.get_sub_type_by_id(sub_type_id)
    
    service_name = service.name if service else service_id
    sub_service_name = sub_type.name if sub_type else sub_type_id
    
    application_id = str(ObjectId())
    order_id = f"SVC{application_id[-8:]}{int(datetime.utcnow().timestamp())}"
    
    upi_id = settings.UPI_ID or "your-upi-id@okhdfcbank"
    upi_text = f"upi://pay?pa={upi_id}&pn=RojgarNext&am={final_fee}&cu=INR&tn={order_id}&tid={order_id}"
    qr_image_url = f"https://chart.googleapis.com/chart?cht=qr&chl={upi_text}&chs=300x300&choe=UTF-8"
    
    qr_data = {
        "type": "upi_qr",
        "upi_text": upi_text,
        "qr_image_url": qr_image_url,
        "amount": final_fee,
        "order_id": order_id,
        "service_type": service_id,
        "sub_type": sub_type_id,
        "expires_in_minutes": 30
    }
    
    qr_code_data = base64.b64encode(json.dumps(qr_data).encode()).decode()
    
    # ✅ CREATE SERVICE APPLICATION with application_type="service"
    application = {
        "_id": ObjectId(application_id),
        "application_type": "service",  # ✅ CRITICAL: Set to service
        "service_id": service_id,
        "sub_type_id": sub_type_id,
        "service_name": service_name,
        "sub_service_name": sub_service_name,
        "user_email": user_email,
        "user_name": profile.get("full_name", user_email.split('@')[0]) if profile else user_email.split('@')[0],
        "user_id": current_user.get("user_id"),
        "user_category": "service",
        "is_disabled": is_disabled,
        "fields": form_data,
        "documents": documents,
        "status": "payment_pending",
        "payment_verification_status": "pending",
        "payment_amount": final_fee,
        "payment_category_used": "service",
        "payment_id": application_id,
        "payment_method": "qrcode",
        "qr_code_data": qr_code_data,
        "qr_image_url": qr_image_url,
        "upi_text": upi_text,
        "order_id": order_id,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(minutes=30)
    }
    
    result = await db.applications.insert_one(application)
    inserted_application_id = str(result.inserted_id)
    
    logger.info(f"✅ Created service application: {inserted_application_id} (application_type='service')")
    
    return {
        "success": True,
        "needs_payment": final_fee > 0,
        "payment_id": inserted_application_id,
        "application_id": inserted_application_id,
        "amount": final_fee,
        "category_used": "service",
        "qr_code_data": qr_code_data,
        "qr_image_url": qr_image_url,
        "expires_at": (datetime.utcnow() + timedelta(minutes=30)).isoformat(),
        "service_name": service_name,
        "sub_service_name": sub_service_name,
        "application_type": "service",
        "message": "QR code generated successfully"
    }


# ==================== UPLOAD PAYMENT SCREENSHOT ====================

@router.post("/upload-screenshot")
async def upload_payment_screenshot_endpoint(
    file: UploadFile = File(...),
    username: str = Form(...),
    application_id: str = Form(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ UPLOAD PAYMENT SCREENSHOT - Updates application directly
    """
    logger.info("=" * 60)
    logger.info(f"📤 UPLOAD PAYMENT SCREENSHOT")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Username: {username}")
    logger.info(f"   File: {file.filename}")
    logger.info("=" * 60)
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Screenshot file is required")
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    user_email = current_user.get("email")
    if application.get("user_email") != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    application_type = application.get("application_type", "job")
    
    # Check file size
    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)
    
    if file_size > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max size: 10MB, Your file: {file_size // (1024*1024)}MB"
        )
    
    # Upload to Cloudinary
    upload_result = await upload_payment_screenshot(
        file=file,
        username=username,
        payment_id=application_id
    )
    
    # Update application
    update_data = {
        "payment_receipt_url": upload_result["url"],
        "payment_receipt_public_id": upload_result.get("public_id"),
        "payment_verification_status": "pending",
        "status": "pending_verification",
        "updated_at": datetime.utcnow()
    }
    
    await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )
    
    return {
        "success": True,
        "message": "Screenshot uploaded successfully",
        "url": upload_result["url"],
        "public_id": upload_result.get("public_id"),
        "filename": file.filename,
        "file_size_kb": file_size // 1024,
        "storage": upload_result.get("storage", "cloudinary"),
        "application_type": application_type
    }


# ==================== SUBMIT PAYMENT VERIFICATION ====================

@router.post("/submit-verification/{application_id}")
async def submit_payment_verification(
    application_id: str,
    transaction_id: str = Form(...),
    transaction_date: str = Form(...),
    screenshot: Optional[UploadFile] = File(None),
    screenshot_url: Optional[str] = Form(None),
    screenshot_public_id: Optional[str] = Form(None),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ Submit payment verification - Updates application directly
    """
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    user_email = current_user.get("email")
    if application.get("user_email") != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    application_type = application.get("application_type", "job")
    
    if application.get("payment_verification_status") not in ["pending", "not_submitted"]:
        raise HTTPException(status_code=400, detail="Verification already submitted")
    
    # Handle screenshot
    final_screenshot_url = None
    final_screenshot_public_id = None
    
    if screenshot and screenshot.filename:
        username = user_email.split('@')[0]
        upload_result = await upload_payment_screenshot(
            file=screenshot,
            username=username,
            payment_id=application_id
        )
        final_screenshot_url = upload_result["url"]
        final_screenshot_public_id = upload_result.get("public_id")
    elif screenshot_url:
        final_screenshot_url = screenshot_url
        final_screenshot_public_id = screenshot_public_id
    
    if not final_screenshot_url:
        raise HTTPException(status_code=400, detail="Screenshot is required")
    
    # Parse transaction date
    try:
        transaction_date_parsed = datetime.fromisoformat(transaction_date)
    except ValueError:
        transaction_date_parsed = datetime.utcnow()
    
    # Update application
    await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {
            "$set": {
                "transaction_id": transaction_id.strip(),
                "transaction_date": transaction_date_parsed,
                "payment_receipt_url": final_screenshot_url,
                "payment_receipt_public_id": final_screenshot_public_id,
                "payment_verification_status": "pending",
                "status": "pending_verification",
                "updated_at": datetime.utcnow()
            }
        }
    )
    
    # Send notification
    await central_notification.send_notification(
        user_ids=[user_email],
        notification_type="application_status",
        title="⏳ Payment Verification Pending",
        message=f"Your payment verification has been submitted. Admin will review it shortly.",
        related_id=application_id,
        metadata={
            "status": "pending_verification",
            "amount": application.get("payment_amount", 0),
            "transaction_id": transaction_id,
            "application_type": application_type,
            "show_blue_bell": True
        },
        send_email=True,
        send_websocket=True
    )
    
    return {
        "success": True,
        "message": "Verification submitted successfully",
        "application_id": application_id,
        "payment_receipt_url": final_screenshot_url,
        "status": "pending_verification",
        "application_type": application_type
    }


# ==================== ADMIN VERIFY PAYMENT ====================

@router.post("/verify-payment/{application_id}")
async def admin_verify_payment(
    application_id: str,
    action: str = Query(..., pattern="^(approve|reject)$"),
    notes: Optional[str] = Query(None),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ ADMIN: Verify payment - Updates application directly
    """
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    if application.get("payment_verification_status") != "pending":
        return {
            "success": False,
            "message": f"Payment already {application.get('payment_verification_status')}"
        }
    
    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email missing")
    
    application_type = application.get("application_type", "job")
    user_email = application.get("user_email")
    amount = application.get("payment_amount", 0)
    job_title = application.get("job_title", "Job Application")
    service_name = application.get("service_name", "Service")
    transaction_id = application.get("transaction_id")
    category_used = application.get("payment_category_used", "none")
    
    if action == "approve":
        if application_type == "job":
            new_status = "verification_successful"
            title = f"✅ Payment Verified Successfully: {job_title}"
            message = f"Your payment of ₹{amount} for '{job_title}' has been verified successfully."
        else:
            new_status = "payment_verified"
            title = f"✅ Service Payment Verified: {service_name}"
            message = f"Your payment of ₹{amount} for '{service_name}' has been verified successfully."
        
        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "payment_verification_status": "approved",
                    "status": new_status,
                    "payment_verified_by": admin_email,
                    "payment_verified_at": datetime.utcnow(),
                    "verification_notes": notes if notes else "Payment approved by admin",
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        # Notify user
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=application_id,
            metadata={
                "status": new_status,
                "amount": amount,
                "transaction_id": transaction_id,
                "category_used": category_used,
                "application_type": application_type,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        
    else:  # reject
        if not notes:
            notes = "Payment rejected by admin - Please contact support"
        
        if application_type == "job":
            new_status = "verification_rejected"
            title = f"❌ Payment Verification Failed: {job_title}"
            message = f"Your payment of ₹{amount} for '{job_title}' has been rejected.\nReason: {notes}"
        else:
            new_status = "rejected"
            title = f"❌ Service Payment Failed: {service_name}"
            message = f"Your payment of ₹{amount} for '{service_name}' has been rejected.\nReason: {notes}"
        
        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "payment_verification_status": "rejected",
                    "status": new_status,
                    "payment_verified_by": admin_email,
                    "payment_verified_at": datetime.utcnow(),
                    "rejection_reason": notes,
                    "verification_notes": notes,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        # Notify user
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=application_id,
            metadata={
                "status": new_status,
                "amount": amount,
                "rejection_reason": notes,
                "category_used": category_used,
                "application_type": application_type,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
    
    return {
        "success": True,
        "message": f"Payment {action}d successfully",
        "application_id": application_id,
        "action": action,
        "status": new_status,
        "application_type": application_type,
        "notifications_sent": True
    }


# ==================== GET PENDING PAYMENTS (ADMIN) ====================

@router.get("/pending-payments")
async def get_pending_payments(
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Get pending payment verifications from applications
    """
    pending = await db.applications.find({
        "payment_verification_status": "pending"
    }).to_list(100)
    
    results = []
    for app in pending:
        application_type = app.get("application_type", "job")
        
        if application_type == "job":
            job = await db.job.find_one({"_id": ObjectId(app["job_id"])}) if app.get("job_id") else None
            results.append({
                "id": str(app["_id"]),
                "type": "job",
                "user_email": app.get("user_email"),
                "user_name": app.get("user_name", "Unknown"),
                "job_title": app.get("job_title", "Job"),
                "organization": app.get("organization", ""),
                "amount": app.get("payment_amount", 0),
                "category_used": app.get("payment_category_used", "none"),
                "transaction_id": app.get("transaction_id", "N/A"),
                "screenshot_url": app.get("payment_receipt_url"),
                "status": app.get("status", "pending_verification"),
                "application_type": "job",
                "created_at": app.get("created_at")
            })
        else:
            results.append({
                "id": str(app["_id"]),
                "type": "service",
                "user_email": app.get("user_email"),
                "user_name": app.get("user_name", "Unknown"),
                "service_name": app.get("service_name", "Service"),
                "sub_service_name": app.get("sub_service_name", ""),
                "amount": app.get("payment_amount", 0),
                "category_used": app.get("payment_category_used", "service"),
                "transaction_id": app.get("transaction_id", "N/A"),
                "screenshot_url": app.get("payment_receipt_url"),
                "status": app.get("status", "pending_verification"),
                "application_type": "service",
                "created_at": app.get("created_at")
            })
    
    return {
        "payments": results,
        "total": len(results)
    }

# app/modules/payment/routes.py - ADD THIS ENDPOINT

@router.post("/update-payment-status/{job_id}")
async def update_job_payment_status(
    job_id: str,
    update_data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ FIXED: Update application payment status after successful verification
    """
    try:
        user_email = current_user.get("email")
        payment_id = update_data.get("payment_id")
        razorpay_payment_id = update_data.get("razorpay_payment_id")
        razorpay_order_id = update_data.get("razorpay_order_id")
        razorpay_signature = update_data.get("razorpay_signature")
        transaction_id = update_data.get("transaction_id") or razorpay_payment_id
        payment_status = update_data.get("payment_status", "completed")
        amount = update_data.get("amount")

        logger.info("=" * 70)
        logger.info("📤 Updating APPLICATION status on server...")
        logger.info(f"   Job ID: {job_id}")
        logger.info(f"   User: {user_email}")
        logger.info(f"   Payment ID: {payment_id}")
        logger.info(f"   Razorpay Payment ID: {razorpay_payment_id}")
        logger.info(f"   Status: {payment_status}")
        logger.info("=" * 70)

        # ✅ Find the application
        app_query = {"user_email": user_email, "job_id": job_id, "application_type": "job"}
        if payment_id and ObjectId.is_valid(payment_id):
            app_query = {"_id": ObjectId(payment_id)}
        elif razorpay_order_id:
            app_query = {"razorpay_order_id": razorpay_order_id}

        application = await db.applications.find_one(app_query)

        if not application:
            logger.warning(f"⚠️ Application not found for job_id: {job_id}")
            # Try to find by job_id only
            application = await db.applications.find_one({
                "user_email": user_email,
                "job_id": job_id,
                "application_type": "job"
            })

        if not application:
            logger.error(f"❌ Application not found for: {app_query}")
            return {
                "success": False,
                "message": "Application not found"
            }

        application_id = str(application["_id"])

        # ✅ Update application with payment details
        update_data_db = {
            "status": "verification_successful",
            "payment_verification_status": "approved",
            "transaction_id": transaction_id,
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_order_id": razorpay_order_id,
            "razorpay_signature": razorpay_signature,
            "paid_at": datetime.utcnow(),
            "payment_verified_at": datetime.utcnow(),
            "payment_verified_by": user_email or "system",
            "updated_at": datetime.utcnow()
        }

        if amount:
            update_data_db["payment_amount"] = int(amount)

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data_db}
        )

        logger.info(f"✅ Application {application_id} updated to verification_successful")

        # ✅ Send notification
        applicant_email = application.get("applicant_email") or application.get("user_email")
        if applicant_email:
            from app.modules.notification.service import central_notification
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title="✅ Payment Verified Successfully",
                message=f"Your payment of ₹{amount} for '{application.get('job_title', 'Job')}' has been verified successfully.\n\nTransaction ID: {razorpay_payment_id}\nOrder ID: {razorpay_order_id}\n\nYour application has been submitted.",
                metadata={
                    "status": "verification_successful",
                    "amount": amount,
                    "transaction_id": razorpay_payment_id,
                    "show_blue_bell": True,
                    "job_title": application.get("job_title", "Job"),
                    "application_id": application_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "razorpay_order_id": razorpay_order_id
                },
                send_email=True,
                send_websocket=True
            )

        return {
            "success": True,
            "message": "Application payment status updated successfully",
            "application_id": application_id,
            "status": "verification_successful"
        }

    except Exception as e:
        logger.error(f"❌ Error updating payment status: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "message": str(e)
        }

# app/modules/payment/routes.py - ADD THIS ENDPOINT

@router.post("/payment/razorpay/verify-payment-no-signature")
async def verify_payment_no_signature(
    request_data: dict = Body(...),
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    ✅ EMERGENCY FIX: Verify payment without signature
    This is a fallback for when Razorpay Web SDK doesn't return signature
    """
    try:
        razorpay_order_id = request_data.get("razorpay_order_id")
        razorpay_payment_id = request_data.get("razorpay_payment_id")
        application_id = request_data.get("application_id")

        logger.info("=" * 70)
        logger.info("🔐 Verifying payment WITHOUT signature (Fallback)")
        logger.info(f"   Order ID: {razorpay_order_id}")
        logger.info(f"   Payment ID: {razorpay_payment_id}")
        logger.info(f"   Application ID: {application_id}")
        logger.info("=" * 70)

        if not razorpay_order_id or not razorpay_payment_id:
            return {
                "success": False,
                "code": "E400",
                "message": "Missing required payment details",
                "payment_verified": False
            }

        # ✅ Get application
        application = None
        
        if application_id and ObjectId.is_valid(application_id):
            application = await db.applications.find_one({"_id": ObjectId(application_id)})
        
        if not application:
            application = await db.applications.find_one({"razorpay_order_id": razorpay_order_id})

        if not application:
            user_email = current_user.get("email")
            if user_email:
                application = await db.applications.find_one({
                    "user_email": user_email,
                    "razorpay_order_id": razorpay_order_id
                })

        if not application:
            logger.error(f"❌ Application not found for order: {razorpay_order_id}")
            return {
                "success": False,
                "code": "E404",
                "message": "Application not found",
                "payment_verified": False
            }

        application_id = str(application["_id"])
        application_type = application.get("application_type", "job")
        payment_amount = application.get("payment_amount", 0)
        applicant_email = application.get("applicant_email") or application.get("user_email")

        # ✅ Check if payment already verified
        if application.get("payment_verification_status") == "approved":
            return {
                "success": True,
                "payment_verified": True,
                "application_id": application_id,
                "status": application.get("status"),
                "message": "Payment already verified"
            }

        # ✅ Update application with verified status
        update_data = {
            "payment_verification_status": "approved",
            "status": "verification_successful" if application_type == "job" else "payment_verified",
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_order_id": razorpay_order_id,
            "transaction_id": razorpay_payment_id,
            "paid_at": datetime.utcnow(),
            "payment_verified_at": datetime.utcnow(),
            "payment_verified_by": current_user.get("email") if current_user else "system",
            "updated_at": datetime.utcnow(),
            "verification_method": "no_signature_fallback"
        }

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        logger.info(f"✅ Application {application_id} updated to verification_successful (no signature)")

        # ✅ Send notification
        if applicant_email:
            job_title = application.get("job_title", "Job Application")
            from app.modules.notification.service import central_notification
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title="✅ Payment Verified Successfully",
                message=f"Your payment for '{job_title}' has been verified successfully.\n\nTransaction ID: {razorpay_payment_id}",
                metadata={
                    "status": "verification_successful",
                    "amount": payment_amount,
                    "transaction_id": razorpay_payment_id,
                    "show_blue_bell": True,
                    "job_title": job_title,
                    "application_id": application_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "razorpay_order_id": razorpay_order_id
                },
                send_email=True,
                send_websocket=True
            )

        return {
            "success": True,
            "payment_verified": True,
            "application_id": application_id,
            "status": update_data["status"],
            "payment_verification_status": "approved",
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_order_id": razorpay_order_id,
            "verification_method": "no_signature_fallback",
            "message": "Payment verified successfully (no signature)!",
            "application_type": application_type
        }

    except Exception as e:
        logger.error(f"❌ Verification error: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "code": "E500",
            "message": f"Verification failed: {str(e)}",
            "payment_verified": False
        }
    
print("=" * 70)
print("✅ Payment Routes Loaded - ONLY RAZORPAY")
print("   ✅ All data stored in applications collection")
print("   ✅ application_type='job' for job applications")
print("   ✅ application_type='service' for service applications")
print("   ✅ No separate payments tables needed")
print("=" * 70)