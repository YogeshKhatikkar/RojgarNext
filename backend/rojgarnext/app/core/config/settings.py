# app/core/config/settings.py
# ✅ Complete settings with Brevo + MSG91 + Multi-provider support

import os
import json
import re
from typing import List, Optional
from urllib.parse import quote_plus

try:
    from pydantic_settings import BaseSettings
except ImportError:
    from pydantic import BaseSettings

from dotenv import load_dotenv

load_dotenv()


class Settings(BaseSettings):
    # ================= CORE =================
    MONGO_URI: str = "mongodb://localhost:27017"
    DATABASE_NAME: str = "rojgarnext"
    ENVIRONMENT: str = "development"
    PORT: int = 8000

    # ================= SECURITY =================
    SECRET_KEY: str = "your-secret-key-change-in-production-minimum-32-chars"
    SESSION_SECRET_KEY: str = "your-session-secret-key-change-in-production"
    JWT_SECRET_KEY: str = "your-jwt-secret-key-change-in-production"
    ENCRYPTION_KEY: Optional[str] = None

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # ================= REDIS =================
    REDIS_URL: Optional[str] = None

    # ============================================================
    # 📧 EMAIL PROVIDER CONFIGURATION
    # ============================================================
    EMAIL_PROVIDER: str = "brevo"  # smtp | brevo | sendgrid | mailgun

    # SMTP (Gmail)
    SMTP_HOST: Optional[str] = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_FROM: Optional[str] = None
    SMTP_FROM_NAME: str = "RojgarNext"

    # Brevo
    BREVO_API_KEY: Optional[str] = None
    BREVO_SENDER_EMAIL: Optional[str] = None
    BREVO_SENDER_NAME: str = "RojgarNext"
    BREVO_SMTP_HOST: str = "smtp-relay.brevo.com"
    BREVO_SMTP_PORT: int = 587
    BREVO_SMTP_USER: Optional[str] = None
    BREVO_SMTP_PASSWORD: Optional[str] = None

    # SendGrid
    SENDGRID_API_KEY: Optional[str] = None
    SENDGRID_FROM_EMAIL: Optional[str] = None
    SENDGRID_FROM_NAME: str = "RojgarNext"

    # Mailgun
    MAILGUN_API_KEY: Optional[str] = None
    MAILGUN_DOMAIN: Optional[str] = None
    MAILGUN_FROM_EMAIL: Optional[str] = None
    MAILGUN_FROM_NAME: str = "RojgarNext"

    # ============================================================
    # 📱 SMS PROVIDER CONFIGURATION
    # ============================================================
    SMS_PROVIDER: str = "msg91"  # twilio | msg91 | fast2sms | brevo

    # Twilio
    TWILIO_ACCOUNT_SID: Optional[str] = None
    TWILIO_AUTH_TOKEN: Optional[str] = None
    TWILIO_PHONE: Optional[str] = None

    # MSG91
    MSG91_AUTH_KEY: Optional[str] = None
    MSG91_SENDER_ID: str = "RJRNXT"
    MSG91_TEMPLATE_ID_OTP: Optional[str] = None
    MSG91_TEMPLATE_ID_VERIFY: Optional[str] = None
    MSG91_TEMPLATE_ID_ALERT: Optional[str] = None
    MSG91_ROUTE: int = 4
    MSG91_COUNTRY: str = "91"
    MSG91_DLT_TE_ID: Optional[str] = None

    # Fast2SMS
    FAST2SMS_API_KEY: Optional[str] = None

    # Brevo SMS
    BREVO_SMS_SENDER: str = "RojgarNext"
    BREVO_SMS_API_KEY: Optional[str] = None

    # OTP Bypass
    MOBILE_OTP_BYPASS: bool = True

    # ============================================================
    # 💬 WHATSAPP PROVIDER CONFIGURATION
    # ============================================================
    WHATSAPP_PROVIDER: str = "msg91"  # msg91 | twilio | meta | disabled

    # MSG91 WhatsApp
    MSG91_WHATSAPP_API_KEY: Optional[str] = None
    MSG91_WHATSAPP_INTEGRATED_NUMBER: Optional[str] = None
    MSG91_WHATSAPP_TEMPLATE_OTP: Optional[str] = None
    MSG91_WHATSAPP_TEMPLATE_ALERT: Optional[str] = None
    MSG91_WHATSAPP_TEMPLATE_JOB: Optional[str] = None
    MSG91_WHATSAPP_TEMPLATE_STATUS: Optional[str] = None

    # Twilio WhatsApp
    TWILIO_WHATSAPP_NUMBER: Optional[str] = None

    # Meta WhatsApp Business
    META_WA_PHONE_NUMBER_ID: Optional[str] = None
    META_WA_ACCESS_TOKEN: Optional[str] = None
    META_WA_BUSINESS_ACCOUNT_ID: Optional[str] = None
    META_WA_VERIFY_TOKEN: Optional[str] = None
    META_WA_TEMPLATE_OTP: str = "otp_verification"
    META_WA_TEMPLATE_ALERT: str = "general_alert"

    WHATSAPP_FALLBACK_TO_SMS: bool = True

    # ============================================================
    # 🔔 NOTIFICATION CHANNEL SETTINGS
    # ============================================================
    NOTIFY_OTP_CHANNELS: str = "email,sms,whatsapp"
    NOTIFY_VERIFICATION_CHANNELS: str = "email,sms"
    NOTIFY_JOB_ALERT_CHANNELS: str = "email,whatsapp,inapp,websocket"
    NOTIFY_APPLICATION_STATUS_CHANNELS: str = "email,sms,whatsapp,inapp,websocket"
    NOTIFY_PAYMENT_CHANNELS: str = "email,sms,whatsapp,inapp,websocket"
    NOTIFY_ADMIN_ALERT_CHANNELS: str = "email,inapp,websocket"
    NOTIFY_PASSWORD_RESET_CHANNELS: str = "email,sms,whatsapp"
    NOTIFY_WELCOME_CHANNELS: str = "email,whatsapp"

    # ============================================================
    # 🌐 OTHER SERVICES
    # ============================================================
    APP_BASE_URL: str = "http://localhost:8000"
    SECURE_FOLDER_PATH: str = "./secure"
    SECRET_TOKEN: Optional[str] = None

    OPENAI_API_KEY: Optional[str] = None
    PROXY_POOL: Optional[str] = None
    CAPTCHA_API_KEY: Optional[str] = None
    DISABLE_AUTH: bool = False

    # Job APIs
    ADZUNA_APP_ID: Optional[str] = None
    ADZUNA_API_KEY: Optional[str] = None
    FREE_JOB_SEARCH_API_KEY: Optional[str] = None
    INFOTRIE_API_KEY: Optional[str] = None
    CORESIGNAL_API_KEY: Optional[str] = None

    # Cloudinary
    CLOUDINARY_CLOUD_NAME: Optional[str] = None
    CLOUDINARY_API_KEY: Optional[str] = None
    CLOUDINARY_API_SECRET: Optional[str] = None

    # ML & AI
    ML_MODELS_PATH: str = "./models"
    AI_LEARNING_RATE: float = 0.01
    AUTO_RETRAIN_INTERVAL_HOURS: int = 24

    # Advanced features
    ENABLE_AUTO_APPLY: bool = True
    ENABLE_AUTO_SHORTLIST: bool = True
    AUTO_SHORTLIST_THRESHOLD: int = 85
    ENABLE_SMART_NOTIFICATIONS: bool = True

    # Blockchain
    WEB3_PROVIDER_URL: Optional[str] = None
    CONTRACT_ADDRESS: Optional[str] = None
    ISSUER_ADDRESS: Optional[str] = None

    # Stripe
    STRIPE_SECRET_KEY: Optional[str] = None
    STRIPE_PUBLISHABLE_KEY: Optional[str] = None

    # Google Drive
    GOOGLE_DRIVE_SERVICE_ACCOUNT_EMAIL: Optional[str] = None
    GOOGLE_DRIVE_PRIVATE_KEY: Optional[str] = None
    GOOGLE_DRIVE_FOLDER_ID: Optional[str] = None
    GOOGLE_DRIVE_FOLDER_NAME: str = "rojgarnext_advertisements"

    # Razorpay
    RAZORPAY_KEY_ID: Optional[str] = None
    RAZORPAY_KEY_SECRET: Optional[str] = None
    RAZORPAY_WEBHOOK_SECRET: Optional[str] = None
    RAZORPAY_TEST_MODE: bool = True

    # PhonePe
    PHONEPE_CLIENT_ID: Optional[str] = None
    PHONEPE_CLIENT_SECRET: Optional[str] = None
    PHONEPE_MERCHANT_ID: Optional[str] = "PGTESTPAYUAT"
    PHONEPE_CLIENT_VERSION: str = "1"
    PHONEPE_MODE: str = "SANDBOX"
    PHONEPE_REDIRECT_URL: Optional[str] = None
    PHONEPE_SALT_KEY: Optional[str] = None
    PHONEPE_SALT_INDEX: Optional[str] = None
    PHONEPE_API_URL: Optional[str] = None
    PHONEPE_STATUS_URL: Optional[str] = None
    PHONEPE_ENV: Optional[str] = None

    # UPI
    UPI_ID: str = "your-upi-id@okhdfcbank"

    # Fake job detection
    FAKE_JOB_DETECTION_ENABLED: bool = True
    FAKE_JOB_CONFIDENCE_THRESHOLD: int = 60
    DUPLICATE_JOB_DAYS_THRESHOLD: int = 30
    MAX_JOBS_PER_FETCH: int = 50

    # ============================================================
    # 🧪 DEV MODE
    # ============================================================
    DEV_MODE_LOG_ONLY: bool = False
    USE_MOCK_PROVIDERS: bool = False
    EMAIL_RATE_LIMIT_PER_HOUR: int = 500
    SMS_RATE_LIMIT_PER_HOUR: int = 200
    WHATSAPP_RATE_LIMIT_PER_HOUR: int = 200

    # ================= CORS =================
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "https://www.rojgarnext.com",
        "https://rojgarnext.com",
    ]

    # ================= PROPERTIES =================
    @property
    def PHONEPE_AUTH_URL(self) -> str:
        if self.PHONEPE_MODE == "PRODUCTION":
            return "https://identitymanager.phonepe.com/apis/identity-manager/v1/oauth/token"
        return "https://api-preprod.phonepe.com/apis/identity-manager/v1/oauth/token"

    @property
    def PHONEPE_PAY_API(self) -> str:
        if self.PHONEPE_MODE == "PRODUCTION":
            return "https://api.phonepe.com/apis/pg/v2/pay"
        return "https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/pay"

    @property
    def PHONEPE_STATUS_API(self) -> str:
        if self.PHONEPE_MODE == "PRODUCTION":
            return "https://api.phonepe.com/apis/pg/v2/order"
        return "https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/order"

    @property
    def is_razorpay_test_mode(self) -> bool:
        return self.RAZORPAY_TEST_MODE or self.ENVIRONMENT == "development"

    @property
    def IS_LOCAL_DB(self) -> bool:
        return 'localhost' in self.MONGO_URI or '127.0.0.1' in self.MONGO_URI

    @property
    def IS_ATLAS_DB(self) -> bool:
        return 'mongodb+srv://' in self.MONGO_URI

    @property
    def SAFE_MONGO_URI(self) -> str:
        uri = self.MONGO_URI
        if 'localhost' in uri or '127.0.0.1' in uri:
            print(f"✅ Using LOCAL MongoDB: {uri}")
            return uri
        if 'mongodb+srv://' in uri:
            pattern = r'(mongodb(?:\+srv)?://)([^:]+):([^@]+)@(.+)'
            match = re.match(pattern, uri)
            if not match:
                print(f"⚠️ Could not parse Atlas URI, using as-is")
                return uri
            scheme = match.group(1)
            username = match.group(2)
            password = match.group(3)
            rest = match.group(4)
            encoded_username = quote_plus(username)
            encoded_password = quote_plus(password)
            safe_uri = f"{scheme}{encoded_username}:{encoded_password}@{rest}"
            if '?' in safe_uri:
                safe_uri += "&tls=true&tlsAllowInvalidCertificates=true"
            else:
                safe_uri += "?tls=true&tlsAllowInvalidCertificates=true"
            print(f"✅ Using MongoDB Atlas with SSL bypass")
            return safe_uri
        return uri

    @property
    def MONGO_OPTIONS(self) -> dict:
        options = {
            "serverSelectionTimeoutMS": 60000,
            "connectTimeoutMS": 60000,
            "socketTimeoutMS": 60000,
            "maxPoolSize": 10,
            "minPoolSize": 2,
            "maxIdleTimeMS": 30000,
            "retryWrites": True,
            "retryReads": True,
            "heartbeatFrequencyMS": 5000,
        }
        if self.IS_ATLAS_DB:
            options.update({
                "tls": True,
                "tlsAllowInvalidCertificates": True,
                "tlsAllowInvalidHostnames": True,
            })
        return options

    # ================= HELPERS =================
    def get_channels_for(self, notification_type: str) -> List[str]:
        """Return list of channels enabled for a notification type."""
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
        raw = mapping.get(notification_type, "email,inapp,websocket")
        return [c.strip().lower() for c in raw.split(",") if c.strip()]

    class Config:
        env_file = ".env"
        extra = "ignore"
        case_sensitive = True

    def __init__(self, **data):
        super().__init__(**data)
        if isinstance(self.CORS_ORIGINS, str):
            try:
                self.CORS_ORIGINS = json.loads(self.CORS_ORIGINS)
            except Exception:
                self.CORS_ORIGINS = [x.strip() for x in self.CORS_ORIGINS.split(",")]
        if self.ML_MODELS_PATH and not os.path.exists(self.ML_MODELS_PATH):
            os.makedirs(self.ML_MODELS_PATH, exist_ok=True)


settings = Settings()

print("=" * 60)
print("✅ Settings loaded")
print(f"   Environment: {settings.ENVIRONMENT}")
print(f"   Email Provider: {settings.EMAIL_PROVIDER}")
print(f"   SMS Provider: {settings.SMS_PROVIDER}")
print(f"   WhatsApp Provider: {settings.WHATSAPP_PROVIDER}")
print(f"   Database: {'LOCAL' if settings.IS_LOCAL_DB else 'ATLAS' if settings.IS_ATLAS_DB else 'UNKNOWN'}")
print("=" * 60)