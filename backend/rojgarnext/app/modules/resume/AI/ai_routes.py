# app/modules/resume/AI/ai_routes.py
"""
Resume AI Routes - Accessed via /api/v1/resume/ai/*
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from bson import ObjectId
import logging

from app.core.services.dependencies import get_current_user
from app.db.connection import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["Resume AI Services"])


@router.get("/score")
async def resume_score(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """AI-powered resume scoring"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        return {"resume_score": 0, "suggestions": ["Complete your profile first"]}
    
    score = 0
    suggestions = []
    
    if profile.get('full_name'):
        score += 10
    else:
        suggestions.append("Add your full name")
    
    if profile.get('summary'):
        score += 15
    else:
        suggestions.append("Add a professional summary")
    
    skills_count = len(profile.get('skills', []))
    if skills_count >= 10:
        score += 20
    elif skills_count >= 5:
        score += 15
        suggestions.append(f"Add {10 - skills_count} more skills")
    else:
        score += 5
        suggestions.append("Add at least 5-10 relevant skills")
    
    exp_count = len(profile.get('experience', []))
    if exp_count >= 3:
        score += 20
    elif exp_count >= 1:
        score += 10
        suggestions.append("Add more work experience details")
    else:
        suggestions.append("Add work experience or internships")
    
    edu_count = len(profile.get('academic_records', []))
    if edu_count >= 2:
        score += 15
    elif edu_count >= 1:
        score += 10
        suggestions.append("Add your educational qualifications")
    
    return {
        "resume_score": min(100, score),
        "rating": "Excellent" if score >= 80 else "Good" if score >= 60 else "Average" if score >= 40 else "Needs Improvement",
        "suggestions": suggestions[:10],
        "profile_completion": min(100, score)
    }