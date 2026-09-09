# app/core/config/settings.py - Complete Razorpay section
# ✅ NO LINES SKIPPED

import os
import json
import re
from typing import List, Optional
from urllib.parse import quote_plus

# ✅ FIXED: Proper import with fallback for pydantic_settings
try:
    from pydantic_settings import BaseSettings
except ImportError:
    # Fallback for older versions or if package not installed
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

    # ================= SMTP =================
    SMTP_HOST: Optional[str] = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_FROM: Optional[str] = None

    # ================= SMS =================
    TWILIO_ACCOUNT_SID: Optional[str] = None
    TWILIO_AUTH_TOKEN: Optional[str] = None
    TWILIO_PHONE: Optional[str] = None
    MOBILE_OTP_BYPASS: bool = True

    # ================= APP =================
    APP_BASE_URL: str = "http://localhost:8000"
    SECURE_FOLDER_PATH: str = "./secure"
    SECRET_TOKEN: Optional[str] = None

    # ================= APIs =================
    OPENAI_API_KEY: Optional[str] = None
    PROXY_POOL: Optional[str] = None
    CAPTCHA_API_KEY: Optional[str] = None
    DISABLE_AUTH: bool = False
    FAST2SMS_API_KEY: Optional[str] = None

    # Job APIs
    ADZUNA_APP_ID: Optional[str] = None
    ADZUNA_API_KEY: Optional[str] = None
    FREE_JOB_SEARCH_API_KEY: Optional[str] = None
    INFOTRIE_API_KEY: Optional[str] = None
    CORESIGNAL_API_KEY: Optional[str] = None

    # ================= CLOUDINARY =================
    CLOUDINARY_CLOUD_NAME: Optional[str] = None
    CLOUDINARY_API_KEY: Optional[str] = None
    CLOUDINARY_API_SECRET: Optional[str] = None

    # ================= ML & AI =================
    ML_MODELS_PATH: str = "./models"
    AI_LEARNING_RATE: float = 0.01
    AUTO_RETRAIN_INTERVAL_HOURS: int = 24

    # ================= ADVANCED FEATURES =================
    ENABLE_AUTO_APPLY: bool = True
    ENABLE_AUTO_SHORTLIST: bool = True
    AUTO_SHORTLIST_THRESHOLD: int = 85

    # ================= SMART NOTIFICATIONS =================
    ENABLE_SMART_NOTIFICATIONS: bool = True

    # ================= BLOCKCHAIN =================
    WEB3_PROVIDER_URL: Optional[str] = None
    CONTRACT_ADDRESS: Optional[str] = None
    ISSUER_ADDRESS: Optional[str] = None

    # ================= STRIPE =================
    STRIPE_SECRET_KEY: Optional[str] = None
    STRIPE_PUBLISHABLE_KEY: Optional[str] = None

    # ================= GOOGLE DRIVE =================
    GOOGLE_DRIVE_SERVICE_ACCOUNT_EMAIL: Optional[str] = None
    GOOGLE_DRIVE_PRIVATE_KEY: Optional[str] = None
    GOOGLE_DRIVE_FOLDER_ID: Optional[str] = None
    GOOGLE_DRIVE_FOLDER_NAME: str = "rojgarnext_advertisements"

    # ================= RAZORPAY =================
    RAZORPAY_KEY_ID: Optional[str] = None
    RAZORPAY_KEY_SECRET: Optional[str] = None
    RAZORPAY_WEBHOOK_SECRET: Optional[str] = None
    RAZORPAY_TEST_MODE: bool = True

    # ================= PHONEPE =================
    PHONEPE_CLIENT_ID: Optional[str] = None
    PHONEPE_CLIENT_SECRET: Optional[str] = None
    PHONEPE_MERCHANT_ID: Optional[str] = "PGTESTPAYUAT"
    PHONEPE_CLIENT_VERSION: str = "1"
    PHONEPE_MODE: str = "SANDBOX"
    PHONEPE_REDIRECT_URL: Optional[str] = None

    # ================= UPI PAYMENT =================
    UPI_ID: str = "your-upi-id@okhdfcbank"

    # ================= CORS =================
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ]

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
        """Check if Razorpay is in test mode"""
        return self.RAZORPAY_TEST_MODE or self.ENVIRONMENT == "development"

    @property
    def SAFE_MONGO_URI(self) -> str:
        """Return properly formatted MongoDB URI with SSL bypass for Atlas"""
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
        """MongoDB connection options with SSL bypass"""
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

    @property
    def IS_LOCAL_DB(self) -> bool:
        return 'localhost' in self.MONGO_URI or '127.0.0.1' in self.MONGO_URI

    @property
    def IS_ATLAS_DB(self) -> bool:
        return 'mongodb+srv://' in self.MONGO_URI

    class Config:
        env_file = ".env"
        extra = "ignore"
        case_sensitive = True

    def __init__(self, **data):
        super().__init__(**data)
        # Parse CORS_ORIGINS if it comes as string from env
        if isinstance(self.CORS_ORIGINS, str):
            try:
                self.CORS_ORIGINS = json.loads(self.CORS_ORIGINS)
            except:
                self.CORS_ORIGINS = [x.strip() for x in self.CORS_ORIGINS.split(",")]

        # Ensure ML models path exists
        if self.ML_MODELS_PATH and not os.path.exists(self.ML_MODELS_PATH):
            os.makedirs(self.ML_MODELS_PATH, exist_ok=True)


# Create global settings instance
settings = Settings()

print("=" * 60)
print("✅ Settings loaded")
print(f"   Environment: {settings.ENVIRONMENT}")
print(f"   Database: {'LOCAL' if settings.IS_LOCAL_DB else 'ATLAS' if settings.IS_ATLAS_DB else 'UNKNOWN'}")
print(f"   Razorpay Test Mode: {settings.is_razorpay_test_mode}")
print(f"   Razorpay Key ID: {settings.RAZORPAY_KEY_ID[:10] + '...' if settings.RAZORPAY_KEY_ID else 'Not configured'}")
print("=" * 60)