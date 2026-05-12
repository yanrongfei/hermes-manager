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