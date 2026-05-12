from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.schemas.auth import UserRegister, UserLogin, TokenResponse, TokenRefresh, UserResponse
from app.services.auth import AuthService
from app.core.deps import get_current_user
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(data: UserRegister, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    existing = await service.get_user_by_username(data.username)
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")
    user = await service.create_user(data.username, data.password)
    return user

@router.post("/login", response_model=TokenResponse)
async def login(data: UserLogin, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    user = await service.authenticate_user(data.username, data.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    tokens = service.create_tokens(user.id, user.username)
    return tokens

@router.post("/refresh", response_model=dict)
async def refresh(data: TokenRefresh, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    result = await service.refresh_access_token(data.refresh_token)
    if not result:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    return result

@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user