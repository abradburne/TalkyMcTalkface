"""
FastAPI routers.
"""
from app.routers.health import router as health_router
from app.routers.voices import router as voices_router
from app.routers.jobs import router as jobs_router
from app.routers.model import router as model_router

__all__ = ['health_router', 'voices_router', 'jobs_router', 'model_router']
