from enum import Enum
from typing import Any, Optional


class ErrorCode(str, Enum):
    # Auth
    AUTH_USERNAME_EXISTS = "AUTH_001"
    AUTH_INVALID_CREDENTIALS = "AUTH_002"
    AUTH_INVALID_TOKEN = "AUTH_003"
    AUTH_TOKEN_EXPIRED = "AUTH_004"
    AUTH_UNAUTHORIZED = "AUTH_005"

    # Validation
    VALIDATION_ERROR = "VALID_001"

    # Resource
    RESOURCE_NOT_FOUND = "RES_001"
    RESOURCE_FORBIDDEN = "RES_002"
    RESOURCE_CONFLICT = "RES_003"
    RESOURCE_BAD_REQUEST = "RES_004"

    # Gateway
    GATEWAY_UNREACHABLE = "GW_001"

    # Internal
    INTERNAL_ERROR = "SYS_001"


ERROR_MESSAGES: dict[ErrorCode, str] = {
    ErrorCode.AUTH_USERNAME_EXISTS: "用户名已存在",
    ErrorCode.AUTH_INVALID_CREDENTIALS: "用户名或密码错误",
    ErrorCode.AUTH_INVALID_TOKEN: "无效的认证令牌",
    ErrorCode.AUTH_TOKEN_EXPIRED: "认证令牌已过期",
    ErrorCode.AUTH_UNAUTHORIZED: "未授权，请先登录",
    ErrorCode.VALIDATION_ERROR: "请求参数校验失败",
    ErrorCode.RESOURCE_NOT_FOUND: "请求的资源不存在",
    ErrorCode.RESOURCE_FORBIDDEN: "无权访问该资源",
    ErrorCode.RESOURCE_CONFLICT: "资源冲突",
    ErrorCode.RESOURCE_BAD_REQUEST: "请求参数错误",
    ErrorCode.GATEWAY_UNREACHABLE: "网关连接失败",
    ErrorCode.INTERNAL_ERROR: "服务器内部错误",
}


class AppException(Exception):
    def __init__(
        self,
        code: ErrorCode,
        msg: Optional[str] = None,
        status_code: int = 400,
        details: Optional[Any] = None,
    ):
        self.code = code
        self.msg = msg or ERROR_MESSAGES.get(code, "未知错误")
        self.status_code = status_code
        self.details = details
        super().__init__(self.msg)


def error_response(
    code: ErrorCode,
    msg: Optional[str] = None,
    details: Optional[Any] = None,
) -> dict:
    return {
        "code": code.value,
        "msg": msg or ERROR_MESSAGES.get(code, "未知错误"),
        **({"details": details} if details else {}),
    }
