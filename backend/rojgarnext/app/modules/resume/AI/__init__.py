# app/modules/resume/AI/__init__.py
from .ai_routes import router as ai_router
from .resume_parser import ResumeParserAI
from .ats_optimizer import ATSOptimizerAI

__all__ = [
    'ai_router',
    'ResumeParserAI',
    'ATSOptimizerAI'
]