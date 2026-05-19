import secrets
from typing import List, Optional
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.room import Room, RoomMember
from app.models.agent import RoomAgent, Agent
from app.models.message import Message
from app.models.user import User

class RoomService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_room(self, owner_id: str, name: str, mode: str = "broadcast", profile_id: Optional[str] = None) -> Room:
        invite_code = secrets.token_urlsafe(6)
        room = Room(
            owner_id=owner_id,
            name=name,
            mode=mode,
            invite_code=invite_code,
            profile_id=profile_id
        )
        self.db.add(room)
        await self.db.commit()
        await self.db.refresh(room)

        # Add owner as member
        member = RoomMember(room_id=room.id, user_id=owner_id, role="owner")
        self.db.add(member)

        # If profile_id is provided (1:1 chat), add agent to room
        if profile_id:
            # Find the agent for this profile
            result = await self.db.execute(
                select(RoomAgent).where(RoomAgent.room_id == room.id)
            )
            if not result.scalar_one_or_none():
                agent_result = await self.db.execute(
                    select(Agent).where(Agent.profile_id == profile_id)
                )
                agent = agent_result.scalar_one_or_none()
                if agent:
                    room_agent = RoomAgent(room_id=room.id, agent_id=agent.id)
                    self.db.add(room_agent)

        await self.db.commit()
        await self.db.refresh(room)

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

    async def update_room(
        self,
        room_id: str,
        user_id: str,
        data,  # RoomUpdate schema
    ) -> Optional[Room]:
        """Update room info. Only owner/admin can do this."""
        room = await self.get_room(room_id)
        if not room:
            return None

        # Check permission
        result = await self.db.execute(
            select(RoomMember).where(
                and_(RoomMember.room_id == room_id, RoomMember.user_id == user_id)
            )
        )
        member = result.scalar_one_or_none()
        if not member or member.role not in ("owner", "admin"):
            return None

        if data.name is not None:
            room.name = data.name
        if data.avatar is not None:
            room.avatar = data.avatar
        if data.mode is not None:
            room.mode = data.mode
        if data.profile_id is not None:
            room.profile_id = data.profile_id

        await self.db.commit()
        await self.db.refresh(room)
        return room

    async def get_room_members(self, room_id: str) -> List[RoomMember]:
        result = await self.db.execute(
            select(RoomMember)
            .options(selectinload(RoomMember.user))
            .where(RoomMember.room_id == room_id)
        )
        return list(result.scalars().all())

    async def get_member(self, room_id: str, user_id: str) -> Optional[RoomMember]:
        result = await self.db.execute(
            select(RoomMember)
            .options(selectinload(RoomMember.user))
            .where(
                and_(RoomMember.room_id == room_id, RoomMember.user_id == user_id)
            )
        )
        return result.scalar_one_or_none()

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

    async def remove_member(self, room_id: str, target_user_id: str, actor_user_id: str) -> bool:
        """Remove a member. Only owner/admin can remove others, or a member can remove themselves."""
        # Get actor's role
        actor = await self.get_member(room_id, actor_user_id)
        if not actor:
            return False

        # Get target
        target = await self.get_member(room_id, target_user_id)
        if not target:
            return False

        # Owner cannot be removed
        if target.role == "owner":
            return False

        # Admin can remove members but not other admins
        if actor.role == "admin" and target.role in ("admin", "owner"):
            return False

        # Members can only remove themselves
        if actor.role == "member" and target_user_id != actor_user_id:
            return False

        await self.db.delete(target)
        await self.db.commit()
        return True

    async def update_member_role(
        self, room_id: str, target_user_id: str, actor_user_id: str, new_role: str
    ) -> Optional[RoomMember]:
        """Update a member's role. Only owner can do this."""
        actor = await self.get_member(room_id, actor_user_id)
        if not actor or actor.role != "owner":
            return None

        target = await self.get_member(room_id, target_user_id)
        if not target or target.role == "owner":
            return None

        if new_role in ("admin", "member"):
            target.role = new_role
            await self.db.commit()
            await self.db.refresh(target)
            return target
        return None

    async def is_member(self, room_id: str, user_id: str) -> bool:
        result = await self.db.execute(
            select(RoomMember).where(
                and_(RoomMember.room_id == room_id, RoomMember.user_id == user_id)
            )
        )
        return result.scalar_one_or_none() is not None

    async def is_admin_or_owner(self, room_id: str, user_id: str) -> bool:
        result = await self.db.execute(
            select(RoomMember).where(
                and_(RoomMember.room_id == room_id, RoomMember.user_id == user_id)
            )
        )
        member = result.scalar_one_or_none()
        return member is not None and member.role in ("owner", "admin")

    async def get_room_by_code(self, invite_code: str) -> Optional[Room]:
        result = await self.db.execute(
            select(Room).where(Room.invite_code == invite_code)
        )
        return result.scalar_one_or_none()
