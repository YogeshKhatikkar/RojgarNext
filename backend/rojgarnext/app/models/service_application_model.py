# app/models/service_application_model.py
"""
Service Application Model - For storing service applications
✅ USES 'services' collection
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional, Dict, Any, List
from datetime import datetime
from enum import Enum


class ServiceApplicationStatus(str, Enum):
    PAYMENT_PENDING = "payment_pending"
    PENDING_VERIFICATION = "pending_verification"
    UNDER_REVIEW = "under_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    COMPLETED = "completed"
    REPLACED = "replaced"


class ServiceApplicationModel(BaseModel):
    """Service Application Model - Saved in 'services' collection"""
    
    # Service details
    service_id: str
    sub_type_id: str
    service_name: str
    sub_service_name: str
    application_type: str = "online_service"
    
    # User details
    user_email: EmailStr
    user_name: str
    user_id: str
    user_category: Optional[str] = "service"  # ✅ FIXED: Always "service" for service apps
    is_disabled: bool = False
    
    # Form data
    fields: Dict[str, Any] = Field(default_factory=dict)
    documents: Dict[str, str] = Field(default_factory=dict)
    
    # Status
    status: ServiceApplicationStatus = ServiceApplicationStatus.PAYMENT_PENDING
    payment_verification_status: str = "not_submitted"
    
    # Payment details
    payment_id: Optional[str] = None
    transaction_id: Optional[str] = None
    transaction_date: Optional[datetime] = None
    payment_receipt_url: Optional[str] = None
    payment_receipt_public_id: Optional[str] = None
    payment_amount: Optional[int] = None
    payment_category_used: Optional[str] = "service"  # ✅ FIXED: Always "service"
    qr_code_data: Optional[str] = None

    payment_verified_by: Optional[str] = None
    payment_verified_at: Optional[datetime] = None
    payment_rejection_reason: Optional[str] = None
        # Razorpay fields
    razorpay_order_id: Optional[str] = None
    razorpay_payment_id: Optional[str] = None
    razorpay_signature: Optional[str] = None
    
    # Admin fields
    admin_notes: Optional[str] = None
    
    
    # Timestamps
    applied_at: datetime = Field(default_factory=datetime.utcnow)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    
    # Re-application tracking
    previous_application_id: Optional[str] = None
    previous_status: Optional[str] = None
    replaced_at: Optional[datetime] = None
    
    class Config:
        collection = "services"  # ✅ FIXED: Uses 'services' collection
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            ServiceApplicationStatus: lambda v: v.value
        }
        arbitrary_types_allowed = True


# ==================== CREATE COLLECTION ON STARTUP ====================

async def ensure_services_collection(db):
    """Ensure services collection exists"""
    collections = await db.list_collection_names()
    if "services" not in collections:
        await db.create_collection("services")
        print("✅ Created services collection")
    
    # Create indexes
    await db.services.create_index("user_email")
    await db.services.create_index("service_id")
    await db.services.create_index("sub_type_id")
    await db.services.create_index("status")
    await db.services.create_index("payment_id")
    await db.services.create_index("created_at")
    await db.services.create_index([("user_email", 1), ("service_id", 1), ("sub_type_id", 1)])
    
    print("✅ Services indexes created")
    return True