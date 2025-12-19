"""
Async database setup with SQLAlchemy and aiosqlite.
"""
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy import event, text

from app.config import DATABASE_URL, ensure_directories
from app.models import Base


# Create async engine
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    future=True,
)


# Session factory
async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def enable_wal_mode():
    """Enable WAL mode for SQLite concurrent read/write access."""
    async with engine.begin() as conn:
        await conn.execute(text('PRAGMA journal_mode=WAL'))
        await conn.execute(text('PRAGMA synchronous=NORMAL'))


async def init_db():
    """Initialize database - create tables if they don't exist."""
    ensure_directories()

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Enable WAL mode after tables are created
    await enable_wal_mode()


async def close_db():
    """Close database connections."""
    await engine.dispose()


async def get_db():
    """
    Dependency that provides an async database session.

    Usage:
        @app.get('/items')
        async def get_items(db: AsyncSession = Depends(get_db)):
            ...
    """
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
