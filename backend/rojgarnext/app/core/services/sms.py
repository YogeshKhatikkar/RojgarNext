# app/core/services/sms.py
# ============================================================
# 📱 UNIFIED SMS SERVICE
# Supports: Twilio | MSG91 | Fast2SMS | Brevo
# Switch via SMS_PROVIDER in .env — NO CODE CHANGES NEEDED
# ============================================================

import logging
import httpx
from typing import Optional

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


# ============================================================
# BASE PROVIDER
# ============================================================
class BaseSMSProvider:
    name = "base"

    async def send_sms(
        self, to_mobile: str, message: str, template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        raise NotImplementedError

    def send_sms_sync(
        self, to_mobile: str, message: str, template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        raise NotImplementedError


# ============================================================
# 1️⃣ TWILIO
# ============================================================
class TwilioSMSProvider(BaseSMSProvider):
    name = "twilio"

    def __init__(self):
        self.sid = settings.TWILIO_ACCOUNT_SID
        self.token = settings.TWILIO_AUTH_TOKEN
        self.from_number = settings.TWILIO_PHONE

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("+"):
            return mobile
        if mobile.startswith("91") and len(mobile) == 12:
            return f"+{mobile}"
        return f"+91{mobile}"

    async def send_sms(
        self, to_mobile: str, message: str, template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if not self.sid or not self.token:
            logger.warning("❌ [Twilio] Not configured")
            return False
        try:
            from twilio.rest import Client
            client = Client(self.sid, self.token)
            to = self._format_mobile(to_mobile)
            client.messages.create(
                body=message,
                from_=self.from_number,
                to=to,
            )
            logger.info(f"✅ [Twilio] SMS sent to {to}")
            return True
        except Exception as e:
            logger.error(f"❌ [Twilio] Exception: {e}")
            return False

    def send_sms_sync(self, *args, **kwargs) -> bool:
        import asyncio
        try:
            return asyncio.run(self.send_sms(*args, **kwargs))
        except Exception:
            return False


# ============================================================
# 2️⃣ MSG91
# ============================================================
class MSG91SMSProvider(BaseSMSProvider):
    """
    MSG91 Flow API (v5).
    Requires DLT-registered templates for India.
    """
    name = "msg91"
    SEND_OTP_URL = "https://control.msg91.com/api/v5/otp"
    SEND_FLOW_URL = "https://control.msg91.com/api/v5/flow/"

    def __init__(self):
        self.auth_key = settings.MSG91_AUTH_KEY
        self.sender_id = settings.MSG91_SENDER_ID
        self.template_otp = settings.MSG91_TEMPLATE_ID_OTP
        self.template_verify = settings.MSG91_TEMPLATE_ID_VERIFY
        self.template_alert = settings.MSG91_TEMPLATE_ID_ALERT
        self.country = settings.MSG91_COUNTRY or "91"
        self.dlt_te_id = settings.MSG91_DLT_TE_ID

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("+"):
            mobile = mobile[1:]
        if mobile.startswith(self.country):
            return mobile
        return f"{self.country}{mobile}"

    async def send_sms(
        self, to_mobile: str, message: str, template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if not self.auth_key:
            logger.warning("❌ [MSG91] AUTH_KEY not configured")
            return False

        mobile = self._format_mobile(to_mobile)
        headers = {
            "authkey": self.auth_key,
            "Content-Type": "application/json",
        }

        # ---- If OTP template + OTP value present, use OTP API ----
        if template_id and variables and "otp" in (variables or {}):
            try:
                payload = {
                    "template_id": template_id,
                    "mobile": mobile,
                    "otp": str(variables.get("otp")),
                    "otp_expiry": 10,
                }
                async with httpx.AsyncClient(timeout=20.0) as client:
                    r = await client.post(
                        self.SEND_OTP_URL, json=payload, headers=headers
                    )
                    if r.status_code in (200, 201):
                        logger.info(f"✅ [MSG91] OTP SMS sent to {mobile}")
                        return True
                    logger.error(f"❌ [MSG91] Failed: {r.status_code} {r.text[:300]}")
                    return False
            except Exception as e:
                logger.error(f"❌ [MSG91] OTP exception: {e}")
                return False

        # ---- Otherwise use Flow API with template ----
        tpl = template_id or self.template_alert
        if not tpl:
            logger.warning("❌ [MSG91] No template ID for flow API")
            return False

        try:
            payload = {
                "template_id": tpl,
                "sender": self.sender_id,
                "short_url": "0",
                "recipients": [
                    {"mobiles": mobile, **(variables or {})}
                ],
            }
            if self.dlt_te_id:
                payload["DLT_TE_ID"] = self.dlt_te_id

            async with httpx.AsyncClient(timeout=20.0) as client:
                r = await client.post(
                    self.SEND_FLOW_URL, json=payload, headers=headers
                )
                if r.status_code in (200, 201):
                    logger.info(f"✅ [MSG91] Flow SMS sent to {mobile}")
                    return True
                logger.error(f"❌ [MSG91] Failed: {r.status_code} {r.text[:300]}")
                return False
        except Exception as e:
            logger.error(f"❌ [MSG91] Exception: {e}")
            return False

    def send_sms_sync(self, *args, **kwargs) -> bool:
        import asyncio
        try:
            return asyncio.run(self.send_sms(*args, **kwargs))
        except Exception:
            return False


# ============================================================
# 3️⃣ FAST2SMS
# ============================================================
class Fast2SMSProvider(BaseSMSProvider):
    name = "fast2sms"
    URL = "https://www.fast2sms.com/dev/bulkV2"

    def __init__(self):
        self.api_key = settings.FAST2SMS_API_KEY

    async def send_sms(
        self, to_mobile: str, message: str, template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if not self.api_key:
            logger.warning("❌ [Fast2SMS] API key not configured")
            return False

        mobile = str(to_mobile).strip().replace(" ", "")[-10:]
        headers = {
            "authorization": self.api_key,
            "Content-Type": "application/json",
        }

        if template_id and variables and "otp" in (variables or {}):
            payload = {
                "route": "otp",
                "variables_values": str(variables.get("otp")),
                "numbers": mobile,
            }
        else:
            payload = {
                "route": "q",
                "message": message,
                "language": "english",
                "flash": 0,
                "numbers": mobile,
            }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                r = await client.post(self.URL, json=payload, headers=headers)
                data = r.json()
                if r.status_code == 200 and data.get("return") is True:
                    logger.info(f"✅ [Fast2SMS] SMS sent to {mobile}")
                    return True
                logger.error(f"❌ [Fast2SMS] Failed: {r.status_code} {r.text[:300]}")
                return False
        except Exception as e:
            logger.error(f"❌ [Fast2SMS] Exception: {e}")
            return False

    def send_sms_sync(self, *args, **kwargs) -> bool:
        import asyncio
        try:
            return asyncio.run(self.send_sms(*args, **kwargs))
        except Exception:
            return False


# ============================================================
# 4️⃣ BREVO SMS
# ============================================================
class BrevoSMSProvider(BaseSMSProvider):
    name = "brevo"
    URL = "https://api.brevo.com/v3/transactionalSMS/sms"

    def __init__(self):
        self.api_key = settings.BREVO_SMS_API_KEY or settings.BREVO_API_KEY
        self.sender = settings.BREVO_SMS_SENDER

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("+"):
            return mobile
        if mobile.startswith("91"):
            return f"+{mobile}"
        return f"+91{mobile}"

    async def send_sms(
        self, to_mobile: str, message: str, template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if not self.api_key:
            logger.warning("❌ [Brevo SMS] API key not configured")
            return False

        mobile = self._format_mobile(to_mobile)
        headers = {
            "accept": "application/json",
            "api-key": self.api_key,
            "content-type": "application/json",
        }
        payload = {
            "sender": self.sender,
            "recipient": mobile,
            "content": message,
            "type": "transactional",
        }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                r = await client.post(self.URL, json=payload, headers=headers)
                if r.status_code in (200, 201, 202):
                    logger.info(f"✅ [Brevo SMS] Sent to {mobile}")
                    return True
                logger.error(f"❌ [Brevo SMS] Failed: {r.status_code} {r.text[:300]}")
                return False
        except Exception as e:
            logger.error(f"❌ [Brevo SMS] Exception: {e}")
            return False

    def send_sms_sync(self, *args, **kwargs) -> bool:
        import asyncio
        try:
            return asyncio.run(self.send_sms(*args, **kwargs))
        except Exception:
            return False


# ============================================================
# 🎯 UNIFIED SMS SERVICE
# ============================================================
class UnifiedSMSService:
    def __init__(self):
        self.provider_name = (settings.SMS_PROVIDER or "msg91").lower()
        self.provider = self._get_provider(self.provider_name)
        logger.info(f"📱 SMS service initialized: provider={self.provider_name}")

    def _get_provider(self, name: str) -> BaseSMSProvider:
        if name == "twilio":
            return TwilioSMSProvider()
        elif name == "fast2sms":
            return Fast2SMSProvider()
        elif name == "brevo":
            return BrevoSMSProvider()
        else:
            return MSG91SMSProvider()

    async def send(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if settings.DEV_MODE_LOG_ONLY:
            logger.info(f"🧪 [LOG-ONLY] SMS to {to_mobile}: {message[:60]}")
            return True

        if settings.MOBILE_OTP_BYPASS and variables and "otp" in variables:
            logger.info(f"🔧 [DEV BYPASS] SMS OTP to {to_mobile} = {variables['otp']}")
            return True

        return await self.provider.send_sms(
            to_mobile, message, template_id=template_id, variables=variables
        )

    def send_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if settings.DEV_MODE_LOG_ONLY:
            logger.info(f"🧪 [LOG-ONLY] SMS to {to_mobile}")
            return True

        if settings.MOBILE_OTP_BYPASS and variables and "otp" in variables:
            logger.info(f"🔧 [DEV BYPASS] SMS OTP to {to_mobile} = {variables['otp']}")
            return True

        return self.provider.send_sms_sync(
            to_mobile, message, template_id=template_id, variables=variables
        )


# ============================================================
# 🌍 GLOBAL INSTANCE + BACKWARD-COMPATIBLE FUNCTION
# ============================================================
_sms_service: Optional[UnifiedSMSService] = None


def get_sms_service() -> UnifiedSMSService:
    global _sms_service
    if _sms_service is None:
        _sms_service = UnifiedSMSService()
    return _sms_service


def send_mobile_otp(mobile: str, otp: str) -> bool:
    """
    Legacy helper: sends OTP SMS.
    Backward compatible with existing code.
    """
    service = get_sms_service()
    message = f"Your RojgarNext OTP is {otp}. Valid for 10 minutes. Do not share."

    # Provide template + variables so providers can use DLT-friendly OTP flow
    return service.send_sync(
        to_mobile=mobile,
        message=message,
        template_id=settings.MSG91_TEMPLATE_ID_OTP,
        variables={"otp": otp, "message": message},
    )


async def send_sms_async(
    to_mobile: str,
    message: str,
    template_id: Optional[str] = None,
    variables: Optional[dict] = None,
) -> bool:
    return await get_sms_service().send(
        to_mobile=to_mobile,
        message=message,
        template_id=template_id,
        variables=variables,
    )


print("✅ Unified SMS Service Loaded")
print(f"   Provider: {settings.SMS_PROVIDER}")