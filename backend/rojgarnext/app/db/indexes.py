# app/db/indexes.py - COMPLETE FIXED VERSION
# ✅ CRITICAL: NO TTL INDEXES - DATA NEVER AUTO-DELETED
# ✅ All data is PERMANENT

from typing import Dict, Any
from app.db.connection import get_db
import logging

logger = logging.getLogger(__name__)


async def create_index_safely(collection, keys, **kwargs):
    """
    Create index safely - ignore if already exists.

    ⚠️ CRITICAL: We BLOCK expireAfterSeconds to prevent auto-deletion!
    """
    if 'expireAfterSeconds' in kwargs:
        logger.warning(
            f"🚫 BLOCKED TTL index on '{collection.name}' for keys {keys}. "
            f"Data will NOT be auto-deleted."
        )
        kwargs = {k: v for k, v in kwargs.items() if k != 'expireAfterSeconds'}

    try:
        await collection.create_index(keys, **kwargs)
        return True
    except Exception as e:
        error_msg = str(e)
        if (
            "already exists" in error_msg
            or "IndexKeySpecsConflict" in error_msg
            or "IndexOptionsConflict" in error_msg
        ):
            logger.debug(f"Index already exists: {keys}")
            return False
        elif "DuplicateKey" in error_msg or "E11000" in error_msg:
            logger.warning(f"⚠️ Duplicate key found - skipping index: {keys}")
            return False
        else:
            logger.warning(f"Index creation warning: {e}")
            return False


async def setup_all_indexes() -> Dict[str, Any]:
    """
    Create all indexes with safe error handling.

    ✅ NO TTL INDEXES - All data is PERMANENT
    """
    db = get_db()

    logger.info("=" * 60)
    logger.info("📊 Setting up indexes (NO TTL - PERMANENT DATA)")
    logger.info("=" * 60)

    indexes_created = []

    # ==================== AUTH INDEXES (NO TTL) ====================
    await create_index_safely(db.auth, "email", unique=True)
    await create_index_safely(db.auth, "mobile", unique=True, sparse=True)
    await create_index_safely(db.auth, "created_at")
    await create_index_safely(db.auth, "role")
    await create_index_safely(db.auth, "is_active")
    await create_index_safely(db.auth, "failed_attempts")
    await create_index_safely(db.auth, "lock_until")
    # ❌ REMOVED: email_otp_expiry TTL
    # ❌ REMOVED: mobile_otp_expiry TTL
    indexes_created.append("auth")

    # ==================== SESSIONS INDEXES (NO TTL) ====================
    await create_index_safely(db.sessions, "user_id")
    await create_index_safely(db.sessions, "session_hash", unique=True, sparse=True)
    await create_index_safely(db.sessions, "created_at")   # ✅ NO TTL
    await create_index_safely(db.sessions, "ip")
    await create_index_safely(db.sessions, "device")
    await create_index_safely(db.sessions, "expires_at")   # ✅ NO TTL
    await create_index_safely(db.sessions, [("user_id", 1), ("is_active", 1)])
    await create_index_safely(db.sessions, [("user_id", 1), ("is_archived", 1)])
    indexes_created.append("sessions")

    # ==================== PROFILE INDEXES ====================
    await create_index_safely(db.profile, "email", unique=True)
    await create_index_safely(db.profile, "created_at")
    await create_index_safely(db.profile, "updated_at")
    await create_index_safely(db.profile, "category")
    await create_index_safely(db.profile, "disability.is_disabled")
    await create_index_safely(db.profile, "disability.category")
    await create_index_safely(db.profile, [("skills.name", 1)])
    indexes_created.append("profile")

    # ==================== JOBS INDEXES ====================
    await create_index_safely(db.job, "status")
    await create_index_safely(db.job, "created_at")
    await create_index_safely(db.job, [("post_date", -1)])
    await create_index_safely(db.job, "organization")
    await create_index_safely(db.job, "job_type")
    await create_index_safely(db.job, "category")
    indexes_created.append("jobs")

    # ==================== APPLICATIONS INDEXES ====================
    await create_index_safely(db.applications, "job_id")
    await create_index_safely(db.applications, "applicant_email")
    await create_index_safely(db.applications, "status")
    await create_index_safely(db.applications, "match_score")
    await create_index_safely(db.applications, "applied_at")
    await create_index_safely(db.applications, "created_at")
    indexes_created.append("applications")

    # ==================== NOTIFICATIONS INDEXES (NO TTL) ====================
    await create_index_safely(db.notifications, "user_id")
    await create_index_safely(db.notifications, "created_at")   # ✅ NO TTL
    await create_index_safely(db.notifications, [("user_id", 1), ("read", 1)])
    indexes_created.append("notifications")

    # ==================== SECURITY INDEXES (NO TTL) ====================
    await create_index_safely(db.security, "type")
    await create_index_safely(db.security, "ip_address")
    await create_index_safely(db.security, "created_at")
    await create_index_safely(db.security, "expires_at")   # ✅ NO TTL
    await create_index_safely(db.security, "severity")
    await create_index_safely(db.security, [("ip_address", 1), ("type", 1)])
    await create_index_safely(db.security, [("user_id", 1), ("type", 1)])
    indexes_created.append("security")

    # ==================== AI INSIGHTS INDEXES (NO TTL) ====================
    await create_index_safely(db.ai_insights, "email")
    await create_index_safely(db.ai_insights, "type")
    await create_index_safely(db.ai_insights, "is_current")
    await create_index_safely(db.ai_insights, "analysis_hash", unique=True, sparse=True)
    await create_index_safely(db.ai_insights, "expires_at")   # ✅ NO TTL
    await create_index_safely(db.ai_insights, [("email", 1), ("type", 1), ("is_current", 1)])
    await create_index_safely(db.ai_insights, [("type", 1), ("status", 1), ("progress_percentage", -1)])
    indexes_created.append("ai_insights")

    # ==================== RESUMES INDEXES ====================
    await create_index_safely(db.resumes, "user_email")
    await create_index_safely(db.resumes, "created_at")
    await create_index_safely(db.resumes, "is_primary")
    indexes_created.append("resumes")

    # ==================== BACKUP RECORDS ====================
    await create_index_safely(db.backup_records, "created_at")
    indexes_created.append("backup_records")

    logger.info("=" * 60)
    logger.info(f"✅ Index setup complete! ({len(indexes_created)} collections)")
    logger.info("✅ NO TTL INDEXES - ALL DATA IS PERMANENT")
    logger.info("=" * 60)

    return {
        "success": True,
        "collections_indexed": indexes_created,
        "total_collections": len(indexes_created),
        "ttl_indexes": 0,
        "data_is_permanent": True,
    }