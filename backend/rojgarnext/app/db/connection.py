# app/db/connection.py - UPDATED WITH UNIFIED COLLECTIONS

from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config.settings import settings
import logging
import asyncio

logger = logging.getLogger(__name__)

client = None
db = None


async def create_index_safely(collection, keys, **kwargs):
    """Create index safely - ignore if already exists"""
    try:
        await collection.create_index(keys, **kwargs)
        return True
    except Exception as e:
        error_msg = str(e)
        if "already exists" in error_msg or "IndexKeySpecsConflict" in error_msg or "IndexOptionsConflict" in error_msg:
            logger.debug(f"Index already exists: {keys}")
            return False
        elif "DuplicateKey" in error_msg or "E11000" in error_msg:
            logger.warning(f"⚠️ Duplicate key found - skipping index: {keys}")
            return False
        else:
            logger.warning(f"Index creation warning: {e}")
            return False


async def connect_db():
    """Connect to MongoDB with unified collections"""
    global client, db
    
    try:
        mongo_uri = settings.SAFE_MONGO_URI
        
        print("=" * 60)
        print(f"🔗 Connecting to MongoDB...")
        print(f"   Environment: {settings.ENVIRONMENT}")
        print(f"   Database Type: {'LOCAL' if settings.IS_LOCAL_DB else 'ATLAS' if settings.IS_ATLAS_DB else 'UNKNOWN'}")
        print("=" * 60)
        
        options = settings.MONGO_OPTIONS.copy()
        
        max_retries = 3
        last_error = None
        
        for attempt in range(max_retries):
            try:
                client = AsyncIOMotorClient(mongo_uri, **options)
                await asyncio.wait_for(client.admin.command("ping"), timeout=15.0)
                print(f"✅ MongoDB ping successful! (attempt {attempt + 1})")
                break
            except asyncio.TimeoutError:
                print(f"⚠️ Attempt {attempt + 1} timed out")
                last_error = "Connection timeout"
                if attempt < max_retries - 1:
                    await asyncio.sleep(3)
            except Exception as e:
                print(f"⚠️ Attempt {attempt + 1} failed: {e}")
                last_error = str(e)
                if attempt < max_retries - 1:
                    await asyncio.sleep(3)
        else:
            raise Exception(f"All {max_retries} connection attempts failed. Last error: {last_error}")
        
        db = client[settings.DATABASE_NAME]
        print(f"✅ Connected to database: {settings.DATABASE_NAME}")
        
        # ✅ Create collections if they don't exist
        collections = await db.list_collection_names()
        
        required_collections = [
            "auth", "profile", "job", 
            "applications",  # ✅ Unified collection for ALL applications
            "resumes", "sessions", "notifications", "ai_insights",
            "reports", "security"
        ]
        
        for coll_name in required_collections:
            if coll_name not in collections:
                await db.create_collection(coll_name)
                print(f"📁 Created collection: {coll_name}")
        
        # ✅ Setup unified indexes
        await create_all_indexes(db)
        await verify_and_show_data(db)
        
        return True
        
    except Exception as e:
        print(f"❌ MongoDB Connection Error: {e}")
        print("\n📌 Troubleshooting:")
        print("   1. Check your internet connection")
        print("   2. Verify MongoDB Atlas credentials")
        print("   3. Check IP whitelist in MongoDB Atlas Network Access")
        print("   4. Try: pip install --upgrade motor")
        raise


async def create_all_indexes(db):
    """Create all indexes for all collections with unified applications"""
    print("\n📊 Creating database indexes...")
    
    # Auth indexes
    await create_index_safely(db.auth, "email", unique=True)
    await create_index_safely(db.auth, "mobile", unique=True, sparse=True)
    await create_index_safely(db.auth, "created_at")
    await create_index_safely(db.auth, "role")
    await create_index_safely(db.auth, "is_active")
    await create_index_safely(db.auth, "failed_attempts")
    await create_index_safely(db.auth, "lock_until")
    await create_index_safely(db.auth, "email_otp_expiry", expireAfterSeconds=0, sparse=True)
    await create_index_safely(db.auth, "mobile_otp_expiry", expireAfterSeconds=0, sparse=True)
    
    # Job indexes
    await create_index_safely(db.job, "status")
    await create_index_safely(db.job, "created_at")
    await create_index_safely(db.job, "organization")
    await create_index_safely(db.job, "job_type")
    await create_index_safely(db.job, "category")
    
    # Profile indexes
    await create_index_safely(db.profile, "email", unique=True)
    await create_index_safely(db.profile, "created_at")
    await create_index_safely(db.profile, "updated_at")
    await create_index_safely(db.profile, "category")
    await create_index_safely(db.profile, "disability.is_disabled")
    await create_index_safely(db.profile, "disability.category")
    await create_index_safely(db.profile, [("skills.name", 1)])
    
    # ==================== UNIFIED APPLICATIONS ====================
    # ✅ Unified collection for all applications (jobs + services)
    await create_index_safely(db.applications, "application_type")
    await create_index_safely(db.applications, "user_email")
    await create_index_safely(db.applications, "user_id")
    await create_index_safely(db.applications, "status")
    await create_index_safely(db.applications, "payment_verification_status")
    await create_index_safely(db.applications, "created_at")
    await create_index_safely(db.applications, "updated_at")
    await create_index_safely(db.applications, "job_id", sparse=True)
    await create_index_safely(db.applications, "service_id", sparse=True)
    await create_index_safely(db.applications, "transaction_id", sparse=True)
    await create_index_safely(db.applications, "payment_id", sparse=True)
    
    # Compound indexes for efficient queries
    await create_index_safely(db.applications, [("user_email", 1), ("application_type", 1)])
    await create_index_safely(db.applications, [("user_email", 1), ("status", 1)])
    await create_index_safely(db.applications, [("application_type", 1), ("status", 1)])
    await create_index_safely(db.applications, [("job_id", 1), ("user_email", 1)])
    await create_index_safely(db.applications, [("service_id", 1), ("sub_type_id", 1), ("user_email", 1)])
    await create_index_safely(db.applications, [("payment_verification_status", 1), ("status", 1)])
    
    # TTL index for expired payment sessions
    await create_index_safely(db.applications, "expires_at", expireAfterSeconds=0)
    
    print("✅ Unified applications indexes created")
    
    # Sessions indexes
    await create_index_safely(db.sessions, "user_id")
    await create_index_safely(db.sessions, "session_hash", unique=True, sparse=True)
    await create_index_safely(db.sessions, "created_at", expireAfterSeconds=604800)
    await create_index_safely(db.sessions, "ip")
    await create_index_safely(db.sessions, "device")
    await create_index_safely(db.sessions, "expires_at", expireAfterSeconds=0)
    await create_index_safely(db.sessions, [("user_id", 1), ("is_active", 1)])
    await create_index_safely(db.sessions, [("user_id", 1), ("is_archived", 1)])
    
    # Notifications indexes
    await create_index_safely(db.notifications, "user_id")
    await create_index_safely(db.notifications, "created_at")
    await create_index_safely(db.notifications, "created_at", expireAfterSeconds=2592000)
    await create_index_safely(db.notifications, [("user_id", 1), ("read", 1)])
    
    # Security indexes
    await create_index_safely(db.security, "type")
    await create_index_safely(db.security, "ip_address")
    await create_index_safely(db.security, "created_at")
    await create_index_safely(db.security, "expires_at", expireAfterSeconds=0)
    await create_index_safely(db.security, "severity")
    await create_index_safely(db.security, [("ip_address", 1), ("type", 1)])
    await create_index_safely(db.security, [("user_id", 1), ("type", 1)])
    
    # AI Insights indexes
    await create_index_safely(db.ai_insights, "email")
    await create_index_safely(db.ai_insights, "type")
    await create_index_safely(db.ai_insights, "is_current")
    await create_index_safely(db.ai_insights, "analysis_hash", unique=True, sparse=True)
    await create_index_safely(db.ai_insights, "expires_at", expireAfterSeconds=0)
    await create_index_safely(db.ai_insights, [("email", 1), ("type", 1), ("is_current", 1)])
    await create_index_safely(db.ai_insights, [("type", 1), ("status", 1), ("progress_percentage", -1)])
    
    # Resumes
    await create_index_safely(db.resumes, "user_email")
    await create_index_safely(db.resumes, "created_at")
    await create_index_safely(db.resumes, "is_primary")
    
    # Backup records
    await create_index_safely(db.backup_records, "created_at")
    
    print("✅ All indexes created successfully")
    print("=" * 60)


async def verify_and_show_data(db):
    """Verify connection and show collection statistics"""
    print("\n📊 DATABASE VERIFICATION")
    print("=" * 60)
    
    try:
        stats = await db.command("dbStats")
        print(f"📁 Database Name: {settings.DATABASE_NAME}")
        print(f"📊 Total Collections: {stats.get('collections', 0)}")
        print(f"💾 Data Size: {stats.get('dataSize', 0) / (1024*1024):.2f} MB")
        print(f"📈 Index Size: {stats.get('indexSize', 0) / (1024*1024):.2f} MB")
        
        print("\n📋 COLLECTION DETAILS:")
        print("-" * 60)
        
        collections = await db.list_collection_names()
        for coll_name in sorted(collections):
            try:
                count = await db[coll_name].count_documents({})
                print(f"   📄 {coll_name}: {count:,} documents")
            except:
                print(f"   📄 {coll_name}: (error counting)")
        
        print("\n" + "=" * 60)
        print("✅ DATABASE VERIFICATION COMPLETE")
        print("=" * 60)
        
    except Exception as e:
        print(f"⚠️ Could not get database stats: {e}")


async def ensure_connection():
    """Ensure database connection is established"""
    global db, client
    if db is None:
        await connect_db()
    return db


def get_db():
    """Get database instance"""
    global db
    if db is None:
        import asyncio
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.create_task(connect_db())
            else:
                loop.run_until_complete(connect_db())
        except RuntimeError:
            import asyncio
            asyncio.run(connect_db())
    return db


async def close_db():
    """Close MongoDB connection"""
    global client
    if client:
        client.close()
        print("✅ MongoDB Connection Closed")


print("=" * 70)
print("✅ Database Connection Module Loaded with UNIFIED COLLECTIONS")
print("   ✅ Single 'applications' collection for ALL applications")
print("   ✅ application_type='job' for job applications")
print("   ✅ application_type='service' for service applications")
print("   ✅ No separate services table needed")
print("=" * 70)