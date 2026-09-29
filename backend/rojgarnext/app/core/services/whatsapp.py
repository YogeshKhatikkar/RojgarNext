# app/core/services/whatsapp.py
# ============================================================
# 💬 UNIFIED WHATSAPP SERVICE - COMPLETELY FIXED
# Supports: MSG91 | Twilio | Meta (WhatsApp Business Cloud API) | Disabled
# Switch via WHATSAPP_PROVIDER in .env — NO CODE CHANGES NEEDED
# ============================================================
# ✅ MOBILE_OTP_BYPASS=true  → DEV MODE  → Log only, no real WhatsApp
# ✅ MOBILE_OTP_BYPASS=false → PROD MODE → Real WhatsApp sent
# ============================================================
# 🔧 FIXES APPLIED:
#   1. Twilio trial account errors handled gracefully (no fallback loop)
#   2. ContentSid error (21654) detected and logged clearly
#   3. SMS fallback skipped if SMS_PROVIDER=twilio (same trial issue)
#   4. Proper TwilioRestException import and handling
#   5. Sync wrapper fixed (no nested event loop conflicts)
# ============================================================

import logging
import httpx
import asyncio
from typing import Optional

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


# ============================================================
# BASE PROVIDER
# ============================================================
class BaseWhatsAppProvider:
    name = "base"

    async def send_message(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        raise NotImplementedError

    def send_message_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        """
        ✅ FIXED: Safe sync wrapper that doesn't conflict with running event loops.
        """
        try:
            # Check if there's already a running loop
            try:
                asyncio.get_running_loop()
                # We're inside an async context — create a new loop in a thread
                import concurrent.futures
                with concurrent.futures.ThreadPoolExecutor() as pool:
                    future = pool.submit(
                        asyncio.run,
                        self.send_message(
                            to_mobile, message, template_id, variables, media_url
                        ),
                    )
                    return future.result(timeout=35)
            except RuntimeError:
                # No running loop — safe to create one
                return asyncio.run(
                    self.send_message(
                        to_mobile, message, template_id, variables, media_url
                    )
                )
        except Exception as e:
            logger.error(f"❌ [WhatsApp] Sync wrapper failed: {e}")
            return False


# ============================================================
# 1️⃣ MSG91 WhatsApp
# ============================================================
class MSG91WhatsAppProvider(BaseWhatsAppProvider):
    name = "msg91"
    URL = "https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/"

    def __init__(self):
        self.api_key = settings.MSG91_WHATSAPP_API_KEY or settings.MSG91_AUTH_KEY
        self.integrated_number = settings.MSG91_WHATSAPP_INTEGRATED_NUMBER
        self.template_otp = settings.MSG91_WHATSAPP_TEMPLATE_OTP
        self.template_alert = settings.MSG91_WHATSAPP_TEMPLATE_ALERT
        self.template_job = settings.MSG91_WHATSAPP_TEMPLATE_JOB
        self.template_status = settings.MSG91_WHATSAPP_TEMPLATE_STATUS

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("+"):
            mobile = mobile[1:]
        if not mobile.startswith("91"):
            mobile = f"91{mobile}"
        return mobile

    def _pick_template(self, template_id, variables):
        if template_id:
            return template_id
        if variables and "otp" in variables:
            return self.template_otp
        if variables and "job_title" in variables:
            return self.template_job
        if variables and "status" in variables:
            return self.template_status
        return self.template_alert

    def _build_payload(self, mobile, message, template_id, variables):
        tpl = self._pick_template(template_id, variables)
        if not tpl:
            return None
        components = {}
        if variables:
            components = {"body_1": str(variables.get("name", variables.get("otp", "")))}
            if "otp" in variables:
                components["body_1"] = str(variables["otp"])
            if "message" in variables:
                components["body_2"] = str(variables["message"])
            if "job_title" in variables:
                components["body_2"] = str(variables["job_title"])
            if "company" in variables:
                components["body_3"] = str(variables["company"])

        return {
            "integrated_number": self.integrated_number,
            "content_type": "template",
            "payload": {
                "messaging_product": "whatsapp",
                "type": "template",
                "template": {
                    "name": tpl,
                    "language": {"code": "en", "policy": "deterministic"},
                    "to_and_components": [
                        {
                            "to": [mobile],
                            "components": {
                                k: {"type": "text", "value": v}
                                for k, v in components.items()
                            },
                        }
                    ],
                },
            },
        }

    async def send_message(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        if not self.api_key or not self.integrated_number:
            logger.warning("❌ [MSG91 WhatsApp] Not configured (missing API key or integrated number)")
            return False

        mobile = self._format_mobile(to_mobile)
        payload = self._build_payload(mobile, message, template_id, variables)
        if not payload:
            logger.warning("❌ [MSG91 WhatsApp] No template available - check MSG91_WHATSAPP_TEMPLATE_* in .env")
            return False

        headers = {"authkey": self.api_key, "Content-Type": "application/json"}
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.post(self.URL, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [MSG91 WhatsApp] Sent to {mobile}")
                return True
            logger.error(f"❌ [MSG91 WhatsApp] Failed: {r.status_code} {r.text[:300]}")
            return False
        except Exception as e:
            logger.error(f"❌ [MSG91 WhatsApp] Exception: {e}")
            return False

    def send_message_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        if not self.api_key or not self.integrated_number:
            logger.warning("❌ [MSG91 WhatsApp] Not configured")
            return False

        mobile = self._format_mobile(to_mobile)
        payload = self._build_payload(mobile, message, template_id, variables)
        if not payload:
            logger.warning("❌ [MSG91 WhatsApp] No template available")
            return False

        headers = {"authkey": self.api_key, "Content-Type": "application/json"}
        try:
            with httpx.Client(timeout=30.0) as client:
                r = client.post(self.URL, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [MSG91 WhatsApp] Sent (sync) to {mobile}")
                return True
            logger.error(f"❌ [MSG91 WhatsApp] Failed: {r.status_code} {r.text[:300]}")
            return False
        except Exception as e:
            logger.error(f"❌ [MSG91 WhatsApp] Sync exception: {e}")
            return False


# ============================================================
# 2️⃣ TWILIO WhatsApp - COMPLETELY FIXED
# ============================================================
class TwilioWhatsAppProvider(BaseWhatsAppProvider):
    name = "twilio"

    def __init__(self):
        self.sid = settings.TWILIO_ACCOUNT_SID
        self.token = settings.TWILIO_AUTH_TOKEN
        self.from_number = settings.TWILIO_WHATSAPP_NUMBER or "whatsapp:+14155238886"
        self._trial_warning_logged = False  # Avoid log spam

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("whatsapp:"):
            return mobile
        if mobile.startswith("+"):
            return f"whatsapp:{mobile}"
        if mobile.startswith("91") and len(mobile) == 12:
            return f"whatsapp:+{mobile}"
        return f"whatsapp:+91{mobile}"

    def _handle_twilio_error(self, e, to: str) -> bool:
        """
        ✅ FIXED: Handle Twilio errors gracefully with clear messages.
        """
        try:
            from twilio.base.exceptions import TwilioRestException
            if isinstance(e, TwilioRestException):
                code = getattr(e, 'code', None)
                if code == 21654:
                    if not self._trial_warning_logged:
                        logger.error(
                            "=" * 70 + "\n"
                            "❌ [Twilio WhatsApp] ContentSid Required (Error 21654)\n"
                            "   Twilio WhatsApp requires a pre-approved template.\n"
                            "   \n"
                            "   🔧 SOLUTIONS:\n"
                            "   1. Switch provider: WHATSAPP_PROVIDER=msg91 in .env\n"
                            "   2. OR disable: WHATSAPP_PROVIDER=disabled in .env\n"
                            "   3. OR set MOBILE_OTP_BYPASS=true for development\n"
                            "=" * 70
                        )
                        self._trial_warning_logged = True
                    return False
                elif code == 63016:
                    logger.error(
                        f"❌ [Twilio WhatsApp] Sandbox expired/not joined (63016) - {to}\n"
                        f"   Join sandbox: https://www.twilio.com/console/sms/whatsapp/learn"
                    )
                    return False
                elif code == 21608:
                    logger.error(
                        f"❌ [Twilio WhatsApp] Number not verified (21608) - {to}\n"
                        f"   Verify: https://console.twilio.com/us1/develop/phone-numbers/manage/verified"
                    )
                    return False
                else:
                    logger.error(f"❌ [Twilio WhatsApp] API Error {code}: {str(e)[:200]}")
                    return False
        except ImportError:
            pass

        logger.error(f"❌ [Twilio WhatsApp] Exception: {type(e).__name__}: {str(e)[:200]}")
        return False

    async def send_message(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        if not self.sid or not self.token:
            logger.warning("❌ [Twilio WhatsApp] Not configured (SID/TOKEN missing)")
            return False

        try:
            from twilio.rest import Client
            client = Client(self.sid, self.token)
            to = self._format_mobile(to_mobile)

            def _send():
                kwargs = {
                    "body": message,
                    "from_": self.from_number,
                    "to": to,
                }
                if media_url:
                    kwargs["media_url"] = [media_url]
                return client.messages.create(**kwargs)

            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(None, _send)
            logger.info(f"✅ [Twilio WhatsApp] Sent to {to} | SID: {result.sid}")
            return True
        except Exception as e:
            return self._handle_twilio_error(e, to_mobile)

    def send_message_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        if not self.sid or not self.token:
            logger.warning("❌ [Twilio WhatsApp] Not configured")
            return False

        try:
            from twilio.rest import Client
            client = Client(self.sid, self.token)
            to = self._format_mobile(to_mobile)
            kwargs = {
                "body": message,
                "from_": self.from_number,
                "to": to,
            }
            if media_url:
                kwargs["media_url"] = [media_url]
            result = client.messages.create(**kwargs)
            logger.info(f"✅ [Twilio WhatsApp] Sent (sync) to {to} | SID: {result.sid}")
            return True
        except Exception as e:
            return self._handle_twilio_error(e, to_mobile)


# ============================================================
# 3️⃣ META WhatsApp Business Cloud API
# ============================================================
class MetaWhatsAppProvider(BaseWhatsAppProvider):
    name = "meta"

    def __init__(self):
        self.phone_number_id = settings.META_WA_PHONE_NUMBER_ID
        self.access_token = settings.META_WA_ACCESS_TOKEN
        self.template_otp = settings.META_WA_TEMPLATE_OTP
        self.template_alert = settings.META_WA_TEMPLATE_ALERT

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("+"):
            mobile = mobile[1:]
        if not mobile.startswith("91"):
            mobile = f"91{mobile}"
        return mobile

    def _build_payload(self, to, message, template_id, variables):
        tpl = template_id or (
            self.template_otp if variables and "otp" in variables else self.template_alert
        )
        if tpl and variables:
            params = [
                {"type": "text", "text": str(variables[k])}
                for k in sorted(variables.keys())
            ]
            return {
                "messaging_product": "whatsapp",
                "to": to,
                "type": "template",
                "template": {
                    "name": tpl,
                    "language": {"code": "en"},
                    "components": [{"type": "body", "parameters": params}],
                },
            }
        return {
            "messaging_product": "whatsapp",
            "to": to,
            "type": "text",
            "text": {"body": message},
        }

    async def send_message(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        if not self.phone_number_id or not self.access_token:
            logger.warning("❌ [Meta WhatsApp] Not configured")
            return False

        to = self._format_mobile(to_mobile)
        url = f"https://graph.facebook.com/v20.0/{self.phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        payload = self._build_payload(to, message, template_id, variables)

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.post(url, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [Meta WhatsApp] Sent to {to}")
                return True
            logger.error(f"❌ [Meta WhatsApp] Failed: {r.status_code} {r.text[:300]}")
            return False
        except Exception as e:
            logger.error(f"❌ [Meta WhatsApp] Exception: {e}")
            return False

    def send_message_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        if not self.phone_number_id or not self.access_token:
            logger.warning("❌ [Meta WhatsApp] Not configured")
            return False

        to = self._format_mobile(to_mobile)
        url = f"https://graph.facebook.com/v20.0/{self.phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        payload = self._build_payload(to, message, template_id, variables)

        try:
            with httpx.Client(timeout=30.0) as client:
                r = client.post(url, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [Meta WhatsApp] Sent (sync) to {to}")
                return True
            logger.error(f"❌ [Meta WhatsApp] Failed: {r.status_code} {r.text[:300]}")
            return False
        except Exception as e:
            logger.error(f"❌ [Meta WhatsApp] Sync exception: {e}")
            return False


# ============================================================
# 4️⃣ DISABLED / NO-OP
# ============================================================
class DisabledWhatsAppProvider(BaseWhatsAppProvider):
    name = "disabled"

    async def send_message(self, *args, **kwargs) -> bool:
        logger.debug("ℹ️ WhatsApp provider is disabled")
        return False

    def send_message_sync(self, *args, **kwargs) -> bool:
        logger.debug("ℹ️ WhatsApp provider is disabled")
        return False


# ============================================================
# 🎯 UNIFIED WHATSAPP SERVICE (COMPLETELY FIXED)
# ============================================================
class UnifiedWhatsAppService:
    """
    ✅ CRITICAL: In DEV MODE (MOBILE_OTP_BYPASS=true), NO real WhatsApp is sent.
    ✅ In PROD MODE (MOBILE_OTP_BYPASS=false), real WhatsApp IS sent.
    🔧 FIXED: SMS fallback now skips if SMS_PROVIDER is also Twilio (trial issue).
    """

    def __init__(self):
        self.provider_name = (settings.WHATSAPP_PROVIDER or "disabled").lower()
        self.provider = self._get_provider(self.provider_name)
        # ✅ Track if we've already warned about trial issues (avoid log spam)
        self._fallback_warning_logged = False
        logger.info(f"💬 WhatsApp service initialized: provider={self.provider_name}")

    def _get_provider(self, name: str) -> BaseWhatsAppProvider:
        if name == "msg91":
            return MSG91WhatsAppProvider()
        elif name == "twilio":
            return TwilioWhatsAppProvider()
        elif name == "meta":
            return MetaWhatsAppProvider()
        else:
            return DisabledWhatsAppProvider()

    def _should_skip_sms_fallback(self) -> bool:
        """
        ✅ FIXED: Skip SMS fallback if SMS provider is also Twilio (trial account).
        This prevents the endless error loop in logs.
        """
        sms_provider = (settings.SMS_PROVIDER or "").lower()
        if sms_provider == "twilio":
            if not self._fallback_warning_logged:
                logger.warning(
                    "⚠️ WhatsApp → SMS fallback SKIPPED "
                    "(SMS_PROVIDER=twilio also has trial limitations). "
                    "Switch to MSG91 or set MOBILE_OTP_BYPASS=true."
                )
                self._fallback_warning_logged = True
            return True
        return False

    async def send(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        # ✅ DEV MODE: MOBILE_OTP_BYPASS=true → Log only, no real WhatsApp
        if settings.MOBILE_OTP_BYPASS:
            logger.info(
                f"🔧 [DEV MODE] WhatsApp NOT sent (MOBILE_OTP_BYPASS=true)"
            )
            logger.info(f"   To: {to_mobile}")
            if variables and "otp" in variables:
                logger.info(f"   OTP: {variables['otp']}")
            return True

        # ✅ PROD MODE: MOBILE_OTP_BYPASS=false → Real WhatsApp
        if self.provider_name == "disabled":
            logger.info("ℹ️ WhatsApp provider is disabled - skipping")
            return False

        ok = await self.provider.send_message(
            to_mobile, message, template_id=template_id, variables=variables,
            media_url=media_url,
        )

        # ✅ FIXED: Only attempt SMS fallback if it makes sense
        if not ok and settings.WHATSAPP_FALLBACK_TO_SMS:
            if self._should_skip_sms_fallback():
                return False

            logger.warning("⚠️ WhatsApp failed, falling back to SMS")
            try:
                from app.core.services.sms import send_sms_async
                ok = await send_sms_async(
                    to_mobile=to_mobile,
                    message=message,
                    template_id=(
                        settings.MSG91_TEMPLATE_ID_OTP
                        if variables and "otp" in variables
                        else settings.MSG91_TEMPLATE_ID_ALERT
                    ),
                    variables=variables,
                )
            except Exception as e:
                logger.error(f"❌ SMS fallback failed: {e}")

        return ok

    def send_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        # ✅ DEV MODE: MOBILE_OTP_BYPASS=true → Log only, no real WhatsApp
        if settings.MOBILE_OTP_BYPASS:
            logger.info(
                f"🔧 [DEV MODE] WhatsApp NOT sent (MOBILE_OTP_BYPASS=true)"
            )
            logger.info(f"   To: {to_mobile}")
            if variables and "otp" in variables:
                logger.info(f"   OTP: {variables['otp']}")
            return True

        # ✅ PROD MODE: MOBILE_OTP_BYPASS=false → Real WhatsApp
        if self.provider_name == "disabled":
            logger.info("ℹ️ WhatsApp provider is disabled - skipping")
            return False

        ok = self.provider.send_message_sync(
            to_mobile, message, template_id=template_id, variables=variables,
            media_url=media_url,
        )

        # ✅ FIXED: Only attempt SMS fallback if it makes sense
        if not ok and settings.WHATSAPP_FALLBACK_TO_SMS:
            if self._should_skip_sms_fallback():
                return False

            logger.warning("⚠️ WhatsApp failed, falling back to SMS (sync)")
            try:
                from app.core.services.sms import send_mobile_otp, get_sms_service
                if variables and "otp" in variables:
                    ok = send_mobile_otp(to_mobile, variables["otp"])
                else:
                    svc = get_sms_service()
                    ok = svc.send_sync(
                        to_mobile=to_mobile,
                        message=message,
                        template_id=settings.MSG91_TEMPLATE_ID_ALERT,
                        variables=variables,
                    )
            except Exception as e:
                logger.error(f"❌ SMS fallback (sync) failed: {e}")

        return ok


# ============================================================
# 🌍 GLOBAL INSTANCE + PUBLIC HELPERS
# ============================================================
_whatsapp_service: Optional[UnifiedWhatsAppService] = None


def get_whatsapp_service() -> UnifiedWhatsAppService:
    global _whatsapp_service
    if _whatsapp_service is None:
        _whatsapp_service = UnifiedWhatsAppService()
    return _whatsapp_service


async def send_whatsapp(
    to_mobile: str,
    message: str,
    template_id: Optional[str] = None,
    variables: Optional[dict] = None,
    media_url: Optional[str] = None,
) -> bool:
    return await get_whatsapp_service().send(
        to_mobile=to_mobile,
        message=message,
        template_id=template_id,
        variables=variables,
        media_url=media_url,
    )


def send_whatsapp_sync(
    to_mobile: str,
    message: str,
    template_id: Optional[str] = None,
    variables: Optional[dict] = None,
    media_url: Optional[str] = None,
) -> bool:
    return get_whatsapp_service().send_sync(
        to_mobile=to_mobile,
        message=message,
        template_id=template_id,
        variables=variables,
        media_url=media_url,
    )


print("✅ Unified WhatsApp Service Loaded (FIXED)")
print(f"   Provider: {settings.WHATSAPP_PROVIDER}")
print(f"   OTP Mode: {'DEVELOPMENT (log only)' if settings.MOBILE_OTP_BYPASS else 'PRODUCTION (real send)'}")