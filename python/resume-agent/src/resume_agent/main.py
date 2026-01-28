"""FastAPI application entry point."""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from resume_agent.api.routes import router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup: validate config
    if not os.getenv("OPENAI_API_KEY"):
        print("WARNING: OPENAI_API_KEY not set. Agent calls will fail.")
    yield
    # Shutdown: cleanup if needed


app = FastAPI(
    title="Resume Agent API",
    description="AI-powered resume analysis and improvement service",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS middleware for cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routes
app.include_router(router, prefix="/api/v1")


@app.get("/")
async def root():
    """Root endpoint with API info."""
    return {
        "name": "Resume Agent API",
        "version": "0.1.0",
        "docs": "/docs",
        "health": "/api/v1/health",
    }


def main():
    """Run the application with uvicorn."""
    import uvicorn

    uvicorn.run(
        "resume_agent.main:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000")),
        reload=os.getenv("ENV", "development") == "development",
    )


if __name__ == "__main__":
    main()
