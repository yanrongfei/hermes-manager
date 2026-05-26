import time
from typing import List, Optional
from sqlalchemy import select, and_, desc, update
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
        parent_id: Optional[str] = None,
        is_streaming: bool = False,
        is_aborted: bool = False,
    ) -> Message:
        message = Message(
            room_id=room_id,
            sender_id=sender_id,
            sender_type=sender_type,
            sender_name=sender_name,
            content=content,
            content_type=content_type,
            extra=extra,
            parent_id=parent_id,
            is_streaming=is_streaming,
            is_aborted=is_aborted,
        )
        self.db.add(message)
        await self.db.commit()
        await self.db.refresh(message)
        return message

    async def update_message(
        self,
        message_id: str,
        content: Optional[str] = None,
        extra: Optional[str] = None,
        is_streaming: Optional[bool] = None,
        is_aborted: Optional[bool] = None,
    ) -> Optional[Message]:
        """Update an existing message (e.g., after streaming completes)."""
        result = await self.db.execute(
            select(Message).where(Message.id == message_id)
        )
        message = result.scalar_one_or_none()
        if not message:
            return None
        if content is not None:
            message.content = content
        if extra is not None:
            message.extra = extra
        if is_streaming is not None:
            message.is_streaming = is_streaming
        if is_aborted is not None:
            message.is_aborted = is_aborted
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
        query = query.order_by(desc(Message.created_at), desc(Message.id)).limit(limit + 1)

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
            .order_by(Message.created_at, Message.id)
        )
        return list(result.scalars().all())