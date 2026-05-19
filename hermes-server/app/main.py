from contextlib import asynccontextmanager
import logging
import time
import uuid
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.types import ASGIApp, Receive, Scope, Send
from app.database import init_db, get_engine
from app.config import get_settings
from app.core.errors import AppException
from app.core.handlers import app_exception_handler, http_exception_handler, validation_exception_handler, generic_exception_handler
from app.api.auth import router as auth_router
from app.api.rooms import router as rooms_router
from app.api.gateways import router as gateways_router
from app.api.agents import router as agents_router
from app.api.ws import router as ws_router
from app.models import User, Room, RoomMember, Message, Gateway, Profile, Agent, RoomAgent

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


class LogRequestsMiddleware:
    """Pure ASGI middleware that logs HTTP requests and transparently passes WebSocket connections."""

    def __init__(self, app: ASGIApp):
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request_id = str(uuid.uuid4())[:8]
        path = scope.get("path", "")
        method = scope.get("method", "")

        start = time.time()
        logger.info(f"[{request_id}] --> {method} {path}")

        async def send_with_log(message):
            if message["type"] == "http.response.start":
                status_code = message.get("status", 0)
                duration = (time.time() - start) * 1000
                logger.info(f"[{request_id}] <-- {status_code} ({duration:.0f}ms)")
            await send(message)

        try:
            await self.app(scope, receive, send_with_log)
        except Exception as e:
            duration = (time.time() - start) * 1000
            logger.error(f"[{request_id}] <-- ERROR ({duration:.0f}ms) {type(e).__name__}: {e}")
            raise


app.add_middleware(LogRequestsMiddleware)


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
app.include_router(gateways_router)
app.include_router(agents_router)
app.include_router(ws_router)


@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.0.0"}


@app.get("/")
async def root():
    return {"message": "Hermes App API", "version": "1.0.0"}
