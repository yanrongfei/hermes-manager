from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User
from app.core.security import verify_password, get_password_hash, create_access_token, create_refresh_token, decode_token

class AuthService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_user_by_username(self, username: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.username == username))
        return result.scalar_one_or_none()

    async def get_user_by_id(self, user_id: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def create_user(self, username: str, password: str) -> User:
        user = User(
            username=username,
            password_hash=get_password_hash(password)
        )
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        return user

    async def authenticate_user(self, username: str, password: str) -> Optional[User]:
        user = await self.get_user_by_username(username)
        if not user or not verify_password(password, user.password_hash):
            return None
        return user

    def create_tokens(self, user_id: str, username: str) -> dict:
        return {
            "access_token": create_access_token({"sub": user_id, "username": username}),
            "refresh_token": create_refresh_token({"sub": user_id})
        }

    async def refresh_access_token(self, refresh_token: str) -> Optional[dict]:
        payload = decode_token(refresh_token)
        if not payload or payload.get("type") != "refresh":
            return None
        user = await self.get_user_by_id(payload.get("sub"))
        if not user:
            return None
        return {
            "access_token": create_access_token({"sub": user.id, "username": user.username})
        }