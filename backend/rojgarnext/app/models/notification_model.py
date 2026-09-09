# app/models/notification_model.py
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, Literal

class NotificationModel(BaseModel):
    user_id: Optional[str] = None                    # str(ObjectId) of user (None = broadcast future)
    type: Literal["new_job", "application_update", "system", "otp"] = "new_job"
    title: str
    message: str
    related_id: Optional[str] = None                 # job_id / application_id
    read: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)

    model_config = {
        "collection": "notifications",
        "arbitrary_types_allowed": True,
        "json_encoders": {
            datetime: lambda v: v.isoformat()
        }
    }