# Hermes App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现完整的 Hermes App（Flutter + FastAPI），支持多用户群聊、多 Agent 管理

**Architecture:** 分阶段实现：
- Phase 1-2: 服务端骨架 + JWT 认证 + 数据库模型
- Phase 3: 服务端核心 API（Rooms/Messages/WebSocket）
- Phase 4: 服务端机器/Agent 管理
- Phase 5: App 骨架 + 认证
- Phase 6: App 群聊功能
- Phase 7: App 发现/设置页面

**Tech Stack:**
- Backend: Python 3.11+ / FastAPI / SQLAlchemy 2.0 / SQLite / PyJWT
- App: Flutter 3.x / Riverpod / dio / web_socket_channel / go_router

---

## Phase 1: 服务端骨架 (hermes-server)

### Task 1: 初始化 FastAPI 项目结构

**Files:**
- Create: `hermes-server/requirements.txt`
- Create: `hermes-server/app/__init__.py`
- Create: `hermes-server/app/main.py`
- Create: `hermes-server/app/config.py`
- Create: `hermes-server/app/database.py`

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p hermes-server/app/{models,schemas,api,services,core}
mkdir -p hermes-server/tests
touch hermes-server/app/__init__.py
touch hermes-server/app/models/__init__.py
touch hermes-server/app/schemas/__init__.py
touch hermes-server/app/api/__init__.py
touch hermes-server/app/services/__init__.py
touch hermes-server/app/core/__init__.py
touch hermes-server/tests/__init__.py
```

- [ ] **Step 2: 创建 requirements.txt**

```txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
sqlalchemy==2.0.25
pydantic==2.5.3
pydantic-settings==2.1.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
aiosqlite==0.19.0
httpx==0.26.0
websockets==12.0
pytest==7.4.4
pytest-asyncio==0.23.3
```

- [ ] **Step 3: 创建 config.py**

```python
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    APP_NAME: str = "Hermes App"
    DEBUG: bool = True

    # JWT
    JWT_SECRET_KEY: str = "your-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./hermes.db"

    class Config:
        env_file = ".env"

@lru_cache()
def get_settings() -> Settings:
    return Settings()
```

- [ ] **Step 4: 创建 database.py**

```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import get_settings

settings = get_settings()

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    future=True
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)

class Base(DeclarativeBase):
    pass

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
```

- [ ] **Step 5: 创建 main.py**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import init_db
from app.config import get_settings

settings = get_settings()

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup():
    await init_db()

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/")
async def root():
    return {"message": "Hermes App API"}
```

- [ ] **Step 6: 提交**

```bash
cd hermes-server && pip install -r requirements.txt
cd .. && git add hermes-server/requirements.txt hermes-server/app/ && git commit -m "feat(server): init FastAPI project structure"
```

---

### Task 2: 用户认证模块

**Files:**
- Create: `hermes-server/app/core/security.py`
- Create: `hermes-server/app/models/user.py`
- Create: `hermes-server/app/schemas/auth.py`
- Create: `hermes-server/app/services/auth.py`
- Create: `hermes-server/app/api/auth.py`
- Create: `hermes-server/tests/test_auth.py`

- [ ] **Step 1: 创建 security.py (JWT + Password utils)**

```python
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.config import get_settings

settings = get_settings()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

def decode_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        return payload
    except JWTError:
        return None
```

- [ ] **Step 2: 创建 user.py model**

```python
from sqlalchemy import Column, String, Integer, Boolean, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))
    multi_device = Column(Boolean, default=False)

    # Relationships
    rooms = relationship("RoomMember", back_populates="user")
    machines = relationship("Machine", back_populates="user")
```

- [ ] **Step 3: 创建 auth.py schemas**

```python
from pydantic import BaseModel, Field

class UserRegister(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)

class UserLogin(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class TokenRefresh(BaseModel):
    refresh_token: str

class UserResponse(BaseModel):
    id: str
    username: str
    multi_device: bool

    class Config:
        from_attributes = True
```

- [ ] **Step 4: 创建 auth.py service**

```python
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
```

- [ ] **Step 5: 创建 auth.py api**

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.schemas.auth import UserRegister, UserLogin, TokenResponse, TokenRefresh, UserResponse
from app.services.auth import AuthService

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
async def get_me(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(lambda: None)  # Placeholder for JWT dependency
):
    # TODO: Add JWT dependency
    pass
```

- [ ] **Step 6: 提交**

```bash
git add hermes-server/app/core/security.py hermes-server/app/models/user.py hermes-server/app/schemas/auth.py hermes-server/app/services/auth.py hermes-server/app/api/auth.py
git commit -m "feat(server): add user auth module with JWT"
```

---

### Task 3: 添加 JWT 认证依赖

**Files:**
- Create: `hermes-server/app/core/deps.py`
- Modify: `hermes-server/app/api/auth.py`

- [ ] **Step 1: 创建 deps.py (JWT 认证依赖)**

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.core.security import decode_token
from app.services.auth import AuthService

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
):
    token = credentials.credentials
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid token")
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")
    service = AuthService(db)
    user = await service.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user
```

- [ ] **Step 2: 更新 auth.py API**

```python
# 在 auth.py 的 get_me 中替换为:
@router.get("/me", response_model=UserResponse)
async def get_me(current_user = Depends(get_current_user)):
    return current_user
```

- [ ] **Step 3: 提交**

```bash
git add hermes-server/app/core/deps.py && git commit -m "feat(server): add JWT auth dependency"
```

---

## Phase 2: 服务端数据库模型

### Task 4: Room & Message 模型

**Files:**
- Create: `hermes-server/app/models/room.py`
- Create: `hermes-server/app/models/message.py`
- Create: `hermes-server/app/schemas/room.py`
- Create: `hermes-server/app/schemas/message.py`

- [ ] **Step 1: 创建 room.py model**

```python
from sqlalchemy import Column, String, Integer, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class Room(Base):
    __tablename__ = "rooms"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    avatar = Column(String, nullable=True)
    owner_id = Column(String, ForeignKey("users.id"), nullable=False)
    mode = Column(String, default="broadcast")  # broadcast/mention/router/pipeline
    trigger_tokens = Column(Integer, default=100000)
    max_history_tokens = Column(Integer, default=32000)
    tail_message_count = Column(Integer, default=20)
    invite_code = Column(String, nullable=True)
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    owner = relationship("User", foreign_keys=[owner_id])
    members = relationship("RoomMember", back_populates="room")
    agents = relationship("RoomAgent", back_populates="room")
    messages = relationship("Message", back_populates="room")

class RoomMember(Base):
    __tablename__ = "room_members"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    role = Column(String, default="member")  # owner/admin/member
    joined_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    room = relationship("Room", back_populates="members")
    user = relationship("User", back_populates="rooms")
```

- [ ] **Step 2: 创建 message.py model**

```python
from sqlalchemy import Column, String, Integer, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class Message(Base):
    __tablename__ = "messages"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    sender_id = Column(String, nullable=True)
    sender_type = Column(String, nullable=True)  # 'user'/'agent'
    sender_name = Column(String, nullable=True)
    content = Column(Text, nullable=False)
    content_type = Column(String, default="text")  # text/image/voice
    extra = Column(Text, nullable=True)  # JSON for image_url, voice_text etc.
    parent_id = Column(String, nullable=True)  # for threading/pipeline
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    room = relationship("Room", back_populates="messages")
```

- [ ] **Step 3: 创建 room.py schemas**

```python
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class RoomCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    avatar: Optional[str] = None
    mode: str = Field(default="broadcast")

class RoomUpdate(BaseModel):
    name: Optional[str] = None
    avatar: Optional[str] = None
    mode: Optional[str] = None

class RoomResponse(BaseModel):
    id: str
    name: str
    avatar: Optional[str]
    owner_id: str
    mode: str
    invite_code: Optional[str]
    created_at: int

    class Config:
        from_attributes = True

class RoomDetail(RoomResponse):
    members: List["MemberResponse"] = []

class RoomJoin(BaseModel):
    invite_code: str

class MemberResponse(BaseModel):
    id: str
    user_id: str
    username: str
    role: str
    joined_at: int

    class Config:
        from_attributes = True
```

- [ ] **Step 4: 创建 message.py schemas**

```python
from pydantic import BaseModel
from typing import Optional, List

class MessageCreate(BaseModel):
    content: str
    content_type: str = "text"
    extra: Optional[str] = None

class MessageResponse(BaseModel):
    id: str
    room_id: str
    sender_id: Optional[str]
    sender_type: Optional[str]
    sender_name: Optional[str]
    content: str
    content_type: str
    extra: Optional[str]
    parent_id: Optional[str]
    created_at: int

    class Config:
        from_attributes = True

class MessageListResponse(BaseModel):
    messages: List[MessageResponse]
    has_more: bool
```

- [ ] **Step 5: 提交**

```bash
git add hermes-server/app/models/room.py hermes-server/app/models/message.py hermes-server/app/schemas/room.py hermes-server/app/schemas/message.py
git commit -m "feat(server): add Room and Message models"
```

---

### Task 5: Machine & Agent 模型

**Files:**
- Create: `hermes-server/app/models/machine.py`
- Create: `hermes-server/app/models/agent.py`
- Create: `hermes-server/app/schemas/machine.py`
- Create: `hermes-server/app/schemas/agent.py`

- [ ] **Step 1: 创建 machine.py model**

```python
from sqlalchemy import Column, String, Integer, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class Machine(Base):
    __tablename__ = "machines"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=True)
    address = Column(String, nullable=False)  # IP:Port
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    user = relationship("User", back_populates="machines")
    agents = relationship("Agent", back_populates="machine")
```

- [ ] **Step 2: 创建 agent.py model**

```python
from sqlalchemy import Column, String, Integer, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from app.database import Base

class Agent(Base):
    __tablename__ = "agents"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    machine_id = Column(String, ForeignKey("machines.id"), nullable=False)
    remote_id = Column(String, nullable=False)  # ID on Hermes Gateway
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    avatar = Column(String, nullable=True)
    profile = Column(String, nullable=True)
    invited = Column(Boolean, default=False)
    created_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    machine = relationship("Machine", back_populates="agents")
    rooms = relationship("RoomAgent", back_populates="agent")

class RoomAgent(Base):
    __tablename__ = "room_agents"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    agent_id = Column(String, ForeignKey("agents.id"), nullable=False)
    joined_at = Column(Integer, default=lambda: int(datetime.utcnow().timestamp()))

    # Relationships
    room = relationship("Room", back_populates="agents")
    agent = relationship("Agent", back_populates="rooms")
```

- [ ] **Step 3: 创建 machine.py schemas**

```python
from pydantic import BaseModel, Field
from typing import Optional

class MachineCreate(BaseModel):
    name: Optional[str] = None
    address: str = Field(..., pattern=r"^\d+\.\d+\.\d+\.\d+:\d+$")

class MachineUpdate(BaseModel):
    name: Optional[str] = None

class MachineResponse(BaseModel):
    id: str
    name: Optional[str]
    address: str
    created_at: int

    class Config:
        from_attributes = True
```

- [ ] **Step 4: 创建 agent.py schemas**

```python
from pydantic import BaseModel
from typing import Optional

class AgentCreate(BaseModel):
    machine_id: str
    remote_id: str
    name: str
    description: Optional[str] = None
    avatar: Optional[str] = None
    profile: Optional[str] = None
    invited: bool = False

class AgentUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    avatar: Optional[str] = None
    profile: Optional[str] = None

class AgentResponse(BaseModel):
    id: str
    machine_id: str
    remote_id: str
    name: str
    description: Optional[str]
    avatar: Optional[str]
    profile: Optional[str]
    invited: bool
    created_at: int

    class Config:
        from_attributes = True
```

- [ ] **Step 5: 提交**

```bash
git add hermes-server/app/models/machine.py hermes-server/app/models/agent.py hermes-server/app/schemas/machine.py hermes-server/app/schemas/agent.py
git commit -m "feat(server): add Machine and Agent models"
```

---

## Phase 3: 服务端核心 API

### Task 6: Rooms API

**Files:**
- Create: `hermes-server/app/services/room.py`
- Create: `hermes-server/app/api/rooms.py`

- [ ] **Step 1: 创建 room.py service**

```python
import secrets
from typing import List, Optional
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.room import Room, RoomMember
from app.models.message import Message
from app.models.user import User

class RoomService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_room(self, owner_id: str, name: str, mode: str = "broadcast") -> Room:
        invite_code = secrets.token_urlsafe(6)
        room = Room(
            owner_id=owner_id,
            name=name,
            mode=mode,
            invite_code=invite_code
        )
        self.db.add(room)
        await self.db.commit()
        await self.db.refresh(room)

        # Add owner as member
        member = RoomMember(room_id=room.id, user_id=owner_id, role="owner")
        self.db.add(member)
        await self.db.commit()

        return room

    async def get_room(self, room_id: str) -> Optional[Room]:
        result = await self.db.execute(
            select(Room).where(Room.id == room_id)
        )
        return result.scalar_one_or_none()

    async def get_user_rooms(self, user_id: str) -> List[Room]:
        result = await self.db.execute(
            select(Room)
            .join(RoomMember)
            .where(RoomMember.user_id == user_id)
        )
        return list(result.scalars().all())

    async def get_room_members(self, room_id: str) -> List[RoomMember]:
        result = await self.db.execute(
            select(RoomMember)
            .options(selectinload(RoomMember.user))
            .where(RoomMember.room_id == room_id)
        )
        return list(result.scalars().all())

    async def join_room(self, room_id: str, user_id: str) -> RoomMember:
        member = RoomMember(room_id=room_id, user_id=user_id, role="member")
        self.db.add(member)
        await self.db.commit()
        await self.db.refresh(member)
        return member

    async def join_by_code(self, invite_code: str, user_id: str) -> Optional[Room]:
        result = await self.db.execute(
            select(Room).where(Room.invite_code == invite_code)
        )
        room = result.scalar_one_or_none()
        if not room:
            return None
        # Check if already member
        existing = await self.db.execute(
            select(RoomMember).where(
                and_(RoomMember.room_id == room.id, RoomMember.user_id == user_id)
            )
        )
        if existing.scalar_one_or_none():
            return room
        await self.join_room(room.id, user_id)
        return room

    async def leave_room(self, room_id: str, user_id: str) -> bool:
        result = await self.db.execute(
            select(RoomMember).where(
                and_(RoomMember.room_id == room_id, RoomMember.user_id == user_id)
            )
        )
        member = result.scalar_one_or_none()
        if not member or member.role == "owner":
            return False
        await self.db.delete(member)
        await self.db.commit()
        return True

    async def is_member(self, room_id: str, user_id: str) -> bool:
        result = await self.db.execute(
            select(RoomMember).where(
                and_(RoomMember.room_id == room_id, RoomMember.user_id == user_id)
            )
        )
        return result.scalar_one_or_none() is not None

    async def get_room_by_code(self, invite_code: str) -> Optional[Room]:
        result = await self.db.execute(
            select(Room).where(Room.invite_code == invite_code)
        )
        return result.scalar_one_or_none()
```

- [ ] **Step 2: 创建 rooms.py API**

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.database import get_db
from app.core.deps import get_current_user
from app.schemas.room import RoomCreate, RoomUpdate, RoomResponse, RoomDetail, MemberResponse
from app.schemas.message import MessageListResponse
from app.services.room import RoomService
from app.models.message import Message

router = APIRouter(prefix="/rooms", tags=["rooms"])

@router.get("", response_model=List[RoomResponse])
async def list_rooms(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    return await service.get_user_rooms(current_user.id)

@router.post("", response_model=RoomResponse, status_code=status.HTTP_201_CREATED)
async def create_room(
    data: RoomCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    return await service.create_room(current_user.id, data.name, data.mode)

@router.get("/{room_id}", response_model=RoomDetail)
async def get_room(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    room = await service.get_room(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    if not await service.is_member(room_id, current_user.id):
        raise HTTPException(status_code=403, detail="Not a member")
    members = await service.get_room_members(room_id)
    return {
        **RoomResponse.model_validate(room).model_dump(),
        "members": [
            {
                "id": m.id,
                "user_id": m.user_id,
                "username": m.user.username,
                "role": m.role,
                "joined_at": m.joined_at
            }
            for m in members
        ]
    }

@router.post("/join", response_model=RoomResponse)
async def join_room_by_code(
    invite_code: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    room = await service.join_by_code(invite_code, current_user.id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    return room

@router.delete("/{room_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
async def leave_room(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    success = await service.leave_room(room_id, current_user.id)
    if not success:
        raise HTTPException(status_code=400, detail="Cannot leave room")
```

- [ ] **Step 3: 提交**

```bash
git add hermes-server/app/services/room.py hermes-server/app/api/rooms.py && git commit -m "feat(server): add Rooms API"
```

---

### Task 7: Messages API

**Files:**
- Create: `hermes-server/app/services/message.py`
- Create: `hermes-server/app/api/messages.py`

- [ ] **Step 1: 创建 message.py service**

```python
from typing import List, Optional
from sqlalchemy import select, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.message import Message
from app.services.room import RoomService

class MessageService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.room_service = RoomService(db)

    async def create_message(
        self,
        room_id: str,
        sender_id: str,
        sender_type: str,
        sender_name: str,
        content: str,
        content_type: str = "text",
        extra: Optional[str] = None,
        parent_id: Optional[str] = None
    ) -> Message:
        message = Message(
            room_id=room_id,
            sender_id=sender_id,
            sender_type=sender_type,
            sender_name=sender_name,
            content=content,
            content_type=content_type,
            extra=extra,
            parent_id=parent_id
        )
        self.db.add(message)
        await self.db.commit()
        await self.db.refresh(message)
        return message

    async def get_messages(
        self,
        room_id: str,
        before: Optional[int] = None,
        limit: int = 50
    ) -> tuple[List[Message], bool]:
        query = select(Message).where(Message.room_id == room_id)
        if before:
            query = query.where(Message.created_at < before)
        query = query.order_by(desc(Message.created_at)).limit(limit + 1)

        result = await self.db.execute(query)
        messages = list(result.scalars().all())
        has_more = len(messages) > limit
        if has_more:
            messages = messages[:limit]
        messages.reverse()
        return messages, has_more

    async def get_recent_messages(self, room_id: str, days: int = 7) -> List[Message]:
        import time
        cutoff = int(time.time()) - (days * 24 * 60 * 60)
        result = await self.db.execute(
            select(Message)
            .where(
                and_(
                    Message.room_id == room_id,
                    Message.created_at >= cutoff
                )
            )
            .order_by(Message.created_at)
        )
        return list(result.scalars().all())
```

- [ ] **Step 2: 创建 messages.py API**

```python
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from app.database import get_db
from app.core.deps import get_current_user
from app.schemas.message import MessageCreate, MessageResponse, MessageListResponse
from app.services.message import MessageService
from app.services.room import RoomService

router = APIRouter(prefix="/rooms/{room_id}/messages", tags=["messages"])

@router.get("", response_model=MessageListResponse)
async def get_messages(
    room_id: str,
    before: Optional[int] = Query(None),
    limit: int = Query(50, ge=1, le=100),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    room_service = RoomService(db)
    if not await room_service.is_member(room_id, current_user.id):
        raise HTTPException(status_code=403, detail="Not a member")

    service = MessageService(db)
    messages, has_more = await service.get_messages(room_id, before, limit)
    return {
        "messages": [MessageResponse.model_validate(m) for m in messages],
        "has_more": has_more
    }
```

- [ ] **Step 3: 提交**

```bash
git add hermes-server/app/services/message.py hermes-server/app/api/messages.py && git commit -m "feat(server): add Messages API"
```

---

### Task 8: WebSocket 聊天

**Files:**
- Create: `hermes-server/app/services/websocket.py`
- Create: `hermes-server/app/api/ws.py`

- [ ] **Step 1: 创建 websocket.py service**

```python
import json
import asyncio
from typing import Dict, Set
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        # room_id -> set of websockets
        self.active_connections: Dict[str, Set[WebSocket]] = {}
        # websocket -> user_id
        self.user_connections: Dict[WebSocket, str] = {}
        # websocket -> room_id
        self.room_connections: Dict[WebSocket, str] = {}
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, room_id: str, user_id: str):
        await websocket.accept()
        async with self._lock:
            if room_id not in self.active_connections:
                self.active_connections[room_id] = set()
            self.active_connections[room_id].add(websocket)
            self.user_connections[websocket] = user_id
            self.room_connections[websocket] = room_id

    async def disconnect(self, websocket: WebSocket):
        async with self._lock:
            room_id = self.room_connections.get(websocket)
            if room_id and room_id in self.active_connections:
                self.active_connections[room_id].discard(websocket)
                if not self.active_connections[room_id]:
                    del self.active_connections[room_id]
            self.user_connections.pop(websocket, None)
            self.room_connections.pop(websocket, None)

    async def send_to_room(self, room_id: str, event: str, data: dict):
        if room_id not in self.active_connections:
            return
        message = json.dumps({"event": event, "data": data})
        dead_connections = set()
        for connection in self.active_connections[room_id]:
            try:
                await connection.send_text(message)
            except Exception:
                dead_connections.add(connection)
        for dead in dead_connections:
            await self.disconnect(dead)

    async def broadcast_to_room(self, room_id: str, event: str, data: dict, exclude: WebSocket = None):
        if room_id not in self.active_connections:
            return
        message = json.dumps({"event": event, "data": data})
        dead_connections = set()
        for connection in self.active_connections[room_id]:
            if connection != exclude:
                try:
                    await connection.send_text(message)
                except Exception:
                    dead_connections.add(connection)
        for dead in dead_connections:
            await self.disconnect(dead)

manager = ConnectionManager()
```

- [ ] **Step 2: 创建 ws.py API (WebSocket endpoint)**

```python
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db, AsyncSessionLocal
from app.core.security import decode_token
from app.services.room import RoomService
from app.services.message import MessageService
from app.services.websocket import manager

router = APIRouter()

@router.websocket("/ws/chat")
async def websocket_chat(
    websocket: WebSocket,
    token: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    # Verify token
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        await websocket.close(code=4001)
        return
    user_id = payload.get("sub")

    # Join room
    data = await websocket.receive_json()
    event = data.get("event")
    if event != "join":
        await websocket.close(code=4002)
        return

    room_id = data.get("data", {}).get("roomId")
    if not room_id:
        await websocket.close(code=4003)
        return

    room_service = RoomService(db)
    if not await room_service.is_member(room_id, user_id):
        await websocket.close(code=4003)
        return

    await manager.connect(websocket, room_id, user_id)

    # Notify room
    await manager.broadcast_to_room(
        room_id,
        "member_joined",
        {"userId": user_id, "roomId": room_id},
        exclude=websocket
    )

    try:
        while True:
            data = await websocket.receive_json()
            event = data.get("event")
            payload_data = data.get("data", {})

            if event == "message":
                content = payload_data.get("content", "")
                async with AsyncSessionLocal() as session:
                    message_service = MessageService(session)
                    msg = await message_service.create_message(
                        room_id=room_id,
                        sender_id=user_id,
                        sender_type="user",
                        sender_name=payload.get("username", "User"),
                        content=content
                    )
                    await manager.broadcast_to_room(
                        room_id,
                        "message",
                        {
                            "id": msg.id,
                            "roomId": room_id,
                            "senderId": user_id,
                            "senderType": "user",
                            "senderName": msg.sender_name,
                            "content": msg.content,
                            "contentType": msg.content_type,
                            "createdAt": msg.created_at
                        }
                    )

            elif event == "typing":
                await manager.broadcast_to_room(
                    room_id,
                    "typing",
                    {"userId": user_id},
                    exclude=websocket
                )

            elif event == "stop_typing":
                await manager.broadcast_to_room(
                    room_id,
                    "stop_typing",
                    {"userId": user_id},
                    exclude=websocket
                )

    except WebSocketDisconnect:
        await manager.disconnect(websocket)
        await manager.broadcast_to_room(
            room_id,
            "member_left",
            {"userId": user_id, "roomId": room_id}
        )
```

- [ ] **Step 3: 在 main.py 中注册 WebSocket 路由**

```python
# Add to imports in main.py
from app.api.ws import router as ws_router

# Add to app startup
app.include_router(ws_router)
```

- [ ] **Step 4: 提交**

```bash
git add hermes-server/app/services/websocket.py hermes-server/app/api/ws.py && git commit -m "feat(server): add WebSocket chat support"
```

---

## Phase 4: 服务端机器/Agent 管理

### Task 9: Machines API

**Files:**
- Create: `hermes-server/app/services/machine.py`
- Create: `hermes-server/app/api/machines.py`

- [ ] **Step 1: 创建 machine.py service**

```python
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.machine import Machine

class MachineService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_machine(self, user_id: str, address: str, name: Optional[str] = None) -> Machine:
        machine = Machine(user_id=user_id, address=address, name=name)
        self.db.add(machine)
        await self.db.commit()
        await self.db.refresh(machine)
        return machine

    async def get_machine(self, machine_id: str, user_id: str) -> Optional[Machine]:
        result = await self.db.execute(
            select(Machine).where(Machine.id == machine_id, Machine.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_user_machines(self, user_id: str) -> List[Machine]:
        result = await self.db.execute(
            select(Machine).where(Machine.user_id == user_id)
        )
        return list(result.scalars().all())

    async def update_machine(self, machine_id: str, user_id: str, name: str) -> Optional[Machine]:
        machine = await self.get_machine(machine_id, user_id)
        if not machine:
            return None
        machine.name = name
        await self.db.commit()
        await self.db.refresh(machine)
        return machine

    async def delete_machine(self, machine_id: str, user_id: str) -> bool:
        machine = await self.get_machine(machine_id, user_id)
        if not machine:
            return False
        await self.db.delete(machine)
        await self.db.commit()
        return True
```

- [ ] **Step 2: 创建 machines.py API**

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.database import get_db
from app.core.deps import get_current_user
from app.schemas.machine import MachineCreate, MachineUpdate, MachineResponse
from app.services.machine import MachineService

router = APIRouter(prefix="/machines", tags=["machines"])

@router.get("", response_model=List[MachineResponse])
async def list_machines(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = MachineService(db)
    return await service.get_user_machines(current_user.id)

@router.post("", response_model=MachineResponse, status_code=status.HTTP_201_CREATED)
async def create_machine(
    data: MachineCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = MachineService(db)
    return await service.create_machine(current_user.id, data.address, data.name)

@router.get("/{machine_id}", response_model=MachineResponse)
async def get_machine(
    machine_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = MachineService(db)
    machine = await service.get_machine(machine_id, current_user.id)
    if not machine:
        raise HTTPException(status_code=404, detail="Machine not found")
    return machine

@router.put("/{machine_id}", response_model=MachineResponse)
async def update_machine(
    machine_id: str,
    data: MachineUpdate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = MachineService(db)
    machine = await service.update_machine(machine_id, current_user.id, data.name)
    if not machine:
        raise HTTPException(status_code=404, detail="Machine not found")
    return machine

@router.delete("/{machine_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_machine(
    machine_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = MachineService(db)
    success = await service.delete_machine(machine_id, current_user.id)
    if not success:
        raise HTTPException(status_code=404, detail="Machine not found")
```

- [ ] **Step 3: 提交**

```bash
git add hermes-server/app/services/machine.py hermes-server/app/api/machines.py && git commit -m "feat(server): add Machines API"
```

---

### Task 10: Agents API

**Files:**
- Create: `hermes-server/app/services/agent.py`
- Create: `hermes-server/app/api/agents.py`

- [ ] **Step 1: 创建 agent.py service**

```python
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.agent import Agent, RoomAgent
from app.models.machine import Machine
from app.services.machine import MachineService

class AgentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_agent(
        self,
        machine_id: str,
        remote_id: str,
        name: str,
        user_id: str,
        description: Optional[str] = None,
        avatar: Optional[str] = None,
        profile: Optional[str] = None,
        invited: bool = False
    ) -> Agent:
        machine_service = MachineService(self.db)
        machine = await machine_service.get_machine(machine_id, user_id)
        if not machine:
            raise ValueError("Machine not found")

        agent = Agent(
            machine_id=machine_id,
            remote_id=remote_id,
            name=name,
            description=description,
            avatar=avatar,
            profile=profile,
            invited=invited
        )
        self.db.add(agent)
        await self.db.commit()
        await self.db.refresh(agent)
        return agent

    async def get_agent(self, agent_id: str) -> Optional[Agent]:
        result = await self.db.execute(
            select(Agent).where(Agent.id == agent_id)
        )
        return result.scalar_one_or_none()

    async def get_user_agents(self, user_id: str) -> List[Agent]:
        result = await self.db.execute(
            select(Agent)
            .join(Machine)
            .where(Machine.user_id == user_id)
        )
        return list(result.scalars().all())

    async def get_machine_agents(self, machine_id: str, user_id: str) -> List[Agent]:
        machine_service = MachineService(self.db)
        machine = await machine_service.get_machine(machine_id, user_id)
        if not machine:
            return []
        result = await self.db.execute(
            select(Agent).where(Agent.machine_id == machine_id)
        )
        return list(result.scalars().all())

    async def add_agent_to_room(self, room_id: str, agent_id: str) -> RoomAgent:
        room_agent = RoomAgent(room_id=room_id, agent_id=agent_id)
        self.db.add(room_agent)
        await self.db.commit()
        await self.db.refresh(room_agent)
        return room_agent

    async def get_room_agents(self, room_id: str) -> List[Agent]:
        result = await self.db.execute(
            select(Agent)
            .join(RoomAgent)
            .where(RoomAgent.room_id == room_id)
        )
        return list(result.scalars().all())

    async def remove_agent_from_room(self, room_id: str, agent_id: str) -> bool:
        result = await self.db.execute(
            select(RoomAgent).where(
                RoomAgent.room_id == room_id,
                RoomAgent.agent_id == agent_id
            )
        )
        room_agent = result.scalar_one_or_none()
        if not room_agent:
            return False
        await self.db.delete(room_agent)
        await self.db.commit()
        return True
```

- [ ] **Step 2: 创建 agents.py API**

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.database import get_db
from app.core.deps import get_current_user
from app.schemas.agent import AgentCreate, AgentUpdate, AgentResponse
from app.services.agent import AgentService
from app.services.machine import MachineService

router = APIRouter(tags=["agents"])

@router.get("/agents", response_model=List[AgentResponse])
async def list_agents(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = AgentService(db)
    return await service.get_user_agents(current_user.id)

@router.get("/machines/{machine_id}/agents", response_model=List[AgentResponse])
async def list_machine_agents(
    machine_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = AgentService(db)
    return await service.get_machine_agents(machine_id, current_user.id)

@router.post("/agents", response_model=AgentResponse, status_code=status.HTTP_201_CREATED)
async def create_agent(
    data: AgentCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = AgentService(db)
    try:
        return await service.create_agent(
            machine_id=data.machine_id,
            remote_id=data.remote_id,
            name=data.name,
            user_id=current_user.id,
            description=data.description,
            avatar=data.avatar,
            profile=data.profile,
            invited=data.invited
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/agents/{agent_id}", response_model=AgentResponse)
async def get_agent(
    agent_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = AgentService(db)
    agent = await service.get_agent(agent_id)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")
    return agent

@router.post("/rooms/{room_id}/agents", status_code=status.HTTP_201_CREATED)
async def add_agent_to_room(
    room_id: str,
    agent_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = AgentService(db)
    return await service.add_agent_to_room(room_id, agent_id)

@router.delete("/rooms/{room_id}/agents/{agent_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_agent_from_room(
    room_id: str,
    agent_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = AgentService(db)
    success = await service.remove_agent_from_room(room_id, agent_id)
    if not success:
        raise HTTPException(status_code=404, detail="Agent not in room")
```

- [ ] **Step 3: 提交**

```bash
git add hermes-server/app/services/agent.py hermes-server/app/api/agents.py && git commit -m "feat(server): add Agents API"
```

---

## Phase 5: App 骨架 (hermes-app)

### Task 11: 初始化 Flutter 项目

**Files:**
- Create: `hermes-app/pubspec.yaml`
- Create: `hermes-app/lib/main.dart`
- Create: `hermes-app/lib/app.dart`
- Create: `hermes-app/lib/core/config/app_config.dart`

- [ ] **Step 1: 创建 pubspec.yaml**

```yaml
name: hermes_app
description: Hermes App - Mobile AI Chat
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  dio: ^5.4.0
  web_socket_channel: ^2.4.0
  go_router: ^13.0.0
  shared_preferences: ^2.2.2
  json_annotation: ^4.8.1
  freezed_annotation: ^2.4.1
  intl: ^0.18.1
  cached_network_image: ^3.3.0
  image_picker: ^1.0.7
  audio_waveforms: ^1.0.5
  permission_handler: ^11.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
  freezed: ^2.4.6
  riverpod_generator: ^2.3.9

flutter:
  uses-material-design: true
```

- [ ] **Step 2: 创建 app_config.dart**

```dart
class AppConfig {
  static const String appName = 'Hermes App';
  static const String baseUrl = 'http://localhost:8000';
  static const String wsUrl = 'ws://localhost:8000';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user';
}
```

- [ ] **Step 3: 创建 main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: HermesApp(),
    ),
  );
}
```

- [ ] **Step 4: 创建 app.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';

class HermesApp extends ConsumerWidget {
  const HermesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Hermes App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 5: 创建 router/app_router.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/register_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/chat_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return ChatScreen(roomId: roomId);
        },
      ),
    ],
  );
});
```

- [ ] **Step 6: 创建占位 Screen 文件**

```dart
// lib/presentation/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../data/providers/storage_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final storage = ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (!mounted) return;
    if (token != null) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
```

- [ ] **Step 7: 创建 storage_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  Future<String?> get(String key) async => _prefs.getString(key);
  Future<bool> set(String key, String value) async => _prefs.setString(key, value);
  Future<bool> remove(String key) async => _prefs.remove(key);
  Future<bool> clear() async => _prefs.clear();
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

final storageProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(sharedPreferencesProvider));
});
```

- [ ] **Step 8: 提交**

```bash
cd hermes-app && flutter pub get && cd .. && git add hermes-app/ && git commit -m "feat(app): init Flutter project structure"
```

---

### Task 12: App 认证模块

**Files:**
- Create: `hermes-app/lib/data/models/user.dart`
- Create: `hermes-app/lib/data/models/auth.dart`
- Create: `hermes-app/lib/data/providers/api_provider.dart`
- Create: `hermes-app/lib/data/providers/auth_provider.dart`
- Create: `hermes-app/lib/presentation/screens/login_screen.dart`
- Create: `hermes-app/lib/presentation/screens/register_screen.dart`

- [ ] **Step 1: 创建 user.dart model**

```dart
class User {
  final String id;
  final String username;
  final bool multiDevice;

  User({
    required this.id,
    required this.username,
    this.multiDevice = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      multiDevice: json['multi_device'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'multi_device': multiDevice,
  };
}
```

- [ ] **Step 2: 创建 auth.dart model**

```dart
class LoginRequest {
  final String username;
  final String password;

  LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
  };
}

class RegisterRequest {
  final String username;
  final String password;

  RegisterRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
  };
}

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}
```

- [ ] **Step 3: 创建 api_provider.dart**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import 'storage_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LogInterceptor());

  return dio;
});

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final storage = _ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Handle token refresh
    }
    handler.next(err);
  }
}
```

- [ ] **Step 4: 创建 auth_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../models/auth.dart';
import '../models/user.dart';
import 'api_provider.dart';
import 'storage_provider.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(AuthState());

  Future<bool> login(String username, String password) async {
    state = AuthState(isLoading: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      final tokens = TokenResponse.fromJson(response.data);

      final storage = _ref.read(storageProvider);
      await storage.set(AppConfig.accessTokenKey, tokens.accessToken);
      await storage.set(AppConfig.refreshTokenKey, tokens.refreshToken);

      // Fetch user info
      final userResponse = await dio.get('/auth/me');
      final user = User.fromJson(userResponse.data);

      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> register(String username, String password) async {
    state = AuthState(isLoading: true);
    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/auth/register', data: {
        'username': username,
        'password': password,
      });
      // Auto login after register
      return login(username, password);
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    final storage = _ref.read(storageProvider);
    await storage.remove(AppConfig.accessTokenKey);
    await storage.remove(AppConfig.refreshTokenKey);
    state = AuthState();
  }

  Future<void> checkAuth() async {
    final storage = _ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (token == null) {
      state = AuthState();
      return;
    }
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/auth/me');
      state = AuthState(user: User.fromJson(response.data));
    } catch (e) {
      await logout();
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
```

- [ ] **Step 5: 创建 login_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Hermes',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _login,
                  child: authState.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Login'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text("Don't have an account? Register"),
                ),
                if (authState.error != null) ...[
                  const SizedBox(height: 16),
                  Text(authState.error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: 创建 register_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Required';
                    if (v!.length < 3) return 'Min 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Required';
                    if (v!.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _register,
                  child: authState.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Register'),
                ),
                if (authState.error != null) ...[
                  const SizedBox(height: 16),
                  Text(authState.error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: 提交**

```bash
git add hermes-app/lib/data/models/ hermes-app/lib/data/providers/ hermes-app/lib/presentation/screens/login_screen.dart hermes-app/lib/presentation/screens/register_screen.dart
git commit -m "feat(app): add authentication module"
```

---

## Phase 6: App 群聊功能

### Task 13: Home Screen (Tab 导航)

**Files:**
- Create: `hermes-app/lib/presentation/screens/home_screen.dart`
- Create: `hermes-app/lib/presentation/screens/chat_list_tab.dart`
- Create: `hermes-app/lib/presentation/screens/discover_tab.dart`
- Create: `hermes-app/lib/presentation/screens/profile_tab.dart`

- [ ] **Step 1: 创建 home_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'chat_list_tab.dart';
import 'discover_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _tabs = const [
    ChatListTab(),
    DiscoverTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '对话',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 chat_list_tab.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/room_provider.dart';

class ChatListTab extends ConsumerWidget {
  const ChatListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('对话'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Search
            },
          ),
        ],
      ),
      body: roomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return const Center(
              child: Text('暂无群聊\n点击右下角创建群聊', textAlign: TextAlign.center),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(roomsProvider.future),
            child: ListView.builder(
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: room.avatar != null ? NetworkImage(room.avatar!) : null,
                    child: room.avatar == null ? Text(room.name[0]) : null,
                  ),
                  title: Text(room.name),
                  subtitle: Text(room.lastMessage ?? ''),
                  trailing: Text(
                    room.lastMessageTime != null ? _formatTime(room.lastMessageTime!) : '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => context.push('/chat/${room.id}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRoomDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}';
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建群聊'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '群聊名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref.read(roomsProvider.notifier).createRoom(nameController.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 创建 discover_tab.dart 和 profile_tab.dart**

```dart
// lib/presentation/screens/discover_tab.dart
import 'package:flutter/material.dart';

class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.computer),
            title: const Text('机器管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('Agent 管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.extension),
            title: const Text('Skills'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Plugins'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.model_training),
            title: const Text('Models'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('定时任务'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.view_kanban),
            title: const Text('看板'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// lib/presentation/screens/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/auth_provider.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(authState.user?.username ?? ''),
            accountEmail: Text('User ID: ${authState.user?.id ?? ''}'),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            decoration: const BoxDecoration(color: Colors.blue),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('用量统计'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('网关管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profiles'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.psychology),
            title: const Text('记忆'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 创建 room_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/room.dart';
import '../../data/providers/api_provider.dart';

class Room {
  final String id;
  final String name;
  final String? avatar;
  final String ownerId;
  final String mode;
  final String? inviteCode;
  final int createdAt;
  final String? lastMessage;
  final int? lastMessageTime;

  Room({
    required this.id,
    required this.name,
    this.avatar,
    required this.ownerId,
    required this.mode,
    this.inviteCode,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      ownerId: json['owner_id'] as String,
      mode: json['mode'] as String? ?? 'broadcast',
      inviteCode: json['invite_code'] as String?,
      createdAt: json['created_at'] as int,
    );
  }
}

class RoomsNotifier extends StateNotifier<AsyncValue<List<Room>>> {
  final Ref _ref;

  RoomsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadRooms();
  }

  Future<void> loadRooms() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/rooms');
      final rooms = (response.data as List)
          .map((json) => Room.fromJson(json))
          .toList();
      state = AsyncValue.data(rooms);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createRoom(String name, {String mode = 'broadcast'}) async {
    final dio = _ref.read(dioProvider);
    await dio.post('/rooms', data: {'name': name, 'mode': mode});
    await loadRooms();
  }
}

final roomsProvider = StateNotifierProvider<RoomsNotifier, AsyncValue<List<Room>>>((ref) {
  return RoomsNotifier(ref);
});
```

- [ ] **Step 5: 提交**

```bash
git add hermes-app/lib/presentation/screens/home_screen.dart hermes-app/lib/presentation/screens/chat_list_tab.dart hermes-app/lib/presentation/screens/discover_tab.dart hermes-app/lib/presentation/screens/profile_tab.dart hermes-app/lib/data/models/room.dart hermes-app/lib/data/providers/room_provider.dart
git commit -m "feat(app): add home screen with tab navigation"
```

---

### Task 14: Chat Screen

**Files:**
- Create: `hermes-app/lib/data/models/message.dart`
- Create: `hermes-app/lib/data/providers/chat_provider.dart`
- Create: `hermes-app/lib/presentation/screens/chat_screen.dart`
- Create: `hermes-app/lib/presentation/widgets/message_bubble.dart`

- [ ] **Step 1: 创建 message.dart model**

```dart
class Message {
  final String id;
  final String roomId;
  final String? senderId;
  final String? senderType;  // 'user' or 'agent'
  final String? senderName;
  final String content;
  final String contentType;  // 'text', 'image', 'voice'
  final String? extra;  // JSON for additional data
  final String? parentId;
  final int createdAt;

  Message({
    required this.id,
    required this.roomId,
    this.senderId,
    this.senderType,
    this.senderName,
    required this.content,
    this.contentType = 'text',
    this.extra,
    this.parentId,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String?,
      senderType: json['sender_type'] as String?,
      senderName: json['sender_name'] as String?,
      content: json['content'] as String,
      contentType: json['content_type'] as String? ?? 'text',
      extra: json['extra'] as String?,
      parentId: json['parent_id'] as String?,
      createdAt: json['created_at'] as int,
    );
  }

  bool get isFromUser => senderType == 'user';
  bool get isFromAgent => senderType == 'agent';
}
```

- [ ] **Step 2: 创建 chat_provider.dart**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import '../../data/models/message.dart';
import '../../data/providers/storage_provider.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isConnected;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isConnected = false,
    this.error,
  });
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String roomId;
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  ChatNotifier(this.roomId, this._ref) : super(ChatState()) {
    _connect();
  }

  Future<void> _connect() async {
    final storage = _ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (token == null) return;

    state = state.copyWith(isLoading: true);

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.baseUrl}/ws/chat?token=$token'),
      );

      // Join room
      _channel!.sink.add(jsonEncode({
        'event': 'join',
        'data': {'roomId': roomId},
      }));

      _subscription = _channel!.stream.listen(
        (data) {
          final json = jsonDecode(data);
          final event = json['event'] as String;
          final payload = json['data'] as Map<String, dynamic>;

          switch (event) {
            case 'message':
              final msg = Message.fromJson(payload);
              state = state.copyWith(
                messages: [...state.messages, msg],
                isLoading: false,
                isConnected: true,
              );
              break;
            case 'member_joined':
              // Handle
              break;
            case 'member_left':
              // Handle
              break;
          }
        },
        onError: (e) {
          state = state.copyWith(error: e.toString(), isConnected: false);
        },
        onDone: () {
          state = state.copyWith(isConnected: false);
        },
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void sendMessage(String content) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'event': 'message',
      'data': {'content': content},
    }));
  }

  void sendTyping() {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'event': 'typing'}));
  }

  void sendStopTyping() {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'event': 'stop_typing'}));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, roomId) {
  return ChatNotifier(roomId, ref);
});
```

- [ ] **Step 3: 创建 chat_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/chat_provider.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;

  const ChatScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref.read(chatProvider(widget.roomId).notifier).sendMessage(content);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.roomId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('群聊'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              // TODO: Show invite dialog
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                    ? const Center(child: Text('暂无消息'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.messages[index];
                          return MessageBubble(message: message);
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // TODO: Show attachment options
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && !_isTyping) {
                    _isTyping = true;
                    ref.read(chatProvider(widget.roomId).notifier).sendTyping();
                  } else if (value.isEmpty && _isTyping) {
                    _isTyping = false;
                    ref.read(chatProvider(widget.roomId).notifier).sendStopTyping();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.mic),
              onPressed: () {
                // TODO: Voice input
              },
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 创建 message_bubble.dart**

```dart
import 'package:flutter/material.dart';
import '../../data/models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              child: Text(message.senderName?[0] ?? 'A'),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Text(
                      message.senderName ?? 'Agent',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add hermes-app/lib/data/models/message.dart hermes-app/lib/data/providers/chat_provider.dart hermes-app/lib/presentation/screens/chat_screen.dart hermes-app/lib/presentation/widgets/message_bubble.dart
git commit -m "feat(app): add chat screen with WebSocket"
```

---

## Phase 7: App 发现/设置页面 (基础实现)

### Task 15: Machine/Agent 管理页面

**Files:**
- Create: `hermes-app/lib/data/models/machine.dart`
- Create: `hermes-app/lib/data/models/agent.dart`
- Create: `hermes-app/lib/data/providers/machine_provider.dart`
- Create: `hermes-app/lib/presentation/screens/machines_screen.dart`
- Create: `hermes-app/lib/presentation/screens/agents_screen.dart`

- [ ] **Step 1-5: 创建相关文件（简化版实现）**

```dart
// lib/data/models/machine.dart
class Machine {
  final String id;
  final String? name;
  final String address;
  final int createdAt;

  Machine({required this.id, this.name, required this.address, required this.createdAt});

  factory Machine.fromJson(Map<String, dynamic> json) => Machine(
    id: json['id'],
    name: json['name'],
    address: json['address'],
    createdAt: json['created_at'],
  );
}

// lib/data/models/agent.dart
class Agent {
  final String id;
  final String machineId;
  final String remoteId;
  final String name;
  final String? description;
  final String? avatar;
  final String? profile;
  final bool invited;
  final int createdAt;

  Agent({
    required this.id,
    required this.machineId,
    required this.remoteId,
    required this.name,
    this.description,
    this.avatar,
    this.profile,
    this.invited = false,
    required this.createdAt,
  });

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
    id: json['id'],
    machineId: json['machine_id'],
    remoteId: json['remote_id'],
    name: json['name'],
    description: json['description'],
    avatar: json['avatar'],
    profile: json['profile'],
    invited: json['invited'] ?? false,
    createdAt: json['created_at'],
  );
}

// lib/data/providers/machine_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/machine.dart';
import '../models/agent.dart';
import 'api_provider.dart';

final machinesProvider = FutureProvider<List<Machine>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/machines');
  return (response.data as List).map((json) => Machine.fromJson(json)).toList();
});

final machineAgentsProvider = FutureProvider.family<List<Agent>, String>((ref, machineId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/machines/$machineId/agents');
  return (response.data as List).map((json) => Agent.fromJson(json)).toList();
});

// lib/presentation/screens/machines_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/machine_provider.dart';

class MachinesScreen extends ConsumerWidget {
  const MachinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machinesAsync = ref.watch(machinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('机器管理')),
      body: machinesAsync.when(
        data: (machines) => machines.isEmpty
            ? const Center(child: Text('暂无机器\n点击右下角添加'))
            : ListView.builder(
                itemCount: machines.length,
                itemBuilder: (context, index) {
                  final machine = machines[index];
                  return ListTile(
                    leading: const Icon(Icons.computer),
                    title: Text(machine.name ?? machine.address),
                    subtitle: Text(machine.address),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MachineDetailScreen(machineId: machine.id),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMachineDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddMachineDialog(BuildContext context, WidgetRef ref) {
    final addressController = TextEditingController();
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加机器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '名称（可选）'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: '地址',
                hintText: '192.168.1.100:8642',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (addressController.text.isNotEmpty) {
                // TODO: Implement add machine
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

class MachineDetailScreen extends ConsumerWidget {
  final String machineId;

  const MachineDetailScreen({super.key, required this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(machineAgentsProvider(machineId));

    return Scaffold(
      appBar: AppBar(title: const Text('Agent 列表')),
      body: agentsAsync.when(
        data: (agents) => agents.isEmpty
            ? const Center(child: Text('暂无 Agent'))
            : ListView.builder(
                itemCount: agents.length,
                itemBuilder: (context, index) {
                  final agent = agents[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(agent.name[0]),
                    ),
                    title: Text(agent.name),
                    subtitle: Text(agent.description ?? ''),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 6: 提交**

```bash
git add hermes-app/lib/data/models/machine.dart hermes-app/lib/data/models/agent.dart hermes-app/lib/data/providers/machine_provider.dart hermes-app/lib/presentation/screens/machines_screen.dart
git commit -m "feat(app): add machine and agent management screens"
```

---

## 实施检查清单

### 服务端 (hermes-server)

- [ ] Task 1: 项目骨架
- [ ] Task 2: 用户认证模块
- [ ] Task 3: JWT 认证依赖
- [ ] Task 4: Room & Message 模型
- [ ] Task 5: Machine & Agent 模型
- [ ] Task 6: Rooms API
- [ ] Task 7: Messages API
- [ ] Task 8: WebSocket 聊天
- [ ] Task 9: Machines API
- [ ] Task 10: Agents API

### App 端 (hermes-app)

- [ ] Task 11: Flutter 项目初始化
- [ ] Task 12: 认证模块
- [ ] Task 13: Home Screen + Tab 导航
- [ ] Task 14: Chat Screen
- [ ] Task 15: Machine/Agent 管理页面

---

## 后续任务（未包含在此计划中）

- Pipeline 模式实现
- 语音消息录制与发送
- 图片消息发送
- 通知推送集成
- Tab2/Tab3 完整功能实现
- Docker 部署配置
- CI/CD 配置

---

**Plan saved to:** `docs/superpowers/plans/2026-05-12-hermes-app-implementation.md`
