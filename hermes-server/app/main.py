from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import init_db, get_engine
from app.config import get_settings
from app.api.auth import router as auth_router
from app.api.rooms import router as rooms_router
from app.api.machines import router as machines_router
from app.api.gateways import router as gateways_router
from app.api.agents import router as agents_router
from app.api.ws import router as ws_router

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(rooms_router)
app.include_router(machines_router)
app.include_router(gateways_router)
app.include_router(agents_router)
app.include_router(ws_router)

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/")
async def root():
    return {"message": "Hermes App API"}
