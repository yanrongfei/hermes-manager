from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.core.security import decode_token
from app.core.errors import AppException, ErrorCode
from app.services.auth import AuthService

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
):
    token = credentials.credentials
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise AppException(ErrorCode.AUTH_INVALID_TOKEN, status_code=401)
    user_id = payload.get("sub")
    if not user_id:
        raise AppException(ErrorCode.AUTH_INVALID_TOKEN, status_code=401)
    service = AuthService(db)
    user = await service.get_user_by_id(user_id)
    if not user:
        raise AppException(ErrorCode.AUTH_UNAUTHORIZED, status_code=401)
    return user
