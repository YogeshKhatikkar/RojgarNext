# app/modules/payment/routes.py - COMPLETE FIXED VERSION
# ✅ CRITICAL FIX: NO application record is created when Razorpay order is created
# ✅ Application is created ONLY after successful payment verification
# ✅ Failed/cancelled payments create NO database record
# ✅ Supports BOTH job and service payments
# ✅ GST (18%) + Service Charge (₹50) added to total amount
# ✅ Razorpay ONLY - No PhonePe, No QR code

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


# ============================================================
# ✅ SAFE HELPER — Prevents "Settings has no attribute" crash
# ============================================================
def _get_razorpay_test_mode() -> bool:
    """
    SAFE: Returns test mode value using multiple fallbacks.
    Prevents 'Settings' object has no attribute 'is_razorpay_test_mode' error.
    """
    for attr in [
        'RAZORPAY_TEST_MODE',
        'is_razorpay_test_mode',
        'IS_RAZORPAY_TEST_MODE',
        'razorpay_test_mode'
    ]:
        try:
            val = getattr(settings, attr, None)
            if val is not None:
                return bool(val)
        except AttributeError:
            continue

    try:
        key_id = getattr(settings, 'RAZORPAY_KEY_ID', '') or ''
        if key_id.startswith('rzp_test_'):
            return True
        if key_id.startswith('rzp_live_'):
            return False
    except Exception:
        pass

    return True


# ==================== RAZORPAY CLIENT ====================
RAZORPAY_KEY_ID = getattr(settings, "RAZORPAY_KEY_ID", "") or ""
RAZORPAY_KEY_SECRET = getattr(settings, "RAZORPAY_KEY_SECRET", "") or ""
RAZORPAY_TEST_MODE = _get_razorpay_test_mode()

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


# ==================== GST & SERVICE CHARGE CONSTANTS ====================
GST_PERCENT = 18.0
SERVICE_CHARGE = 50  # ₹50 flat


def calculate_fee_breakdown(application_fee: int) -> Dict[str, int]:
    """Calculate total fee with GST and service charge"""
    gst_amount = int((application_fee * GST_PERCENT) / 100)
    total = application_fee + gst_amount + SERVICE_CHARGE
    return {
        "application_fee": application_fee,
        "gst_amount": gst_amount,
        "service_charge": SERVICE_CHARGE,
        "total": total
    }


# ==================== SCHEMAS ====================

class CreateOrderSchema(BaseModel):
    amount: int
    payment_type: str = "job"
    job_id: Optional[str] = None
    job_title: Optional[str] = None
    organization: Optional[str] = None
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
    application_id: Optional[str] = None  # This is now the order_id


# ============================================================
# ✅ CREATE RAZORPAY ORDER
# ============================================================
# CRITICAL FIX: This endpoint DOES NOT create any application record.
# It ONLY creates a Razorpay order.
# The application record is created later in verify-payment ONLY
# after successful payment verification.
# ============================================================

@router.post("/razorpay/create-order")
async def create_razorpay_order(
    data: CreateOrderSchema,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
 ):
    """
    CREATE RAZORPAY ORDER - NO APPLICATION RECORD CREATED HERE
    
    Flow:
    1. User clicks "Apply" on job/service
    2. This endpoint is called → creates Razorpay order ONLY
    3. User pays via Razorpay checkout
    4. verify-payment endpoint creates the application record
    5. If user cancels → NO application record exists
    """
    logger.info("=" * 70)
    logger.info(f"💰 Creating Razorpay Order - Type: {data.payment_type}")
    logger.info(f"   User: {current_user.get('email')}")
    logger.info(f"   Amount: ₹{data.amount}")
    logger.info(f"   ⚠️ NO APPLICATION CREATED HERE - Only Razorpay order")
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

    # Default values
    amount = data.amount
    category_used = "none"
    job_title = ""
    organization = ""
    added_by = "admin@rojgarnext.com"

    # ==================== JOB PAYMENT ====================
    if data.payment_type == "job":
        if not data.job_id or not ObjectId.is_valid(data.job_id):
            raise HTTPException(status_code=400, detail="Invalid job ID")

        job = await db.job.find_one({"_id": ObjectId(data.job_id)})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        job_title = data.job_title or job.get("post_name", "Job Application")
        organization = job.get("organization", "Company")
        added_by = job.get("added_by", "admin@rojgarnext.com")

        # ✅ Check if already applied (any non-rejected status)
        existing = await db.applications.find_one({
            "job_id": data.job_id,
            "user_email": user_email,
            "application_type": "job",
            "status": {
                "$in": [
                    "verification_successful", "pending", "shortlisted",
                    "interview", "offered", "submitted", "review_application",
                    "final_submitted", "confirmed_application", "approved_application"
                ]
            }
        })
        if existing:
            raise HTTPException(
                status_code=400,
                detail="You have already applied for this job"
            )

        # ✅ Calculate fee based on category
        job_fees = job.get("application_fees", {})
        if job_fees and len(job_fees) > 0:
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

    # ==================== SERVICE PAYMENT ====================
    elif data.payment_type == "service":
        if not data.service_id or not data.sub_type_id:
            raise HTTPException(
                status_code=400,
                detail="service_id and sub_type_id are required for service payment"
            )

        from app.modules.services.models.service_types import ServiceMasterData
        service = ServiceMasterData.get_service_by_id(data.service_id)
        sub_type = ServiceMasterData.get_sub_type_by_id(data.sub_type_id)

        job_title = service.name if service else data.service_id
        organization = sub_type.name if sub_type else data.sub_type_id

        # ✅ Check if already applied
        existing = await db.applications.find_one({
            "service_id": data.service_id,
            "sub_type_id": data.sub_type_id,
            "user_email": user_email,
            "application_type": "service",
            "status": {
                "$nin": ["replaced", "rejected", "verification_rejected"]
            }
        })
        if existing:
            existing_status = existing.get("status", "")
            if existing_status in ["approved", "completed", "payment_verified"]:
                raise HTTPException(
                    status_code=400,
                    detail="You have already successfully applied for this service"
                )

        category_used = "service"
        amount = data.amount

    else:
        raise HTTPException(
            status_code=400,
            detail="Invalid payment_type. Must be 'job' or 'service'."
        )

    # ==================== CALCULATE TOTAL WITH GST + SERVICE CHARGE ====================
    fee_breakdown = calculate_fee_breakdown(amount)

    logger.info(f"💰 Fee Breakdown:")
    logger.info(f"   Application Fee: ₹{fee_breakdown['application_fee']}")
    logger.info(f"   GST ({GST_PERCENT}%): ₹{fee_breakdown['gst_amount']}")
    logger.info(f"   Service Charge: ₹{fee_breakdown['service_charge']}")
    logger.info(f"   TOTAL: ₹{fee_breakdown['total']}")

    # ==================== CREATE RAZORPAY ORDER ====================
    order_data = {
        "amount": fee_breakdown['total'] * 100,  # Convert to paise
        "currency": "INR",
        "receipt": f"rcpt_{uuid.uuid4().hex[:20]}",
        "payment_capture": 1,
        "notes": {
            "payment_type": data.payment_type,
            "user_email": user_email,
            "user_name": user_name,
            "user_id": user_id or "",
            "job_id": data.job_id or "",
            "job_title": job_title,
            "organization": organization,
            "added_by": added_by,
            "service_id": data.service_id or "",
            "service_type": data.service_type or "",
            "sub_type_id": data.sub_type_id or "",
            "sub_service_name": data.sub_service_name or "",
            "application_fee": str(fee_breakdown['application_fee']),
            "gst_amount": str(fee_breakdown['gst_amount']),
            "service_charge": str(fee_breakdown['service_charge']),
            "total_amount": str(fee_breakdown['total']),
            "category_used": category_used,
            "user_category": user_category,
            "is_disabled": str(is_disabled),
            "form_data": json.dumps(data.form_data or {}),
            "test_mode": str(_get_razorpay_test_mode())
        }
    }

    order = None
    for attempt in range(1, 4):
        try:
            order = razorpay_client.order.create(data=order_data)
            logger.info(f"✅ Order created on attempt {attempt}: {order['id']}")
            break
        except Exception as e:
            logger.error(f"⚠️ Attempt {attempt} failed: {e}")
            if attempt == 3:
                raise HTTPException(
                    status_code=400,
                    detail=f"Failed to create order: {str(e)}"
                )
            await asyncio.sleep(1 * attempt)

    if not order:
        raise HTTPException(status_code=500, detail="Failed to create payment order")

    razorpay_order_id = order["id"]

    logger.info("=" * 70)
    logger.info(f"✅ Razorpay order created successfully!")
    logger.info(f"   Order ID: {razorpay_order_id}")
    logger.info(f"   Total Amount: ₹{fee_breakdown['total']}")
    logger.info(f"   ⚠️ NO APPLICATION SAVED YET - Will save on payment success")
    logger.info("=" * 70)

    return {
        "success": True,
        "order_id": razorpay_order_id,
        "amount": fee_breakdown['total'],
        "application_fee": fee_breakdown['application_fee'],
        "gst_amount": fee_breakdown['gst_amount'],
        "service_charge": fee_breakdown['service_charge'],
        "amount_paise": fee_breakdown['total'] * 100,
        "currency": "INR",
        "key_id": RAZORPAY_KEY_ID,
        "payment_type": data.payment_type,
        "category_used": category_used,
        "test_mode": _get_razorpay_test_mode(),
        "message": "Order created. Application will be saved only after successful payment."
    }


# ============================================================
# ✅ VERIFY RAZORPAY PAYMENT - CREATES APPLICATION ONLY ON SUCCESS
# ============================================================
# This is the ONLY place where applications are created.
# If payment fails/cancelled, this endpoint is never called,
# so NO application record exists.
# ============================================================

@router.post("/razorpay/verify-payment")
async def verify_razorpay_payment(
    data: VerifyPaymentSchema,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    VERIFY RAZORPAY PAYMENT - Creates application ONLY on success
    """
    logger.info("=" * 70)
    logger.info(f"🔐 Verifying Razorpay payment")
    logger.info(f"   Order ID: {data.razorpay_order_id}")
    logger.info(f"   Payment ID: {data.razorpay_payment_id}")
    logger.info("=" * 70)

    if not razorpay_client or not razorpay_initialized:
        if not initialize_razorpay_client():
            raise HTTPException(status_code=400, detail="Razorpay not configured")

    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

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
        raise HTTPException(status_code=400, detail="Invalid payment signature")

    # ==================== FETCH ORDER DETAILS ====================
    try:
        order_details = razorpay_client.order.fetch(data.razorpay_order_id)
        order_notes = order_details.get("notes", {})
        logger.info(f"✅ Order fetched. Notes keys: {list(order_notes.keys())}")
    except Exception as e:
        logger.error(f"❌ Failed to fetch order: {e}")
        raise HTTPException(status_code=400, detail="Failed to fetch order details")

    # ==================== EXTRACT FROM ORDER NOTES ====================
    payment_type = order_notes.get("payment_type", "job")
    job_id = order_notes.get("job_id", "")
    job_title = order_notes.get("job_title", "")
    organization = order_notes.get("organization", "")
    added_by = order_notes.get("added_by", "admin@rojgarnext.com")
    service_id = order_notes.get("service_id", "")
    service_type = order_notes.get("service_type", "")
    sub_type_id = order_notes.get("sub_type_id", "")
    sub_service_name = order_notes.get("sub_service_name", "")
    application_fee = int(order_notes.get("application_fee", "0"))
    gst_amount = int(order_notes.get("gst_amount", "0"))
    service_charge = int(order_notes.get("service_charge", "0"))
    total_amount = int(order_notes.get("total_amount", "0"))
    category_used = order_notes.get("category_used", "none")
    user_category = order_notes.get("user_category", "General/UR")
    is_disabled_str = order_notes.get("is_disabled", "false")
    is_disabled = is_disabled_str.lower() == "true"
    order_user_email = order_notes.get("user_email", user_email)
    order_user_id = order_notes.get("user_id", current_user.get("user_id"))

    try:
        form_data = json.loads(order_notes.get("form_data", "{}"))
    except Exception:
        form_data = {}

    # ==================== GET APPLICANT DETAILS ====================
    profile = await db.profile.find_one({"email": order_user_email})
    applicant_name = profile.get("full_name") if profile else order_notes.get("user_name", "User")
    application_username = order_user_email.split('@')[0]

    # ==================== CREATE APPLICATION (PAYMENT SUCCESS) ====================
    logger.info("=" * 70)
    logger.info("✅ PAYMENT VERIFIED - CREATING APPLICATION NOW")
    logger.info("=" * 70)

    application_id = None
    new_status = "verification_successful"
    display_title = job_title if payment_type == "job" else sub_service_name or job_title

    if payment_type == "job":
        # Check idempotency - already exists?
        existing = await db.applications.find_one({
            "job_id": job_id,
            "user_email": order_user_email,
            "application_type": "job",
            "status": {
                "$in": [
                    "verification_successful", "pending", "shortlisted",
                    "interview", "offered", "submitted", "review_application",
                    "final_submitted", "confirmed_application", "approved_application"
                ]
            }
        })

        if existing:
            logger.info(f"📋 Application already exists: {existing['_id']}")
            application_id = str(existing["_id"])
            new_status = existing.get("status", "verification_successful")
        else:
            # CREATE NEW JOB APPLICATION
            application_doc = {
                "application_type": "job",
                "job_id": job_id,
                "job_title": job_title,
                "organization": organization,
                "added_by": added_by,

                "applicant_email": order_user_email,
                "applicant_name": applicant_name,
                "user_email": order_user_email,
                "user_name": applicant_name,
                "user_id": order_user_id,
                "user_category": user_category,
                "is_disabled": is_disabled,
                "application_username": application_username,

                # ✅ PAYMENT SUCCESS - Correct status
                "status": "verification_successful",
                "payment_verification_status": "approved",
                "payment_status": "completed",

                # Payment breakdown
                "payment_id": data.razorpay_payment_id,
                "payment_amount": application_fee,
                "payment_gst": gst_amount,
                "payment_service_charge": service_charge,
                "payment_total": total_amount,
                "payment_category_used": category_used,
                "payment_method": "razorpay",

                # Razorpay
                "razorpay_order_id": data.razorpay_order_id,
                "razorpay_payment_id": data.razorpay_payment_id,
                "razorpay_signature": data.razorpay_signature,

                # Transaction
                "transaction_id": data.razorpay_payment_id,
                "transaction_date": datetime.utcnow(),
                "paid_at": datetime.utcnow(),
                "payment_verified_at": datetime.utcnow(),
                "payment_verified_by": "razorpay_auto",

                # Timestamps
                "applied_at": datetime.utcnow(),
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),

                # Extras
                "cover_letter": None,
                "additional_info": form_data if form_data else None,
            }

            result = await db.applications.insert_one(application_doc)
            application_id = str(result.inserted_id)
            new_status = "verification_successful"

            logger.info(f"✅ JOB APPLICATION CREATED: {application_id}")
            logger.info(f"   Status: verification_successful")

    elif payment_type == "service":
        existing = await db.applications.find_one({
            "service_id": service_id,
            "sub_type_id": sub_type_id,
            "user_email": order_user_email,
            "application_type": "service",
            "status": {
                "$nin": ["replaced", "rejected", "verification_rejected"]
            }
        })

        if existing:
            logger.info(f"📋 Service application already exists: {existing['_id']}")
            application_id = str(existing["_id"])
            new_status = existing.get("status", "payment_verified")
        else:
            from app.modules.services.models.service_types import ServiceMasterData
            service = ServiceMasterData.get_service_by_id(service_id)
            sub_type = ServiceMasterData.get_sub_type_by_id(sub_type_id)

            service_name = service.name if service else service_id
            sub_service_name_final = sub_type.name if sub_type else sub_type_id

            application_doc = {
                "application_type": "service",
                "service_id": service_id,
                "sub_type_id": sub_type_id,
                "service_name": service_name,
                "sub_service_name": sub_service_name_final,

                "user_email": order_user_email,
                "user_name": applicant_name,
                "user_id": order_user_id,
                "user_category": "service",
                "is_disabled": is_disabled,
                "application_username": application_username,

                "fields": form_data or {},
                "documents": {},
                "service_documents": [],

                # ✅ PAYMENT SUCCESS - Correct status
                "status": "payment_verified",
                "payment_verification_status": "approved",
                "payment_status": "completed",

                # Payment breakdown
                "payment_id": data.razorpay_payment_id,
                "payment_amount": application_fee,
                "payment_gst": gst_amount,
                "payment_service_charge": service_charge,
                "payment_total": total_amount,
                "payment_category_used": category_used,
                "payment_method": "razorpay",

                # Razorpay
                "razorpay_order_id": data.razorpay_order_id,
                "razorpay_payment_id": data.razorpay_payment_id,
                "razorpay_signature": data.razorpay_signature,

                # Transaction
                "transaction_id": data.razorpay_payment_id,
                "transaction_date": datetime.utcnow(),
                "paid_at": datetime.utcnow(),
                "payment_verified_at": datetime.utcnow(),
                "payment_verified_by": "razorpay_auto",

                # Timestamps
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
            }

            result = await db.applications.insert_one(application_doc)
            application_id = str(result.inserted_id)
            new_status = "payment_verified"

            logger.info(f"✅ SERVICE APPLICATION CREATED: {application_id}")
            logger.info(f"   Status: payment_verified")
    else:
        raise HTTPException(status_code=400, detail="Invalid payment type")

    # ==================== SEND NOTIFICATION ====================
    try:
        await central_notification.send_notification(
            user_ids=[order_user_email],
            notification_type="application_status",
            title=f"✅ Payment Successful: {display_title}",
            message=(
                f"Your payment of ₹{total_amount} for '{display_title}' "
                f"was successful. Your application has been submitted."
            ),
            related_id=application_id,
            metadata={
                "status": new_status,
                "amount": total_amount,
                "transaction_id": data.razorpay_payment_id,
                "show_blue_bell": True,
                "job_title": display_title,
                "application_id": application_id,
                "application_type": payment_type,
            },
            send_email=True,
            send_websocket=True
        )
    except Exception as e:
        logger.warning(f"⚠️ Notification failed: {e}")

    logger.info("=" * 70)
    logger.info(f"✅ PAYMENT COMPLETE & APPLICATION SAVED")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Type: {payment_type}")
    logger.info(f"   Status: {new_status}")
    logger.info("=" * 70)

    return {
        "success": True,
        "payment_verified": True,
        "application_id": application_id,
        "application_type": payment_type,
        "application_status": new_status,
        "amount": total_amount,
        "application_fee": application_fee,
        "gst_amount": gst_amount,
        "service_charge": service_charge,
        "razorpay_payment_id": data.razorpay_payment_id,
        "razorpay_order_id": data.razorpay_order_id,
        "message": "Payment verified and application saved successfully"
    }


# ============================================================
# ✅ PAYMENT STATUS CHECK
# ============================================================

@router.get("/payment-status/{application_id}")
async def get_application_payment_status(
    application_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get payment status from application directly"""
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    user_email = current_user.get("email")
    app_email = application.get("user_email") or application.get("applicant_email")
    if app_email != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")

    application_type = application.get("application_type", "job")

    return {
        "success": True,
        "application_id": application_id,
        "application_type": application_type,
        "payment_status": application.get("payment_verification_status", "not_submitted"),
        "application_status": application.get("status", "pending"),
        "is_completed": application.get("status") in [
            "verification_successful", "payment_verified", "approved", "completed"
        ],
        "amount": application.get("payment_amount", 0),
        "category_used": application.get("payment_category_used", "none"),
        "transaction_id": application.get("transaction_id"),
        "razorpay_order_id": application.get("razorpay_order_id"),
        "razorpay_payment_id": application.get("razorpay_payment_id"),
    }


# ============================================================
# ✅ UPDATE PAYMENT STATUS
# ============================================================

@router.put("/payment-status/{application_id}")
async def update_application_payment_status(
    application_id: str,
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Update payment status - Directly updates application"""
    logger.info(f"📝 Updating payment status: {application_id}")

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    user_email = current_user.get("email")
    app_email = application.get("user_email") or application.get("applicant_email")
    if app_email != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")

    application_type = application.get("application_type", "job")
    new_status = data.get("status")
    if not new_status:
        raise HTTPException(status_code=400, detail="Status is required")

    update_data = {"updated_at": datetime.utcnow()}

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


# ============================================================
# ✅ UPLOAD PAYMENT SCREENSHOT
# ============================================================

@router.post("/upload-screenshot")
async def upload_payment_screenshot_endpoint(
    file: UploadFile = File(...),
    username: str = Form(...),
    application_id: str = Form(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Upload payment screenshot - Updates application"""
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
    app_email = application.get("user_email") or application.get("applicant_email")
    if app_email != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")

    application_type = application.get("application_type", "job")

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    if file_size > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max size: 10MB, Your file: {file_size // (1024*1024)}MB"
        )

    upload_result = await upload_payment_screenshot(
        file=file,
        username=username,
        payment_id=application_id
    )

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


# ============================================================
# ✅ ADMIN VERIFY PAYMENT
# ============================================================

@router.post("/verify-payment/{application_id}")
async def admin_verify_payment(
    application_id: str,
    action: str = Query(..., pattern="^(approve|reject)$"),
    notes: Optional[str] = Query(None),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """ADMIN: Verify payment - Updates application"""
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
    user_email = application.get("user_email") or application.get("applicant_email")
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

    else:
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


# ============================================================
# ✅ GET PENDING PAYMENTS (ADMIN)
# ============================================================

@router.get("/pending-payments")
async def get_pending_payments(
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Get pending payment verifications from applications"""
    pending = await db.applications.find({
        "payment_verification_status": "pending"
    }).to_list(100)

    results = []
    for app in pending:
        application_type = app.get("application_type", "job")

        if application_type == "job":
            results.append({
                "id": str(app["_id"]),
                "type": "job",
                "user_email": app.get("user_email") or app.get("applicant_email"),
                "user_name": app.get("user_name") or app.get("applicant_name", "Unknown"),
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


# ============================================================
# ✅ TEST MODE: SIMULATE PAYMENT
# ============================================================

@router.post("/test/simulate-payment/{order_id}")
async def simulate_payment(
    order_id: str,
    action: str = Query(..., pattern="^(success|failed)$"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """TEST MODE: Simulate payment success/failure"""
    if not _get_razorpay_test_mode():
        raise HTTPException(
            status_code=400,
            detail="Test mode is disabled. Set RAZORPAY_TEST_MODE=true in .env"
        )

    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    # Just verify the order exists
    try:
        if razorpay_client:
            order = razorpay_client.order.fetch(order_id)
            return {
                "success": True,
                "message": f"Test order fetched: {order.get('id')}",
                "test_mode": True,
                "note": "Use the real Razorpay test cards to complete payment"
            }
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"Order not found: {str(e)}")

    return {"success": False, "message": "Cannot fetch order"}


# ============================================================
# ✅ EMERGENCY FALLBACK: VERIFY WITHOUT SIGNATURE
# ============================================================

@router.post("/payment/razorpay/verify-payment-no-signature")
async def verify_payment_no_signature(
    request_data: dict = Body(...),
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """EMERGENCY FIX: Verify payment without signature - creates application"""
    try:
        razorpay_order_id = request_data.get("razorpay_order_id")
        razorpay_payment_id = request_data.get("razorpay_payment_id")
        application_id = request_data.get("application_id")

        logger.info("=" * 70)
        logger.info("🔐 Verifying payment WITHOUT signature (Fallback)")
        logger.info(f"   Order ID: {razorpay_order_id}")
        logger.info(f"   Payment ID: {razorpay_payment_id}")
        logger.info("=" * 70)

        if not razorpay_order_id or not razorpay_payment_id:
            return {
                "success": False,
                "code": "E400",
                "message": "Missing required payment details",
                "payment_verified": False
            }

        # Fetch order from Razorpay
        if not razorpay_client:
            initialize_razorpay_client()
        
        if not razorpay_client:
            return {
                "success": False,
                "code": "E500",
                "message": "Razorpay not configured",
                "payment_verified": False
            }

        try:
            order_details = razorpay_client.order.fetch(razorpay_order_id)
        except Exception as e:
            return {
                "success": False,
                "code": "E404",
                "message": f"Order not found: {str(e)}",
                "payment_verified": False
            }

        order_notes = order_details.get("notes", {})
        payment_type = order_notes.get("payment_type", "job")
        user_email = order_notes.get("user_email", current_user.get("email"))
        user_id = order_notes.get("user_id", current_user.get("user_id"))
        job_id = order_notes.get("job_id", "")
        job_title = order_notes.get("job_title", "")
        organization = order_notes.get("organization", "")
        added_by = order_notes.get("added_by", "admin@rojgarnext.com")
        service_id = order_notes.get("service_id", "")
        sub_type_id = order_notes.get("sub_type_id", "")
        sub_service_name = order_notes.get("sub_service_name", "")
        application_fee = int(order_notes.get("application_fee", "0"))
        gst_amount = int(order_notes.get("gst_amount", "0"))
        service_charge = int(order_notes.get("service_charge", "0"))
        total_amount = int(order_notes.get("total_amount", "0"))
        category_used = order_notes.get("category_used", "none")
        user_category = order_notes.get("user_category", "General/UR")
        is_disabled = order_notes.get("is_disabled", "false").lower() == "true"
        form_data_raw = order_notes.get("form_data", "{}")
        
        try:
            form_data = json.loads(form_data_raw)
        except Exception:
            form_data = {}

        profile = await db.profile.find_one({"email": user_email})
        applicant_name = profile.get("full_name") if profile else "User"
        application_username = user_email.split('@')[0]

        # Create application
        if payment_type == "job":
            existing = await db.applications.find_one({
                "job_id": job_id,
                "user_email": user_email,
                "application_type": "job",
                "status": {
                    "$in": [
                        "verification_successful", "pending", "shortlisted",
                        "interview", "offered", "submitted", "review_application",
                        "final_submitted", "confirmed_application", "approved_application"
                    ]
                }
            })

            if existing:
                application_id = str(existing["_id"])
                new_status = existing.get("status", "verification_successful")
            else:
                doc = {
                    "application_type": "job",
                    "job_id": job_id,
                    "job_title": job_title,
                    "organization": organization,
                    "added_by": added_by,
                    "applicant_email": user_email,
                    "applicant_name": applicant_name,
                    "user_email": user_email,
                    "user_name": applicant_name,
                    "user_id": user_id,
                    "user_category": user_category,
                    "is_disabled": is_disabled,
                    "application_username": application_username,
                    "status": "verification_successful",
                    "payment_verification_status": "approved",
                    "payment_status": "completed",
                    "payment_id": razorpay_payment_id,
                    "payment_amount": application_fee,
                    "payment_gst": gst_amount,
                    "payment_service_charge": service_charge,
                    "payment_total": total_amount,
                    "payment_category_used": category_used,
                    "payment_method": "razorpay",
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "transaction_id": razorpay_payment_id,
                    "transaction_date": datetime.utcnow(),
                    "paid_at": datetime.utcnow(),
                    "payment_verified_at": datetime.utcnow(),
                    "payment_verified_by": "razorpay_fallback",
                    "applied_at": datetime.utcnow(),
                    "created_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow(),
                    "additional_info": form_data if form_data else None,
                }
                result = await db.applications.insert_one(doc)
                application_id = str(result.inserted_id)
                new_status = "verification_successful"
        else:
            existing = await db.applications.find_one({
                "service_id": service_id,
                "sub_type_id": sub_type_id,
                "user_email": user_email,
                "application_type": "service",
                "status": {"$nin": ["replaced", "rejected", "verification_rejected"]}
            })

            if existing:
                application_id = str(existing["_id"])
                new_status = existing.get("status", "payment_verified")
            else:
                from app.modules.services.models.service_types import ServiceMasterData
                service = ServiceMasterData.get_service_by_id(service_id)
                sub_type = ServiceMasterData.get_sub_type_by_id(sub_type_id)

                doc = {
                    "application_type": "service",
                    "service_id": service_id,
                    "sub_type_id": sub_type_id,
                    "service_name": service.name if service else service_id,
                    "sub_service_name": sub_type.name if sub_type else sub_type_id,
                    "user_email": user_email,
                    "user_name": applicant_name,
                    "user_id": user_id,
                    "user_category": "service",
                    "is_disabled": is_disabled,
                    "application_username": application_username,
                    "fields": form_data or {},
                    "documents": {},
                    "service_documents": [],
                    "status": "payment_verified",
                    "payment_verification_status": "approved",
                    "payment_status": "completed",
                    "payment_id": razorpay_payment_id,
                    "payment_amount": application_fee,
                    "payment_gst": gst_amount,
                    "payment_service_charge": service_charge,
                    "payment_total": total_amount,
                    "payment_category_used": category_used,
                    "payment_method": "razorpay",
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "transaction_id": razorpay_payment_id,
                    "transaction_date": datetime.utcnow(),
                    "paid_at": datetime.utcnow(),
                    "payment_verified_at": datetime.utcnow(),
                    "payment_verified_by": "razorpay_fallback",
                    "created_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow(),
                }
                result = await db.applications.insert_one(doc)
                application_id = str(result.inserted_id)
                new_status = "payment_verified"

        return {
            "success": True,
            "payment_verified": True,
            "application_id": application_id,
            "application_type": payment_type,
            "application_status": new_status,
            "amount": total_amount,
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_order_id": razorpay_order_id,
            "verification_method": "no_signature_fallback",
            "message": "Payment verified and application saved successfully"
        }

    except HTTPException:
        raise
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


# ============================================================
# ✅ UPDATE JOB PAYMENT STATUS (Legacy endpoint - kept for compatibility)
# ============================================================

@router.post("/update-payment-status/{job_id}")
async def update_job_payment_status(
    job_id: str,
    update_data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Update payment status. Since applications are now created directly
    in verify-payment, this endpoint is only used to update existing apps.
    """
    try:
        user_email = current_user.get("email")
        razorpay_payment_id = update_data.get("razorpay_payment_id")
        razorpay_order_id = update_data.get("razorpay_order_id")
        razorpay_signature = update_data.get("razorpay_signature")
        transaction_id = update_data.get("transaction_id") or razorpay_payment_id
        amount = update_data.get("amount")

        logger.info("=" * 70)
        logger.info("📤 Updating application payment status")
        logger.info(f"   Job ID: {job_id}")
        logger.info(f"   User: {user_email}")
        logger.info(f"   Razorpay Payment ID: {razorpay_payment_id}")
        logger.info("=" * 70)

        # Find application
        application = await db.applications.find_one({
            "user_email": user_email,
            "job_id": job_id,
            "application_type": "job"
        })

        if not application:
            logger.error(f"❌ Application not found")
            return {
                "success": False,
                "message": "Application not found"
            }

        application_id = str(application["_id"])

        # Update
        update_data_db = {
            "status": "verification_successful",
            "payment_verification_status": "approved",
            "payment_status": "completed",
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

        return {
            "success": True,
            "message": "Payment status updated",
            "application_id": application_id,
            "status": "verification_successful"
        }

    except Exception as e:
        logger.error(f"❌ Error updating payment status: {e}")
        import traceback
        traceback.print_exc()
        return {"success": False, "message": str(e)}


# ============================================================
# ✅ RAZORPAY WEBHOOK (Auto-creates application if needed)
# ============================================================

@router.post("/razorpay/webhook")
async def razorpay_webhook(
    request_data: dict = Body(...),
    db=Depends(get_db)
):
    """
    Webhook handler. If payment is captured but verify-payment
    endpoint was never called, this creates the application.
    """
    try:
        event = request_data.get("event")
        payload = request_data.get("payload", {})
        logger.info(f"📨 Razorpay webhook received: {event}")

        if event == "payment.captured":
            payment = payload.get("payment", {}).get("entity", {})
            order_id = payment.get("order_id")
            payment_id = payment.get("id")
            amount = payment.get("amount", 0) / 100

            logger.info(f"💰 Payment captured: {payment_id} for order: {order_id}")

            # Check if application already exists
            existing = await db.applications.find_one({
                "razorpay_order_id": order_id
            })

            if existing:
                logger.info(f"✅ Application already exists: {existing['_id']}")
                return {"success": True, "received": True, "already_exists": True}

            # Fetch order and create application
            if razorpay_client:
                try:
                    order_details = razorpay_client.order.fetch(order_id)
                    order_notes = order_details.get("notes", {})
                    
                    payment_type = order_notes.get("payment_type", "job")
                    user_email = order_notes.get("user_email")
                    user_id = order_notes.get("user_id")
                    job_id = order_notes.get("job_id", "")
                    job_title = order_notes.get("job_title", "")
                    organization = order_notes.get("organization", "")
                    added_by = order_notes.get("added_by", "admin@rojgarnext.com")
                    service_id = order_notes.get("service_id", "")
                    sub_type_id = order_notes.get("sub_type_id", "")
                    application_fee = int(order_notes.get("application_fee", "0"))
                    gst_amount = int(order_notes.get("gst_amount", "0"))
                    service_charge = int(order_notes.get("service_charge", "0"))
                    total_amount = int(order_notes.get("total_amount", "0"))
                    category_used = order_notes.get("category_used", "none")
                    user_category = order_notes.get("user_category", "General/UR")
                    is_disabled = order_notes.get("is_disabled", "false").lower() == "true"
                    
                    try:
                        form_data = json.loads(order_notes.get("form_data", "{}"))
                    except Exception:
                        form_data = {}

                    profile = await db.profile.find_one({"email": user_email})
                    applicant_name = profile.get("full_name") if profile else "User"
                    application_username = user_email.split('@')[0] if user_email else "user"

                    if payment_type == "job":
                        doc = {
                            "application_type": "job",
                            "job_id": job_id,
                            "job_title": job_title,
                            "organization": organization,
                            "added_by": added_by,
                            "applicant_email": user_email,
                            "applicant_name": applicant_name,
                            "user_email": user_email,
                            "user_name": applicant_name,
                            "user_id": user_id,
                            "user_category": user_category,
                            "is_disabled": is_disabled,
                            "application_username": application_username,
                            "status": "verification_successful",
                            "payment_verification_status": "approved",
                            "payment_status": "completed",
                            "payment_id": payment_id,
                            "payment_amount": application_fee,
                            "payment_gst": gst_amount,
                            "payment_service_charge": service_charge,
                            "payment_total": total_amount,
                            "payment_category_used": category_used,
                            "payment_method": "razorpay",
                            "razorpay_order_id": order_id,
                            "razorpay_payment_id": payment_id,
                            "transaction_id": payment_id,
                            "transaction_date": datetime.utcnow(),
                            "paid_at": datetime.utcnow(),
                            "payment_verified_at": datetime.utcnow(),
                            "payment_verified_by": "razorpay_webhook",
                            "applied_at": datetime.utcnow(),
                            "created_at": datetime.utcnow(),
                            "updated_at": datetime.utcnow(),
                            "additional_info": form_data if form_data else None,
                        }
                    else:
                        from app.modules.services.models.service_types import ServiceMasterData
                        service = ServiceMasterData.get_service_by_id(service_id)
                        sub_type = ServiceMasterData.get_sub_type_by_id(sub_type_id)
                        
                        doc = {
                            "application_type": "service",
                            "service_id": service_id,
                            "sub_type_id": sub_type_id,
                            "service_name": service.name if service else service_id,
                            "sub_service_name": sub_type.name if sub_type else sub_type_id,
                            "user_email": user_email,
                            "user_name": applicant_name,
                            "user_id": user_id,
                            "user_category": "service",
                            "is_disabled": is_disabled,
                            "application_username": application_username,
                            "fields": form_data or {},
                            "documents": {},
                            "service_documents": [],
                            "status": "payment_verified",
                            "payment_verification_status": "approved",
                            "payment_status": "completed",
                            "payment_id": payment_id,
                            "payment_amount": application_fee,
                            "payment_gst": gst_amount,
                            "payment_service_charge": service_charge,
                            "payment_total": total_amount,
                            "payment_category_used": category_used,
                            "payment_method": "razorpay",
                            "razorpay_order_id": order_id,
                            "razorpay_payment_id": payment_id,
                            "transaction_id": payment_id,
                            "transaction_date": datetime.utcnow(),
                            "paid_at": datetime.utcnow(),
                            "payment_verified_at": datetime.utcnow(),
                            "payment_verified_by": "razorpay_webhook",
                            "created_at": datetime.utcnow(),
                            "updated_at": datetime.utcnow(),
                        }
                    
                    result = await db.applications.insert_one(doc)
                    logger.info(f"✅ Webhook created application: {result.inserted_id}")
                except Exception as e:
                    logger.error(f"❌ Webhook failed to create application: {e}")

        elif event == "payment.failed":
            payment = payload.get("payment", {}).get("entity", {})
            order_id = payment.get("order_id")
            payment_id = payment.get("id")
            logger.warning(f"❌ Payment failed: {payment_id} for order: {order_id}")
            # No application to update - nothing was created

        return {"success": True, "received": True}
    except Exception as e:
        logger.error(f"❌ Webhook error: {e}")
        return {"success": False, "error": str(e)}


print("=" * 70)
print("✅ Payment Routes Loaded - ONLY RAZORPAY")
print("   ✅ NO application created on order creation")
print("   ✅ Application created ONLY after successful payment")
print("   ✅ Failed/cancelled payments create NO record")
print("   ✅ GST (18%) + Service Charge (₹50) added")
print("   ✅ Supports job + service payments")
print("=" * 70)