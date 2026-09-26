# app/modules/auth/service.py
# COMPLETE FIXED VERSION – PROTECTS MOBILE FIELD
# ✅ INTEGRATED: Brevo + MSG91 + WhatsApp via unified dispatcher
# ✅ Keeps legacy imports (send_email, send_mobile_otp) for backward compatibility
# ✅ All OTP sending now goes through dispatch_otp → Email + SMS + WhatsApp
# ✅ Switch providers ONLY via .env — no code changes needed

import secrets
from fastapi import HTTPException, Request, BackgroundTasks
from datetime import datetime, timedelta
from bson import ObjectId
from app.modules.auth.utils import generate_otp
from app.db.connection import get_db, connect_db

# ============================================================
# 📧📱💬 UNIFIED NOTIFICATION IMPORTS
# ============================================================
# Legacy imports — kept for backward compatibility (still work)
from app.core.services.email import send_email
from app.core.services.sms import send_mobile_otp

# NEW unified dispatcher — routes to all configured channels
# (Email + SMS + WhatsApp) based on .env settings
from app.core.services.notification_dispatcher import (
    dispatch_otp,
    dispatch_verification_success,
    dispatch_password_reset,
    dispatch_welcome,
)

from app.core.utils.logger import logger
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    hash_pin,
    verify_pin,
    validate_password,
)
from jose import jwt, JWTError
from app.core.config.settings import settings
import hashlib
import hmac
import asyncio


# ================= DATABASE HELPER (SAFE) =================
async def get_db_safe():
    """Get database connection safely - ensures connection is established"""
    db = get_db()

    if db is None:
        logger.warning("⚠️ Database not initialized! Attempting to connect...")
        try:
            await connect_db()
            db = get_db()
            if db is None:
                raise HTTPException(status_code=500, detail="Database connection failed after retry")
        except Exception as e:
            logger.error(f"❌ Failed to connect to database: {e}")
            raise HTTPException(status_code=500, detail="Database connection failed")

    return db


# ================= OTP HELPERS =================
def hash_otp(otp: str) -> str:
    return hashlib.sha256(otp.encode()).hexdigest()


def verify_hashed_otp(stored: str, provided: str) -> bool:
    if not stored or not provided:
        return False
    return hmac.compare_digest(stored, hash_otp(provided.strip()))


# ================= ASYNC TASK WRAPPERS =================
# BackgroundTasks expects sync callables. These wrappers safely run
# the async dispatcher functions inside a fresh event loop.

def _run_async_dispatch_otp(
    email: str,
    mobile: str,
    otp: str,
    purpose: str,
    user_name: str,
):
    """Sync wrapper for dispatch_otp — used in BackgroundTasks."""
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(
                dispatch_otp(
                    email=email,
                    mobile=mobile,
                    otp=otp,
                    purpose=purpose,
                    user_name=user_name,
                )
            )
        finally:
            loop.close()
    except Exception as e:
        logger.error(f"❌ dispatch_otp background task failed: {e}")


def _run_async_dispatch_verification(
    email: str,
    mobile: str,
    user_name: str,
    verified_field: str = "Email",
):
    """Sync wrapper for dispatch_verification_success."""
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(
                dispatch_verification_success(
                    email=email,
                    mobile=mobile,
                    user_name=user_name,
                    verified_field=verified_field,
                )
            )
        finally:
            loop.close()
    except Exception as e:
        logger.error(f"❌ dispatch_verification_success background task failed: {e}")


def _run_async_dispatch_welcome(
    email: str,
    mobile: str,
    user_name: str,
):
    """Sync wrapper for dispatch_welcome."""
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(
                dispatch_welcome(
                    email=email,
                    mobile=mobile,
                    user_name=user_name,
                )
            )
        finally:
            loop.close()
    except Exception as e:
        logger.error(f"❌ dispatch_welcome background task failed: {e}")


# ================= REGISTER =================
async def register_user(data, background_tasks: BackgroundTasks, role: str = "user"):
    db = await get_db_safe()
    validate_password(data.password)

    email_lower = data.email.lower().strip()
    allowed_roles = ["user", "admin", "customadmin"]
    if role not in allowed_roles:
        role = "user"

    if await db.auth.find_one({"email": email_lower}):
        raise HTTPException(400, "Email already registered")
    if await db.auth.find_one({"mobile": data.mobile}):
        raise HTTPException(400, "Mobile already registered")

    email_otp = generate_otp()
    mobile_otp = "123456" if settings.MOBILE_OTP_BYPASS else generate_otp()

    user_data = {
        "name": data.name.strip(),
        "email": email_lower,
        "mobile": data.mobile.strip(),
        "password": hash_password(data.password),
        "role": role,
        "is_email_verified": False,
        "is_mobile_verified": False,
        "email_otp": hash_otp(email_otp),
        "mobile_otp": hash_otp(mobile_otp),
        "email_otp_attempts": 0,
        "mobile_otp_attempts": 0,
        "email_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
        "mobile_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
        "failed_attempts": 0,
        "created_at": datetime.utcnow()
    }
    await db.auth.insert_one(user_data)

    # ============================================================
    # ✅ UNIFIED OTP DISPATCH
    # Sends OTP to Email + SMS + WhatsApp based on .env settings
    # (see NOTIFY_OTP_CHANNELS in .env)
    # ============================================================
    background_tasks.add_task(
        _run_async_dispatch_otp,
        data.email,
        data.mobile,
        email_otp,  # Same OTP for all channels (email OTP used for consistency)
        "registration",
        data.name,
    )

    logger.info(f"✅ Registration OTP dispatched to {data.email} / +91{data.mobile} via all configured channels")

    return {
        "msg": f"OTP sent to email, mobile, and WhatsApp. Role: {role}. Use 123456 for mobile OTP in dev mode.",
        "role": role
    }


# ================= MPIN SETUP =================
async def setup_mpin_service(data, current_user):
    db = await get_db_safe()

    logger.info(f"🔐 MPIN Setup Request - Email: {data.email}, PIN length: {len(data.pin)}")

    user = await db.auth.find_one({"email": data.email})
    if not user:
        logger.error(f"❌ User not found: {data.email}")
        raise HTTPException(404, "User not found")

    if str(user["_id"]) != current_user.get("user_id"):
        logger.error(f"❌ Unauthorized: User {user['_id']} vs {current_user.get('user_id')}")
        raise HTTPException(403, "Unauthorized")

    if len(data.pin) != 6 or not data.pin.isdigit():
        logger.error(f"❌ Invalid PIN: {data.pin}")
        raise HTTPException(400, "PIN must be 6 digits")

    result = await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "pin": hash_pin(data.pin),
            "is_pin_set": True,
            "pin_attempts": 0
        }}
    )

    if result.modified_count == 0:
        logger.error(f"❌ Failed to set MPIN for {data.email}")
        raise HTTPException(500, "Failed to set MPIN")

    logger.info(f"✅ MPIN set successfully for {data.email}")
    return {"msg": "MPIN setup successfully", "success": True}


# ================= ENABLE BIOMETRIC =================
async def enable_biometric_service(data: dict, current_user):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.get("email")})
    if not user or str(user["_id"]) != current_user.get("user_id"):
        raise HTTPException(403, "Unauthorized")

    await db.auth.update_one(
        {"email": data.get("email")},
        {"$set": {
            "is_biometric_enabled": True,
            "biometric_device_info": data.get("device_info")
        }}
    )
    return {"msg": "Biometric login enabled successfully"}


# ================= MPIN LOGIN =================
async def login_pin(data, request: Request = None):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")

    if not user.get("is_pin_set"):
        raise HTTPException(400, "MPIN not set. Please setup MPIN first.")

    if user.get("pin_attempts", 0) >= 5:
        raise HTTPException(403, "Too many failed attempts. Account locked.")

    if not verify_pin(data.pin, user["pin"]):
        attempts = user.get("pin_attempts", 0) + 1
        update_data = {"pin_attempts": attempts}
        if attempts >= 5:
            update_data["lock_until"] = datetime.utcnow() + timedelta(minutes=30)
        await db.auth.update_one({"email": data.email}, {"$set": update_data})
        raise HTTPException(400, f"Invalid MPIN. {5 - attempts} attempts remaining.")

    # ==================== LOCATION HANDLING ====================
    location_doc = None
    if hasattr(data, 'latitude') and data.latitude is not None and data.latitude != 0:
        from app.core.location.location_handler import location_handler
        location_data = await location_handler.get_location_name(data.latitude, data.longitude)
        location_doc = {
            "latitude": data.latitude,
            "longitude": data.longitude,
            "location_name": data.location_name or location_data.get("location_name", f"{data.latitude}, {data.longitude}"),
            "city": location_data.get("city", ""),
            "district": location_data.get("district", ""),
            "state": location_data.get("state", ""),
            "country": location_data.get("country", "India"),
            "last_updated": datetime.utcnow()
        }
        await db.auth.update_one(
            {"email": data.email},
            {"$set": {"current_location": location_doc, "last_location_update": datetime.utcnow()}}
        )
        logger.info(f"📍 MPIN Login - Location saved: {location_doc.get('location_name')}")
    else:
        location_doc = user.get("current_location")
        logger.info(f"📍 MPIN Login - Using existing location")

    # Reset pin attempts and update last login
    await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "pin_attempts": 0,
            "last_login": datetime.utcnow(),
            "last_login_ip": request.client.host if request else ""
        }}
    )

    # ==================== GET PROFILE DATA ====================
    profile = await db.profile.find_one({"email": data.email})

    # ✅ FIXED: Preserve existing mobile if not found in profile
    mobile = user.get("mobile", "")
    if not mobile and profile:
        mobile = profile.get("phone", "")

    full_name = profile.get("full_name", "") if profile else ""
    if not full_name:
        full_name = user.get("name", "")

    # Create access token
    access_token = create_access_token({
        "user_id": str(user["_id"]),
        "role": user["role"],
        "email": user["email"],
        "name": full_name
    })

    refresh_token = create_refresh_token({"user_id": str(user["_id"])})

    # ==================== STORE SESSION ====================
    session_data = {
        "user_id": str(user["_id"]),
        "user_email": user["email"],
        "session_hash": secrets.token_hex(32),
        "ip": request.client.host if request else "",
        "device": request.headers.get("user-agent", "Unknown") if request else "Unknown",
        "created_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(days=3),
        "is_active": True
    }
    await db.sessions.insert_one(session_data)

    logger.info(f"✅ MPIN Login successful for {data.email}")

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "role": user["role"],
        "email": user["email"],
        "name": full_name,
        "mobile": mobile,  # ✅ Return preserved mobile
        "current_location": location_doc if location_doc else user.get("current_location")
    }


# ================= BIOMETRIC LOGIN =================
async def biometric_login_service(data, request: Request):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")

    if not user.get("is_biometric_enabled"):
        raise HTTPException(400, "Biometric not enabled. Please enable it in settings.")

    # ==================== LOCATION HANDLING ====================
    location_doc = None
    if data.latitude is not None and data.longitude is not None and data.latitude != 0:
        from app.core.location.location_handler import location_handler
        location_data = await location_handler.get_location_name(data.latitude, data.longitude)
        location_doc = {
            "latitude": data.latitude,
            "longitude": data.longitude,
            "location_name": data.location_name or location_data.get("location_name", f"{data.latitude}, {data.longitude}"),
            "city": location_data.get("city", ""),
            "district": location_data.get("district", ""),
            "state": location_data.get("state", ""),
            "country": location_data.get("country", "India"),
            "last_updated": datetime.utcnow()
        }
        await db.auth.update_one(
            {"email": data.email},
            {"$set": {"current_location": location_doc, "last_location_update": datetime.utcnow()}}
        )
        logger.info(f"📍 Biometric Login - Location saved: {location_doc.get('location_name')}")
    else:
        location_doc = user.get("current_location")
        logger.info(f"📍 Biometric Login - Using existing location")

    # Update last login
    await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "last_login": datetime.utcnow(),
            "last_login_ip": request.client.host if request else ""
        }}
    )

    # ==================== GET PROFILE DATA ====================
    profile = await db.profile.find_one({"email": data.email})

    # ✅ FIXED: Preserve existing mobile
    mobile = user.get("mobile", "")
    if not mobile and profile:
        mobile = profile.get("phone", "")

    full_name = profile.get("full_name", "") if profile else ""
    if not full_name:
        full_name = user.get("name", "")

    # Create tokens
    access_token = create_access_token({
        "user_id": str(user["_id"]),
        "role": user["role"],
        "email": user["email"],
        "name": full_name
    })
    refresh_token = create_refresh_token({"user_id": str(user["_id"])})

    # Store session
    session_data = {
        "user_id": str(user["_id"]),
        "user_email": user["email"],
        "session_hash": secrets.token_hex(32),
        "ip": request.client.host if request else "",
        "device": request.headers.get("user-agent", "Unknown") if request else "Unknown",
        "created_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(days=3),
        "is_active": True
    }
    await db.sessions.insert_one(session_data)

    logger.info(f"✅ Biometric Login successful for {data.email}")

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "role": user["role"],
        "email": user["email"],
        "name": full_name,
        "mobile": mobile,  # ✅ Return preserved mobile
        "current_location": location_doc if location_doc else user.get("current_location")
    }


# ================= SET PIN (LEGACY) =================
async def set_pin(data):
    db = await get_db_safe()
    if len(data.pin) != 6 or not data.pin.isdigit():
        raise HTTPException(400, "PIN must be 6 digits")
    await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "pin": hash_pin(data.pin),
            "is_pin_set": True,
            "pin_attempts": 0
        }}
    )
    return {"msg": "PIN set"}


# ================= NORMAL RESEND OTP =================
async def send_email_otp_service(email: str, background_tasks: BackgroundTasks):
    """
    Resend email OTP.
    ✅ Now uses unified dispatcher → sends to Email + SMS + WhatsApp.
    """
    db = await get_db_safe()
    user = await db.auth.find_one({"email": email})
    if not user:
        raise HTTPException(404, "User not found")
    if user.get("last_otp_sent") and datetime.utcnow() < user["last_otp_sent"] + timedelta(seconds=30):
        raise HTTPException(429, "Wait 30 seconds before resending")

    otp = generate_otp()
    await db.auth.update_one(
        {"email": email},
        {"$set": {
            "email_otp": hash_otp(otp),
            "email_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
            "email_otp_attempts": 0,
            "last_otp_sent": datetime.utcnow()
        }}
    )

    # ============================================================
    # ✅ UNIFIED DISPATCH — Email + SMS + WhatsApp
    # ============================================================
    mobile = user.get("mobile", "")
    background_tasks.add_task(
        _run_async_dispatch_otp,
        email,
        mobile,
        otp,
        "email verification",
        user.get("name", "User"),
    )

    logger.info(f"✅ OTP resent to {email} via all configured channels (Email/SMS/WhatsApp)")
    return {"msg": "OTP resent successfully to email, mobile, and WhatsApp"}


async def send_mobile_otp_service(mobile: str, background_tasks: BackgroundTasks):
    """
    Resend mobile OTP.
    ✅ Now uses unified dispatcher → sends to Email + SMS + WhatsApp.
    """
    db = await get_db_safe()
    user = await db.auth.find_one({"mobile": mobile})
    if not user:
        raise HTTPException(404, "User not found")
    if user.get("last_otp_sent") and datetime.utcnow() < user["last_otp_sent"] + timedelta(seconds=30):
        raise HTTPException(429, "Wait 30 seconds before resending")

    otp = "123456" if settings.MOBILE_OTP_BYPASS else generate_otp()
    await db.auth.update_one(
        {"mobile": mobile},
        {"$set": {
            "mobile_otp": hash_otp(otp),
            "mobile_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
            "mobile_otp_attempts": 0,
            "last_otp_sent": datetime.utcnow()
        }}
    )

    # ============================================================
    # ✅ UNIFIED DISPATCH — Email + SMS + WhatsApp
    # ============================================================
    email = user.get("email", "")
    background_tasks.add_task(
        _run_async_dispatch_otp,
        email,
        mobile,
        otp,
        "mobile verification",
        user.get("name", "User"),
    )

    logger.info(f"✅ Mobile OTP resent to +91{mobile} via all configured channels (Email/SMS/WhatsApp)")
    return {"msg": "Mobile OTP resent successfully to email, mobile, and WhatsApp"}


# ================= VERIFY NORMAL OTP =================
async def verify_email_otp(data):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")
    if not user.get("email_otp_expiry") or datetime.utcnow() > user["email_otp_expiry"]:
        raise HTTPException(400, "OTP expired")
    if user.get("email_otp_attempts", 0) >= 5:
        raise HTTPException(429, "Too many attempts")
    if not verify_hashed_otp(user.get("email_otp"), data.otp):
        await db.auth.update_one({"email": data.email}, {"$inc": {"email_otp_attempts": 1}})
        raise HTTPException(400, "Invalid OTP")
    await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "is_email_verified": True,
            "email_otp": None,
            "email_otp_expiry": None
        }}
    )
    return {"msg": "Email verified"}


async def verify_mobile_otp(data):
    db = await get_db_safe()
    user = await db.auth.find_one({"mobile": data.mobile})
    if not user:
        raise HTTPException(404, "User not found")
    if not user.get("mobile_otp_expiry") or datetime.utcnow() > user["mobile_otp_expiry"]:
        raise HTTPException(400, "OTP expired")
    if user.get("mobile_otp_attempts", 0) >= 5:
        raise HTTPException(429, "Too many attempts")
    is_valid = False
    if settings.MOBILE_OTP_BYPASS and data.otp == "123456":
        is_valid = True
    else:
        is_valid = verify_hashed_otp(user.get("mobile_otp"), data.otp)
    if not is_valid:
        await db.auth.update_one({"mobile": data.mobile}, {"$inc": {"mobile_otp_attempts": 1}})
        raise HTTPException(400, "Invalid OTP")
    await db.auth.update_one(
        {"mobile": data.mobile},
        {"$set": {
            "is_mobile_verified": True,
            "mobile_otp": None,
            "mobile_otp_expiry": None,
            "mobile_otp_attempts": 0
        }}
    )
    return {"msg": "Mobile verified successfully"}


# ================= LOGIN (Email + Password) =================
async def login_user(data, request: Request):
    db = await get_db_safe()
    email_lower = data.email.lower().strip()

    # ✅ Step 1: Check if user exists
    user = await db.auth.find_one({"email": email_lower})
    if not user:
        logger.warning(f"❌ Login failed: User not found - {email_lower}")
        raise HTTPException(400, "Invalid email or password")

    # ✅ Step 2: Check if account is locked
    if user.get("lock_until") and datetime.utcnow() < user["lock_until"]:
        logger.warning(f"❌ Login failed: Account locked for {email_lower}")
        raise HTTPException(403, "Account temporarily locked. Please try again later.")

    # ✅ Step 3: Check if email and mobile are verified
    if not user.get("is_email_verified", False):
        logger.warning(f"❌ Login failed: Email not verified for {email_lower}")
        raise HTTPException(403, "Please verify your email first. Check your inbox for OTP.")

    if not user.get("is_mobile_verified", False):
        logger.warning(f"❌ Login failed: Mobile not verified for {email_lower}")
        raise HTTPException(403, "Please verify your mobile number first.")

    # ✅ Step 4: Verify password
    if not verify_password(data.password, user["password"]):
        attempts = user.get("failed_attempts", 0) + 1
        update_data = {"failed_attempts": attempts}

        if attempts >= 5:
            update_data["lock_until"] = datetime.utcnow() + timedelta(minutes=30)
            logger.warning(f"❌ Login failed: Account locked after {attempts} attempts for {email_lower}")
            raise HTTPException(403, f"Too many failed attempts. Account locked for 30 minutes.")

        await db.auth.update_one({"email": email_lower}, {"$set": update_data})
        remaining = 5 - attempts
        logger.warning(f"❌ Login failed: Invalid password for {email_lower} (Attempts: {attempts}/5)")
        raise HTTPException(400, f"Invalid email or password. {remaining} attempts remaining.")

    # ✅ Step 5: Reset failed attempts on successful login
    user_role = user.get("role", "user")
    if user_role == "custom_admin":
        user_role = "customadmin"

    await db.auth.update_one(
        {"email": email_lower},
        {"$set": {
            "failed_attempts": 0,
            "lock_until": None,
            "last_login": datetime.utcnow(),
            "last_login_ip": request.client.host
        }}
    )

    # ✅ Step 6: Get profile data
    profile = await db.profile.find_one({"email": email_lower})

    # ✅ FIXED: Preserve existing mobile
    mobile = user.get("mobile", "")
    if not mobile and profile:
        mobile = profile.get("phone", "")

    full_name = profile.get("full_name", "") if profile else ""
    if not full_name:
        full_name = user.get("name", "")

    # ✅ Step 7: Create tokens
    payload = {
        "user_id": str(user["_id"]),
        "role": user_role,
        "email": user["email"],
        "name": full_name
    }

    access = create_access_token(payload)
    refresh = create_refresh_token({"user_id": str(user["_id"])})

    # ✅ Step 8: Store session
    await db.sessions.insert_one({
        "user_id": str(user["_id"]),
        "user_email": user["email"],
        "role": user_role,
        "session_hash": secrets.token_hex(32),
        "refresh_token": refresh,
        "ip": request.client.host,
        "device": request.headers.get("user-agent", "Unknown"),
        "created_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(days=7),
        "is_active": True
    })

    logger.info(f"✅ Login successful for {email_lower}")

    return {
        "access_token": access,
        "refresh_token": refresh,
        "role": user_role,
        "email": user["email"],
        "name": full_name,
        "mobile": mobile  # ✅ Return preserved mobile
    }


# ================= REFRESH TOKEN =================
async def refresh_access_token(data):
    try:
        payload = jwt.decode(data.refresh_token, settings.JWT_SECRET_KEY, algorithms=["HS256"])
        if payload.get("type") != "refresh":
            raise HTTPException(401, "Invalid refresh token")
        user_id = payload.get("user_id")
        db = await get_db_safe()
        session = await db.sessions.find_one({
            "user_id": user_id,
            "refresh_token": data.refresh_token
        })
        if not session:
            raise HTTPException(401, "Session expired")
        user = await db.auth.find_one({"_id": ObjectId(user_id)})
        user_role = user.get("role", "user") if user else "user"
        new_access = create_access_token({
            "user_id": user_id,
            "role": user_role,
            "email": user.get("email") if user else None
        })
        return {"access_token": new_access}
    except JWTError:
        raise HTTPException(401, "Invalid refresh token")


# ================= FORGOT PASSWORD =================
async def forgot_password(email: str, background_tasks: BackgroundTasks):
    db = await get_db_safe()
    email_lower = email.lower().strip()
    user = await db.auth.find_one({"email": email_lower})

    if not user:
        raise HTTPException(400, "Invalid email")

    # ✅ FIX: Get mobile from different possible locations
    user_mobile = user.get("mobile")

    # If mobile not in auth, try to get from profile
    if not user_mobile:
        profile = await db.profile.find_one({"email": email_lower})
        if profile:
            user_mobile = profile.get("phone") or profile.get("mobile")
            # Also update auth with this mobile for future use
            if user_mobile:
                await db.auth.update_one(
                    {"email": email_lower},
                    {"$set": {"mobile": user_mobile}}
                )
                logger.info(f"✅ Mobile synced from profile to auth for {email_lower}")

    # If still no mobile, allow password reset without mobile OTP (but log warning)
    if not user_mobile:
        logger.warning(f"⚠️ No mobile number found for {email_lower}. Will send only email OTP.")

        email_otp = generate_otp()
        await db.auth.update_one(
            {"email": email_lower},
            {"$set": {
                "reset_email_otp": hash_otp(email_otp),
                "reset_email_verified": False,
                "reset_email_expiry": datetime.utcnow() + timedelta(minutes=10),
                "last_otp_sent": datetime.utcnow(),
                # Mark mobile as verified by default for reset flow
                "reset_mobile_verified": True
            }}
        )

        # ============================================================
        # ✅ UNIFIED DISPATCH — sends to whichever channels are available
        # (Email always; SMS/WhatsApp only if mobile is present)
        # ============================================================
        background_tasks.add_task(
            _run_async_dispatch_otp,
            email_lower,
            user_mobile or "",  # empty → SMS/WhatsApp skipped
            email_otp,
            "password reset",
            user.get("name", "User"),
        )

        logger.info(f"📧 Reset OTP sent to {email_lower} (email only)")
        return {
            "msg": "Reset OTP sent to your email",
            "email": email_lower,
            "mobile": None,
            "mobile_missing": True
        }

    # User has mobile, proceed with both OTPs
    email_otp = generate_otp()
    mobile_otp = "123456" if settings.MOBILE_OTP_BYPASS else generate_otp()

    await db.auth.update_one(
        {"email": email_lower},
        {"$set": {
            "reset_email_otp": hash_otp(email_otp),
            "reset_mobile_otp": hash_otp(mobile_otp),
            "reset_email_verified": False,
            "reset_mobile_verified": False,
            "reset_email_expiry": datetime.utcnow() + timedelta(minutes=10),
            "reset_mobile_expiry": datetime.utcnow() + timedelta(minutes=10),
            "last_otp_sent": datetime.utcnow()
        }}
    )

    # ============================================================
    # ✅ UNIFIED DISPATCH — Email + SMS + WhatsApp
    # ============================================================
    background_tasks.add_task(
        _run_async_dispatch_otp,
        email_lower,
        user_mobile,
        email_otp,
        "password reset",
        user.get("name", "User"),
    )

    logger.info(f"📧 Reset OTP sent to {email_lower} and mobile {user_mobile} via all configured channels")

    return {
        "msg": "Reset OTP sent to your email, mobile, and WhatsApp",
        "email": email_lower,
        "mobile": user_mobile,
        "mobile_missing": False
    }


# ================= RESEND RESET OTP SERVICES =================

async def resend_reset_email_otp_service(email: str, background_tasks: BackgroundTasks):
    """Resend reset email OTP - Service function"""
    db = await get_db_safe()
    user = await db.auth.find_one({"email": email})
    if not user:
        raise HTTPException(404, "User not found")

    if user.get("last_otp_sent") and datetime.utcnow() < user["last_otp_sent"] + timedelta(seconds=30):
        raise HTTPException(429, "Please wait 30 seconds before resending")

    otp = generate_otp()
    await db.auth.update_one(
        {"email": email},
        {"$set": {
            "reset_email_otp": hash_otp(otp),
            "reset_email_expiry": datetime.utcnow() + timedelta(minutes=10),
            "reset_email_attempts": 0,
            "reset_email_verified": False,
            "last_otp_sent": datetime.utcnow()
        }}
    )

    # ✅ UNIFIED DISPATCH — Email + SMS + WhatsApp
    mobile = user.get("mobile", "")
    background_tasks.add_task(
        _run_async_dispatch_otp,
        email,
        mobile,
        otp,
        "password reset",
        user.get("name", "User"),
    )

    logger.info(f"✅ Reset OTP resent to {email} via all configured channels")
    return {"msg": "Reset OTP resent successfully to email, mobile, and WhatsApp"}


async def resend_reset_mobile_otp_service(mobile: str, background_tasks: BackgroundTasks):
    """Resend reset mobile OTP - Service function"""
    db = await get_db_safe()
    user = await db.auth.find_one({"mobile": mobile})
    if not user:
        raise HTTPException(404, "User not found")

    if user.get("last_otp_sent") and datetime.utcnow() < user["last_otp_sent"] + timedelta(seconds=30):
        raise HTTPException(429, "Please wait 30 seconds before resending")

    otp = "123456" if settings.MOBILE_OTP_BYPASS else generate_otp()
    await db.auth.update_one(
        {"mobile": mobile},
        {"$set": {
            "reset_mobile_otp": hash_otp(otp),
            "reset_mobile_expiry": datetime.utcnow() + timedelta(minutes=10),
            "reset_mobile_attempts": 0,
            "reset_mobile_verified": False,
            "last_otp_sent": datetime.utcnow()
        }}
    )

    # ✅ UNIFIED DISPATCH — Email + SMS + WhatsApp
    email = user.get("email", "")
    background_tasks.add_task(
        _run_async_dispatch_otp,
        email,
        mobile,
        otp,
        "password reset",
        user.get("name", "User"),
    )

    logger.info(f"✅ Reset Mobile OTP resent to +91{mobile} via all configured channels")
    return {"msg": "Reset Mobile OTP resent successfully to email, mobile, and WhatsApp"}


# ================= VERIFY RESET OTP =================
async def verify_reset_email_otp(data):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")

    if not user.get("reset_email_expiry") or datetime.utcnow() > user["reset_email_expiry"]:
        raise HTTPException(400, "Reset Email OTP expired")

    if user.get("reset_email_attempts", 0) >= 5:
        raise HTTPException(429, "Too many attempts")

    is_valid = verify_hashed_otp(user.get("reset_email_otp"), data.otp)

    if not is_valid:
        await db.auth.update_one({"email": data.email}, {"$inc": {"reset_email_attempts": 1}})
        raise HTTPException(400, "Invalid Reset Email OTP")

    await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "reset_email_verified": True,
            "reset_email_otp": None,
            "reset_email_expiry": None,
            "reset_email_attempts": 0
        }}
    )
    return {"msg": "Reset Email OTP verified"}


async def verify_reset_mobile_otp(data):
    db = await get_db_safe()
    user = await db.auth.find_one({"mobile": data.mobile})

    if not user:
        user = await db.auth.find_one({"email": data.mobile})
        if not user:
            raise HTTPException(404, "User not found")

    # ✅ If mobile verification is already marked as True (for users without mobile)
    if user.get("reset_mobile_verified") == True:
        return {"msg": "Reset Mobile OTP already verified"}

    if not user.get("reset_mobile_expiry") or datetime.utcnow() > user["reset_mobile_expiry"]:
        raise HTTPException(400, "Reset Mobile OTP expired")

    if user.get("reset_mobile_attempts", 0) >= 5:
        raise HTTPException(429, "Too many attempts")

    is_valid = False
    if settings.MOBILE_OTP_BYPASS and data.otp == "123456":
        is_valid = True
    else:
        is_valid = verify_hashed_otp(user.get("reset_mobile_otp"), data.otp)

    if not is_valid:
        await db.auth.update_one({"_id": user["_id"]}, {"$inc": {"reset_mobile_attempts": 1}})
        raise HTTPException(400, "Invalid Reset Mobile OTP")

    await db.auth.update_one(
        {"_id": user["_id"]},
        {"$set": {
            "reset_mobile_verified": True,
            "reset_mobile_otp": None,
            "reset_mobile_expiry": None,
            "reset_mobile_attempts": 0
        }}
    )
    return {"msg": "Reset Mobile OTP verified"}


# ================= RESET PASSWORD - FIXED (PRESERVES MOBILE) =================
async def reset_password(data):
    db = await get_db_safe()
    validate_password(data.new_password)
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")

    # ✅ Check verification status
    email_verified = user.get("reset_email_verified", False)
    mobile_verified = user.get("reset_mobile_verified", False)

    # If user has no mobile in DB, we only need email verification
    user_mobile = user.get("mobile")
    if not user_mobile:
        profile = await db.profile.find_one({"email": data.email})
        if profile:
            user_mobile = profile.get("phone") or profile.get("mobile")

    if not user_mobile:
        # No mobile in system, only require email verification
        if not email_verified:
            raise HTTPException(403, "Please verify email OTP first")
    else:
        # User has mobile, require both verifications
        if not email_verified or not mobile_verified:
            raise HTTPException(403, "Please verify both email and mobile OTP first")

    new_hashed = hash_password(data.new_password)
    if verify_password(data.new_password, user.get("password", "")):
        raise HTTPException(400, "New password cannot be same as old password")

    # ✅ CRITICAL FIX: Update ONLY password and reset flags
    # DO NOT modify or delete the mobile field
    result = await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "password": new_hashed,
            "reset_email_verified": False,
            "reset_mobile_verified": False,
            "reset_email_otp": None,
            "reset_mobile_otp": None,
            "reset_email_expiry": None,
            "reset_mobile_expiry": None,
            "reset_email_attempts": 0,
            "reset_mobile_attempts": 0,
            "failed_attempts": 0,
            "lock_until": None
        }}
        # ✅ MOBILE FIELD IS NOT TOUCHED - stays as is
    )

    if result.modified_count == 0:
        logger.error(f"❌ Password reset failed – no document updated for {data.email}")
        raise HTTPException(500, "Password reset failed. Please try again.")

    logger.info(f"✅ Password reset successful for {data.email}")
    return {"msg": "Password reset successful"}


# ================= LOGOUT =================
async def logout_all(user):
    db = await get_db_safe()
    await db.sessions.delete_many({"user_id": user["user_id"]})
    return {"msg": "Logged out from all devices"}


# ================= ROLE MANAGEMENT (Superadmin only) =================
async def get_user_role(email: str, current_user: dict):
    db = await get_db_safe()
    if current_user.get("role") != "superadmin":
        raise HTTPException(403, "Only superadmin can view user roles")
    user = await db.auth.find_one({"email": email})
    if not user:
        raise HTTPException(404, "User not found")
    return {
        "email": user["email"],
        "name": user["name"],
        "role": user.get("role", "user"),
        "is_active": user.get("is_active", True),
        "last_login": user.get("last_login").isoformat() if user.get("last_login") else None
    }


async def update_user_role(email: str, new_role: str, current_user: dict):
    db = await get_db_safe()
    if current_user.get("role") != "superadmin":
        raise HTTPException(403, "Only superadmin can update user roles")
    allowed_roles = ["user", "admin", "customadmin", "superadmin"]
    if new_role not in allowed_roles:
        raise HTTPException(400, f"Invalid role. Allowed: {allowed_roles}")
    if current_user.get("email") == email and new_role != "superadmin":
        raise HTTPException(403, "Superadmin cannot demote themselves")
    user = await db.auth.find_one({"email": email})
    if not user:
        raise HTTPException(404, "User not found")
    old_role = user.get("role", "user")
    result = await db.auth.update_one(
        {"email": email},
        {"$set": {
            "role": new_role,
            "role_updated_at": datetime.utcnow(),
            "role_updated_by": current_user.get("email")
        }}
    )
    logger.info(f"User {email} role changed from {old_role} to {new_role} by {current_user.get('email')}")
    return {
        "email": email,
        "old_role": old_role,
        "new_role": new_role,
        "updated_by": current_user.get("email")
    }


async def get_all_users_roles(current_user: dict):
    db = await get_db_safe()
    if current_user.get("role") != "superadmin":
        raise HTTPException(403, "Only superadmin can view all users")
    users = await db.auth.find({}, {
        "_id": 1,
        "email": 1,
        "name": 1,
        "role": 1,
        "is_active": 1,
        "last_login": 1,
        "created_at": 1
    }).to_list(1000)
    return [
        {
            "id": str(u["_id"]),
            "email": u["email"],
            "name": u.get("name", ""),
            "role": u.get("role", "user"),
            "is_active": u.get("is_active", True),
            "last_login": u.get("last_login").isoformat() if u.get("last_login") else None,
            "created_at": u.get("created_at").isoformat() if u.get("created_at") else None
        }
        for u in users
    ]


async def send_verification_notification(email: str, user_id: str, name: str):
    from app.modules.notification.service import central_notification
    await central_notification.notify_user_verified(email, name, user_id)


print("✅ Auth Service Loaded — Brevo + MSG91 + WhatsApp integrated")