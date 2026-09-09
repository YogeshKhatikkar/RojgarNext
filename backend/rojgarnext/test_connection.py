import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

async def test_atlas():
    # ✅ Use SRV URI with SSL bypass
    uri = "mongodb+srv://rojgarnext_db:Rojgarnext123@cluster0.bmbx8bu.mongodb.net/rojgarnext?retryWrites=true&w=majority&tlsAllowInvalidCertificates=true"
    
    print("🔍 Testing Atlas connection with SSL bypass...")
    
    try:
        client = AsyncIOMotorClient(
            uri,
            serverSelectionTimeoutMS=30000,
            connectTimeoutMS=30000,
            tls=True,
            tlsAllowInvalidCertificates=True,
            tlsAllowInvalidHostnames=True,
        )
        
        await client.admin.command('ping')
        print("✅ Connection successful!")
        
        db = client["rojgarnext"]
        collections = await db.list_collection_names()
        print(f"📊 Collections: {collections}")
        
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        
        # Try without SSL
        print("\n🔄 Trying without SSL...")
        try:
            uri_no_ssl = "mongodb+srv://rojgarnext_db:Rojgarnext123@cluster0.bmbx8bu.mongodb.net/rojgarnext?retryWrites=true&w=majority&ssl=false"
            client = AsyncIOMotorClient(uri_no_ssl, serverSelectionTimeoutMS=30000)
            await client.admin.command('ping')
            print("✅ Connection successful without SSL!")
        except Exception as e2:
            print(f"❌ Also failed: {e2}")

if __name__ == "__main__":
    asyncio.run(test_atlas())
