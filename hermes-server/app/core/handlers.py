import logging
from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.errors import AppException, ErrorCode, ERROR_MESSAGES

logger = logging.getLogger(__name__)


async def app_exception_handler(_request: Request, exc: AppException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"code": exc.code.value, "msg": exc.msg, **({"details": exc.details} if exc.details else {})},
    )


async def http_exception_handler(_request: Request, exc: StarletteHTTPException) -> JSONResponse:
    code = _map_http_status_to_code(exc.status_code)
    return JSONResponse(
        status_code=exc.status_code,
        content={"code": code.value, "msg": str(exc.detail)},
    )


async def validation_exception_handler(_request: Request, exc: RequestValidationError) -> JSONResponse:
    errors = []
    for err in exc.errors():
        loc = ".".join(str(l) for l in err.get("loc", []))
        errors.append({"field": loc, "message": err.get("msg", "")})
    return JSONResponse(
        status_code=422,
        content={
            "code": ErrorCode.VALIDATION_ERROR.value,
            "msg": ERROR_MESSAGES[ErrorCode.VALIDATION_ERROR],
            "details": errors,
        },
    )


async def generic_exception_handler(_request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled exception")
    return JSONResponse(
        status_code=500,
        content={"code": ErrorCode.INTERNAL_ERROR.value, "msg": ERROR_MESSAGES[ErrorCode.INTERNAL_ERROR]},
    )


def _map_http_status_to_code(status_code: int) -> ErrorCode:
    mapping = {
        400: ErrorCode.RESOURCE_BAD_REQUEST,
        401: ErrorCode.AUTH_UNAUTHORIZED,
        403: ErrorCode.RESOURCE_FORBIDDEN,
        404: ErrorCode.RESOURCE_NOT_FOUND,
        409: ErrorCode.RESOURCE_CONFLICT,
    }
    return mapping.get(status_code, ErrorCode.INTERNAL_ERROR)
