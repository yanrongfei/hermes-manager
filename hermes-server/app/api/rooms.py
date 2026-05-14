from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from pydantic import BaseModel
from app.database import get_db
from app.core.deps import get_current_user
from app.schemas.room import RoomCreate, RoomUpdate, RoomResponse, RoomDetail, MemberResponse
from app.schemas.message import MessageListResponse
from app.services.room import RoomService
from app.models.message import Message

router = APIRouter(prefix="/rooms", tags=["rooms"])


class UpdateMemberRole(BaseModel):
    role: str  # admin / member


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


@router.put("/{room_id}", response_model=RoomResponse)
async def update_room(
    room_id: str,
    data: RoomUpdate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    room = await service.update_room(room_id, current_user.id, data)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


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


@router.get("/{room_id}/members", response_model=List[MemberResponse])
async def list_members(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    if not await service.is_member(room_id, current_user.id):
        raise HTTPException(status_code=403, detail="Not a member")
    members = await service.get_room_members(room_id)
    return [
        {
            "id": m.id,
            "user_id": m.user_id,
            "username": m.user.username,
            "role": m.role,
            "joined_at": m.joined_at
        }
        for m in members
    ]


@router.delete("/{room_id}/members/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_member(
    room_id: str,
    user_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Remove a member from the room. Only owner/admin can do this."""
    service = RoomService(db)
    success = await service.remove_member(room_id, user_id, current_user.id)
    if not success:
        raise HTTPException(status_code=400, detail="Cannot remove member")


@router.put("/{room_id}/members/{user_id}", response_model=MemberResponse)
async def update_member_role(
    room_id: str,
    user_id: str,
    data: UpdateMemberRole,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update a member's role. Only owner can do this."""
    service = RoomService(db)
    member = await service.update_member_role(room_id, user_id, current_user.id, data.role)
    if not member:
        raise HTTPException(status_code=404, detail="Member not found or not authorized")
    return {
        "id": member.id,
        "user_id": member.user_id,
        "username": member.user.username,
        "role": member.role,
        "joined_at": member.joined_at
    }
