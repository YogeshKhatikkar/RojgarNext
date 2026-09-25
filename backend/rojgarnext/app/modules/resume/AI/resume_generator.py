# app/modules/resume/AI/resume_generator.py
# ============================================================
# FULLY AUTOMATIC AI RESUME GENERATOR
# Builds complete resumes from user profile + optional JD
# ============================================================

import json
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional

from openai import AsyncOpenAI
from app.core.config.settings import settings
from app.db.connection import get_db
from app.core.utils.logger import logger

module_logger = logging.getLogger(__name__)


class ResumeGenerator:
    """
    Fully automatic resume generator:
    - Reads user's full profile from DB
    - Uses AI to rewrite/enhance every section
    - Auto-inserts keywords from a JD (if provided)
    - Returns both a rich object AND ready-to-render sections
    """

    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
        module_logger.info("✅ Resume Generator initialized")

    # ============================================================
    # MAIN: Generate full resume for an email
    # ============================================================
    async def generate_full_resume(
        self,
        email: str,
        job_description: Optional[str] = None,
        target_role: Optional[str] = None,
        style: str = "modern",  # classic | modern | tech | executive | government | fresher
    ) -> Dict[str, Any]:
        db = get_db()

        profile = await db.profile.find_one({"email": email}) or {}
        auth = await db.auth.find_one({"email": email}) or {}

        # Step 1: Build base sections from real data (never fake)
        base = self._build_base_sections(profile, auth)

        # Step 2: AI enhance each section (parallel-safe, sequential here for clarity)
        enhanced = await self._ai_enhance_all(
            base=base,
            job_description=job_description,
            target_role=target_role or base["user_info"].get("current_role") or "",
            style=style,
        )

        # Step 3: Build final resume object
        final = {
            "user_info": enhanced["user_info"],
            "contact_info": enhanced["contact_info"],
            "professional_summary": enhanced["professional_summary"],
            "career_objective": enhanced["career_objective"],
            "experience": enhanced["experience"],
            "education": enhanced["education"],
            "skills": enhanced["skills"],
            "projects": enhanced["projects"],
            "certifications": enhanced["certifications"],
            "languages": enhanced["languages"],
            "social_links": enhanced["social_links"],
            "generated_at": datetime.utcnow().isoformat(),
            "style": style,
            "target_role": target_role,
            "has_jd": bool(job_description),
            "ai_powered": bool(self.client),
            "statistics": self._statistics(enhanced),
        }

        return final

    # ============================================================
    # BUILD BASE SECTIONS (raw from profile — no AI yet)
    # ============================================================
    def _build_base_sections(
        self, profile: Dict[str, Any], auth: Dict[str, Any]
    ) -> Dict[str, Any]:
        # -------- User info --------
        full_name = (
            profile.get("full_name")
            or auth.get("name")
            or ""
        ).strip()

        dob = profile.get("dob") or ""
        age = self._calc_age(dob)

        current_role = ""
        experience_list = profile.get("experience") or []
        if experience_list:
            # Latest role = first non-null end_date or top entry
            current = next(
                (e for e in experience_list if not e.get("end_date")),
                experience_list[0],
            )
            current_role = current.get("role", "")

        user_info = {
            "full_name": full_name,
            "first_name": profile.get("first_name") or full_name.split(" ")[0] if full_name else "",
            "last_name": profile.get("last_name") or (full_name.split(" ")[-1] if full_name else ""),
            "email": auth.get("email", profile.get("email", "")),
            "mobile": auth.get("mobile", profile.get("mobile", "")),
            "dob": dob,
            "age": age,
            "gender": profile.get("gender", ""),
            "category": profile.get("category", ""),
            "current_role": current_role,
        }

        # -------- Contact --------
        addr = profile.get("current_address") or {}
        location_parts = [
            addr.get("village_name") or addr.get("city") or "",
            addr.get("district") or "",
            addr.get("state") or "",
            addr.get("country") or "",
        ]
        location = ", ".join([p for p in location_parts if p])

        contact_info = {
            "email": user_info["email"],
            "phone": user_info["mobile"],
            "location": location,
            "linkedin": (profile.get("social_links") or {}).get("linkedin", ""),
            "github": (profile.get("social_links") or {}).get("github", ""),
            "portfolio": (profile.get("social_links") or {}).get("portfolio", ""),
            "website": (profile.get("social_links") or {}).get("personal_website", ""),
        }

        # -------- Experience --------
        experience = []
        for exp in experience_list:
            experience.append({
                "role": exp.get("role", ""),
                "company": exp.get("company", ""),
                "location": exp.get("location", ""),
                "start_date": exp.get("start_date", ""),
                "end_date": exp.get("end_date") or "Present",
                "description": exp.get("description", ""),
                "achievements": exp.get("achievements") or [],
                "skills_used": exp.get("skills_used") or [],
            })

        # -------- Education --------
        education = []
        for edu in profile.get("academic_records") or []:
            education.append({
                "level": edu.get("level", ""),
                "degree": edu.get("degree") or edu.get("stream") or "",
                "institute": edu.get("institute", ""),
                "board_university": edu.get("board_university", ""),
                "year_of_passing": edu.get("year_of_passing", ""),
                "score": edu.get("cgpa_percentage", ""),
                "result_type": edu.get("result_type", ""),
            })

        # -------- Skills --------
        raw_skills = profile.get("skills") or []
        skills = {
            "all": [
                {"name": (s.get("name") if isinstance(s, dict) else str(s)),
                 "level": (s.get("level") if isinstance(s, dict) else "intermediate")}
                for s in raw_skills
            ],
        }

        # -------- Projects --------
        projects = []
        for p in profile.get("projects") or []:
            projects.append({
                "title": p.get("title", ""),
                "description": p.get("description", ""),
                "technologies": p.get("technologies") or [],
                "role": p.get("role", ""),
                "url": p.get("url", ""),
                "github_url": p.get("github_url", ""),
            })

        # -------- Certifications --------
        certifications = []
        for c in profile.get("certifications") or []:
            certifications.append({
                "name": c.get("name", ""),
                "issuer": c.get("issuer", ""),
                "year": c.get("year", ""),
                "credential_id": c.get("credential_id", ""),
            })

        # -------- Languages --------
        languages = profile.get("languages") or []

        return {
            "user_info": user_info,
            "contact_info": contact_info,
            "professional_summary": profile.get("summary") or "",
            "career_objective": profile.get("career_objective") or "",
            "experience": experience,
            "education": education,
            "skills": skills,
            "projects": projects,
            "certifications": certifications,
            "languages": languages,
            "social_links": profile.get("social_links") or {},
        }

    # ============================================================
    # AI ENHANCEMENT — every section
    # ============================================================
    async def _ai_enhance_all(
        self,
        base: Dict[str, Any],
        job_description: Optional[str],
        target_role: str,
        style: str,
    ) -> Dict[str, Any]:
        if not self.client:
            # No AI → return base but with safe defaults
            base["professional_summary"] = base["professional_summary"] or self._default_summary(base, target_role)
            base["career_objective"] = base["career_objective"] or self._default_objective(target_role)
            base["experience"] = self._ensure_bullets(base["experience"])
            return base

        try:
            prompt = self._build_master_prompt(base, job_description, target_role, style)
            resp = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are an expert resume writer + ATS optimizer. "
                            "Rewrite the user's resume content to be ATS-perfect, "
                            "quantified, achievement-focused, and keyword-rich. "
                            "NEVER invent facts, companies, dates, or degrees. "
                            "Only enhance phrasing, add measurable structure, and "
                            "insert keywords ONLY when they truthfully match the user's skills. "
                            "Return ONLY valid JSON — no markdown, no code fences."
                        ),
                    },
                    {"role": "user", "content": prompt},
                ],
                temperature=0.4,
                max_tokens=3500,
            )

            raw = resp.choices[0].message.content.strip()
            raw = self._strip_code_fences(raw)
            enhanced = json.loads(raw)

            # Merge with base (never lose real data)
            return self._merge_safely(base, enhanced)

        except Exception as e:
            module_logger.error(f"AI enhancement failed: {e}")
            base["professional_summary"] = base["professional_summary"] or self._default_summary(base, target_role)
            base["career_objective"] = base["career_objective"] or self._default_objective(target_role)
            base["experience"] = self._ensure_bullets(base["experience"])
            return base

    def _build_master_prompt(
        self,
        base: Dict[str, Any],
        job_description: Optional[str],
        target_role: str,
        style: str,
    ) -> str:
        user = base["user_info"]
        exps = base["experience"]
        edus = base["education"]
        skills = [s["name"] for s in base["skills"]["all"]]
        projects = base["projects"]
        certs = base["certifications"]

        return f"""Rewrite this resume for ATS + human recruiters.

STYLE TARGET: {style}
TARGET ROLE: {target_role or "Not specified"}

----- USER -----
Name: {user['full_name']}
Email: {user['email']}
Phone: {user['mobile']}
Location: {base['contact_info']['location']}
Experience entries: {len(exps)}
Education entries: {len(edus)}
Skills: {skills}
Projects: {len(projects)}
Certifications: {len(certs)}

----- JOB DESCRIPTION -----
{(job_description or "None provided")[:3000]}

----- EXISTING DATA -----
Current summary: {base['professional_summary'] or "(empty)"}
Current objective: {base['career_objective'] or "(empty)"}
Experience:
{json.dumps(exps, default=str)[:3500]}
Education:
{json.dumps(edus, default=str)[:1500]}
Projects:
{json.dumps(projects, default=str)[:1500]}
Certifications:
{json.dumps(certs, default=str)[:800]}

----- REWRITE INSTRUCTIONS -----
1. professional_summary: 3–4 sentences, 50–90 words. Include role, years exp, key skills, top achievement.
2. career_objective: 2 sentences, forward-looking.
3. experience: for EACH entry, keep role/company/dates EXACTLY. Rewrite `description` (2–4 sentences). Rewrite `achievements` as 3–5 bullet points starting with strong verbs and numbers where possible.
4. skills: group into {{all, technical, soft, tools}}. Never invent — only reuse + infer common tools for mentioned domains.
5. projects: keep title/url. Enhance `description` with impact + tech stack.
6. education: never modify factual fields.

----- OUTPUT JSON (EXACT SHAPE) -----
{{
  "professional_summary": "...",
  "career_objective": "...",
  "experience": [
    {{
      "role": "...",
      "company": "...",
      "start_date": "...",
      "end_date": "...",
      "description": "...",
      "achievements": ["...", "...", "..."]
    }}
  ],
  "skills": {{
    "all": [{{"name": "...", "level": "..."}}],
    "technical": ["..."],
    "soft": ["..."],
    "tools": ["..."]
  }},
  "projects": [
    {{"title": "...", "description": "...", "technologies": ["..."]}}
  ],
  "certifications": [{{"name": "...", "issuer": "...", "year": "..."}}]
}}"""

    # ============================================================
    # SAFE MERGE — never lose real data
    # ============================================================
    def _merge_safely(self, base: Dict[str, Any], enhanced: Dict[str, Any]) -> Dict[str, Any]:
        merged = dict(base)

        if enhanced.get("professional_summary"):
            merged["professional_summary"] = enhanced["professional_summary"]
        if enhanced.get("career_objective"):
            merged["career_objective"] = enhanced["career_objective"]

        # Experience — keep base facts
        if isinstance(enhanced.get("experience"), list):
            merged_exp = []
            for i, base_exp in enumerate(base["experience"]):
                enh_exp = enhanced["experience"][i] if i < len(enhanced["experience"]) else {}
                merged_exp.append({
                    "role": base_exp["role"] or enh_exp.get("role", ""),
                    "company": base_exp["company"] or enh_exp.get("company", ""),
                    "start_date": base_exp["start_date"] or enh_exp.get("start_date", ""),
                    "end_date": base_exp["end_date"] or enh_exp.get("end_date", ""),
                    "description": enh_exp.get("description") or base_exp["description"],
                    "achievements": enh_exp.get("achievements") or base_exp["achievements"],
                    "skills_used": base_exp["skills_used"],
                    "location": base_exp.get("location", ""),
                })
            merged["experience"] = merged_exp

        # Skills — merge
        if isinstance(enhanced.get("skills"), dict):
            all_skills = enhanced["skills"].get("all") or base["skills"]["all"]
            merged["skills"] = {
                "all": all_skills,
                "technical": enhanced["skills"].get("technical", []),
                "soft": enhanced["skills"].get("soft", []),
                "tools": enhanced["skills"].get("tools", []),
            }

        # Projects — keep title from base
        if isinstance(enhanced.get("projects"), list):
            merged_projects = []
            for i, base_p in enumerate(base["projects"]):
                enh_p = enhanced["projects"][i] if i < len(enhanced["projects"]) else {}
                merged_projects.append({
                    "title": base_p["title"] or enh_p.get("title", ""),
                    "description": enh_p.get("description") or base_p["description"],
                    "technologies": enh_p.get("technologies") or base_p["technologies"],
                    "url": base_p.get("url", ""),
                    "github_url": base_p.get("github_url", ""),
                    "role": base_p.get("role", ""),
                })
            merged["projects"] = merged_projects

        # Certifications — keep name
        if isinstance(enhanced.get("certifications"), list):
            merged_certs = []
            for i, base_c in enumerate(base["certifications"]):
                enh_c = enhanced["certifications"][i] if i < len(enhanced["certifications"]) else {}
                merged_certs.append({
                    "name": base_c["name"] or enh_c.get("name", ""),
                    "issuer": enh_c.get("issuer") or base_c.get("issuer", ""),
                    "year": enh_c.get("year") or base_c.get("year", ""),
                })
            merged["certifications"] = merged_certs

        return merged

    # ============================================================
    # HELPERS
    # ============================================================
    def _strip_code_fences(self, text: str) -> str:
        text = text.strip()
        if text.startswith("```"):
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]
        if text.endswith("```"):
            text = text[:-3]
        return text.strip()

    def _calc_age(self, dob: str) -> Optional[int]:
        if not dob:
            return None
        try:
            birth = datetime.strptime(dob[:10], "%Y-%m-%d")
            today = datetime.now()
            age = today.year - birth.year
            if (today.month, today.day) < (birth.month, birth.day):
                age -= 1
            return age
        except Exception:
            return None

    def _default_summary(self, base: Dict[str, Any], target_role: str) -> str:
        role = target_role or base["user_info"].get("current_role") or "professional"
        skills = ", ".join([s["name"] for s in base["skills"]["all"][:5]])
        years = len(base["experience"])
        return (
            f"{role} with {years}+ years of experience. "
            f"Skilled in {skills}. "
            f"Passionate about delivering measurable results and continuously learning new technologies."
        )

    def _default_objective(self, target_role: str) -> str:
        role = target_role or "a challenging role"
        return (
            f"Seeking {role} where I can apply my technical expertise, "
            f"contribute to impactful projects, and grow as a professional."
        )

    def _ensure_bullets(self, experience: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        for exp in experience:
            if not exp.get("achievements"):
                desc = exp.get("description", "")
                if desc:
                    parts = [p.strip() for p in desc.split(".") if p.strip()]
                    exp["achievements"] = [f"{p}." for p in parts[:5]]
        return experience

    def _statistics(self, resume: Dict[str, Any]) -> Dict[str, Any]:
        skills_all = resume.get("skills", {}).get("all", [])
        return {
            "total_experience_entries": len(resume.get("experience") or []),
            "total_education_entries": len(resume.get("education") or []),
            "total_skills": len(skills_all),
            "total_projects": len(resume.get("projects") or []),
            "total_certifications": len(resume.get("certifications") or []),
            "profile_completion": self._completion(resume),
        }

    def _completion(self, resume: Dict[str, Any]) -> int:
        checks = [
            bool((resume.get("user_info") or {}).get("full_name")),
            bool((resume.get("contact_info") or {}).get("email")),
            bool((resume.get("contact_info") or {}).get("phone")),
            bool(resume.get("professional_summary")),
            bool(resume.get("experience")),
            bool(resume.get("education")),
            bool((resume.get("skills") or {}).get("all")),
            bool(resume.get("projects")),
        ]
        return int((sum(checks) / len(checks)) * 100)


resume_generator = ResumeGenerator()