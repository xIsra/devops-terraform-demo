# Resume Agent

AI-powered resume analysis and improvement service built with LangChain and LangGraph.

## Features

- **Resume Analysis**: Get comprehensive feedback on resume quality, strengths, and weaknesses
- **Job Matching**: Match your resume against job descriptions with skill gap analysis
- **Summary Generation**: Generate professional summaries in different tones
- **Resume Tailoring**: Get tailored recommendations for specific job applications

## Quick Start

### Prerequisites

- Python 3.10+
- [UV](https://docs.astral.sh/uv/) package manager
- OpenAI API key

### Installation

```bash
# Clone and navigate to the project
cd python/resume-agent

# Install dependencies
uv sync

# Copy environment template
cp .env.example .env

# Edit .env with your OpenAI API key
```

### Running the Server

```bash
# Development mode (with hot reload)
uv run resume-agent

# Or directly with uvicorn
uv run uvicorn resume_agent.main:app --reload
```

The API will be available at `http://localhost:8000`

### API Documentation

Once running, visit:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## API Endpoints

### `POST /api/v1/analyze`

Analyze a resume and optionally match against a job description.

```json
{
  "resume": {
    "name": "John Doe",
    "email": "john@example.com",
    "summary": "Experienced software engineer...",
    "experience": [
      {
        "title": "Senior Developer",
        "company": "Tech Corp",
        "duration": "2020-2024",
        "description": "Led development of..."
      }
    ],
    "education": [
      {
        "degree": "BS Computer Science",
        "institution": "MIT",
        "year": "2018"
      }
    ],
    "skills": ["Python", "TypeScript", "AWS"]
  },
  "job_description": {
    "title": "Staff Engineer",
    "company": "Startup Inc",
    "description": "Looking for...",
    "required_skills": ["Python", "Kubernetes"],
    "preferred_skills": ["Go", "Terraform"]
  }
}
```

### `POST /api/v1/generate-summary`

Generate a professional summary for a resume.

```json
{
  "resume": { ... },
  "tone": "professional",
  "max_words": 100
}
```

### `POST /api/v1/tailor`

Tailor a resume for a specific job.

```json
{
  "resume": { ... },
  "job_description": { ... }
}
```

### `GET /api/v1/health`

Health check endpoint.

## Docker

```bash
# Build
docker build -t resume-agent .

# Run
docker run -p 8000:8000 -e OPENAI_API_KEY=sk-xxx resume-agent
```

## Architecture

The agent uses LangGraph to orchestrate a multi-step analysis workflow:

1. **Analyze Node**: Evaluates overall resume quality
2. **Match Skills Node**: Matches skills against job requirements
3. **Suggestions Node**: Generates actionable improvements

```
┌─────────┐    ┌──────────────┐    ┌─────────────────────┐
│ Analyze │───▶│ Match Skills │───▶│ Generate Suggestions│───▶ END
└─────────┘    └──────────────┘    └─────────────────────┘
```

## Environment Variables

| Variable         | Description                              | Default       |
| ---------------- | ---------------------------------------- | ------------- |
| `OPENAI_API_KEY` | OpenAI API key                           | Required      |
| `OPENAI_MODEL`   | Model to use                             | `gpt-4o-mini` |
| `HOST`           | Server host                              | `0.0.0.0`     |
| `PORT`           | Server port                              | `8000`        |
| `ENV`            | Environment (`development`/`production`) | `development` |
| `CORS_ORIGINS`   | Allowed CORS origins (comma-separated)   | `*`           |

## Development

```bash
# Install with dev dependencies
uv sync --all-extras

# Run tests
uv run pytest

# Type checking
uv run mypy src/
```

## License

MIT
