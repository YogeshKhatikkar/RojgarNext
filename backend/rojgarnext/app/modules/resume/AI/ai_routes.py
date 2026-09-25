# app/modules/resume/AI/ai_routes.py
# ============================================================
# AI RESUME ROUTES — Full API surface
# ============================================================

from fastapi import APIRouter, Depends, HTTPException, Body
from typing import Dict, Any, List, Optional
from pydantic import BaseModel, Field

from app.core.services.dependencies import get_current_user
from app.modules.resume.AI.ats_optimizer import ats_optimizer
from app.modules.resume.AI.resume_generator import resume_generator
from app.modules.resume.AI.resume_enhancer import resume_enhancer
from app.core.utils.logger import logger

router = APIRouter(prefix="/resume/ai", tags=["Resume AI"])


# ============================================================
# REQUEST MODELS
# ============================================================
class ScoreRequest(BaseModel):
    job_description: Optional[str] = None
    job_skills: Optional[List[str]] = None


class GenerateRequest(BaseModel):
    job_description: Optional[str] = None
    target_role: Optional[str] = None
    style: str = Field(default="modern", description="classic|modern|tech|executive|government|fresher")


class BulletRequest(BaseModel):
    bullets: List[str]
    role: Optional[str] = ""
    job_description: Optional[str] = None
    count: int = 5


class SummaryRequest(BaseModel):
    base_summary: str = ""
    role: str = ""
    skills: List[str] = []
    years_experience: int = 0
    job_description: Optional[str] = None


# ============================================================
# 1. SCORE RESUME (ATS)
# ============================================================
@router.post("/score")
async def score_resume(
    payload: ScoreRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Score the current user's resume against an optional job description.
    """
    try:
        email = current_user.get("email")
        if not email:
            raise HTTPException(status_code=401, detail="Email missing in token")

        # Generate fresh resume object (uses real profile data)
        resume = await resume_generator.generate_full_resume(
            email=email,
            job_description=payload.job_description,
            style="modern",
        )

        report = await ats_optimizer.score_resume(
            resume_data=resume,
            job_description=payload.job_description,
            job_skills=payload.job_skills or [],
        )

        return {"success": True, "data": report}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"score_resume error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# 2. AUTO-GENERATE FULL RESUME
# ============================================================
@router.post("/generate")
async def generate_resume(
    payload: GenerateRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Fully automatic AI resume generation from the user's profile.
    """
    try:
        email = current_user.get("email")
        if not email:
            raise HTTPException(status_code=401, detail="Email missing in token")

        resume = await resume_generator.generate_full_resume(
            email=email,
            job_description=payload.job_description,
            target_role=payload.target_role,
            style=payload.style,
        )

        return {"success": True, "data": resume}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"generate_resume error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# 3. SCORE + GENERATE (Combo — one call, both results)
# ============================================================
@router.post("/generate-and-score")
async def generate_and_score(
    payload: GenerateRequest,
    current_user: dict = Depends(get_current_user),
):
    try:
        email = current_user.get("email")
        if not email:
            raise HTTPException(status_code=401, detail="Email missing in token")

        resume = await resume_generator.generate_full_resume(
            email=email,
            job_description=payload.job_description,
            target_role=payload.target_role,
            style=payload.style,
        )

        report = await ats_optimizer.score_resume(
            resume_data=resume,
            job_description=payload.job_description,
        )

        return {"success": True, "data": {"resume": resume, "ats_report": report}}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"generate_and_score error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# 4. ENHANCE BULLET POINTS
# ============================================================
@router.post("/enhance-bullets")
async def enhance_bullets(
    payload: BulletRequest,
    current_user: dict = Depends(get_current_user),
):
    try:
        bullets = await resume_enhancer.enhance_bullet_points(
            raw_bullets=payload.bullets,
            role=payload.role or "",
            job_description=payload.job_description,
            count=payload.count,
        )
        return {"success": True, "data": {"bullets": bullets}}
    except Exception as e:
        logger.error(f"enhance_bullets error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# 5. ENHANCE SUMMARY
# ============================================================
@router.post("/enhance-summary")
async def enhance_summary(
    payload: SummaryRequest,
    current_user: dict = Depends(get_current_user),
):
    try:
        summary = await resume_enhancer.enhance_summary(
            base_summary=payload.base_summary,
            role=payload.role,
            skills=payload.skills,
            years_experience=payload.years_experience,
            job_description=payload.job_description,
        )
        return {"success": True, "data": {"summary": summary}}
    except Exception as e:
        logger.error(f"enhance_summary error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# 6. QUICK ATS SCORE (no JD)
# ============================================================
@router.get("/quick-score")
async def quick_score(current_user: dict = Depends(get_current_user)):
    try:
        email = current_user.get("email")
        if not email:
            raise HTTPException(status_code=401, detail="Email missing in token")

        resume = await resume_generator.generate_full_resume(email=email)
        report = await ats_optimizer.score_resume(resume_data=resume)

        return {
            "success": True,
            "data": {
                "overall_score": report["overall_score"],
                "grade": report["grade"],
                "section_scores": report["section_scores"],
                "top_fixes": report["prioritized_fixes"][:3],
                "ai_summary": report["ai_summary"],
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"quick_score error: {e}")
        raise HTTPException(status_code=500, detail=str(e))