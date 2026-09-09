# app/modules/services/service.py - UPDATED FOR UNIFIED APPLICATIONS
# ✅ Uses unified 'applications' collection with application_type='service'

from fastapi import HTTPException, BackgroundTasks
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from bson import ObjectId
import logging
import json
import base64
import secrets

from app.db.connection import get_db
from app.core.config.settings import settings
from app.core.utils.logger import logger
from app.models.unified_application_model import UnifiedApplicationModel, ApplicationType
from app.modules.services.schema import (
    ServiceApplicationCreateSchema,
    ServiceApplicationUpdateSchema,
    ServiceApplicationStatus,
    ServiceType,
    ServiceFeeSchema,
    ServiceApplicationConfirmSchema,
    ServiceApplicationUpdateSubmitSchema
)
from app.modules.notification.service import central_notification

module_logger = logging.getLogger(__name__)


class ServiceService:
    """Service Application Service - Uses Unified Applications Collection"""
    
    def __init__(self, db):
        self.db = db
        self.applications = db.applications  # ✅ Unified collection
        self.auth = db.auth
        self.profile = db.profile
        self.notifications = db.notifications
    
    async def _get_db(self):
        """Get database instance"""
        return self.db
    
    def _get_service_display_details(self, service_id: str, sub_type_id: str) -> Dict[str, str]:
        """Get display details for service"""
        service_names = {
            "pan": "PAN Card",
            "aadhar": "Aadhaar",
            "epf": "EPF / PF",
            "passport": "Passport",
            "driving_license": "Driving License",
            "voter_id": "Voter ID",
            "ration_card": "Ration Card",
            "income_certificate": "Income Certificate",
            "caste_certificate": "Caste Certificate",
            "domicile": "Domicile Certificate",
            "disability": "Disability Certificate",
            "bonafide": "Bonafide Certificate",
            "gap_certificate": "Gap Certificate",
        }
        
        service_icons = {
            "pan": "🪪",
            "aadhar": "🪪",
            "epf": "🏦",
            "passport": "🛂",
            "driving_license": "🚗",
            "voter_id": "🗳️",
            "ration_card": "🪪",
            "income_certificate": "💵",
            "caste_certificate": "📜",
            "domicile": "🏠",
            "disability": "♿",
            "bonafide": "📄",
            "gap_certificate": "⏳",
        }
        
        return {
            "service_name": service_names.get(service_id, service_id),
            "service_icon": service_icons.get(service_id, "📄"),
            "sub_service_name": sub_type_id.replace("_", " ").title(),
            "sub_service_description": "",
        }
    
    # ==================== CREATE APPLICATION ====================
    
    async def create_application(
        self,
        data: ServiceApplicationCreateSchema,
        user_email: str,
        user_name: str,
        user_id: str
    ) -> Dict[str, Any]:
        """Create a new service application - uses unified collection"""
        try:
            profile = await self.profile.find_one({"email": user_email})
            user_category = profile.get("category", "General/UR") if profile else "General/UR"
            
            disability = profile.get("disability", {}) if profile else {}
            is_disabled = disability.get("is_disabled", False) if isinstance(disability, dict) else False
            
            fee = await self._calculate_service_fee(
                service_type=data.service_type,
                sub_type_id=data.service_sub_type,
                user_category=user_category,
                is_disabled=is_disabled
            )
            
            # ✅ CREATE UNIFIED APPLICATION with application_type='service'
            application = UnifiedApplicationModel(
                application_type="service",
                user_email=user_email,
                user_name=user_name,
                user_id=user_id,
                user_category="service",
                is_disabled=is_disabled,
                service_id=data.service_type.value,
                sub_type_id=data.service_sub_type,
                service_name=data.service_name,
                sub_service_name=data.sub_service_name,
                fields=data.fields,
                documents=data.documents,
                status="payment_pending",
                payment_amount=fee,
                payment_category_used="service",
                payment_verification_status="not_submitted",
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            
            # ✅ Insert into unified applications collection
            result = await self.applications.insert_one(application.to_dict())
            application_id = str(result.inserted_id)
            
            qr_response = None
            if fee > 0:
                qr_response = await self._generate_payment_qr(
                    application_id=application_id,
                    user_email=user_email,
                    amount=fee,
                    service_type=data.service_type.value,
                    sub_type_id=data.service_sub_type,
                    form_data=data.fields,
                    documents=data.documents
                )
                
                await self.applications.update_one(
                    {"_id": ObjectId(application_id)},
                    {
                        "$set": {
                            "payment_id": qr_response["payment_id"],
                            "qr_code_data": qr_response["qr_code_data"],
                            "qr_image_url": qr_response["qr_image_url"],
                            "upi_text": qr_response.get("upi_text"),
                            "order_id": qr_response.get("order_id"),
                            "expires_at": qr_response.get("expires_at"),
                            "status": "payment_pending",
                            "updated_at": datetime.utcnow()
                        }
                    }
                )
            
            return {
                "success": True,
                "application_id": application_id,
                "application_type": "service",
                "amount": fee,
                "needs_payment": fee > 0,
                "payment_id": qr_response.get("payment_id") if qr_response else None,
                "qr_code_data": qr_response.get("qr_code_data") if qr_response else None,
                "qr_image_url": qr_response.get("qr_image_url") if qr_response else None,
                "expires_at": qr_response.get("expires_at") if qr_response else None,
                "status": "payment_pending",
                "message": "Application created. Complete payment to submit."
            }
            
        except Exception as e:
            module_logger.error(f"Failed to create service application: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create application: {str(e)}")

    # ==================== SUBMIT VERIFICATION ====================
    
    async def submit_verification(
        self,
        application_id: str,
        transaction_id: str,
        transaction_date: str,
        screenshot_url: str,
        screenshot_public_id: str,
        user_email: str
    ) -> Dict[str, Any]:
        """Submit verification - Application becomes active"""
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")
        
        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        if application.get("user_email") != user_email:
            raise HTTPException(status_code=403, detail="Unauthorized")
        
        if application.get("payment_verification_status") == "pending":
            raise HTTPException(status_code=400, detail="Verification already submitted")
        
        # ✅ Update unified application
        update_data = {
            "transaction_id": transaction_id.strip(),
            "transaction_date": datetime.fromisoformat(transaction_date),
            "payment_receipt_url": screenshot_url,
            "payment_receipt_public_id": screenshot_public_id,
            "payment_verification_status": "pending",
            "status": "pending_verification",
            "updated_at": datetime.utcnow()
        }
        
        await self.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )
        
        # Send notifications
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title="⏳ Service Application Pending Verification",
            message=f"Your service application '{application.get('sub_service_name')}' is pending verification.",
            related_id=application_id,
            metadata={
                "service_name": application.get("service_name"),
                "sub_service_name": application.get("sub_service_name"),
                "amount": application.get("payment_amount"),
                "application_type": "service",
                "status": "pending_verification"
            },
            send_email=True,
            send_websocket=True
        )
        
        await self._notify_admins(
            application_id=application_id,
            service_name=application.get("service_name"),
            sub_service_name=application.get("sub_service_name"),
            user_email=user_email,
            user_name=application.get("user_name"),
            amount=application.get("payment_amount"),
            transaction_id=transaction_id,
            action="verify"
        )
        
        return {
            "success": True,
            "message": "Verification submitted. Application pending admin approval.",
            "application_id": application_id,
            "application_type": "service",
            "status": "pending_verification"
        }

    # ==================== VERIFY PAYMENT ====================
    
    async def verify_payment(
        self,
        application_id: str,
        action: str,
        admin_email: str,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """Verify payment for a service application - updates unified collection"""
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")
        
        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        current_status = application.get("status")
        if current_status in ["approved", "rejected", "completed"]:
            return {
                "success": False,
                "message": f"Application already {current_status}",
                "application_id": application_id
            }
        
        user_email = application.get("user_email")
        service_name = application.get("service_name")
        sub_service_name = application.get("sub_service_name")
        amount = application.get("payment_amount", 0)
        transaction_id = application.get("transaction_id")
        
        if action == "approve":
            # ✅ Update unified application
            update_data = {
                "status": "approved",
                "payment_verification_status": "approved",
                "payment_verified_by": admin_email,
                "payment_verified_at": datetime.utcnow(),
                "paid_at": datetime.utcnow(),
                "payment_verification_notes": notes or "Payment approved",
                "updated_at": datetime.utcnow()
            }
            
            await self.applications.update_one(
                {"_id": ObjectId(application_id)},
                {"$set": update_data}
            )
            
            # Notify user
            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title="✅ Payment Verified Successfully!",
                message=f"Your payment of ₹{amount} for '{sub_service_name}' has been verified successfully.",
                related_id=application_id,
                metadata={
                    "status": "approved",
                    "amount": amount,
                    "service_name": service_name,
                    "sub_service_name": sub_service_name,
                    "application_type": "service"
                },
                send_email=True,
                send_websocket=True
            )
            
            module_logger.info(f"✅ Payment approved for {application_id} by {admin_email}")
            
            return {
                "success": True,
                "message": "Payment approved successfully",
                "application_id": application_id,
                "application_type": "service",
                "status": "approved"
            }
            
        else:  # reject
            if not notes:
                notes = "Payment rejected by admin - Please contact support"
            
            update_data = {
                "status": "rejected",
                "payment_verification_status": "rejected",
                "payment_verified_by": admin_email,
                "payment_verified_at": datetime.utcnow(),
                "payment_rejection_reason": notes,
                "payment_verification_notes": notes,
                "updated_at": datetime.utcnow()
            }
            
            await self.applications.update_one(
                {"_id": ObjectId(application_id)},
                {"$set": update_data}
            )
            
            # Notify user
            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title="❌ Payment Verification Failed",
                message=f"Your payment of ₹{amount} for '{sub_service_name}' has been REJECTED.\nReason: {notes}",
                related_id=application_id,
                metadata={
                    "status": "rejected",
                    "amount": amount,
                    "service_name": service_name,
                    "sub_service_name": sub_service_name,
                    "application_type": "service",
                    "rejection_reason": notes
                },
                send_email=True,
                send_websocket=True
            )
            
            module_logger.info(f"❌ Payment rejected for {application_id} by {admin_email}")
            
            return {
                "success": True,
                "message": f"Payment rejected. Reason: {notes}",
                "application_id": application_id,
                "application_type": "service",
                "status": "rejected"
            }

    # ==================== GET USER APPLICATIONS ====================
    
    async def get_user_applications(self, user_email: str) -> List[Dict[str, Any]]:
        """Get all service applications for a user"""
        try:
            applications = await self.applications.find({
                "user_email": user_email,
                "application_type": "service"  # ✅ Only service applications
            }).sort("created_at", -1).to_list(100)
            
            for app in applications:
                app["_id"] = str(app["_id"])
                if app.get("payment_id"):
                    app["payment_id"] = str(app["payment_id"])
                
                if "status" not in app:
                    app["status"] = "payment_pending"
                
                # Ensure document fields
                app["submitted_document_url"] = app.get("submitted_document_url")
                app["submitted_document_name"] = app.get("submitted_document_name")
                app["final_document_url"] = app.get("final_document_url")
                
                service_id = app.get("service_id", "")
                sub_type_id = app.get("sub_type_id", "")
                details = self._get_service_display_details(service_id, sub_type_id)
                app["display_service_name"] = details.get("service_name", service_id)
                app["display_service_icon"] = details.get("service_icon", "📄")
                app["display_sub_service_name"] = details.get("sub_service_name", sub_type_id)
                
                app["application_type"] = "service"
            
            return applications
        except Exception as e:
            module_logger.error(f"Failed to get user applications: {e}")
            return []

    # ==================== GET ALL APPLICATIONS (ADMIN) ====================
    
    async def get_all_applications(
        self,
        admin_email: str,
        status: Optional[str] = None,
        limit: int = 100,
        skip: int = 0
    ) -> Dict[str, Any]:
        """Get all service applications (ADMIN ONLY)"""
        try:
            user = await self.auth.find_one({"email": admin_email})
            if user.get("role") not in ["admin", "customadmin", "superadmin"]:
                raise HTTPException(status_code=403, detail="Access denied")
            
            query = {"application_type": "service"}  # ✅ Only service applications
            if status:
                query["status"] = status
            
            applications = await self.applications.find(query).sort("created_at", -1).skip(skip).limit(limit).to_list(limit)
            
            for app in applications:
                app["_id"] = str(app["_id"])
                if "status" not in app:
                    app["status"] = "payment_pending"
                
                app["submitted_document_url"] = app.get("submitted_document_url")
                app["submitted_document_name"] = app.get("submitted_document_name")
                app["final_document_url"] = app.get("final_document_url")
                
                service_id = app.get("service_id", "")
                sub_type_id = app.get("sub_type_id", "")
                details = self._get_service_display_details(service_id, sub_type_id)
                app["display_service_name"] = details.get("service_name", service_id)
                app["display_service_icon"] = details.get("service_icon", "📄")
                app["display_sub_service_name"] = details.get("sub_service_name", sub_type_id)
                
                app["application_type"] = "service"
            
            total = await self.applications.count_documents(query)
            
            return {
                "applications": applications,
                "total": total,
                "skip": skip,
                "limit": limit
            }
        except Exception as e:
            module_logger.error(f"Failed to get all applications: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    # ==================== GET APPLICATION DETAIL ====================
    
    async def get_application_detail(self, application_id: str, user_email: str) -> Dict[str, Any]:
        """Get detailed service application"""
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")
        
        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        is_owner = application.get("user_email") == user_email
        if not is_owner:
            user = await self.auth.find_one({"email": user_email})
            if user.get("role") not in ["admin", "customadmin", "superadmin"]:
                raise HTTPException(status_code=403, detail="Access denied")
        
        application["_id"] = str(application["_id"])
        if "status" not in application:
            application["status"] = "payment_pending"
        
        application["submitted_document_url"] = application.get("submitted_document_url")
        application["submitted_document_name"] = application.get("submitted_document_name")
        application["final_document_url"] = application.get("final_document_url")
        
        service_id = application.get("service_id", "")
        sub_type_id = application.get("sub_type_id", "")
        details = self._get_service_display_details(service_id, sub_type_id)
        application["display_service_name"] = details.get("service_name", service_id)
        application["display_service_icon"] = details.get("service_icon", "📄")
        application["display_sub_service_name"] = details.get("sub_service_name", sub_type_id)
        
        application["application_type"] = "service"
        
        return application

    # ==================== UPDATE APPLICATION STATUS ====================
    
    async def update_application_status(
        self,
        application_id: str,
        status: str,
        admin_email: str,
        admin_notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """Update service application status - uses unified collection"""
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")
        
        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        old_status = application.get("status")
        
        update_data = {
            "status": status,
            "admin_notes": admin_notes,
            "updated_at": datetime.utcnow(),
            "last_updated_by": admin_email
        }
        
        result = await self.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Application not found or status unchanged")
        
        # Send notification
        user_email = application.get("user_email")
        if user_email:
            status_messages = {
                "payment_verified": "✅ Your payment has been verified.",
                "under_review": "📋 Your application is under review.",
                "review_application": "📋 Your application is under review. Please take action.",
                "approved": "🎉 Congratulations! Your application has been approved.",
                "rejected": "📝 Your application has been rejected.",
                "completed": "✅ Your application has been completed successfully.",
                "confirmed_application": "✅ Your application has been confirmed successfully!",
                "update_application": "📝 Your application update has been submitted for admin review.",
            }
            
            service_name = application.get("service_name", "Service")
            
            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title=f"Service Application Status: {status.upper()}",
                message=status_messages.get(
                    status,
                    f"Your application status has been updated to {status}."
                ),
                related_id=application_id,
                metadata={
                    "application_id": application_id,
                    "service_name": service_name,
                    "old_status": old_status,
                    "new_status": status,
                    "application_type": "service",
                    "admin_notes": admin_notes,
                    "admin_email": admin_email,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
        
        return {
            "success": True,
            "message": f"Application status updated to {status}",
            "application_id": application_id,
            "application_type": "service",
            "old_status": old_status,
            "new_status": status,
            "updated_by": admin_email
        }

    # ==================== USER CONFIRM APPLICATION ====================
    
    async def user_confirm_application(
        self,
        application_id: str,
        user_email: str,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """USER: Confirm their application"""
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")
        
        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        if application.get("user_email") != user_email:
            raise HTTPException(status_code=403, detail="Unauthorized")
        
        current_status = application.get("status", "")
        if current_status not in ["review_application", "under_review"]:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot confirm application in '{current_status}' status."
            )
        
        update_data = {
            "status": "confirmed_application",
            "confirmed_at": datetime.utcnow(),
            "confirmed_by": user_email,
            "updated_at": datetime.utcnow()
        }
        
        if notes:
            update_data["confirmation_notes"] = notes
        
        result = await self.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Application not found")
        
        service_name = application.get("service_name", "Service")
        
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title="✅ Application Confirmed!",
            message=f"Your service application for '{service_name}' has been confirmed successfully.",
            related_id=application_id,
            metadata={
                "status": "confirmed_application",
                "service_name": service_name,
                "application_id": application_id,
                "application_type": "service",
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        
        return {
            "success": True,
            "message": "Application confirmed successfully",
            "application_id": application_id,
            "application_type": "service",
            "status": "confirmed_application"
        }

    # ==================== INTERNAL HELPERS ====================
    
    async def _calculate_service_fee(
        self,
        service_type: ServiceType,
        sub_type_id: str,
        user_category: str,
        is_disabled: bool
    ) -> int:
        """Calculate service fee"""
        base_fees = {
            ServiceType.PAN: 100,
            ServiceType.AADHAAR: 50,
            ServiceType.EPF: 150,
            ServiceType.PASSPORT: 200,
            ServiceType.DRIVING_LICENSE: 150,
            ServiceType.VOTER_ID: 50,
            ServiceType.RATION_CARD: 75,
            ServiceType.INCOME_CERTIFICATE: 100,
            ServiceType.CASTE_CERTIFICATE: 100,
            ServiceType.DOMICILE: 80,
            ServiceType.DISABILITY: 50,
            ServiceType.BONAFIDE: 75,
            ServiceType.GAP_CERTIFICATE: 80,
        }
        
        base_fee = base_fees.get(service_type, 100)
        
        if is_disabled:
            return max(10, int(base_fee * 0.5))
        
        return base_fee
    
    async def _generate_payment_qr(
        self,
        application_id: str,
        user_email: str,
        amount: int,
        service_type: str,
        sub_type_id: str,
        form_data: Dict = None,
        documents: Dict = None
    ) -> Dict[str, Any]:
        """Generate payment QR code"""
        from app.modules.payment.routes import generate_qr_code_html
        
        payment_id = str(ObjectId())
        order_id = f"SVC{payment_id[-8:]}{int(datetime.utcnow().timestamp())}"
        
        upi_id = getattr(settings, 'UPI_ID', 'your-upi-id@okhdfcbank')
        upi_text = f"upi://pay?pa={upi_id}&pn=RojgarNext&am={amount}&cu=INR&tn={order_id}&tid={order_id}"
        qr_image_url = generate_qr_code_html(upi_text, amount, order_id)
        
        qr_data = {
            "type": "upi_qr",
            "upi_text": upi_text,
            "qr_image_url": qr_image_url,
            "amount": amount,
            "order_id": order_id,
            "service_type": service_type,
            "sub_type": sub_type_id,
            "expires_in_minutes": 30
        }
        
        qr_code_data = base64.b64encode(json.dumps(qr_data).encode()).decode()
        
        return {
            "payment_id": payment_id,
            "qr_code_data": qr_code_data,
            "qr_image_url": qr_image_url,
            "amount": amount,
            "order_id": order_id,
            "expires_at": datetime.utcnow() + timedelta(minutes=30)
        }
    
    async def _notify_admins(
        self,
        application_id: str,
        service_name: str,
        sub_service_name: str,
        user_email: str,
        user_name: str,
        amount: int,
        transaction_id: Optional[str] = None,
        action: str = "new",
        update_count: int = 0
    ):
        """Notify admins about service application"""
        try:
            admins = await self.auth.find({
                "role": {"$in": ["admin", "customadmin", "superadmin"]},
                "is_active": True
            }).to_list(100)
            
            admin_emails = [admin.get("email") for admin in admins if admin.get("email")]
            
            if admin_emails:
                if action == "new":
                    title = f"📋 New Service Application: {service_name}"
                    message = f"{user_name} ({user_email}) has applied for {sub_service_name} service.\nAmount: ₹{amount}"
                elif action == "confirm":
                    title = f"✅ Application Confirmed: {service_name}"
                    message = f"{user_name} ({user_email}) has confirmed their application for {sub_service_name}."
                elif action == "update":
                    title = f"📝 Application Update: {service_name}"
                    message = f"{user_name} ({user_email}) has submitted an update for {sub_service_name} service.\nUpdates: {update_count} fields"
                else:
                    title = f"💰 Payment Verification: {service_name}"
                    message = f"{user_name} ({user_email}) has submitted payment verification for {sub_service_name}.\nTransaction ID: {transaction_id}\nAmount: ₹{amount}"
                
                await central_notification.send_notification(
                    user_ids=admin_emails,
                    notification_type="admin_alert",
                    title=title,
                    message=message,
                    metadata={
                        "application_id": application_id,
                        "service_name": service_name,
                        "sub_service_name": sub_service_name,
                        "user_email": user_email,
                        "user_name": user_name,
                        "amount": amount,
                        "application_type": "service",
                        "status": "pending_verification" if action == "verify" else "pending",
                        "transaction_id": transaction_id,
                        "show_blue_bell": True
                    },
                    send_email=True,
                    send_websocket=True
                )
        except Exception as e:
            module_logger.error(f"Failed to notify admins: {e}")


print("=" * 70)
print("✅ Service Service Updated - Uses Unified Applications Collection")
print("   ✅ application_type='service' for all service applications")
print("   ✅ All data stored in unified 'applications' collection")
print("=" * 70)