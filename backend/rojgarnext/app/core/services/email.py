# app/core/services/email.py - WITH PROPER EMAIL SENDING
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config.settings import settings
from app.core.utils.logger import logger

# Global flag to control email notifications
EMAIL_NOTIFICATIONS_ENABLED = getattr(settings, 'ENABLE_EMAIL_NOTIFICATIONS', True)

def send_email(to_email: str, otp: str):
    """OTP email - can be disabled via settings"""
    if not EMAIL_NOTIFICATIONS_ENABLED:
        logger.info(f"🔕 Email notifications disabled. Would have sent OTP to {to_email} → {otp}")
        return
    
    if not settings.SMTP_HOST or settings.SMTP_HOST in ["dummy", ""]:
        print(f"🔧 [DEV MODE] Email OTP for {to_email} → {otp} (Bypassed)")
        logger.info(f"Email bypassed for {to_email}")
        return

    try:
        msg = MIMEText(f"Your OTP is {otp}")
        msg["Subject"] = "Verify your email"
        msg["From"] = settings.SMTP_FROM
        msg["To"] = to_email

        server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT)
        server.starttls()
        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        server.sendmail(settings.SMTP_FROM, [to_email], msg.as_string())
        server.quit()
        logger.info(f"✅ OTP Email sent to {to_email}")
    except Exception as e:
        logger.error(f"❌ OTP Email failed: {e}")


def send_html_email(to_email: str, subject: str, html_body: str):
    """HTML Email for notifications - Enhanced with better error handling"""
    
    # Log for debugging
    logger.info(f"📧 Attempting to send HTML email to: {to_email}")
    logger.info(f"   Subject: {subject}")
    logger.info(f"   SMTP Host: {settings.SMTP_HOST}")
    logger.info(f"   SMTP User: {settings.SMTP_USER}")
    
    if not settings.SMTP_HOST or settings.SMTP_HOST in ["dummy", ""]:
        print(f"🔧 [DEV MODE] HTML Email to {to_email} | {subject}")
        logger.info(f"HTML Email bypassed for {to_email}")
        return

    try:
        # Create message
        msg = MIMEMultipart("alternative")
        msg["From"] = settings.SMTP_FROM
        msg["To"] = to_email
        msg["Subject"] = subject
        
        # Attach HTML body
        msg.attach(MIMEText(html_body, "html"))

        # Connect and send
        server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT)
        server.starttls()
        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        server.sendmail(settings.SMTP_FROM, [to_email], msg.as_string())
        server.quit()
        
        logger.info(f"✅ HTML Email sent successfully to {to_email}")
        return True
        
    except smtplib.SMTPAuthenticationError as e:
        logger.error(f"❌ SMTP Authentication failed: {e}")
        logger.error("   Please check your SMTP_USER and SMTP_PASSWORD in .env file")
        return False
    except smtplib.SMTPException as e:
        logger.error(f"❌ SMTP Exception: {e}")
        return False
    except Exception as e:
        logger.error(f"❌ HTML Email failed: {e}")
        return False