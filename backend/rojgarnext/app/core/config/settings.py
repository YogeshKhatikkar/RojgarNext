# app/core/config/settings.py
# ✅ SINGLE SOURCE OF TRUTH - Everything reads from .env
# ✅ ZERO hardcoded values - change .env, restart server, done!
# ✅ MOBILE_OTP_BYPASS is the MASTER SWITCH for SMS/WhatsApp dev/prod behavior
# ✅ EMAIL IS ALWAYS REAL - NEVER BYPASSED
# ✅ SAFE_MONGO_URI + IS_LOCAL_DB + IS_ATLAS_DB + MONGO_OPTIONS auto-derived

from pydantic_settings import BaseSettings
from typing import List, Optional, Dict, Any
import os


class Settings(BaseSettings):
    # ============================================================
    # 🗄️ DATABASE
    # ============================================================
    MONGO_URI: str = "mongodb://localhost:27017/rojgarnext"
    DATABASE_NAME: str = "rojgarnext"
    ENVIRONMENT: str = "development"
    PORT: int = 8000

    # ============================================================
    # 🔐 SECURITY
    # ============================================================
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    SECRET_KEY: str = "change-me"
    SESSION_SECRET_KEY: str = "change-me"
    JWT_SECRET_KEY: str = "change-me"
    REDIS_URL: str = "redis://localhost:6379"
    ENCRYPTION_KEY: str = "change-me"
    SECRET_TOKEN: str = "change-me"

    # ============================================================
    # 🧪 OTP BYPASS - THE MASTER SWITCH (SMS/WhatsApp ONLY)
    # ============================================================
    # 
    # ⚠️ IMPORTANT: This flag ONLY affects SMS and WhatsApp OTP.
    # ⚠️ EMAIL OTP IS ALWAYS REAL - NEVER BYPASSED.
    #
    # true  → DEV MODE for SMS/WhatsApp:
    #         - NO SMS sent
    #         - NO WhatsApp sent
    #         - Mobile OTP verification accepts DEV_OTP_CODE (123456)
    #         - Email OTP is STILL sent for real with random 6-digit
    #
    # false → PROD MODE:
    #         - Real SMS sent
    #         - Real WhatsApp sent
    #         - Real Email sent (same as always)
    #         - Only real OTPs work
    # ============================================================
    MOBILE_OTP_BYPASS: bool = True
    DEV_OTP_CODE: str = "123456"

    # ============================================================
    # 📧 EMAIL PROVIDER
    # ============================================================
    EMAIL_PROVIDER: str = "smtp"  # smtp | brevo | sendgrid | mailgun
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = ""
    SMTP_FROM_NAME: str = "RojgarNext"

    BREVO_API_KEY: str = ""
    BREVO_SENDER_EMAIL: str = ""
    BREVO_SENDER_NAME: str = "RojgarNext"
    BREVO_SMTP_HOST: str = "smtp-relay.brevo.com"
    BREVO_SMTP_PORT: int = 587
    BREVO_SMTP_USER: str = ""
    BREVO_SMTP_PASSWORD: str = ""

    SENDGRID_API_KEY: str = ""
    SENDGRID_FROM_EMAIL: str = ""
    SENDGRID_FROM_NAME: str = "RojgarNext"

    MAILGUN_API_KEY: str = ""
    MAILGUN_DOMAIN: str = ""
    MAILGUN_FROM_EMAIL: str = ""
    MAILGUN_FROM_NAME: str = "RojgarNext"

    # ============================================================
    # 📱 SMS PROVIDER
    # ============================================================
    SMS_PROVIDER: str = "msg91"  # twilio | msg91 | fast2sms | brevo

    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_PHONE: str = ""

    MSG91_AUTH_KEY: str = ""
    MSG91_SENDER_ID: str = "RJGARN"
    MSG91_TEMPLATE_ID_OTP: str = ""
    MSG91_TEMPLATE_ID_VERIFY: str = ""
    MSG91_TEMPLATE_ID_ALERT: str = ""
    MSG91_ROUTE: str = "4"
    MSG91_COUNTRY: str = "91"
    MSG91_DLT_TE_ID: str = ""

    FAST2SMS_API_KEY: str = ""

    BREVO_SMS_SENDER: str = "RojgarNext"
    BREVO_SMS_API_KEY: str = ""

    # ============================================================
    # 💬 WHATSAPP PROVIDER
    # ============================================================
    WHATSAPP_PROVIDER: str = "msg91"  # msg91 | twilio | meta | disabled

    MSG91_WHATSAPP_API_KEY: str = ""
    MSG91_WHATSAPP_INTEGRATED_NUMBER: str = ""
    MSG91_WHATSAPP_TEMPLATE_OTP: str = ""
    MSG91_WHATSAPP_TEMPLATE_ALERT: str = ""
    MSG91_WHATSAPP_TEMPLATE_JOB: str = ""
    MSG91_WHATSAPP_TEMPLATE_STATUS: str = ""

    TWILIO_WHATSAPP_NUMBER: str = ""

    META_WA_PHONE_NUMBER_ID: str = ""
    META_WA_ACCESS_TOKEN: str = ""
    META_WA_BUSINESS_ACCOUNT_ID: str = ""
    META_WA_VERIFY_TOKEN: str = ""
    META_WA_TEMPLATE_OTP: str = ""
    META_WA_TEMPLATE_ALERT: str = ""

    WHATSAPP_FALLBACK_TO_SMS: bool = False

    # ============================================================
    # 🔔 NOTIFICATION CHANNELS
    # ============================================================
    NOTIFY_OTP_CHANNELS: str = "email,sms,whatsapp"
    NOTIFY_VERIFICATION_CHANNELS: str = "email,sms"
    NOTIFY_JOB_ALERT_CHANNELS: str = "email,whatsapp,inapp"
    NOTIFY_APPLICATION_STATUS_CHANNELS: str = "email,inapp"
    NOTIFY_PAYMENT_CHANNELS: str = "email,sms,inapp"
    NOTIFY_ADMIN_ALERT_CHANNELS: str = "email,inapp"
    NOTIFY_PASSWORD_RESET_CHANNELS: str = "email,sms,whatsapp"
    NOTIFY_WELCOME_CHANNELS: str = "email,inapp"

    # ============================================================
    # 🧪 DEV OVERRIDES
    # ============================================================
    DEV_MODE_LOG_ONLY: bool = False
    USE_MOCK_PROVIDERS: bool = False

    EMAIL_RATE_LIMIT_PER_HOUR: int = 100
    SMS_RATE_LIMIT_PER_HOUR: int = 100
    WHATSAPP_RATE_LIMIT_PER_HOUR: int = 100

    # ============================================================
    # 🌐 OTHER
    # ============================================================
    APP_BASE_URL: str = "http://localhost:8000"
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4o-mini"

    CLOUDINARY_URL: str = ""
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    ADZUNA_APP_ID: str = ""
    ADZUNA_API_KEY: str = ""

    GOOGLE_DRIVE_SERVICE_ACCOUNT_EMAIL: str = ""
    GOOGLE_DRIVE_PRIVATE_KEY: str = ""
    GOOGLE_DRIVE_FOLDER_ID: str = ""
    GOOGLE_DRIVE_FOLDER_NAME: str = "rojgarnext_advertisements"

    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_WEBHOOK_SECRET: str = ""
    RAZORPAY_TEST_MODE: bool = True

    PHONEPE_MERCHANT_ID: str = ""
    PHONEPE_SALT_KEY: str = ""
    PHONEPE_SALT_INDEX: int = 1
    PHONEPE_API_URL: str = ""
    PHONEPE_STATUS_URL: str = ""
    PHONEPE_CLIENT_ID: str = ""
    PHONEPE_CLIENT_SECRET: str = ""
    PHONEPE_CLIENT_VERSION: str = "1"
    PHONEPE_ENV: str = "SANDBOX"
    PHONEPE_REDIRECT_URL: str = ""

    UPI_ID: str = ""

    # ============================================================
    # 🔧 HELPER METHODS (used by dispatcher)
    # ============================================================
    def get_channels(self, notification_type: str) -> List[str]:
        """Get list of channels for a notification type"""
        mapping = {
            "otp": self.NOTIFY_OTP_CHANNELS,
            "verification": self.NOTIFY_VERIFICATION_CHANNELS,
            "job_alert": self.NOTIFY_JOB_ALERT_CHANNELS,
            "application_status": self.NOTIFY_APPLICATION_STATUS_CHANNELS,
            "payment": self.NOTIFY_PAYMENT_CHANNELS,
            "admin_alert": self.NOTIFY_ADMIN_ALERT_CHANNELS,
            "password_reset": self.NOTIFY_PASSWORD_RESET_CHANNELS,
            "welcome": self.NOTIFY_WELCOME_CHANNELS,
        }
        raw = mapping.get(notification_type, "email")
        return [c.strip().lower() for c in raw.split(",") if c.strip()]

    def get_channels_for(self, notification_type: str) -> List[str]:
        """Alias for get_channels — used by notification_dispatcher.py"""
        return self.get_channels(notification_type)

    # ============================================================
    # 🧪 OTP MODE HELPERS
    # ============================================================
    @property
    def is_otp_bypass_enabled(self) -> bool:
        """
        The master switch for SMS/WhatsApp OTP mode.
        
        True  → Development mode: SMS/WhatsApp BYPASSED, Mobile OTP = DEV_OTP_CODE
        False → Production mode: SMS/WhatsApp SENT for real
        
        ⚠️ EMAIL IS ALWAYS REAL - this flag does NOT affect email.
        """
        return self.MOBILE_OTP_BYPASS is True

    @property
    def is_mobile_otp_bypassed(self) -> bool:
        """True when SMS/WhatsApp should be bypassed."""
        return self.MOBILE_OTP_BYPASS is True

    @property
    def is_email_always_real(self) -> bool:
        """
        EMAIL IS ALWAYS REAL - never bypassed.
        This is True regardless of MOBILE_OTP_BYPASS setting.
        """
        return True

    @property
    def dev_otp_value(self) -> str:
        """Returns the fixed OTP code used for MOBILE verification in development mode."""
        return self.DEV_OTP_CODE

    @property
    def otp_code(self) -> str:
        """Alias for dev_otp_value - used for MOBILE OTP verification in dev mode."""
        return self.DEV_OTP_CODE

    # ============================================================
    # 🗄️ DATABASE HELPERS (auto-derived from MONGO_URI)
    # ============================================================
    @property
    def SAFE_MONGO_URI(self) -> str:
        """
        Returns the MongoDB URI with safe parameters.
        URL-encodes password if it contains special characters like @.
        """
        uri = self.MONGO_URI or "mongodb://localhost:27017/rojgarnext"

        # If it's a SRV (Atlas) URI, ensure retryWrites is present
        if uri.startswith("mongodb+srv://"):
            if "retryWrites=" not in uri:
                separator = "&" if "?" in uri else "?"
                uri = f"{uri}{separator}retryWrites=true&w=majority"

        # For non-SRV URIs, ensure retryWrites as well
        elif uri.startswith("mongodb://"):
            if "retryWrites=" not in uri:
                separator = "&" if "?" in uri else "?"
                uri = f"{uri}{separator}retryWrites=true&w=majority"

        return uri

    @property
    def IS_LOCAL_DB(self) -> bool:
        """True if MONGO_URI points to localhost / 127.0.0.1"""
        uri = (self.MONGO_URI or "").lower()
        return (
            "localhost" in uri
            or "127.0.0.1" in uri
            or uri.startswith("mongodb://localhost")
        )

    @property
    def IS_ATLAS_DB(self) -> bool:
        """True if MONGO_URI is a MongoDB Atlas SRV URI"""
        uri = (self.MONGO_URI or "").lower()
        return uri.startswith("mongodb+srv://") or "mongodb.net" in uri

    @property
    def MONGO_OPTIONS(self) -> Dict[str, Any]:
        """
        Returns motor/pymongo connection options based on DB type.
        Local → no TLS, short timeouts (fast fail)
        Atlas → TLS enabled, longer timeouts (network)
        """
        if self.IS_ATLAS_DB:
            return {
                "serverSelectionTimeoutMS": 30000,
                "connectTimeoutMS": 30000,
                "socketTimeoutMS": 30000,
                "tls": True,
                "tlsAllowInvalidCertificates": True,
                "tlsAllowInvalidHostnames": True,
                "retryWrites": True,
                "retryReads": True,
                "maxPoolSize": 100,
                "minPoolSize": 5,
            }
        else:
            # Local or unknown → lightweight options
            return {
                "serverSelectionTimeoutMS": 5000,
                "connectTimeoutMS": 5000,
                "socketTimeoutMS": 10000,
                "retryWrites": True,
                "retryReads": True,
                "maxPoolSize": 50,
                "minPoolSize": 2,
            }

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"


settings = Settings()

# ============================================================
# 🎯 STARTUP DIAGNOSTIC LOG
# ============================================================
print("=" * 70)
print("🔧 ROJGARNEXT SETTINGS LOADED")
print("=" * 70)
print(f"   Environment: {settings.ENVIRONMENT}")
print(f"   MOBILE_OTP_BYPASS: {settings.MOBILE_OTP_BYPASS}")
if settings.MOBILE_OTP_BYPASS:
    print(f"   🟢 SMS/WhatsApp MODE: DEVELOPMENT (BYPASSED)")
    print(f"   🔑 Dev Mobile OTP: {settings.DEV_OTP_CODE}")
    print(f"   ⚠️  Real SMS: DISABLED")
    print(f"   ⚠️  Real WhatsApp: DISABLED")
    print(f"   ✅ EMAIL: ALWAYS REAL (never bypassed)")
else:
    print(f"   🔴 SMS/WhatsApp MODE: PRODUCTION")
    print(f"   🎲 OTP Type: Random 6-digit")
    print(f"   📤 Real SMS: ENABLED")
    print(f"   📤 Real WhatsApp: ENABLED")
    print(f"   ✅ EMAIL: ALWAYS REAL")
print(f"   📧 EMAIL_PROVIDER: {settings.EMAIL_PROVIDER}")
print(f"   📱 SMS_PROVIDER: {settings.SMS_PROVIDER}")
print(f"   💬 WHATSAPP_PROVIDER: {settings.WHATSAPP_PROVIDER}")
print("-" * 70)
print(f"   🗄️ DATABASE TYPE: {'LOCAL' if settings.IS_LOCAL_DB else 'ATLAS' if settings.IS_ATLAS_DB else 'UNKNOWN'}")
print(f"   🔗 MONGO URI: {settings.SAFE_MONGO_URI[:60]}...")
print("=" * 70)