# app/db/session_manager.py - COMPLETE WITH MAX 3 SESSIONS PER USER

from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
from bson import ObjectId
import hashlib
import json
import logging

from app.db.connection import get_db
from app.models.session_model import SessionModel
from app.models.profile_model import SessionInfo

logger = logging.getLogger(__name__)


class SessionManager:
    """
    Smart Session Management with PERMANENT cleanup
    - MAX 3 ACTIVE SESSIONS PER USER (not 5)
    - Auto DELETE (not archive) of old sessions when limit exceeded
    - Session expiry: 3 days
    - Permanent deletion, not archiving
    - Device tracking
    - Security monitoring
    """
    
    def __init__(self):
        self.max_active_sessions = 3  # ✅ MAX 3 SESSIONS PER USER (reduced from 5)
        self.session_timeout_days = 3  # SESSIONS EXPIRE IN 3 DAYS
        self.inactive_timeout_hours = 24  # DELETE INACTIVE SESSIONS AFTER 24 HOURS
    
    async def create_session(self, user_id: str, user_email: str, 
                            request_info: Dict) -> Dict:
        """Create new session with strict limits - MAX 3 sessions per user"""
        db = get_db()
        
        # Get current active sessions count for this user
        active_sessions = await db.sessions.find({
            "user_id": user_id,
            "is_active": True
        }).to_list(100)
        
        active_count = len(active_sessions)
        
        # ✅ If already 3 or more active sessions, DELETE the oldest ones
        if active_count >= self.max_active_sessions:
            # Calculate how many to delete (active_count - max_active_sessions + 1)
            # We need to delete enough to make room for the new session
            to_delete_count = active_count - self.max_active_sessions + 1
            
            # Get oldest active sessions (sorted by created_at ascending)
            oldest_sessions = await db.sessions.find(
                {"user_id": user_id, "is_active": True}
            ).sort("created_at", 1).limit(to_delete_count).to_list(to_delete_count)
            
            # PERMANENTLY DELETE oldest sessions
            for old_session in oldest_sessions:
                await db.sessions.delete_one({"_id": old_session["_id"]})
                await db.profile.update_one(...)
                logger.info(f"🗑️ Deleted old session for user {user_id} (max {self.max_active_sessions} limit reached)")
                
                # Remove from user profile
                await db.profile.update_one(
                    {"email": user_email},
                    {"$pull": {"active_sessions": {"session_id": str(old_session["_id"])}}}
                )
        
        # Create new session with 3 days expiry
        session = SessionModel.create(
            user_id=user_id,
            user_email=user_email,
            ip=request_info.get('ip', ''),
            device=request_info.get('device', 'Unknown'),
            user_agent=request_info.get('user_agent', ''),
            refresh_token=request_info.get('refresh_token')
        )
        session.location = request_info.get('location', 'Unknown')
        
        result = await db.sessions.insert_one(session.model_dump(by_alias=True))
        session_id = str(result.inserted_id)
        
        # Update user profile with active session info (keep only last 3)
        session_info = SessionInfo(
            session_id=session_id,
            session_hash=session.session_hash[:16],
            device=request_info.get('device', 'Unknown'),
            login_time=datetime.utcnow(),
            ip=request_info.get('ip', '')
        )
        
        await db.profile.update_one(
            {"email": user_email},
            {
                "$push": {
                    "active_sessions": {
                        "$each": [session_info.model_dump()],
                        "$slice": -self.max_active_sessions  # Keep only last 3
                    }
                }
            },
            upsert=True
        )
        
        logger.info(f"✅ Session created for {user_email} (active sessions: {min(active_count + 1, self.max_active_sessions)})")
        
        return {
            "session_id": session_id,
            "session_hash": session.session_hash,
            "expires_at": session.expires_at.isoformat()
        }
    
    async def permanent_cleanup(self) -> Dict:
        """
        PERMANENT CLEANUP - Delete all expired, inactive, and old sessions
        Run this every 30 minutes
        Also enforces max 3 sessions per user
        """
        db = get_db()
        now = datetime.utcnow()
        
        results = {
            "expired_deleted": 0,
            "inactive_deleted": 0,
            "old_deleted": 0,
            "per_user_limit_deleted": 0,
            "total_deleted": 0
        }
        
        # 1. DELETE expired sessions
        expired_result = await db.sessions.delete_many({
            "expires_at": {"$lt": now}
        })
        results["expired_deleted"] = expired_result.deleted_count
        
        # 2. DELETE inactive sessions (no activity for 24 hours)
        inactive_cutoff = now - timedelta(hours=self.inactive_timeout_hours)
        inactive_result = await db.sessions.delete_many({
            "is_active": True,
            "last_activity": {"$lt": inactive_cutoff}
        })
        results["inactive_deleted"] = inactive_result.deleted_count
        
        # 3. DELETE sessions older than timeout days
        old_cutoff = now - timedelta(days=self.session_timeout_days)
        old_result = await db.sessions.delete_many({
            "created_at": {"$lt": old_cutoff}
        })
        results["old_deleted"] = old_result.deleted_count
        
        # 4. ✅ Enforce per-user session limit (keep only max_active_sessions per user)
        # Get all users with more than max_active_sessions
        pipeline = [
            {"$match": {"is_active": True}},
            {"$group": {
                "_id": "$user_id",
                "count": {"$sum": 1},
                "sessions": {"$push": "$$ROOT"}
            }},
            {"$match": {"count": {"$gt": self.max_active_sessions}}}
        ]
        
        users_with_excess = await db.sessions.aggregate(pipeline).to_list(100)
        
        for user_data in users_with_excess:
            sessions = user_data["sessions"]
            # Sort by created_at (oldest first)
            sessions.sort(key=lambda x: x.get("created_at", datetime.min))
            # Keep only max_active_sessions most recent
            to_delete = sessions[:-self.max_active_sessions]
            
            for session in to_delete:
                await db.sessions.delete_one({"_id": session["_id"]})
                results["per_user_limit_deleted"] += 1
                
                # Remove from user profile
                await db.profile.update_one(
                    {"user_id": user_data["_id"]},
                    {"$pull": {"active_sessions": {"session_id": str(session["_id"])}}}
                )
                logger.info(f"🗑️ Cleaned up excess session for user {user_data['_id']} (limit: {self.max_active_sessions})")
        
        results["total_deleted"] = (
            results["expired_deleted"] + 
            results["inactive_deleted"] + 
            results["old_deleted"] + 
            results["per_user_limit_deleted"]
        )
        
        if results["total_deleted"] > 0:
            logger.info(f"🗑️ PERMANENT CLEANUP: Deleted {results['total_deleted']} sessions")
            logger.info(f"   - Expired: {results['expired_deleted']}")
            logger.info(f"   - Inactive: {results['inactive_deleted']}")
            logger.info(f"   - Old: {results['old_deleted']}")
            logger.info(f"   - Per-user limit (max {self.max_active_sessions}): {results['per_user_limit_deleted']}")
        
        return results
    
    async def cleanup_expired_sessions(self) -> Dict:
        """
        Legacy method - kept for compatibility
        Now uses permanent_cleanup for better results
        """
        return await self.permanent_cleanup()
    
    async def validate_session(self, session_id: str, session_hash: str) -> Optional[Dict]:
        """Validate if session is still active and not expired"""
        db = get_db()
        
        if not ObjectId.is_valid(session_id):
            return None
        
        session = await db.sessions.find_one({
            "_id": ObjectId(session_id),
            "session_hash": session_hash,
            "is_active": True,
            "expires_at": {"$gt": datetime.utcnow()}
        })
        
        if session:
            # Update last activity
            await db.sessions.update_one(
                {"_id": session["_id"]},
                {"$set": {"last_activity": datetime.utcnow()}}
            )
            
            return {
                "user_id": session["user_id"],
                "user_email": session["user_email"],
                "session_id": str(session["_id"]),
                "created_at": session["created_at"],
                "expires_at": session["expires_at"]
            }
        
        return None
    
    async def logout_session(self, session_id: str, user_id: str) -> Dict:
        """Logout specific session - PERMANENT DELETE"""
        db = get_db()
        
        if not ObjectId.is_valid(session_id):
            return {"message": "Invalid session ID"}
        
        # PERMANENTLY DELETE session
        result = await db.sessions.delete_one({
            "_id": ObjectId(session_id), 
            "user_id": user_id
        })
        
        if result.deleted_count > 0:
            # Remove from user profile
            await db.profile.update_one(
                {"user_id": user_id},
                {"$pull": {"active_sessions": {"session_id": session_id}}}
            )
            logger.info(f"🔓 User {user_id} logged out from session {session_id}")
            return {"message": "Logged out successfully", "session_id": session_id}
        
        return {"message": "Session not found"}
    
    async def logout_all_devices(self, user_email: str, user_id: str, keep_current_session_id: Optional[str] = None) -> Dict:
        """Logout from all devices - PERMANENT DELETE"""
        db = get_db()
        
        # Build query
        query = {"user_email": user_email, "is_active": True}
        if keep_current_session_id:
            query["_id"] = {"$ne": ObjectId(keep_current_session_id)}
        
        # PERMANENTLY DELETE all matching sessions
        result = await db.sessions.delete_many(query)
        
        # Clear from user profile completely
        await db.profile.update_one(
            {"email": user_email},
            {"$set": {"active_sessions": []}}
        )
        
        logger.info(f"🔓 User {user_email} logged out from {result.deleted_count} devices")
        
        return {
            "message": f"Logged out from {result.deleted_count} devices",
            "devices_logged_out": result.deleted_count
        }
    
    async def get_user_sessions(self, user_id: str) -> List[Dict]:
        """Get all active sessions for a user"""
        db = get_db()
        
        sessions = await db.sessions.find(
            {"user_id": user_id, "is_active": True}
        ).sort("created_at", -1).to_list(100)
        
        return [
            {
                "session_id": str(s["_id"]),
                "device": s.get("device", "Unknown"),
                "ip": s.get("ip", "Unknown"),
                "location": s.get("location", "Unknown"),
                "created_at": s["created_at"].isoformat(),
                "last_activity": s["last_activity"].isoformat(),
                "expires_at": s["expires_at"].isoformat()
            }
            for s in sessions
        ]
    
    async def get_session_stats(self) -> Dict:
        """Get session statistics for monitoring"""
        db = get_db()
        now = datetime.utcnow()
        
        total_sessions = await db.sessions.count_documents({})
        total_active = await db.sessions.count_documents({"is_active": True})
        expired_sessions = await db.sessions.count_documents({"expires_at": {"$lt": now}})
        
        # Get unique users with active sessions
        unique_users = len(await db.sessions.distinct("user_id", {"is_active": True}))
        
        # Get users with most sessions (should be max 3 now)
        pipeline = [
            {"$match": {"is_active": True}},
            {"$group": {"_id": "$user_id", "count": {"$sum": 1}}},
            {"$sort": {"count": -1}},
            {"$limit": 5}
        ]
        top_users = await db.sessions.aggregate(pipeline).to_list(5)
        
        # Check if any user exceeds limit
        users_exceeding_limit = [u for u in top_users if u["count"] > self.max_active_sessions]
        
        return {
            "total_sessions": total_sessions,
            "total_active_sessions": total_active,
            "expired_sessions": expired_sessions,
            "unique_users_active": unique_users,
            "max_sessions_per_user": self.max_active_sessions,
            "session_timeout_days": self.session_timeout_days,
            "inactive_timeout_hours": self.inactive_timeout_hours,
            "users_exceeding_limit": len(users_exceeding_limit),
            "top_users_by_sessions": [
                {
                    "user_id": u["_id"][:20] + "..." if len(u["_id"]) > 20 else u["_id"], 
                    "session_count": u["count"]
                } 
                for u in top_users
            ],
            "health_status": "good" if total_active < 100 else "warning" if total_active < 500 else "critical"
        }
    
    async def get_session_count_by_user(self) -> Dict[str, int]:
        """Get session count per user for monitoring"""
        db = get_db()
        
        pipeline = [
            {"$match": {"is_active": True}},
            {"$group": {"_id": "$user_id", "count": {"$sum": 1}}},
            {"$sort": {"count": -1}}
        ]
        
        result = {}
        for item in await db.sessions.aggregate(pipeline).to_list(1000):
            user_id = item["_id"]
            count = item["count"]
            result[user_id[:20] + "..." if len(user_id) > 20 else user_id] = count
        
        return result
    
    async def enforce_session_limit_for_user(self, user_id: str, user_email: str) -> int:
        """
        Enforce max 3 sessions limit for a specific user
        Returns number of sessions deleted
        """
        db = get_db()
        
        # Get all active sessions for this user
        sessions = await db.sessions.find(
            {"user_id": user_id, "is_active": True}
        ).sort("created_at", 1).to_list(100)
        
        session_count = len(sessions)
        deleted_count = 0
        
        if session_count > self.max_active_sessions:
            # Delete oldest sessions
            to_delete = sessions[:session_count - self.max_active_sessions]
            
            for session in to_delete:
                await db.sessions.delete_one({"_id": session["_id"]})
                deleted_count += 1
                
                # Remove from profile
                await db.profile.update_one(
                    {"email": user_email},
                    {"$pull": {"active_sessions": {"session_id": str(session["_id"])}}}
                )
            
            logger.info(f"🔧 Enforced session limit for {user_email}: deleted {deleted_count} old sessions (now {self.max_active_sessions}/{self.max_active_sessions})")
        
        return deleted_count


# Global instance
session_manager = SessionManager()

print("=" * 60)
print("✅ Session Manager Loaded - PERMANENT CLEANUP ENABLED")
print(f"   ✅ Max sessions per user: {session_manager.max_active_sessions} (MAXIMUM 3)")
print(f"   ✅ Session timeout: {session_manager.session_timeout_days} days")
print(f"   ✅ Inactive timeout: {session_manager.inactive_timeout_hours} hours")
print("   ✅ Sessions are PERMANENTLY DELETED (not archived)")
print("   ✅ When user reaches 3 sessions, oldest session is auto-deleted")
print("=" * 60)