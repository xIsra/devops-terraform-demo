"""Resume Agent using LangChain and LangGraph."""

import json
import os
from typing import Annotated, TypedDict

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import END, StateGraph
from langgraph.graph.message import add_messages

from resume_agent.models.schemas import (
    AnalyzeRequest,
    AnalyzeResponse,
    GenerateSummaryRequest,
    GenerateSummaryResponse,
    ImprovementSuggestion,
    ResumeData,
    SkillMatch,
    TailoredSection,
    TailorResumeRequest,
    TailorResumeResponse,
)


class AgentState(TypedDict):
    """State for the resume agent graph."""

    messages: Annotated[list, add_messages]
    resume_data: dict | None
    job_data: dict | None
    analysis_result: dict | None
    current_task: str | None


def get_llm() -> ChatOpenAI:
    """Get the LLM instance."""
    return ChatOpenAI(
        model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
        temperature=0.7,
        api_key=os.getenv("OPENAI_API_KEY"),
    )


def _format_resume_for_prompt(resume: ResumeData) -> str:
    """Format resume data into a readable string."""
    parts = [f"Name: {resume.name}"]

    if resume.email:
        parts.append(f"Email: {resume.email}")
    if resume.phone:
        parts.append(f"Phone: {resume.phone}")
    if resume.summary:
        parts.append(f"\nSummary:\n{resume.summary}")

    if resume.experience:
        parts.append("\nExperience:")
        for exp in resume.experience:
            exp_str = f"- {exp.get('title', 'N/A')} at {exp.get('company', 'N/A')}"
            if exp.get("duration"):
                exp_str += f" ({exp['duration']})"
            if exp.get("description"):
                exp_str += f"\n  {exp['description']}"
            parts.append(exp_str)

    if resume.education:
        parts.append("\nEducation:")
        for edu in resume.education:
            edu_str = f"- {edu.get('degree', 'N/A')} from {edu.get('institution', 'N/A')}"
            if edu.get("year"):
                edu_str += f" ({edu['year']})"
            parts.append(edu_str)

    if resume.skills:
        parts.append(f"\nSkills: {', '.join(resume.skills)}")

    if resume.raw_text:
        parts.append(f"\nAdditional Info:\n{resume.raw_text}")

    return "\n".join(parts)


class ResumeAgent:
    """Agent for resume analysis and improvement."""

    def __init__(self):
        self.llm = get_llm()
        self._build_graph()

    def _build_graph(self):
        """Build the LangGraph workflow."""
        workflow = StateGraph(AgentState)

        # Add nodes
        workflow.add_node("analyze", self._analyze_node)
        workflow.add_node("match_skills", self._match_skills_node)
        workflow.add_node("generate_suggestions", self._suggestions_node)

        # Define edges
        workflow.set_entry_point("analyze")
        workflow.add_edge("analyze", "match_skills")
        workflow.add_edge("match_skills", "generate_suggestions")
        workflow.add_edge("generate_suggestions", END)

        self.graph = workflow.compile()

    def _analyze_node(self, state: AgentState) -> AgentState:
        """Analyze resume quality."""
        resume_text = state.get("resume_data", {}).get("formatted", "")

        system_prompt = """You are an expert resume analyst. Analyze the given resume and provide:
1. An overall score (0-100)
2. A brief summary of the analysis
3. 3-5 strengths
4. 3-5 weaknesses

Respond in JSON format:
{
    "overall_score": <number>,
    "summary": "<string>",
    "strengths": ["<string>", ...],
    "weaknesses": ["<string>", ...]
}"""

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=f"Analyze this resume:\n\n{resume_text}"),
        ]

        response = self.llm.invoke(messages)

        try:
            # Try to parse JSON from response
            content = response.content
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]
            result = json.loads(content.strip())
        except (json.JSONDecodeError, IndexError):
            result = {
                "overall_score": 70,
                "summary": response.content,
                "strengths": [],
                "weaknesses": [],
            }

        state["analysis_result"] = result
        return state

    def _match_skills_node(self, state: AgentState) -> AgentState:
        """Match skills against job requirements."""
        job_data = state.get("job_data")
        if not job_data:
            state["analysis_result"]["skill_matches"] = []
            state["analysis_result"]["job_fit_score"] = None
            return state

        resume_skills = state.get("resume_data", {}).get("skills", [])
        required_skills = job_data.get("required_skills", [])
        preferred_skills = job_data.get("preferred_skills", [])

        system_prompt = """You are a skill matching expert. Given a candidate's skills and job requirements,
determine which skills match. Consider synonyms and related skills.

Respond in JSON format:
{
    "skill_matches": [
        {"skill": "<required skill>", "matched": <boolean>, "confidence": <0-1>},
        ...
    ],
    "job_fit_score": <0-100>
}"""

        user_content = f"""Candidate Skills: {', '.join(resume_skills)}

Required Skills: {', '.join(required_skills)}
Preferred Skills: {', '.join(preferred_skills)}

Job Description: {job_data.get('description', 'N/A')}"""

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_content),
        ]

        response = self.llm.invoke(messages)

        try:
            content = response.content
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]
            result = json.loads(content.strip())
            state["analysis_result"]["skill_matches"] = result.get("skill_matches", [])
            state["analysis_result"]["job_fit_score"] = result.get("job_fit_score")
        except (json.JSONDecodeError, IndexError):
            state["analysis_result"]["skill_matches"] = []
            state["analysis_result"]["job_fit_score"] = None

        return state

    def _suggestions_node(self, state: AgentState) -> AgentState:
        """Generate improvement suggestions."""
        resume_text = state.get("resume_data", {}).get("formatted", "")
        analysis = state.get("analysis_result", {})

        system_prompt = """You are a resume improvement expert. Based on the analysis, provide specific,
actionable suggestions for improvement.

Respond in JSON format:
{
    "suggestions": [
        {"section": "<section name>", "suggestion": "<specific suggestion>", "priority": "high|medium|low"},
        ...
    ]
}"""

        user_content = f"""Resume:
{resume_text}

Current Analysis:
- Score: {analysis.get('overall_score', 'N/A')}
- Weaknesses: {', '.join(analysis.get('weaknesses', []))}"""

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_content),
        ]

        response = self.llm.invoke(messages)

        try:
            content = response.content
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]
            result = json.loads(content.strip())
            state["analysis_result"]["suggestions"] = result.get("suggestions", [])
        except (json.JSONDecodeError, IndexError):
            state["analysis_result"]["suggestions"] = []

        return state

    async def analyze(self, request: AnalyzeRequest) -> AnalyzeResponse:
        """Analyze a resume and optionally match against a job."""
        formatted_resume = _format_resume_for_prompt(request.resume)

        initial_state: AgentState = {
            "messages": [],
            "resume_data": {
                "formatted": formatted_resume,
                "skills": request.resume.skills,
            },
            "job_data": request.job_description.model_dump() if request.job_description else None,
            "analysis_result": None,
            "current_task": "analyze",
        }

        # Run the graph
        final_state = self.graph.invoke(initial_state)
        result = final_state.get("analysis_result", {})

        return AnalyzeResponse(
            overall_score=result.get("overall_score", 70),
            summary=result.get("summary", "Analysis complete"),
            strengths=result.get("strengths", []),
            weaknesses=result.get("weaknesses", []),
            suggestions=[
                ImprovementSuggestion(**s) for s in result.get("suggestions", []) if isinstance(s, dict)
            ],
            skill_matches=[SkillMatch(**sm) for sm in result.get("skill_matches", []) if isinstance(sm, dict)],
            job_fit_score=result.get("job_fit_score"),
        )

    async def generate_summary(self, request: GenerateSummaryRequest) -> GenerateSummaryResponse:
        """Generate a professional summary for a resume."""
        formatted_resume = _format_resume_for_prompt(request.resume)

        tone_instructions = {
            "professional": "formal and polished",
            "creative": "engaging and unique",
            "technical": "precise and skills-focused",
        }

        system_prompt = f"""You are an expert resume writer. Generate a {tone_instructions[request.tone]}
professional summary in approximately {request.max_words} words.

The summary should highlight key strengths, experience, and value proposition.
Return ONLY the summary text, no additional formatting or explanation."""

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=f"Generate a summary for:\n\n{formatted_resume}"),
        ]

        response = self.llm.invoke(messages)
        summary = response.content.strip()
        word_count = len(summary.split())

        return GenerateSummaryResponse(summary=summary, word_count=word_count)

    async def tailor_resume(self, request: TailorResumeRequest) -> TailorResumeResponse:
        """Tailor a resume for a specific job."""
        formatted_resume = _format_resume_for_prompt(request.resume)

        system_prompt = """You are an expert resume tailoring specialist. Modify the resume sections
to better match the job description while keeping content truthful.

Respond in JSON format:
{
    "tailored_sections": [
        {
            "section": "<section name>",
            "original": "<original content or null>",
            "tailored": "<improved content>",
            "changes_made": ["<change 1>", ...]
        },
        ...
    ],
    "keywords_added": ["<keyword>", ...],
    "overall_recommendations": ["<recommendation>", ...]
}"""

        user_content = f"""Resume:
{formatted_resume}

Target Job:
Title: {request.job_description.title}
Company: {request.job_description.company or 'N/A'}
Description: {request.job_description.description}
Required Skills: {', '.join(request.job_description.required_skills)}
Preferred Skills: {', '.join(request.job_description.preferred_skills)}"""

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_content),
        ]

        response = self.llm.invoke(messages)

        try:
            content = response.content
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]
            result = json.loads(content.strip())

            return TailorResumeResponse(
                tailored_sections=[TailoredSection(**ts) for ts in result.get("tailored_sections", [])],
                keywords_added=result.get("keywords_added", []),
                overall_recommendations=result.get("overall_recommendations", []),
            )
        except (json.JSONDecodeError, IndexError):
            return TailorResumeResponse(
                tailored_sections=[],
                keywords_added=[],
                overall_recommendations=["Unable to process. Please try again."],
            )


# Singleton instance
_agent: ResumeAgent | None = None


def get_agent() -> ResumeAgent:
    """Get or create the resume agent singleton."""
    global _agent
    if _agent is None:
        _agent = ResumeAgent()
    return _agent
