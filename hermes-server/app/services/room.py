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

    async def create_room(
        self,
        owner_id: str,
        name: str,
        mode: str = "direct",
        agent_ids: List[str] = None,
        agent_id: Optional[str] = None,
    ) -> Room:
        # Calculate type based on agent_ids length
        type = "1v1" if (len(agent_ids) == 1 if agent_ids else agent_id) else "group"

        # invite_code is lazily generated, set to None at creation
        room = Room(
            owner_id=owner_id,
            name=name,
            mode=mode,
            invite_code=None,
            agent_id=agent_id,
        )
        self.db.add(room)
        await self.db.commit()
        await self.db.refresh(room)

        # Add owner as member
        member = RoomMember(room_id=room.id, user_id=owner_id, role="owner")
        self.db.add(member)

        # If agent_ids provided, add agents to room
        if agent_ids:
            for ag_id in agent_ids:
                room_agent = RoomAgent(room_id=room.id, agent_id=ag_id)
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

    async def get_room_stats(self, room_id: str) -> dict:
        """Get room statistics including member count and running tasks."""
        # Member count
        members = await self.get_room_members(room_id)
        member_count = len(members)

        # Online count (simplified - all members considered online for now)
        online_count = member_count

        # Running tasks count (from ws.py active_executors)
        from app.api.ws import active_executors
        running_count = len(active_executors.get(room_id, []))

        # Get last message preview
        result = await self.db.execute(
            select(Message)
            .where(Message.room_id == room_id)
            .order_by(Message.created_at.desc())
            .limit(1)
        )
        last_message = None
        updated_at = None
        msg = result.scalar_one_or_none()
        if msg:
            updated_at = msg.created_at
            last_message = msg.content[:100] if msg.content and len(msg.content) > 100 else msg.content

        return {
            "member_count": member_count,
            "online_count": online_count,
            "has_running_tasks": running_count > 0,
            "running_tasks_count": running_count,
            "last_message": last_message,
            "updated_at": updated_at,
        }

    async def generate_invite_code(self, room_id: str) -> Optional[str]:
        """Lazily generate invite code for a room."""
        room = await self.get_room(room_id)
        if not room:
            return None
        if room.mode == "direct":
            return None  # 1:1 rooms don't support invite codes
        if room.invite_code:
            return room.invite_code  # Already has one

        invite_code = secrets.token_urlsafe(6)
        room.invite_code = invite_code
        await self.db.commit()
        await self.db.refresh(room)
        return invite_code
