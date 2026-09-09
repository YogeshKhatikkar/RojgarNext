# app/modules/user/schema.py
from pydantic import BaseModel, EmailStr, Field
from typing import List, Optional, Dict, Any
from datetime import datetime


# ================= ADDRESS SCHEMA =================
class AddressSchema(BaseModel):
    state: str = Field(default="", description="State")
    district: str = Field(default="", description="District")
    city: str = Field(default="", description="City")
    country: str = Field(default="India", description="Country")
    house_number: Optional[str] = Field(None, description="House/Flat Number")
    village_name: Optional[str] = Field(None, description="Village/City/Town")
    post_office: Optional[str] = Field(None, description="Post Office")
    tehsil: Optional[str] = Field(None, description="Tehsil/Taluka")
    landmark: Optional[str] = Field(None, description="Landmark")
    pincode: Optional[str] = Field(None, description="Pincode")


# ================= BASIC DETAILS =================
class BasicDetailsSchema(BaseModel):
    full_name: str = Field(..., description="Full Name")
    first_name: Optional[str] = Field(None, description="First Name")
    middle_name: Optional[str] = Field(None, description="Middle Name")
    last_name: Optional[str] = Field(None, description="Last Name")
    email: EmailStr = Field(..., description="Email Address")
    phone: Optional[str] = Field(None, description="Phone Number")
    dob: Optional[str] = Field(None, description="Date of Birth")
    gender: Optional[str] = Field("Male", description="Gender")
    category: Optional[str] = Field("General/UR", description="Category (General/UR, OBC, SC, ST, EWS)")
    is_disable: bool = Field(False, description="Are you a person with disability?")
    disability_category: Optional[str] = Field(None, description="Disability Category (LD, HI, VI, MD)")
    disability_percentage: Optional[float] = Field(None, description="Disability Percentage")
    father_name: Optional[str] = Field(None, description="Father's Name")
    mother_name: Optional[str] = Field(None, description="Mother's Name")
    guardian_name: Optional[str] = Field(None, description="Guardian Name")
    spouse_name: Optional[str] = Field(None, description="Spouse Name")
    marital_status: Optional[str] = Field("Unmarried", description="Marital Status")
    address: AddressSchema = Field(default_factory=AddressSchema)


# ================= EDUCATION SCHEMA =================
class EducationCreateSchema(BaseModel):
    level: str = Field(..., description="Education Level (10th, 12th, Graduation, etc.)")
    degree: Optional[str] = Field(None, description="Degree/Course Name")
    stream: Optional[str] = Field(None, description="Stream/Specialization")
    subjects: List[str] = Field(default_factory=list, description="Subjects")
    institute: str = Field(..., description="School/College/Institute Name")
    board_university: Optional[str] = Field(None, description="Board/University")
    year_of_passing: int = Field(..., description="Year of Passing")
    cgpa_percentage: Optional[float] = Field(None, description="CGPA or Percentage")
    result_type: Optional[str] = Field("Percentage", description="Result Type")
    grade: Optional[str] = Field(None, description="Grade (if applicable)")
    medium: Optional[str] = Field(None, description="Medium of Instruction")
    backlogs: Optional[int] = Field(0, description="Number of Backlogs")
    certificate_url: Optional[str] = Field(None, description="Certificate URL")


class EducationUpdateSchema(EducationCreateSchema):
    pass


# ================= EXPERIENCE SCHEMA =================
class ExperienceCreateSchema(BaseModel):
    company: str = Field(..., description="Company Name")
    role: str = Field(..., description="Job Role")
    industry_type: Optional[str] = Field(None, description="Industry Type")
    work_type: Optional[str] = Field(None, description="Work Type")
    employment_type: Optional[str] = Field("Full-time", description="Employment Type")
    location: Optional[str] = Field(None, description="Work Location")
    salary: Optional[int] = Field(None, description="Monthly Salary")
    start_date: str = Field(..., description="Start Date")
    end_date: Optional[str] = Field(None, description="End Date")
    description: str = Field(..., description="Job Description")
    achievements: List[str] = Field(default_factory=list, description="Key Achievements")
    skills_used: List[str] = Field(default_factory=list, description="Skills Used")
    reason_for_leaving: Optional[str] = Field(None, description="Reason for Leaving")
    reporting_manager: Optional[str] = Field(None, description="Reporting Manager")
    team_size: Optional[int] = Field(None, description="Team Size")


class ExperienceUpdateSchema(ExperienceCreateSchema):
    pass


# ================= SKILL SCHEMA =================
class SkillSchema(BaseModel):
    name: str = Field(..., description="Skill Name")
    level: str = Field("intermediate", description="Proficiency Level (beginner/intermediate/advanced/expert)")
    years_of_experience: Optional[float] = Field(None, description="Years of Experience")
    last_used: Optional[str] = Field(None, description="Last Used")
    importance: Optional[int] = Field(None, ge=1, le=10, description="Importance (1-10)")


# ================= INTERNSHIP SCHEMA =================
class InternshipSchema(BaseModel):
    company: str = Field(..., description="Company Name")
    role: str = Field(..., description="Internship Role")
    start_date: str = Field(..., description="Start Date")
    end_date: Optional[str] = Field(None, description="End Date")
    description: str = Field(..., description="Internship Description")
    stipend: Optional[int] = Field(None, description="Stipend Amount")
    technologies: List[str] = Field(default_factory=list, description="Technologies Learned")


# ================= CERTIFICATION SCHEMA =================
class CertificationSchema(BaseModel):
    name: str = Field(..., description="Certification Name")
    issuer: str = Field(..., description="Issuing Organization")
    year: int = Field(..., description="Year of Certification")
    url: Optional[str] = Field(None, description="Certificate URL")
    expiry_date: Optional[str] = Field(None, description="Expiry Date")
    credential_id: Optional[str] = Field(None, description="Credential ID")


# ================= PROJECT SCHEMA =================
class ProjectSchema(BaseModel):
    title: str = Field(..., description="Project Title")
    description: str = Field(..., description="Project Description")
    technologies: List[str] = Field(default_factory=list, description="Technologies Used")
    url: Optional[str] = Field(None, description="Project URL")
    github_url: Optional[str] = Field(None, description="GitHub URL")
    start_date: Optional[str] = Field(None, description="Start Date")
    end_date: Optional[str] = Field(None, description="End Date")
    is_live: bool = Field(False, description="Is Project Live")


# ================= LANGUAGE SCHEMA =================
class LanguageSchema(BaseModel):
    name: str = Field(..., description="Language Name")
    proficiency: str = Field("fluent", description="Proficiency (native/fluent/intermediate/basic)")


# ================= ADDITIONAL DETAILS SCHEMA =================
class AdditionalDetailsSchema(BaseModel):
    soft_skills: List[str] = Field(default_factory=list, description="Soft Skills")
    linkedin_url: Optional[str] = Field(None, description="LinkedIn URL")
    github_url: Optional[str] = Field(None, description="GitHub URL")
    portfolio_url: Optional[str] = Field(None, description="Portfolio URL")
    resume_url: Optional[str] = Field(None, description="Resume URL")
    video_resume_url: Optional[str] = Field(None, description="Video Resume URL")
    preferred_job_types: List[str] = Field(default_factory=list, description="Preferred Job Types")
    preferred_industries: List[str] = Field(default_factory=list, description="Preferred Industries")
    preferred_locations: List[str] = Field(default_factory=list, description="Preferred Locations")
    open_to_relocate: bool = Field(False, description="Open to Relocate")
    availability_date: Optional[str] = Field(None, description="Availability Date")
    salary_expectation_min: Optional[int] = Field(None, description="Minimum Expected Salary")
    salary_expectation_max: Optional[int] = Field(None, description="Maximum Expected Salary")
    willing_for_internship: bool = Field(True, description="Willing for Internship")
    willing_for_full_time: bool = Field(True, description="Willing for Full Time")


# ================= FULL PROFILE RESPONSE =================
class FullProfileResponse(BaseModel):
    full_name: str = ""
    first_name: str = ""
    middle_name: str = ""
    last_name: str = ""
    email: str = ""
    phone: str = ""
    dob: str = ""
    gender: str = "Male"
    blood_group: str = ""
    nationality: str = "Indian"
    religion: str = ""
    category: str = "General/UR"
    is_disable: bool = False
    disability_category: Optional[str] = None
    disability_percentage: Optional[float] = None
    father_name: str = ""
    mother_name: str = ""
    guardian_name: str = ""
    spouse_name: str = ""
    marital_status: str = "Unmarried"
    family_annual_income: Optional[int] = None
    number_of_dependents: Optional[int] = None
    alternate_mobile: str = ""
    whatsapp_number: str = ""
    emergency_contact: str = ""
    emergency_contact_name: str = ""
    emergency_contact_relation: str = ""
    current_address: AddressSchema = Field(default_factory=AddressSchema)
    permanent_address: Optional[AddressSchema] = None
    same_as_current: bool = True
    summary: str = ""
    career_objective: str = ""
    linkedin_url: str = ""
    github_url: str = ""
    portfolio_url: str = ""
    preferred_location: str = ""
    expected_salary_min: Optional[int] = None
    expected_salary_max: Optional[int] = None
    open_to_relocate: bool = False
    open_to_remote_work: bool = False
    preferred_job_types: List[str] = Field(default_factory=list)
    preferred_industries: List[str] = Field(default_factory=list)
    height: Optional[float] = None
    weight: Optional[float] = None
    languages_known: List[str] = Field(default_factory=list)
    academic_records: List[Dict[str, Any]] = Field(default_factory=list)
    experience: List[Dict[str, Any]] = Field(default_factory=list)
    internships: List[Dict[str, Any]] = Field(default_factory=list)
    skills: List[Dict[str, Any]] = Field(default_factory=list)
    certifications: List[Dict[str, Any]] = Field(default_factory=list)
    projects: List[Dict[str, Any]] = Field(default_factory=list)
    is_educated: bool = True
    can_read: bool = False
    can_write: bool = False
    basic_education_level: str = "None"
    basic_skills: List[str] = Field(default_factory=list)
    is_fresher: bool = True
    internship_details: str = ""
    training_program: str = ""
    daily_wage: Optional[int] = None
    projects_done: str = ""
    certifications_list: List[str] = Field(default_factory=list)
    labour_type: str = "Mason"