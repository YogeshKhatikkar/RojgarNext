# app/core/services/notification_dispatcher.py
# ============================================================
# 🔔 UNIFIED NOTIFICATION DISPATCHER
# Routes notifications to correct channels based on .env settings.
# Combines: Email + SMS + WhatsApp + In-App + WebSocket
# ============================================================

import logging
from typing import Optional, List, Dict, Any

from app.core.config.settings import settings
from app.core.services.email import send_email_async
from app.core.services.sms import send_sms_async
from app.core.services.whatsapp import send_whatsapp

logger = logging.getLogger(__name__)


# ============================================================
# HIGH-LEVEL NOTIFICATION HELPERS
# ============================================================

async def dispatch_otp(
    email: Optional[str],
    mobile: Optional[str],
    otp: str,
    purpose: str = "verification",
    user_name: Optional[str] = None,
) -> Dict[str, bool]:
    """
    Send OTP to all configured channels.
    """
    channels = settings.get_channels_for("otp")
    results = {"email": False, "sms": False, "whatsapp": False}

    # Email
    if "email" in channels and email:
        from app.core.services.email import _build_otp_email_html
        html = _build_otp_email_html(otp, purpose=purpose)
        results["email"] = await send_email_async(
            to_email=email,
            subject=f"Your RojgarNext OTP ({purpose})",
            html_body=html,
            text_body=f"Your OTP is {otp}. Valid for 10 minutes.",
        )

    # SMS
    if "sms" in channels and mobile:
        results["sms"] = await send_sms_async(
            to_mobile=mobile,
            message=f"Your RojgarNext OTP is {otp}. Valid 10 minutes.",
            template_id=settings.MSG91_TEMPLATE_ID_OTP,
            variables={"otp": otp},
        )

    # WhatsApp
    if "whatsapp" in channels and mobile:
        results["whatsapp"] = await send_whatsapp(
            to_mobile=mobile,
            message=f"Your RojgarNext OTP is {otp}",
            template_id=settings.MSG91_WHATSAPP_TEMPLATE_OTP,
            variables={"otp": otp, "name": user_name or "User"},
        )

    logger.info(f"🔔 OTP dispatched → {results}")
    return results


async def dispatch_verification_success(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
    verified_field: str = "Email",
) -> Dict[str, bool]:
    channels = settings.get_channels_for("verification")
    results = {"email": False, "sms": False, "whatsapp": False}

    if "email" in channels and email:
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2 style="color:#10B981;">✅ {verified_field} Verified!</h2>
        <p>Hi <strong>{user_name}</strong>,</p>
        <p>Your {verified_field.lower()} has been successfully verified on RojgarNext.</p>
        <p>You can now log in and start applying for jobs.</p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject=f"✅ Your {verified_field} is verified",
            html_body=html,
        )

    if "sms" in channels and mobile:
        results["sms"] = await send_sms_async(
            to_mobile=mobile,
            message=f"Hi {user_name}, your {verified_field.lower()} is now verified on RojgarNext. Login to continue.",
            template_id=settings.MSG91_TEMPLATE_ID_VERIFY,
            variables={"name": user_name, "field": verified_field},
        )

    if "whatsapp" in channels and mobile:
        results["whatsapp"] = await send_whatsapp(
            to_mobile=mobile,
            message=f"Hi {user_name}, your {verified_field.lower()} has been verified on RojgarNext.",
            template_id=settings.MSG91_WHATSAPP_TEMPLATE_ALERT,
            variables={"name": user_name, "message": f"Your {verified_field} is verified"},
        )

    logger.info(f"🔔 Verification dispatched → {results}")
    return results


async def dispatch_password_reset(
    email: Optional[str],
    mobile: Optional[str],
    otp: str,
    user_name: str = "User",
) -> Dict[str, bool]:
    return await dispatch_otp(
        email=email,
        mobile=mobile,
        otp=otp,
        purpose="password reset",
        user_name=user_name,
    )


async def dispatch_welcome(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("welcome")
    results = {"email": False, "whatsapp": False}

    if "email" in channels and email:
        html = f"""<!DOCTYPE html>
        <html><body style="font-family:Arial;padding:20px;background:#f4f4f7;">
        <div style="max-width:520px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;">
          <div style="background:linear-gradient(135deg,#6C63FF,#FF6588);color:#fff;padding:28px;text-align:center;">
            <h1>🎉 Welcome to RojgarNext!</h1>
          </div>
          <div style="padding:30px;">
            <p>Hi <strong>{user_name}</strong>,</p>
            <p>Welcome aboard! Your account is ready.</p>
            <ul>
              <li>🔍 Browse thousands of jobs</li>
              <li>🤖 Get AI-powered job matches</li>
              <li>📄 Build a professional resume</li>
              <li>📢 Apply with one tap</li>
            </ul>
            <p>Start your journey today!</p>
          </div>
          <div style="text-align:center;padding:18px;background:#f8f9fc;color:#8a8a9a;font-size:12px;">
            © RojgarNext
          </div>
        </div></body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject="🎉 Welcome to RojgarNext!",
            html_body=html,
        )

    if "whatsapp" in channels and mobile:
        results["whatsapp"] = await send_whatsapp(
            to_mobile=mobile,
            message=f"Welcome to RojgarNext, {user_name}! Start exploring jobs now.",
            template_id=settings.MSG91_WHATSAPP_TEMPLATE_ALERT,
            variables={"name": user_name, "message": "Welcome to RojgarNext!"},
        )

    logger.info(f"🔔 Welcome dispatched → {results}")
    return results


async def dispatch_application_status(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
    job_title: str,
    organization: str,
    status: str,
    notes: Optional[str] = None,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("application_status")
    results = {"email": False, "sms": False, "whatsapp": False}

    status_display = status.replace("_", " ").title()

    if "email" in channels and email:
        notes_block = f"<p><strong>Notes:</strong> {notes}</p>" if notes else ""
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2>📋 Application Update</h2>
        <p>Hi <strong>{user_name}</strong>,</p>
        <p>Your application for <strong>{job_title}</strong> at <strong>{organization}</strong> is now:</p>
        <h3 style="color:#6C63FF;">{status_display}</h3>
        {notes_block}
        <p>Log in to RojgarNext for more details.</p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject=f"Application Status: {status_display}",
            html_body=html,
        )

    if "sms" in channels and mobile:
        results["sms"] = await send_sms_async(
            to_mobile=mobile,
            message=f"Hi {user_name}, your application for {job_title} is now {status_display}.",
            template_id=settings.MSG91_TEMPLATE_ID_ALERT,
            variables={"name": user_name, "job_title": job_title, "status": status_display},
        )

    if "whatsapp" in channels and mobile:
        results["whatsapp"] = await send_whatsapp(
            to_mobile=mobile,
            message=f"Hi {user_name}, your application for {job_title} at {organization} is now: {status_display}",
            template_id=settings.MSG91_WHATSAPP_TEMPLATE_STATUS,
            variables={
                "name": user_name,
                "job_title": job_title,
                "company": organization,
                "status": status_display,
            },
        )

    logger.info(f"🔔 Application status dispatched → {results}")
    return results


async def dispatch_job_alert(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
    job_title: str,
    organization: str,
    location: str,
    job_id: str,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("job_alert")
    results = {"email": False, "whatsapp": False}

    apply_url = f"{settings.APP_BASE_URL}/jobs/{job_id}"

    if "email" in channels and email:
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2>🚀 New Job Alert!</h2>
        <p>Hi <strong>{user_name}</strong>,</p>
        <h3>{job_title}</h3>
        <p><strong>{organization}</strong> — {location}</p>
        <p><a href="{apply_url}" style="display:inline-block;padding:10px 22px;background:#6C63FF;color:#fff;border-radius:8px;text-decoration:none;">View & Apply</a></p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject=f"🚀 New Job: {job_title} at {organization}",
            html_body=html,
        )

    if "whatsapp" in channels and mobile:
        results["whatsapp"] = await send_whatsapp(
            to_mobile=mobile,
            message=f"🚀 New job: {job_title} at {organization} ({location}). Apply: {apply_url}",
            template_id=settings.MSG91_WHATSAPP_TEMPLATE_JOB,
            variables={
                "name": user_name,
                "job_title": job_title,
                "company": organization,
                "location": location,
            },
        )

    logger.info(f"🔔 Job alert dispatched → {results}")
    return results


async def dispatch_payment_status(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
    job_title: str,
    amount: int,
    action: str,  # "approved" or "rejected"
    notes: Optional[str] = None,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("payment")
    results = {"email": False, "sms": False, "whatsapp": False}

    is_ok = action.lower() == "approved"
    status_emoji = "✅" if is_ok else "❌"
    status_word = "Verified Successfully" if is_ok else "Rejected"

    if "email" in channels and email:
        notes_block = f"<p><strong>Reason:</strong> {notes}</p>" if notes else ""
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2>{status_emoji} Payment {status_word}</h2>
        <p>Hi <strong>{user_name}</strong>,</p>
        <p>Your payment of <strong>₹{amount}</strong> for <strong>{job_title}</strong> has been {status_word.lower()}.</p>
        {notes_block}
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject=f"{status_emoji} Payment {status_word}",
            html_body=html,
        )

    if "sms" in channels and mobile:
        results["sms"] = await send_sms_async(
            to_mobile=mobile,
            message=f"Hi {user_name}, your ₹{amount} payment for {job_title} is {status_word}.",
            template_id=settings.MSG91_TEMPLATE_ID_ALERT,
            variables={"name": user_name, "amount": str(amount), "status": status_word},
        )

    if "whatsapp" in channels and mobile:
        results["whatsapp"] = await send_whatsapp(
            to_mobile=mobile,
            message=f"Hi {user_name}, your ₹{amount} payment for {job_title} has been {status_word.lower()}.",
            template_id=settings.MSG91_WHATSAPP_TEMPLATE_STATUS,
            variables={
                "name": user_name,
                "amount": str(amount),
                "status": status_word,
            },
        )

    logger.info(f"🔔 Payment status dispatched → {results}")
    return results


async def dispatch_admin_alert(
    admin_email: str,
    title: str,
    message: str,
    metadata: Optional[Dict[str, Any]] = None,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("admin_alert")
    results = {"email": False}

    if "email" in channels and admin_email:
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2>👑 Admin Alert</h2>
        <h3>{title}</h3>
        <p>{message}</p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=admin_email,
            subject=f"👑 {title}",
            html_body=html,
        )

    logger.info(f"🔔 Admin alert dispatched → {results}")
    return results


print("✅ Notification Dispatcher Loaded")