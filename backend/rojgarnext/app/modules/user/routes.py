# app/modules/user/routes.py - COMPLETE FIXED VERSION WITH MIME TYPE CHECKING

from fastapi import APIRouter, Depends, HTTPException, Query, Body, BackgroundTasks, UploadFile, File, Form
from typing import Optional, List, Dict, Any
from bson import ObjectId
from datetime import datetime
import logging
from app.db.connection import get_db
from app.modules.user.service import ProfileService
from app.core.services.dependencies import get_current_user, role_required
from app.core.ai.ultra_ai_engine import ultra_ai_engine
from app.modules.user.AI.ai_routes import router as user_ai_router
from app.core.utils.logger import logger

router = APIRouter()

router.include_router(user_ai_router)

print("✅ User routes loaded with Ultra AI features")

# ================= SERVICE DEPENDENCY =================
async def get_profile_service(db=Depends(get_db)):
    return ProfileService(db)


# ================= CONTACT DETAILS =================
@router.get("/contact-details")
async def get_contact_details(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get user's email and mobile (read-only from login)"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    user = await db.auth.find_one({"email": email})
    mobile = user.get("mobile", "") if user else ""
    name = user.get("name", "") if user else ""
    
    return {
        "email": email,
        "mobile": mobile,
        "name": name
    }


# ================= FULL PROFILE =================
@router.get("/full-profile")
async def get_full_profile(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get complete user profile with all fields"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_full_profile(email)


@router.post("/full-profile")
async def create_or_update_full_profile(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Create or update full profile with all fields"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    data["email"] = email
    return await service.create_or_update_full_profile(data)


# ================= BASIC DETAILS =================
@router.get("/basic-details")
async def get_basic_details(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get basic profile information"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_basic_details(email)


@router.post("/basic-details")
async def save_basic_details(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Save basic profile information"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.save_basic_details(email, data)


# ================= BANK DETAILS =================
@router.get("/bank-details")
async def get_bank_details(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's bank details"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_bank_details(email)


@router.post("/bank-details")
async def update_bank_details(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update bank details"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_bank_details(email, data)


# ================= GOVERNMENT IDs =================
@router.get("/government-ids")
async def get_government_ids(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's government IDs"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_government_ids(email)


@router.post("/government-ids")
async def update_government_ids(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update government IDs"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_government_ids(email, data)


# ================= EMERGENCY CONTACT =================
@router.get("/emergency-contact")
async def get_emergency_contact(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's emergency contact"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_emergency_contact(email)


@router.post("/emergency-contact")
async def update_emergency_contact(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update emergency contact"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_emergency_contact(email, data)


# ================= REFERENCES =================
@router.get("/references")
async def get_references(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's references"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_references(email)


@router.post("/references")
async def add_reference(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Add a new reference"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_reference(email, data)


@router.put("/references/{ref_id}")
async def update_reference(
    ref_id: str,
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update a reference"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_reference(email, ref_id, data)


@router.delete("/references/{ref_id}")
async def delete_reference(
    ref_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Delete a reference"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_reference(email, ref_id)


# ================= EMPLOYMENT PREFERENCES =================
@router.get("/employment-preferences")
async def get_employment_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's employment preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_employment_preferences(email)


@router.post("/employment-preferences")
async def update_employment_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update employment preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_employment_preferences(email, data)


# ================= SOCIAL LINKS =================
@router.get("/social-links")
async def get_social_links(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's social links"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_social_links(email)


@router.post("/social-links")
async def update_social_links(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update social links"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_social_links(email, data)


# ================= WORK AUTHORIZATION =================
@router.get("/work-authorization")
async def get_work_authorization(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's work authorization"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_work_authorization(email)


@router.post("/work-authorization")
async def update_work_authorization(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update work authorization"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_work_authorization(email, data)


# ================= APPLICATION PREFERENCES =================
@router.get("/application-preferences")
async def get_application_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's application preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_application_preferences(email)


@router.post("/application-preferences")
async def update_application_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update application preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_application_preferences(email, data)


# ================= CAREER GOALS =================
@router.get("/career-goals")
async def get_career_goals(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's career goals"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_career_goals(email)


@router.post("/career-goals")
async def update_career_goals(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update career goals"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_career_goals(email, data)


# ================= PERSONALITY TRAITS =================
@router.get("/personality-traits")
async def get_personality_traits(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's personality traits"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_personality_traits(email)


@router.post("/personality-traits")
async def update_personality_traits(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update personality traits"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_personality_traits(email, data)


# ================= WORK ENVIRONMENT PREFERENCES =================
@router.get("/work-environment-preferences")
async def get_work_environment_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's work environment preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_work_environment_preferences(email)


@router.post("/work-environment-preferences")
async def update_work_environment_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update work environment preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_work_environment_preferences(email, data)


# ================= COMPENSATION EXPECTATIONS =================
@router.get("/compensation-expectations")
async def get_compensation_expectations(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's compensation expectations"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_compensation_expectations(email)


@router.post("/compensation-expectations")
async def update_compensation_expectations(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update compensation expectations"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_compensation_expectations(email, data)


# ================= JOB SEARCH PREFERENCES =================
@router.get("/job-search-preferences")
async def get_job_search_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's job search preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_job_search_preferences(email)


@router.post("/job-search-preferences")
async def update_job_search_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update job search preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_job_search_preferences(email, data)


# ================= SKILL ASSESSMENTS =================
@router.get("/skill-assessments")
async def get_skill_assessments(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's skill assessments"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_skill_assessments(email)


@router.post("/skill-assessments")
async def add_skill_assessment(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Add a skill assessment"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_skill_assessment(email, data)


@router.put("/skill-assessments/{assessment_id}")
async def update_skill_assessment(
    assessment_id: str,
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update a skill assessment"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_skill_assessment(email, assessment_id, data)


@router.delete("/skill-assessments/{assessment_id}")
async def delete_skill_assessment(
    assessment_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Delete a skill assessment"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_skill_assessment(email, assessment_id)


# ================= JOB SEARCH STATUS =================
@router.get("/job-search-status")
async def get_job_search_status(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's job search status"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_job_search_status(email)


@router.post("/job-search-status")
async def update_job_search_status(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update job search status"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_job_search_status(email, data)


# ================= CAREER CHANGE INFO =================
@router.get("/career-change-info")
async def get_career_change_info(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's career change information"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_career_change_info(email)


@router.post("/career-change-info")
async def update_career_change_info(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update career change information"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_career_change_info(email, data)


# ================= EDUCATION =================
@router.get("/education")
async def get_education(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get all education records"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_education(email)


@router.post("/education")
async def add_education(
    qualification: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Add a new education record"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_education(email, qualification)


@router.put("/education/{qual_id}")
async def update_education(
    qual_id: str,
    qualification: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update an existing education record"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_education(email, qual_id, qualification)


# ================= EXPERIENCE =================
@router.get("/experience")
async def get_experience(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get all experience records"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_experience(email)


@router.post("/experience")
async def add_experience(
    experience: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Add a new experience record"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_experience(email, experience)


@router.put("/experience/{exp_id}")
async def update_experience(
    exp_id: str,
    experience: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update an existing experience record"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_experience(email, exp_id, experience)


# ================= SKILLS =================
@router.get("/skills")
async def get_skills(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get all skills"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_skills(email)


@router.post("/skills")
async def add_skill(
    skill: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Add a new skill"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_skill(email, skill)


@router.put("/skills/{skill_id}")
async def update_skill(
    skill_id: str,
    skill: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update an existing skill"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_skill(email, skill_id, skill)


@router.delete("/skills/{skill_id}")
async def delete_skill(
    skill_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Delete a skill"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_skill(email, skill_id)


# ================= INTERNSHIPS =================
@router.get("/internships")
async def get_internships(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get all internships"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_internships(email)


@router.post("/internships")
async def add_internship(
    internship: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Add a new internship"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_internship(email, internship)


@router.put("/internships/{internship_id}")
async def update_internship(
    internship_id: str,
    internship: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update an existing internship"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_internship(email, internship_id, internship)


@router.delete("/internships/{internship_id}")
async def delete_internship(
    internship_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Delete an internship"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_internship(email, internship_id)


# ================= CERTIFICATIONS =================
@router.get("/certifications")
async def get_certifications(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get all certifications"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_certifications(email)


@router.post("/certifications")
async def add_certification(
    certification: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Add a new certification"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_certification(email, certification)


@router.put("/certifications/{cert_id}")
async def update_certification(
    cert_id: str,
    certification: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update an existing certification"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_certification(email, cert_id, certification)


@router.delete("/certifications/{cert_id}")
async def delete_certification(
    cert_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Delete a certification"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_certification(email, cert_id)


# ================= PROJECTS =================
@router.get("/projects")
async def get_projects(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get all projects"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_projects(email)


@router.post("/projects")
async def add_project(
    project: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Add a new project"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_project(email, project)


@router.put("/projects/{project_id}")
async def update_project(
    project_id: str,
    project: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update an existing project"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_project(email, project_id, project)


@router.delete("/projects/{project_id}")
async def delete_project(
    project_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Delete a project"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_project(email, project_id)


# ================= LANGUAGES =================
@router.get("/languages")
async def get_languages(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get all languages"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_languages(email)


@router.post("/languages")
async def add_language(
    language: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Add a new language"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_language(email, language)


@router.put("/languages/{lang_id}")
async def update_language(
    lang_id: str,
    language: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update an existing language"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_language(email, lang_id, language)


@router.delete("/languages/{lang_id}")
async def delete_language(
    lang_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Delete a language"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_language(email, lang_id)


# ================= OTHER DETAILS =================
@router.get("/other-details")
async def get_other_details(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get additional details"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_other_details(email)


@router.put("/other-details")
async def update_other_details(
    details: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update additional details"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_other_details(email, details)


# ================= PROFILE + APPLICATIONS =================
@router.get("/profile-with-applications")
async def get_profile_with_applications(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get profile with all applications"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_profile_with_applications(email)


# ================= EDUCATED STATUS =================
@router.post("/educated-status")
async def update_educated_status(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update educated status and related fields"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_educated_status(email, data)


# ================= FRESHER STATUS =================
@router.post("/fresher-status")
async def update_fresher_status(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update fresher status and related fields"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_fresher_status(email, data)


# ================= SAVED JOBS =================
@router.get("/saved-jobs")
async def get_saved_jobs(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get user's saved jobs"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    user = await db.auth.find_one({"email": email})
    saved_job_ids = user.get("saved_jobs", []) if user else []
    
    jobs = []
    for job_id in saved_job_ids:
        try:
            if isinstance(job_id, str) and len(job_id) == 24:
                obj_id = ObjectId(job_id)
            else:
                obj_id = job_id
            
            job = await db.job.find_one({"_id": obj_id})
            if job:
                job["_id"] = str(job["_id"])
                jobs.append(job)
        except Exception:
            continue
    
    return {"saved_jobs": jobs}


@router.post("/saved-jobs")
async def save_job(
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Save a job"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    job_id = data.get("job_id")
    if not job_id:
        raise HTTPException(status_code=400, detail="Job ID required")
    
    try:
        obj_id = ObjectId(job_id) if isinstance(job_id, str) and len(job_id) == 24 else job_id
        job_exists = await db.job.find_one({"_id": obj_id})
        if not job_exists:
            raise HTTPException(status_code=404, detail="Job not found")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    await db.auth.update_one(
        {"email": email},
        {"$addToSet": {"saved_jobs": job_id}}
    )
    
    return {"message": "Job saved successfully", "success": True}


@router.delete("/saved-jobs/{job_id}")
async def unsave_job(
    job_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Remove saved job"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    await db.auth.update_one(
        {"email": email},
        {"$pull": {"saved_jobs": job_id}}
    )
    
    return {"message": "Job removed from saved", "success": True}


# ================= AI POWERED ENDPOINTS =================
@router.get("/ai/insights")
async def get_ai_insights(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get AI career insights for user dashboard"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_ai_insights(email)


@router.get("/ai/recommendations")
async def get_ai_recommendations(
    limit: int = Query(10, ge=1, le=20),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get AI job recommendations"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_ai_recommendations(email, limit)


@router.get("/ai/skill-gap")
async def get_ai_skill_gap(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get AI skill gap analysis"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_ai_skill_gap(email)


@router.post("/ai/refresh")
async def refresh_ai_insights(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Force refresh AI insights (clear cache)"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.refresh_ai_insights(email)


# ================= ULTRA AI ENDPOINTS =================
@router.get("/ai/ultra-analysis")
async def get_ultra_ai_analysis(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get ultra-advanced AI analysis with predictions"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    jobs = await db.job.find({"status": "open"}).limit(50).to_list(50)
    
    career_analysis = await ultra_ai_engine._deep_candidate_analysis(profile, {})
    job_matches = await ultra_ai_engine.auto_job_matching(profile, jobs)
    predictions = await ultra_ai_engine.predictive_analytics(30)
    
    return {
        "career_analysis": career_analysis,
        "top_job_matches": job_matches[:5],
        "market_predictions": predictions,
        "recommended_actions": await _generate_personalized_actions(profile, career_analysis)
    }


@router.get("/ai/resume-score")
async def get_ai_resume_score(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get AI-powered resume score and improvement suggestions"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
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
        suggestions.append(f"Add {10 - skills_count} more skills to reach optimal count")
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
    
    project_count = len(profile.get('projects', []))
    if project_count >= 3:
        score += 10
    elif project_count >= 1:
        score += 5
        suggestions.append("Add more projects to showcase your work")
    
    cert_count = len(profile.get('certifications', []))
    if cert_count >= 2:
        score += 10
    elif cert_count >= 1:
        score += 5
        suggestions.append("Add relevant certifications")
    
    return {
        "resume_score": min(100, score),
        "rating": "Excellent" if score >= 80 else "Good" if score >= 60 else "Average" if score >= 40 else "Needs Improvement",
        "suggestions": suggestions[:10],
        "profile_completion_percentage": min(100, score),
        "next_actions": suggestions[:5]
    }


# ================= HELPER FUNCTIONS =================
async def _generate_personalized_actions(profile: Dict, analysis: Dict) -> List[str]:
    """Generate personalized action items"""
    actions = []
    
    if analysis.get('skill_match', 0) < 60:
        actions.append("Focus on developing in-demand skills")
    
    if len(profile.get('projects', [])) < 2:
        actions.append("Build and showcase personal projects")
    
    if len(profile.get('certifications', [])) < 2:
        actions.append("Get relevant certifications")
    
    if not profile.get('summary'):
        actions.append("Write a compelling professional summary")
    
    if not actions:
        actions.append("Start applying to matching jobs")
        actions.append("Network with industry professionals")
        actions.append("Keep your profile updated")
    
    return actions[:5]

# ==================== EDUCATIONAL BACKGROUND ====================
@router.get("/educational-background")
async def get_educational_background(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's educational background summary"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_educational_background(email)


@router.post("/educational-background")
async def update_educational_background(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update educational background"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_educational_background(email, data)


# ==================== CAREER ASPIRATIONS ====================
@router.get("/career-aspirations")
async def get_career_aspirations(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's career aspirations"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_career_aspirations(email)


@router.post("/career-aspirations")
async def update_career_aspirations(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update career aspirations"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_career_aspirations(email, data)


# ==================== LEARNING PREFERENCES ====================
@router.get("/learning-preferences")
async def get_learning_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's learning preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_learning_preferences(email)


@router.post("/learning-preferences")
async def update_learning_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update learning preferences"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_learning_preferences(email, data)


# ==================== INCOME & EXPENSE ====================
@router.get("/income-expense")
async def get_income_expense(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's income and expense information"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_income_expense(email)


@router.post("/income-expense")
async def update_income_expense(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    """Update income and expense information"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_income_expense(email, data)


# ==================== GET USER PROFILE BY EMAIL (FOR ADMIN/CUSTOMADMIN) ====================

@router.get("/user-profile-by-email")
async def get_user_profile_by_email(
    email: str = Query(..., description="User email to fetch profile"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Get any user's profile by email - For Admin/CustomAdmin only
    This endpoint allows admin/customadmin to view candidate profiles
    """
    # Check if user has admin access
    user_role = current_user.get("role", "").lower()
    allowed_roles = ["admin", "customadmin", "superadmin", "custom_admin"]
    
    if user_role not in allowed_roles:
        raise HTTPException(
            status_code=403, 
            detail="Access denied. Only admin can view other user profiles."
        )
    
    # Fetch profile by email
    profile = await db.profile.find_one({"email": email})
    
    if not profile:
        # Try to get from auth if profile doesn't exist
        auth_user = await db.auth.find_one({"email": email})
        if auth_user:
            profile = {
                "email": auth_user.get("email"),
                "full_name": auth_user.get("name", ""),
                "phone": auth_user.get("mobile", ""),
                "role": auth_user.get("role", "user"),
            }
        else:
            raise HTTPException(status_code=404, detail=f"User with email {email} not found")
    
    # Convert ObjectId to string
    if "_id" in profile:
        profile["_id"] = str(profile["_id"])
    
    # Ensure all fields exist with defaults
    profile = _ensure_profile_defaults(profile)
    
    return {
        "success": True,
        "data": profile,
        "message": "Profile fetched successfully"
    }


def _ensure_profile_defaults(profile: dict) -> dict:
    """Ensure all profile fields have default values"""
    
    # Basic fields
    defaults = {
        "full_name": "",
        "first_name": "",
        "middle_name": "",
        "last_name": "",
        "phone": "",
        "dob": "",
        "gender": "Male",
        "blood_group": "",
        "nationality": "Indian",
        "religion": "",
        "category": "General/UR",
        
        # Disability
        "disability": {
            "is_disabled": False,
            "disability_category": "LD (Learning Disability)",
            "disability_percentage": None,
            "disability_details": "",
            "physically_challenged": "No",
            "certificate_verified": False
        },
        
        # Family
        "father_name": "",
        "mother_name": "",
        "guardian_name": "",
        "spouse_name": "",
        "marital_status": "Unmarried",
        "family_annual_income": None,
        "number_of_dependents": None,
        
        # Contact
        "alternate_mobile": "",
        "whatsapp_number": "",
        "emergency_contact": {"name": "", "relationship": "", "phone": ""},
        
        # Address
        "current_address": {
            "house_number": "", "village_name": "", "post_office": "",
            "tehsil": "", "district": "", "state": "", "pincode": "",
            "landmark": "", "country": "India"
        },
        "permanent_address": {},
        "same_as_current": True,
        
        # Professional
        "summary": "",
        "career_objective": "",
        
        # Social Links
        "social_links": {"linkedin": "", "github": "", "portfolio": ""},
        
        # Education, Experience, Skills
        "academic_records": [],
        "experience": [],
        "skills": [],
        "certifications": [],
        "projects": [],
        "languages_known": [],
        
        # Resume
        "resume_url": "",
        
        # Other
        "created_at": None,
        "updated_at": None
    }
    
    # Apply defaults for missing fields
    for key, default_value in defaults.items():
        if key not in profile:
            profile[key] = default_value
        elif isinstance(default_value, dict) and isinstance(profile[key], dict):
            # For nested dicts, apply defaults for missing keys
            for sub_key, sub_default in default_value.items():
                if sub_key not in profile[key]:
                    profile[key][sub_key] = sub_default
    
    return profile


# ==================== DOCUMENT MANAGEMENT ENDPOINTS (FIXED) ====================

# Allowed MIME types for document uploads
ALLOWED_MIME_TYPES = {
    # Images
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/heic', 'image/heif',
    # PDF
    'application/pdf',
    # Word documents
    'application/msword', 
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    # Excel
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    # PowerPoint
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    # Text files
    'text/plain', 'text/csv',
}

# Allowed file extensions (fallback)
ALLOWED_EXTENSIONS = {
    'pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif',
    'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv'
}


@router.post("/upload-document")
async def upload_user_document_endpoint(
    file: UploadFile = File(...),
    document_type: str = Form(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Upload a document to Cloudinary and save URL to user profile
    """
    from app.core.services.cloudinary import upload_user_document
    
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")
    
    # ✅ FIXED: Check by MIME type first (more reliable)
    content_type = file.content_type
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    
    is_allowed = False
    
    # Check MIME type
    if content_type and content_type in ALLOWED_MIME_TYPES:
        is_allowed = True
    # Fallback to extension check
    elif file_ext in ALLOWED_EXTENSIONS:
        is_allowed = True
    # Also check for image/jpeg variations
    elif content_type and content_type.startswith('image/'):
        is_allowed = True
    
    if not is_allowed:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid file type. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}"
        )
    
    # Check file size (max 10MB)
    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)
    
    max_size = 10 * 1024 * 1024  # 10MB
    if file_size > max_size:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Max size: 10MB, Your file: {file_size // (1024*1024)}MB"
        )
    
    try:
        username = email.split('@')[0]
        
        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="documents"
        )
        
        # Update profile with document URL
        await db.profile.update_one(
            {"email": email},
            {
                "$set": {
                    f"additional_details.{document_type}": upload_result["url"],
                    "updated_at": datetime.utcnow()
                }
            },
            upsert=True
        )
        
        return {
            "success": True,
            "message": "Document uploaded successfully",
            "url": upload_result["url"],
            "document_type": document_type,
            "filename": file.filename,
            "public_id": upload_result.get("public_id"),
            "file_size_kb": file_size // 1024
        }
        
    except Exception as e:
        logger.error(f"Document upload error: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@router.put("/update-profile")
async def update_profile_field(
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Update specific profile fields (for document URLs)
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    update_data = {}
    for key, value in data.items():
        update_data[key] = value
    
    update_data["updated_at"] = datetime.utcnow()
    
    result = await db.profile.update_one(
        {"email": email},
        {"$set": update_data},
        upsert=True
    )
    
    return {
        "success": True,
        "message": "Profile updated successfully",
        "modified": result.modified_count > 0
    }


@router.post("/update-document")
async def update_document_url(
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Update document URL in profile
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    document_key = data.get("document_key")
    document_url = data.get("document_url")
    
    if not document_key or not document_url:
        raise HTTPException(status_code=400, detail="Document key and URL are required")
    
    result = await db.profile.update_one(
        {"email": email},
        {
            "$set": {
                f"additional_details.{document_key}": document_url,
                "updated_at": datetime.utcnow()
            }
        },
        upsert=True
    )
    
    return {
        "success": True,
        "message": "Document URL updated successfully",
        "modified": result.modified_count > 0
    }


@router.delete("/delete-document")
async def delete_document(
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Delete document URL from profile (remove reference)
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    document_key = data.get("document_key")
    
    if not document_key:
        raise HTTPException(status_code=400, detail="Document key is required")
    
    # Remove the document URL from profile
    result = await db.profile.update_one(
        {"email": email},
        {
            "$unset": {f"additional_details.{document_key}": ""},
            "$set": {"updated_at": datetime.utcnow()}
        }
    )
    
    return {
        "success": True,
        "message": "Document deleted successfully",
        "modified": result.modified_count > 0
    }


@router.get("/get-documents")
async def get_user_documents(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Get all documents for the current user
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    
    if not profile:
        return {"success": True, "documents": {}}
    
    # Extract all document URLs from additional_details
    additional = profile.get("additional_details", {})
    
    # Document keys to look for
    document_keys = [
        'resume_url', 'profile_photo_url', 'aadhaar_url', 'pan_url',
        'passport_url', 'driving_license_url', 'voter_id_url',
        'degree_certificate_url', 'experience_letter_url', 'salary_slip_url',
        'offer_letter_url', 'disability_certificate_url', 'caste_certificate_url',
        'income_certificate_url', 'other_document_url'
    ]
    
    documents = {}
    for key in document_keys:
        if key in additional and additional[key]:
            documents[key] = additional[key]
        elif key in profile and profile[key]:
            documents[key] = profile[key]
    
    return {
        "success": True,
        "documents": documents
    }


# ================= END OF FILE =================
print("✅ User routes loaded with Ultra AI features")