from twilio.rest import Client
from app.core.config.settings import settings

def send_mobile_otp(mobile: str, otp: str):
    # ================= DEVELOPMENT BYPASS =================
    if settings.MOBILE_OTP_BYPASS:
        print(f"🔧 [DEV MODE] Mobile OTP for +91{mobile} → 123456 (Bypassed)")
        return True

    # ================= REAL TWILIO =================
    try:
        if not settings.TWILIO_ACCOUNT_SID:
            print(f"📱 DEBUG OTP for +91{mobile}: {otp}")
            return False

        client = Client(
            settings.TWILIO_ACCOUNT_SID,
            settings.TWILIO_AUTH_TOKEN
        )
        message = client.messages.create(
            body=f"Your OTP is {otp}",
            from_=settings.TWILIO_PHONE,
            to=f"+91{mobile}"
        )
        print("✅ SMS Sent:", message.sid)
        return True
    except Exception as e:
        print("❌ SMS Error:", e)
        print(f"📱 DEBUG OTP for +91{mobile}: {otp}")
        return False