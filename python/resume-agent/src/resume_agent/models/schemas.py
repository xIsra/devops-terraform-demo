"""Pydantic models for the Resume Agent API."""

from typing import Literal

from pydantic import BaseModel, Field


class ResumeData(BaseModel):
    """Input resume data."""

    name: str = Field(..., description="Candidate's full name")
    email: str | None = Field(None, description="Contact email")
    phone: str | None = Field(None, description="Contact phone")
    summary: str | None = Field(None, description="Professional summary")
    experience: list[dict] = Field(default_factory=list, description="Work experience entries")
    education: list[dict] = Field(default_factory=list, description="Education entries")
    skills: list[str] = Field(default_factory=list, description="List of skills")
    raw_text: str | None = Field(None, description="Raw resume text if available")


class JobDescription(BaseModel):
    """Target job description for matching."""

    title: str = Field(..., description="Job title")
    company: str | None = Field(None, description="Company name")
    description: str = Field(..., description="Full job description text")
    required_skills: list[str] = Field(default_factory=list, description="Required skills")
    preferred_skills: list[str] = Field(default_factory=list, description="Preferred skills")


class AnalyzeRequest(BaseModel):
    """Request to analyze a resume."""

    resume: ResumeData
    job_description: JobDescription | None = Field(None, description="Optional job to match against")


class ImprovementSuggestion(BaseModel):
    """A single improvement suggestion."""

    section: str = Field(..., description="Resume section this applies to")
    suggestion: str = Field(..., description="The improvement suggestion")
    priority: Literal["high", "medium", "low"] = Field(..., description="Priority level")


class SkillMatch(BaseModel):
    """Skill matching result."""

    skill: str
    matched: bool
    confidence: float = Field(..., ge=0, le=1)


class AnalyzeResponse(BaseModel):
    """Response from resume analysis."""

    overall_score: float = Field(..., ge=0, le=100, description="Overall resume score")
    summary: str = Field(..., description="Analysis summary")
    strengths: list[str] = Field(default_factory=list, description="Resume strengths")
    weaknesses: list[str] = Field(default_factory=list, description="Areas for improvement")
    suggestions: list[ImprovementSuggestion] = Field(default_factory=list)
    skill_matches: list[SkillMatch] = Field(default_factory=list, description="Skill matching if job provided")
    job_fit_score: float | None = Field(None, ge=0, le=100, description="Job fit score if job provided")


class GenerateSummaryRequest(BaseModel):
    """Request to generate a professional summary."""

    resume: ResumeData
    tone: Literal["professional", "creative", "technical"] = Field(
        default="professional", description="Desired tone"
    )
    max_words: int = Field(default=100, ge=50, le=300, description="Maximum word count")


class GenerateSummaryResponse(BaseModel):
    """Generated professional summary."""

    summary: str
    word_count: int


class TailorResumeRequest(BaseModel):
    """Request to tailor resume for a job."""

    resume: ResumeData
    job_description: JobDescription


class TailoredSection(BaseModel):
    """A tailored resume section."""

    section: str
    original: str | None
    tailored: str
    changes_made: list[str]


class TailorResumeResponse(BaseModel):
    """Tailored resume response."""

    tailored_sections: list[TailoredSection]
    keywords_added: list[str]
    overall_recommendations: list[str]


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = "healthy"
    version: str = "0.1.0"
