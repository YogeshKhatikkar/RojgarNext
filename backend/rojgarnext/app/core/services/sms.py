# app/core/services/sms.py
# ============================================================
# 📱 UNIFIED SMS SERVICE
# Supports: Twilio | MSG91 | Fast2SMS | Brevo
# Switch via SMS_PROVIDER in .env — NO CODE CHANGES NEEDED
# ============================================================
# ✅ MOBILE_OTP_BYPASS=true  → DEV MODE  → Log only, no real SMS
# ✅ MOBILE_OTP_BYPASS=false → PROD MODE → Real SMS sent
# ============================================================
# ✅ FIXED: All sync methods use sync HTTP clients (no asyncio.run)
# ✅ Works from BackgroundTasks / threads without crashing
# ✅ No syntax errors, no undefined variables
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
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        raise NotImplementedError

    def send_sms_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
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
        if len(mobile) == 10:
            return f"+91{mobile}"
        return f"+{mobile}"

    async def send_sms(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if not self.sid or not self.token:
            logger.warning("❌ [Twilio] Not configured (SID/TOKEN missing)")
            return False

        try:
            import asyncio
            from twilio.rest import Client
            client = Client(self.sid, self.token)
            to = self._format_mobile(to_mobile)

            def _send():
                return client.messages.create(
                    body=message,
                    from_=self.from_number,
                    to=to,
                )

            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(None, _send)
            logger.info(f"✅ [Twilio] SMS sent to {to} | SID: {result.sid}")
            return True
        except Exception as e:
            logger.error(f"❌ [Twilio] Exception: {type(e).__name__}: {e}")
            return False

    def send_sms_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        """
        Sync version — calls Twilio SDK directly. No asyncio.run.
        ✅ FIXED: Proper newline after `return False`
        """
        if not self.sid or not self.token:
            logger.warning("❌ [Twilio] Not configured (SID/TOKEN missing)")
            return False

        try:
            from twilio.rest import Client
            client = Client(self.sid, self.token)
            to = self._format_mobile(to_mobile)
            result = client.messages.create(
                body=message,
                from_=self.from_number,
                to=to,
            )
            logger.info(f"✅ [Twilio] SMS sent (sync) to {to} | SID: {result.sid}")
            return True
        except Exception as e:
            logger.error(f"❌ [Twilio] Sync exception: {type(e).__name__}: {e}")
            return False


# ============================================================
# 2️⃣ MSG91
# ============================================================
class MSG91SMSProvider(BaseSMSProvider):
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

    def _build_payload(
        self,
        mobile: str,
        message: str,
        template_id: Optional[str],
        variables: Optional[dict],
    ):
        """Shared payload builder for async + sync."""
        if template_id and variables and "otp" in (variables or {}):
            return (
                self.SEND_OTP_URL,
                {
                    "template_id": template_id,
                    "mobile": mobile,
                    "otp": str(variables.get("otp")),
                    "otp_expiry": 10,
                },
            )
        tpl = template_id or self.template_alert
        if not tpl:
            return None, None
        payload = {
            "template_id": tpl,
            "sender": self.sender_id,
            "short_url": "0",
            "recipients": [{"mobiles": mobile, **(variables or {})}],
        }
        if self.dlt_te_id:
            payload["DLT_TE_ID"] = self.dlt_te_id
        return self.SEND_FLOW_URL, payload

    async def send_sms(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if not self.auth_key:
            logger.warning("❌ [MSG91] AUTH_KEY not configured")
            return False

        mobile = self._format_mobile(to_mobile)
        headers = {"authkey": self.auth_key, "Content-Type": "application/json"}
        url, payload = self._build_payload(mobile, message, template_id, variables)
        if not url:
            logger.warning("❌ [MSG91] No template ID for flow API")
            return False

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                r = await client.post(url, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [MSG91] SMS sent to {mobile}")
                return True
            logger.error(f"❌ [MSG91] Failed: {r.status_code} {r.text[:300]}")
            return False
        except Exception as e:
            logger.error(f"❌ [MSG91] Exception: {e}")
            return False

    def send_sms_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        """Sync version — uses httpx.Client. No asyncio.run."""
        if not self.auth_key:
            logger.warning("❌ [MSG91] AUTH_KEY not configured")
            return False

        mobile = self._format_mobile(to_mobile)
        headers = {"authkey": self.auth_key, "Content-Type": "application/json"}
        url, payload = self._build_payload(mobile, message, template_id, variables)
        if not url:
            logger.warning("❌ [MSG91] No template ID for flow API")
            return False

        try:
            with httpx.Client(timeout=20.0) as client:
                r = client.post(url, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [MSG91] SMS sent (sync) to {mobile}")
                return True
            logger.error(f"❌ [MSG91] Failed: {r.status_code} {r.text[:300]}")
            return False
        except Exception as e:
            logger.error(f"❌ [MSG91] Sync exception: {e}")
            return False


# ============================================================
# 3️⃣ FAST2SMS
# ============================================================
class Fast2SMSProvider(BaseSMSProvider):
    name = "fast2sms"
    URL = "https://www.fast2sms.com/dev/bulkV2"

    def __init__(self):
        self.api_key = settings.FAST2SMS_API_KEY

    def _build_payload(
        self,
        mobile: str,
        message: str,
        template_id: Optional[str],
        variables: Optional[dict],
    ):
        if template_id and variables and "otp" in (variables or {}):
            return {
                "route": "otp",
                "variables_values": str(variables.get("otp")),
                "numbers": mobile,
            }
        return {
            "route": "q",
            "message": message,
            "language": "english",
            "flash": 0,
            "numbers": mobile,
        }

    async def send_sms(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if not self.api_key:
            logger.warning("❌ [Fast2SMS] API key not configured")
            return False

        mobile = str(to_mobile).strip().replace(" ", "")[-10:]
        headers = {"authorization": self.api_key, "Content-Type": "application/json"}
        payload = self._build_payload(mobile, message, template_id, variables)

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

    def send_sms_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        if not self.api_key:
            logger.warning("❌ [Fast2SMS] API key not configured")
            return False

        mobile = str(to_mobile).strip().replace(" ", "")[-10:]
        headers = {"authorization": self.api_key, "Content-Type": "application/json"}
        payload = self._build_payload(mobile, message, template_id, variables)

        try:
            with httpx.Client(timeout=20.0) as client:
                r = client.post(self.URL, json=payload, headers=headers)
            data = r.json()
            if r.status_code == 200 and data.get("return") is True:
                logger.info(f"✅ [Fast2SMS] SMS sent (sync) to {mobile}")
                return True
            logger.error(f"❌ [Fast2SMS] Failed: {r.status_code} {r.text[:300]}")
            return False
        except Exception as e:
            logger.error(f"❌ [Fast2SMS] Sync exception: {e}")
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

    def _build_payload(self, mobile: str, message: str):
        return {
            "sender": self.sender,
            "recipient": mobile,
            "content": message,
            "type": "transactional",
        }

    async def send_sms(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
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
        payload = self._build_payload(mobile, message)

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

    def send_sms_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
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
        payload = self._build_payload(mobile, message)

        try:
            with httpx.Client(timeout=20.0) as client:
                r = client.post(self.URL, json=payload, headers=headers)
            if r.status_code in (200, 201, 202):
                logger.info(f"✅ [Brevo SMS] Sent (sync) to {mobile}")
                return True
            logger.error(f"❌ [Brevo SMS] Failed: {r.status_code} {r.text[:300]}")
            return False
        except Exception as e:
            logger.error(f"❌ [Brevo SMS] Sync exception: {e}")
            return False


# ============================================================
# 🎯 UNIFIED SMS SERVICE (provider auto-selected from .env)
# ============================================================
class UnifiedSMSService:
    """
    ✅ CRITICAL: In DEV MODE (MOBILE_OTP_BYPASS=true), NO real SMS is sent.
    ✅ In PROD MODE (MOBILE_OTP_BYPASS=false), real SMS IS sent.

    Provider is auto-selected from `SMS_PROVIDER` in `.env`.
    """

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
        # ✅ DEV MODE: MOBILE_OTP_BYPASS=true → Log only, no real SMS
        if settings.MOBILE_OTP_BYPASS:
            logger.info("🔧 [DEV MODE] SMS NOT sent (MOBILE_OTP_BYPASS=true)")
            logger.info(f"   To: {to_mobile}")
            if variables and "otp" in variables:
                logger.info(f"   OTP: {variables['otp']}")
            return True

        # ✅ PROD MODE: MOBILE_OTP_BYPASS=false → Real SMS
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
        # ✅ DEV MODE: MOBILE_OTP_BYPASS=true → Log only, no real SMS
        if settings.MOBILE_OTP_BYPASS:
            logger.info("🔧 [DEV MODE] SMS NOT sent (MOBILE_OTP_BYPASS=true)")
            logger.info(f"   To: {to_mobile}")
            if variables and "otp" in variables:
                logger.info(f"   OTP: {variables['otp']}")
            return True

        # ✅ PROD MODE: MOBILE_OTP_BYPASS=false → Real SMS
        return self.provider.send_sms_sync(
            to_mobile, message, template_id=template_id, variables=variables
        )


# ============================================================
# 🌍 GLOBAL INSTANCE + PUBLIC HELPERS
# ============================================================
_sms_service: Optional[UnifiedSMSService] = None


def get_sms_service() -> UnifiedSMSService:
    global _sms_service
    if _sms_service is None:
        _sms_service = UnifiedSMSService()
    return _sms_service


def send_mobile_otp(mobile: str, otp: str) -> bool:
    """Legacy helper: sends OTP SMS (used by auth flow)."""
    service = get_sms_service()
    message = f"Your RojgarNext OTP is {otp}. Valid for 10 minutes. Do not share."
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


# ============================================================
# 🎯 STARTUP DIAGNOSTIC
# ============================================================
print("✅ Unified SMS Service Loaded")
print(f"   Provider: {settings.SMS_PROVIDER}")
print(f"   OTP Mode: {'DEVELOPMENT (log only)' if settings.MOBILE_OTP_BYPASS else 'PRODUCTION (real send)'}")