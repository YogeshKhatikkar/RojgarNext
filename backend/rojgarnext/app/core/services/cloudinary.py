# app/core/services/cloudinary.py - UPDATED with correct folder structure

import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional
from fastapi import UploadFile
import time

from app.core.config.settings import settings

logger = logging.getLogger(__name__)

# Import cloudinary
try:
    import cloudinary
    import cloudinary.uploader
    from cloudinary.utils import cloudinary_url
    CLOUDINARY_AVAILABLE = True
    logger.info("✅ Cloudinary libraries loaded successfully")
except ImportError as e:
    CLOUDINARY_AVAILABLE = False
    logger.error(f"❌ Cloudinary import error: {e}")

# Configure Cloudinary
if CLOUDINARY_AVAILABLE and settings.CLOUDINARY_CLOUD_NAME:
    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True
    )
    logger.info(f"☁️ Cloudinary configured: {settings.CLOUDINARY_CLOUD_NAME}")


async def get_signed_view_url(
    public_id: str, 
    resource_type: str = "raw",
    expires_seconds: int = 86400  # 24 hours default
) -> str:
    """Generate a signed URL for viewing private Cloudinary files in browser"""
    if not CLOUDINARY_AVAILABLE:
        return public_id
    
    try:
        url, options = cloudinary_url(
            public_id,
            resource_type=resource_type,
            type="authenticated",  # Private file
            sign_url=True,
            expires_at=int(time.time() + expires_seconds)
        )
        
        logger.info(f"🔐 Generated signed VIEW URL for: {public_id} (expires in {expires_seconds//3600}h)")
        return url
        
    except Exception as e:
        logger.error(f"Failed to generate view URL: {e}")
        return public_id


async def get_signed_download_url(
    public_id: str, 
    resource_type: str = "raw",
    expires_seconds: int = 86400  # 24 hours default
) -> str:
    """Generate a signed download URL that forces download for private Cloudinary files"""
    if not CLOUDINARY_AVAILABLE:
        return public_id
    
    try:
        url, options = cloudinary_url(
            public_id,
            resource_type=resource_type,
            type="authenticated",  # Private file
            sign_url=True,
            flags="attachment",  # Forces download
            expires_at=int(time.time() + expires_seconds)
        )
        
        logger.info(f"🔐 Generated signed DOWNLOAD URL for: {public_id}")
        return url
        
    except Exception as e:
        logger.error(f"Failed to generate download URL: {e}")
        return public_id


async def upload_private_file(
    file: UploadFile, 
    folder: str = "rojgarnext",
    job_id: str = None,
    organization: str = None,
    post_name: str = None
) -> Dict[str, Any]:
    """Upload PRIVATE file to Cloudinary (not publicly accessible)"""
    
    logger.info("=" * 50)
    logger.info(f"📤 Uploading PRIVATE file to CLOUDINARY")
    logger.info(f"   File: {file.filename}")
    logger.info(f"   Folder: {folder}")
    logger.info("=" * 50)
    
    if not CLOUDINARY_AVAILABLE:
        raise Exception("Cloudinary libraries not installed. Run: pip install cloudinary")
    
    if not settings.CLOUDINARY_CLOUD_NAME:
        raise Exception("Cloudinary not configured. Please check .env file")
    
    try:
        file_content = await file.read()
        file_size = len(file_content)
        await file.seek(0)
        
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        cloudinary_folder = f"rojgarnext/{folder}" if folder else "rojgarnext"
        
        original_filename = file.filename or "file"
        name_without_ext = Path(original_filename).stem
        safe_name = "".join(c for c in name_without_ext if c.isalnum() or c in '._-')[:50]
        
        if job_id:
            public_id = f"{cloudinary_folder}/{timestamp}_{job_id}_{safe_name}"
        else:
            public_id = f"{cloudinary_folder}/{timestamp}_{safe_name}"
        
        public_id = public_id.replace("//", "/")
        
        is_pdf = original_filename.lower().endswith('.pdf')
        resource_type = "raw" if is_pdf else "auto"
        
        logger.info(f"   Uploading to Cloudinary (PRIVATE mode)...")
        logger.info(f"   Public ID: {public_id}")
        logger.info(f"   Resource Type: {resource_type}")
        logger.info(f"   File Size: {file_size} bytes")
        logger.info(f"   Is PDF: {is_pdf}")
        
        upload_result = cloudinary.uploader.upload(
            file_content,
            public_id=public_id,
            resource_type=resource_type,
            type="authenticated",
            use_filename=True,
            unique_filename=True,
            overwrite=True
        )
        
        public_id_result = upload_result.get('public_id')
        resource_type_result = upload_result.get('resource_type', resource_type)
        
        logger.info(f"   Upload successful!")
        logger.info(f"   Public ID Result: {public_id_result}")
        logger.info(f"   Resource Type Result: {resource_type_result}")
        
        signed_view_url = await get_signed_view_url(
            public_id_result, 
            resource_type_result,
            expires_seconds=86400
        )
        
        signed_download_url = await get_signed_download_url(
            public_id_result,
            resource_type_result,
            expires_seconds=86400
        )
        
        logger.info(f"✅ Private file uploaded successfully!")
        logger.info(f"   Signed View URL: {signed_view_url[:100]}...")
        logger.info(f"   Signed Download URL: {signed_download_url[:100]}...")
        
        return {
            "url": signed_view_url,
            "download_url": signed_download_url,
            "public_id": public_id_result,
            "resource_type": resource_type_result,
            "filename": original_filename,
            "original_filename": original_filename,
            "size_bytes": file_size,
            "folder_path": cloudinary_folder,
            "storage": "cloudinary",
            "is_pdf": is_pdf,
            "is_public": False,
            "success": True
        }
        
    except Exception as e:
        logger.error(f"❌ Cloudinary upload failed: {e}")
        raise Exception(f"Cloudinary upload failed: {str(e)}")


async def upload_to_cloudinary(
    file: UploadFile, 
    folder: str = "rojgarnext",
    job_id: str = None,
    organization: str = None,
    post_name: str = None
) -> Dict[str, Any]:
    """Upload file to Cloudinary - Public version (kept for backward compatibility)"""
    
    logger.info("=" * 50)
    logger.info(f"📤 Starting public file upload to CLOUDINARY")
    logger.info(f"   File: {file.filename}")
    logger.info(f"   Folder: {folder}")
    logger.info("=" * 50)
    
    if not CLOUDINARY_AVAILABLE:
        raise Exception("Cloudinary libraries not installed. Run: pip install cloudinary")
    
    if not settings.CLOUDINARY_CLOUD_NAME:
        raise Exception("Cloudinary not configured. Please check .env file")
    
    try:
        file_content = await file.read()
        file_size = len(file_content)
        await file.seek(0)
        
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        cloudinary_folder = f"rojgarnext/{folder}" if folder else "rojgarnext"
        
        original_filename = file.filename or "file"
        name_without_ext = Path(original_filename).stem
        safe_name = "".join(c for c in name_without_ext if c.isalnum() or c in '._-')[:50]
        
        if job_id:
            public_id = f"{cloudinary_folder}/{timestamp}_{job_id}_{safe_name}"
        else:
            public_id = f"{cloudinary_folder}/{timestamp}_{safe_name}"
        
        public_id = public_id.replace("//", "/")
        
        logger.info(f"   Uploading to Cloudinary...")
        logger.info(f"   Public ID: {public_id}")
        logger.info(f"   File Size: {file_size} bytes")
        
        upload_result = cloudinary.uploader.upload(
            file_content,
            public_id=public_id,
            resource_type="auto",
            use_filename=True,
            unique_filename=True,
            overwrite=True
        )
        
        file_url = upload_result.get('secure_url')
        public_id_result = upload_result.get('public_id')
        
        logger.info(f"✅ File uploaded to CLOUDINARY successfully!")
        logger.info(f"   URL: {file_url}")
        
        return {
            "url": file_url,
            "public_id": public_id_result,
            "filename": original_filename,
            "original_filename": original_filename,
            "size_bytes": file_size,
            "folder_path": cloudinary_folder,
            "storage": "cloudinary",
            "success": True
        }
        
    except Exception as e:
        logger.error(f"❌ Cloudinary upload failed: {e}")
        raise Exception(f"Cloudinary upload failed: {str(e)}")


async def delete_from_cloudinary(file_id: str, resource_type: str = "image") -> Dict[str, Any]:
    """Delete file from Cloudinary"""
    if not CLOUDINARY_AVAILABLE:
        return {"result": "failed", "error": "Cloudinary not available"}
    
    try:
        result = cloudinary.uploader.destroy(file_id, resource_type=resource_type)
        if result.get('result') == 'ok':
            logger.info(f"🗑️ File deleted from Cloudinary: {file_id}")
            return {"result": "success", "deleted": True}
        else:
            logger.error(f"❌ Failed to delete: {file_id} - {result}")
            return {"result": "failed", "error": str(result)}
    except Exception as e:
        logger.error(f"❌ Delete error: {e}")
        return {"result": "failed", "error": str(e)}


async def refresh_signed_url(
    public_id: str, 
    resource_type: str = "raw",
    expires_seconds: int = 86400
) -> Dict[str, Any]:
    """Refresh expired signed URLs for a private file"""
    if not CLOUDINARY_AVAILABLE:
        return {"success": False, "error": "Cloudinary not available"}
    
    try:
        signed_view_url = await get_signed_view_url(
            public_id, 
            resource_type,
            expires_seconds=expires_seconds
        )
        
        signed_download_url = await get_signed_download_url(
            public_id,
            resource_type,
            expires_seconds=expires_seconds
        )
        
        logger.info(f"🔄 Refreshed signed URLs for: {public_id}")
        
        return {
            "success": True,
            "url": signed_view_url,
            "download_url": signed_download_url,
            "expires_in_hours": expires_seconds // 3600
        }
        
    except Exception as e:
        logger.error(f"Failed to refresh signed URLs: {e}")
        return {"success": False, "error": str(e)}


async def test_cloudinary_connection() -> Dict[str, Any]:
    """Test Cloudinary connection"""
    if not CLOUDINARY_AVAILABLE:
        return {
            "success": False,
            "error": "Cloudinary libraries not installed"
        }
    
    if not settings.CLOUDINARY_CLOUD_NAME:
        return {
            "success": False,
            "error": "Cloudinary not configured"
        }
    
    try:
        url, options = cloudinary_url("test", format="jpg")
        return {
            "success": True,
            "cloud_name": settings.CLOUDINARY_CLOUD_NAME,
            "message": "Cloudinary configured successfully",
            "test_url": url
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


# app/core/services/cloudinary.py - Add this method

async def upload_payment_screenshot(
    file: UploadFile,
    username: str,
    payment_id: str
) -> Dict[str, Any]:
    """
    Upload a payment screenshot to Cloudinary under payment folder
    """
    logger.info("=" * 50)
    logger.info(f"📤 Uploading payment screenshot for user: {username}")
    logger.info(f"   Payment ID: {payment_id}")
    logger.info(f"   File: {file.filename}")
    logger.info("=" * 50)

    if not CLOUDINARY_AVAILABLE:
        raise Exception("Cloudinary libraries not installed. Run: pip install cloudinary")

    if not settings.CLOUDINARY_CLOUD_NAME:
        raise Exception("Cloudinary not configured. Please check .env file")

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    original_filename = file.filename or "screenshot"
    name_without_ext = Path(original_filename).stem
    safe_name = "".join(c for c in name_without_ext if c.isalnum() or c in '._-')[:50]

    folder = f"rojgarnext_uploads/users_data/{username}/payment"
    public_id = f"{folder}/{timestamp}_{payment_id}_{safe_name}"
    public_id = public_id.replace("//", "/")

    is_pdf = original_filename.lower().endswith('.pdf')
    resource_type = "raw" if is_pdf else "auto"

    logger.info(f"   Uploading to Cloudinary (PRIVATE mode)...")
    logger.info(f"   Public ID: {public_id}")
    logger.info(f"   Resource Type: {resource_type}")
    logger.info(f"   File Size: {file_size} bytes")

    upload_result = cloudinary.uploader.upload(
        file_content,
        public_id=public_id,
        resource_type=resource_type,
        type="authenticated",
        use_filename=True,
        unique_filename=True,
        overwrite=True
    )

    public_id_result = upload_result.get('public_id')
    resource_type_result = upload_result.get('resource_type', resource_type)

    signed_view_url = await get_signed_view_url(
        public_id_result,
        resource_type_result,
        expires_seconds=86400
    )

    signed_download_url = await get_signed_download_url(
        public_id_result,
        resource_type_result,
        expires_seconds=86400
    )

    logger.info(f"✅ Payment screenshot uploaded successfully!")
    logger.info(f"   Public ID: {public_id_result}")
    logger.info(f"   View URL: {signed_view_url[:100]}...")
    logger.info(f"   Download URL: {signed_download_url[:100]}...")

    return {
        "url": signed_view_url,
        "download_url": signed_download_url,
        "public_id": public_id_result,
        "resource_type": resource_type_result,
        "filename": original_filename,
        "size_bytes": file_size,
        "folder_path": folder,
        "storage": "cloudinary",
        "is_pdf": is_pdf,
        "success": True
    }

async def upload_user_document(
    file: UploadFile,
    username: str,
    document_type: str = "applications"
) -> Dict[str, Any]:
    """
    Upload user document to Cloudinary under:
        rojgarnext_uploads/users_data/{username}/{document_type}/
    """
    logger.info("=" * 50)
    logger.info(f"📤 Uploading user document to Cloudinary")
    logger.info(f"   Username: {username}")
    logger.info(f"   Document Type: {document_type}")
    logger.info(f"   File: {file.filename}")
    logger.info("=" * 50)
    
    if not CLOUDINARY_AVAILABLE:
        raise Exception("Cloudinary libraries not installed")
    
    if not settings.CLOUDINARY_CLOUD_NAME:
        raise Exception("Cloudinary not configured")
    
    try:
        file_content = await file.read()
        file_size = len(file_content)
        await file.seek(0)
        
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        
        # ✅ FIXED: Correct folder structure
        cloudinary_folder = f"rojgarnext_uploads/users_data/{username}/{document_type}"
        
        original_filename = file.filename or "document"
        name_without_ext = Path(original_filename).stem
        safe_name = "".join(c for c in name_without_ext if c.isalnum() or c in '._-')[:50]
        
        public_id = f"{cloudinary_folder}/{timestamp}_{safe_name}"
        public_id = public_id.replace("//", "/")
        
        is_pdf = original_filename.lower().endswith('.pdf')
        is_image = original_filename.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.gif'))
        
        if is_pdf:
            resource_type = "raw"
        elif is_image:
            resource_type = "image"
        else:
            resource_type = "auto"
        
        upload_result = cloudinary.uploader.upload(
            file_content,
            public_id=public_id,
            resource_type=resource_type,
            type="authenticated",
            use_filename=True,
            unique_filename=True,
            overwrite=True
        )
        
        public_id_result = upload_result.get('public_id')
        resource_type_result = upload_result.get('resource_type', resource_type)
        
        signed_view_url = await get_signed_view_url(
            public_id_result, 
            resource_type_result,
            expires_seconds=86400
        )
        
        signed_download_url = await get_signed_download_url(
            public_id_result,
            resource_type_result,
            expires_seconds=86400
        )
        
        return {
            "url": signed_view_url,
            "download_url": signed_download_url,
            "public_id": public_id_result,
            "resource_type": resource_type_result,
            "filename": original_filename,
            "size_bytes": file_size,
            "folder_path": cloudinary_folder,
            "storage": "cloudinary",
            "is_pdf": is_pdf,
            "is_image": is_image,
            "is_public": False,
            "success": True
        }
        
    except Exception as e:
        logger.error(f"❌ Cloudinary upload failed: {e}")
        raise Exception(f"Cloudinary upload failed: {str(e)}")


logger.info("✅ Cloudinary upload service ready - PRIVATE files supported")
logger.info("   - Private uploads use signed URLs")
logger.info("   - Separate URLs for viewing and downloading")
logger.info("   - URLs expire after 24 hours")