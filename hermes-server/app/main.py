from contextlib import asynccontextmanager
import logging
import time
import uuid
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from starlette.exceptions import HTTPException as StarletteHTTPException
from app.database import init_db, get_engine
from app.config import get_settings
from app.core.errors import AppException
from app.core.handlers import app_exception_handler, http_exception_handler, validation_exception_handler, generic_exception_handler
from app.api.auth import router as auth_router
from app.api.rooms import router as rooms_router
from app.api.machines import router as machines_router
from app.api.gateways import router as gateways_router
from app.api.agents import router as agents_router
from app.api.ws import router as ws_router
from app.models import User, Room, RoomMember, Message, Machine, Agent, RoomAgent

settings = get_settings()
logger = logging.getLogger("hermes")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    logger.info("=== Hermes Server started ===")
    yield
    logger.info("=== Hermes Server shutdown ===")


app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    lifespan=lifespan,
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    request_id = str(uuid.uuid4())[:8]
    request.state.request_id = request_id
    start = time.time()

    logger.info(f"[{request_id}] --> {request.method} {request.url.path}")

    try:
        response = await call_next(request)
        duration = (time.time() - start) * 1000
        logger.info(f"[{request_id}] <-- {response.status_code} ({duration:.0f}ms)")
        response.headers["X-Request-ID"] = request_id
        return response
    except Exception as e:
        duration = (time.time() - start) * 1000
        logger.error(f"[{request_id}] <-- ERROR ({duration:.0f}ms) {type(e).__name__}: {e}")
        raise


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(StarletteHTTPException, http_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(Exception, generic_exception_handler)

app.include_router(auth_router)
app.include_router(rooms_router)
app.include_router(machines_router)
app.include_router(gateways_router)
app.include_router(agents_router)
app.include_router(ws_router)


@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.0.0"}


@app.get("/")
async def root():
    return {"message": "Hermes App API", "version": "1.0.0"}
