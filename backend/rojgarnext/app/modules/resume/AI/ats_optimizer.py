# app/modules/resume/AI/ats_optimizer.py
"""Resume: AI ATS Optimizer"""

import json
import logging
from typing import Dict, Any, List
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class ATSOptimizerAI:
    """Optimize resume for ATS systems"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def optimize_for_ats(self, resume_data: Dict, job: Dict) -> Dict[str, Any]:
        """Get ATS optimization suggestions"""
        if not self.client:
            return self._fallback_optimization(resume_data, job)
        
        try:
            job_skills = []
            for skill in job.get('required_skills', []):
                if isinstance(skill, dict):
                    job_skills.append(skill.get('name', ''))
                else:
                    job_skills.append(str(skill))
            
            prompt = f"""Optimize this resume for ATS and job matching:

RESUME SKILLS: {resume_data.get('skills', [])}
JOB TITLE: {job.get('post_name', 'Unknown')}
JOB SKILLS: {job_skills}

Return ONLY valid JSON:
{{
  "match_percentage": <0-100>,
  "missing_keywords": ["keyword1", "keyword2"],
  "suggested_additions": ["addition1", "addition2"],
  "format_issues": ["issue1", "issue2"],
  "improvement_score": <0-100>,
  "recommendations": ["rec1", "rec2", "rec3"]
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=600
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"ATS optimization failed: {e}")
            return self._fallback_optimization(resume_data, job)
    
    def _fallback_optimization(self, resume_data: Dict, job: Dict) -> Dict:
        resume_skills = set([s.lower() for s in resume_data.get('skills', [])])
        job_skills = set()
        for skill in job.get('required_skills', []):
            if isinstance(skill, dict):
                job_skills.add(skill.get('name', '').lower())
            else:
                job_skills.add(str(skill).lower())
        
        matching_skills = resume_skills & job_skills
        match_percentage = int((len(matching_skills) / max(1, len(job_skills))) * 100)
        
        return {
            "match_percentage": match_percentage,
            "missing_keywords": list(job_skills - resume_skills)[:5],
            "suggested_additions": ["Add more relevant keywords", "Customize for each application"],
            "format_issues": ["Use standard section headings", "Avoid graphics and tables"],
            "improvement_score": max(0, 100 - match_percentage),
            "recommendations": [
                f"Add {', '.join(list(job_skills - resume_skills)[:3])} to your skills",
                "Use a clean, text-based format",
                "Include keywords from job description",
                "Customize your resume for each application"
            ]
        }