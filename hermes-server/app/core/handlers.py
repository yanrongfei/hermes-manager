import logging
import traceback
import uuid
from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.errors import AppException, ErrorCode, ERROR_MESSAGES

logger = logging.getLogger(__name__)


def _build_response(code: str, msg: str, details=None, request_id: str = None) -> dict:
    resp = {"code": code, "msg": msg}
    if details:
        resp["details"] = details
    if request_id:
        resp["request_id"] = request_id
    return resp


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    request_id = request.state.__dict__.get("request_id") if hasattr(request.state, "request_id") else None
    logger.warning(f"[{exc.code.value}] {request.method} {request.url.path} -> {exc.msg}")
    return JSONResponse(
        status_code=exc.status_code,
        content=_build_response(exc.code.value, exc.msg, exc.details, request_id),
    )


async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    logger.warning(f"[HTTP {exc.status_code}] {request.method} {request.url.path} -> {exc.detail}")
    code = _map_http_status_to_code(exc.status_code)
    return JSONResponse(
        status_code=exc.status_code,
        content=_build_response(code.value, str(exc.detail)),
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    errors = []
    for err in exc.errors():
        field = ".".join(str(l) for l in err.get("loc", [])[1:])  # skip 'body'
        errors.append({"field": field or "unknown", "message": err.get("msg", ""), "type": err.get("type", "")})
    logger.warning(f"[VALIDATION_ERROR] {request.method} {request.url.path} -> {len(errors)} field(s) invalid")
    return JSONResponse(
        status_code=422,
        content=_build_response(
            ErrorCode.VALIDATION_ERROR.value,
            "请求参数不合法，请检查以下字段",
            errors,
        ),
    )


async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    error_id = str(uuid.uuid4())[:8]
    logger.error(f"[INTERNAL_ERROR:{error_id}] {request.method} {request.url.path}\n{traceback.format_exc()}")
    return JSONResponse(
        status_code=500,
        content=_build_response(
            ErrorCode.INTERNAL_ERROR.value,
            f"服务器内部错误，请联系管理员，错误编号: {error_id}",
        ),
    )


def _map_http_status_to_code(status_code: int) -> ErrorCode:
    mapping = {
        400: ErrorCode.RESOURCE_BAD_REQUEST,
        401: ErrorCode.AUTH_UNAUTHORIZED,
        403: ErrorCode.RESOURCE_FORBIDDEN,
        404: ErrorCode.RESOURCE_NOT_FOUND,
        405: ErrorCode.RESOURCE_BAD_REQUEST,
        409: ErrorCode.RESOURCE_CONFLICT,
        422: ErrorCode.VALIDATION_ERROR,
        429: ErrorCode.RESOURCE_BAD_REQUEST,
    }
    return mapping.get(status_code, ErrorCode.INTERNAL_ERROR)
