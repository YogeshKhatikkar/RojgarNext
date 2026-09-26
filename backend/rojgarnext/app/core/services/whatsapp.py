# app/core/services/whatsapp.py
# ============================================================
# 💬 UNIFIED WHATSAPP SERVICE
# Supports: MSG91 | Twilio | Meta (WhatsApp Business Cloud API)
# Switch via WHATSAPP_PROVIDER in .env — NO CODE CHANGES NEEDED
# ============================================================

import logging
import httpx
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
        import asyncio
        try:
            return asyncio.run(
                self.send_message(
                    to_mobile, message, template_id, variables, media_url
                )
            )
        except Exception:
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

    def _pick_template(self, template_id: Optional[str], variables: Optional[dict]) -> Optional[str]:
        if template_id:
            return template_id
        if variables and "otp" in variables:
            return self.template_otp
        if variables and "job_title" in variables:
            return self.template_job
        if variables and "status" in variables:
            return self.template_status
        return self.template_alert

    async def send_message(
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
        tpl = self._pick_template(template_id, variables)
        if not tpl:
            logger.warning("❌ [MSG91 WhatsApp] No template available")
            return False

        # MSG91 expects components array
        components = {}
        if variables:
            # Convert flat vars to MSG91 body params (positional)
            components = {
                "body_1": str(variables.get("name", variables.get("otp", ""))),
            }
            if "otp" in variables:
                components["body_1"] = str(variables["otp"])
            if "message" in variables:
                components["body_2"] = str(variables["message"])
            if "job_title" in variables:
                components["body_2"] = str(variables["job_title"])
            if "company" in variables:
                components["body_3"] = str(variables["company"])

        payload = {
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

        headers = {
            "authkey": self.api_key,
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.post(self.URL, json=payload, headers=headers)
                if r.status_code in (200, 201):
                    logger.info(f"✅ [MSG91 WhatsApp] Sent to {mobile}")
                    return True
                logger.error(
                    f"❌ [MSG91 WhatsApp] Failed: {r.status_code} {r.text[:300]}"
                )
                return False
        except Exception as e:
            logger.error(f"❌ [MSG91 WhatsApp] Exception: {e}")
            return False


# ============================================================
# 2️⃣ TWILIO WhatsApp
# ============================================================
class TwilioWhatsAppProvider(BaseWhatsAppProvider):
    name = "twilio"

    def __init__(self):
        self.sid = settings.TWILIO_ACCOUNT_SID
        self.token = settings.TWILIO_AUTH_TOKEN
        self.from_number = settings.TWILIO_WHATSAPP_NUMBER or "whatsapp:+14155238886"

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("whatsapp:"):
            return mobile
        if mobile.startswith("+"):
            return f"whatsapp:{mobile}"
        if mobile.startswith("91") and len(mobile) == 12:
            return f"whatsapp:+{mobile}"
        return f"whatsapp:+91{mobile}"

    async def send_message(
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
            client.messages.create(**kwargs)
            logger.info(f"✅ [Twilio WhatsApp] Sent to {to}")
            return True
        except Exception as e:
            logger.error(f"❌ [Twilio WhatsApp] Exception: {e}")
            return False


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

        # If we have a template + variables → send as template message
        tpl = template_id or (self.template_otp if variables and "otp" in variables else self.template_alert)

        if tpl and variables:
            # Build body parameters in order
            params = []
            for k in sorted(variables.keys()):
                params.append({"type": "text", "text": str(variables[k])})
            payload = {
                "messaging_product": "whatsapp",
                "to": to,
                "type": "template",
                "template": {
                    "name": tpl,
                    "language": {"code": "en"},
                    "components": [
                        {"type": "body", "parameters": params}
                    ],
                },
            }
        else:
            payload = {
                "messaging_product": "whatsapp",
                "to": to,
                "type": "text",
                "text": {"body": message},
            }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.post(url, json=payload, headers=headers)
                if r.status_code in (200, 201):
                    logger.info(f"✅ [Meta WhatsApp] Sent to {to}")
                    return True
                logger.error(
                    f"❌ [Meta WhatsApp] Failed: {r.status_code} {r.text[:300]}"
                )
                return False
        except Exception as e:
            logger.error(f"❌ [Meta WhatsApp] Exception: {e}")
            return False


# ============================================================
# 4️⃣ DISABLED / NO-OP
# ============================================================
class DisabledWhatsAppProvider(BaseWhatsAppProvider):
    name = "disabled"

    async def send_message(self, *args, **kwargs) -> bool:
        logger.info("ℹ️ WhatsApp provider is disabled")
        return False


# ============================================================
# 🎯 UNIFIED WHATSAPP SERVICE
# ============================================================
class UnifiedWhatsAppService:
    def __init__(self):
        self.provider_name = (settings.WHATSAPP_PROVIDER or "disabled").lower()
        self.provider = self._get_provider(self.provider_name)
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

    async def send(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
        media_url: Optional[str] = None,
    ) -> bool:
        if settings.DEV_MODE_LOG_ONLY:
            logger.info(f"🧪 [LOG-ONLY] WhatsApp to {to_mobile}: {message[:80]}")
            return True

        if self.provider_name == "disabled":
            return False

        ok = await self.provider.send_message(
            to_mobile, message, template_id=template_id, variables=variables,
            media_url=media_url,
        )

        # Optional fallback to SMS
        if not ok and settings.WHATSAPP_FALLBACK_TO_SMS:
            logger.warning("⚠️ WhatsApp failed, falling back to SMS")
            try:
                from app.core.services.sms import send_sms_async
                ok = await send_sms_async(
                    to_mobile=to_mobile,
                    message=message,
                    template_id=settings.MSG91_TEMPLATE_ID_OTP if variables and "otp" in variables else settings.MSG91_TEMPLATE_ID_ALERT,
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
        import asyncio
        if settings.DEV_MODE_LOG_ONLY:
            logger.info(f"🧪 [LOG-ONLY] WhatsApp to {to_mobile}")
            return True
        try:
            return asyncio.run(
                self.send(to_mobile, message, template_id, variables, media_url)
            )
        except Exception as e:
            logger.error(f"❌ [WhatsApp] sync failed: {e}")
            return False


# ============================================================
# 🌍 GLOBAL INSTANCE + HELPERS
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
) -> bool:
    return get_whatsapp_service().send_sync(
        to_mobile=to_mobile,
        message=message,
        template_id=template_id,
        variables=variables,
    )


print("✅ Unified WhatsApp Service Loaded")
print(f"   Provider: {settings.WHATSAPP_PROVIDER}")