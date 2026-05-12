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
