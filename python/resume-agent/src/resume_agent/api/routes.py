"""FastAPI routes for the Resume Agent API."""

from fastapi import APIRouter, HTTPException

from resume_agent.agent.resume_agent import get_agent
from resume_agent.models.schemas import (
    AnalyzeRequest,
    AnalyzeResponse,
    GenerateSummaryRequest,
    GenerateSummaryResponse,
    HealthResponse,
    TailorResumeRequest,
    TailorResumeResponse,
)

router = APIRouter()


@router.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check() -> HealthResponse:
    """Health check endpoint."""
    return HealthResponse()


@router.post("/analyze", response_model=AnalyzeResponse, tags=["Resume"])
async def analyze_resume(request: AnalyzeRequest) -> AnalyzeResponse:
    """
    Analyze a resume and provide feedback.

    Optionally match against a job description for fit scoring.
    """
    try:
        agent = get_agent()
        return await agent.analyze(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post("/generate-summary", response_model=GenerateSummaryResponse, tags=["Resume"])
async def generate_summary(request: GenerateSummaryRequest) -> GenerateSummaryResponse:
    """
    Generate a professional summary based on resume data.

    Supports different tones: professional, creative, technical.
    """
    try:
        agent = get_agent()
        return await agent.generate_summary(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post("/tailor", response_model=TailorResumeResponse, tags=["Resume"])
async def tailor_resume(request: TailorResumeRequest) -> TailorResumeResponse:
    """
    Tailor a resume for a specific job description.

    Returns modified sections with tracked changes and keyword recommendations.
    """
    try:
        agent = get_agent()
        return await agent.tailor_resume(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
