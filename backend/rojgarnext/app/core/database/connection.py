# app/db/connection.py - COMPLETE FIXED VERSION

from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config.settings import settings
import logging
import ssl
import asyncio

logger = logging.getLogger(__name__)

client = None
db = None


async def create_index_safely(collection, keys, **kwargs):
    """Create index safely - ignore if already exists or duplicate key errors"""
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
            logger.warning(f"   Error: {error_msg[:200]}")
            return False
        else:
            logger.warning(f"Index creation warning for {keys}: {e}")
            return False


async def drop_unused_collections():
    """Drop unused collections to reduce database size - BUT NEVER DROP AUTH, PROFILE, JOB, APPLICATIONS"""
    global db
    if db is None:
        return
    
    PROTECTED_COLLECTIONS = {
        "auth", "profile", "job", "applications", "payments",
        "resumes", "sessions", "notifications", "ai_insights",
        "reports", "security",
    }
    
    unused_collections = [
    #    "backup_records", "consent_logs", "anomalies",
     #   "blockchain_certificates", "chat_messages",
      #  "phonepe_payments", "razorpay_orders", "razorpay_failed_logs",
       # "shareable_resumes", "support_messages",
    ]
    
    dropped = []
    collections = await db.list_collection_names()
    
    for coll_name in unused_collections:
        try:
            if coll_name in collections:
                if coll_name not in PROTECTED_COLLECTIONS:
                    await db[coll_name].drop()
                    dropped.append(coll_name)
                    logger.info(f"🗑️ Dropped unused collection: {coll_name}")
                else:
                    logger.warning(f"⚠️ Skipped dropping protected collection: {coll_name}")
        except Exception as e:
            logger.debug(f"Could not drop {coll_name}: {e}")
    
    if dropped:
        logger.info(f"✅ Dropped {len(dropped)} unused collections")
    
    return dropped


async def connect_db():
    """Connect to MongoDB (supports both local and Atlas)"""
    global client, db
    
    try:
        mongo_uri = settings.SAFE_MONGO_URI
        
        print("=" * 60)
        print(f"🔗 Connecting to MongoDB...")
        print(f"   Environment: {settings.ENVIRONMENT}")
        print(f"   Database Type: {'LOCAL' if settings.IS_LOCAL_DB else 'ATLAS' if settings.IS_ATLAS_DB else 'UNKNOWN'}")
        print("=" * 60)
        
        # Get connection options
        options = settings.MONGO_OPTIONS.copy()
        
        # Add Atlas-specific SSL options
        if settings.IS_ATLAS_DB:
            options.update({
                "tls": True,
                "tlsAllowInvalidCertificates": True,
                "tlsAllowInvalidHostnames": True,
            })
        
        # Connection with retry logic
        max_retries = 3
        for attempt in range(max_retries):
            try:
                client = AsyncIOMotorClient(mongo_uri, **options)
                # Test connection with timeout
                await asyncio.wait_for(client.admin.command("ping"), timeout=10.0)
                print(f"✅ MongoDB ping successful! (attempt {attempt + 1})")
                break
            except asyncio.TimeoutError:
                print(f"⚠️ Attempt {attempt + 1} timed out")
                if attempt == max_retries - 1:
                    raise
                await asyncio.sleep(3)
            except Exception as e:
                print(f"⚠️ Attempt {attempt + 1} failed: {e}")
                if attempt == max_retries - 1:
                    raise
                await asyncio.sleep(3)
        
        db = client[settings.DATABASE_NAME]
        print(f"✅ Connected to database: {settings.DATABASE_NAME}")
        
        # Create collections if they don't exist
        collections = await db.list_collection_names()
        
        required_collections = [
            "auth", "profile", "job", "applications", "payments",
            "resumes", "sessions", "notifications", "ai_insights",
            "reports", "security"
        ]
        
        for coll_name in required_collections:
            if coll_name not in collections:
                await db.create_collection(coll_name)
                print(f"📁 Created collection: {coll_name}")
        
        await drop_unused_collections()
        await create_all_indexes(db)
        await verify_and_show_data(db)
        
        return True
        
    except Exception as e:
        print(f"❌ MongoDB Connection Error: {e}")
        print("\n📌 Troubleshooting:")
        print("   1. For LOCAL DB: Make sure MongoDB is running")
        print("      - Run: mongod")
        print("      - Or: sudo systemctl start mongod")
        print("   2. For ATLAS DB: Check username/password encoding")
        print("   3. Verify IP whitelist in MongoDB Atlas Network Access")
        print("   4. Check .env file for correct MONGO_URI")
        print("   5. Try: pip install --upgrade motor")
        raise


async def create_all_indexes(db):
    """Create all indexes for all collections"""
    print("\n📊 Creating database indexes...")
    
    # Auth indexes
    await create_index_safely(db.auth, "email", unique=True)
    await create_index_safely(db.auth, "mobile", unique=True, sparse=True)
    await create_index_safely(db.auth, "created_at")
    await create_index_safely(db.auth, "role")
    await create_index_safely(db.auth, "is_active")
    
    # Job indexes
    await create_index_safely(db.job, "status")
    await create_index_safely(db.job, "created_at")
    await create_index_safely(db.job, "organization")
    await create_index_safely(db.job, "job_type")
    await create_index_safely(db.job, "category")
    
    # Applications indexes
    await create_index_safely(db.applications, "job_id")
    await create_index_safely(db.applications, "applicant_email")
    await create_index_safely(db.applications, "status")
    await create_index_safely(db.applications, "match_score")
    await create_index_safely(db.applications, "applied_at")
    await create_index_safely(db.applications, "created_at")
    
    # Profile indexes
    await create_index_safely(db.profile, "email", unique=True)
    await create_index_safely(db.profile, "created_at")
    await create_index_safely(db.profile, "updated_at")
    
    # Payments indexes
    await create_index_safely(db.payments, "application_id")
    await create_index_safely(db.payments, "user_email")
    await create_index_safely(db.payments, "job_id")
    await create_index_safely(db.payments, "payment_status")
    await create_index_safely(db.payments, "verification_status")
    
    # Sessions indexes
    await create_index_safely(db.sessions, "user_id")
    await create_index_safely(db.sessions, "session_hash", unique=True, sparse=True)
    await create_index_safely(db.sessions, "created_at", expireAfterSeconds=604800)
    await create_index_safely(db.sessions, "expires_at", expireAfterSeconds=0)
    
    # Notifications indexes
    await create_index_safely(db.notifications, "user_id")
    await create_index_safely(db.notifications, "created_at")
    await create_index_safely(db.notifications, "created_at", expireAfterSeconds=2592000)
    
    # Security indexes
    await create_index_safely(db.security, "type")
    await create_index_safely(db.security, "ip_address")
    await create_index_safely(db.security, "created_at")
    
    # AI Insights indexes
    await create_index_safely(db.ai_insights, "email")
    await create_index_safely(db.ai_insights, "type")
    await create_index_safely(db.ai_insights, "is_current")
    
    print("✅ All indexes created successfully")
    print("=" * 60)


async def verify_and_show_data(db):
    """Verify connection and show collection statistics"""
    print("\n📊 DATABASE VERIFICATION")
    print("=" * 60)
    
    try:
        # Get database stats
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


print("✅ Database connection module loaded")