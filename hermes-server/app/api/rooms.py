import time
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from pydantic import BaseModel
from app.database import get_db
from app.core.deps import get_current_user
from app.core.errors import AppException, ErrorCode
from app.schemas.room import RoomCreate, RoomUpdate, RoomResponse, RoomDetail, MemberResponse, RoomJoin
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
    # Update user activity so online status reflects browsing
    current_user.last_active_at = int(time.time())
    await db.commit()

    service = RoomService(db)
    rooms = await service.get_user_rooms(current_user.id)

    # Add statistics to each room
    result = []
    for room in rooms:
        room_dict = RoomResponse.model_validate(room).model_dump()
        stats = await service.get_room_stats(room.id, user_id=current_user.id)
        room_dict.update(stats)
        result.append(room_dict)
    return result


@router.post("", response_model=RoomResponse, status_code=status.HTTP_201_CREATED)
async def create_room(
    data: RoomCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    # For 1:1, use agent_id; for group, use agent_ids
    agent_id = data.agent_ids[0] if len(data.agent_ids) == 1 else None
    room = await service.create_room(
        owner_id=current_user.id,
        name=data.name,
        mode=data.mode,
        agent_ids=data.agent_ids if len(data.agent_ids) > 1 else None,
        agent_id=agent_id,
    )
    room_dict = RoomResponse.model_validate(room).model_dump()
    stats = await service.get_room_stats(room.id, user_id=current_user.id)
    room_dict.update(stats)
    return room_dict


@router.get("/{room_id}", response_model=RoomDetail)
async def get_room(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    room = await service.get_room(room_id)
    if not room:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "聊天室不存在", status_code=404)
    if not await service.is_member(room_id, current_user.id):
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "你不是该聊天室的成员", status_code=403)
    members = await service.get_room_members(room_id)
    stats = await service.get_room_stats(room_id, user_id=current_user.id)
    return {
        **RoomResponse.model_validate(room).model_dump(),
        **stats,
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
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "聊天室不存在", status_code=404)
    return room


@router.delete("/{room_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_room(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    if not await service.is_member(room_id, current_user.id):
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "你不是该聊天室的成员", status_code=403)
    success = await service.delete_room(room_id, current_user.id)
    if not success:
        raise AppException(ErrorCode.RESOURCE_BAD_REQUEST, "无法删除聊天室", status_code=400)


@router.post("/join", response_model=RoomResponse)
async def join_room_by_code(
    data: RoomJoin,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    room = await service.join_by_code(data.invite_code, current_user.id)
    if not room:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "邀请码无效或聊天室不存在", status_code=404)
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
        raise AppException(ErrorCode.RESOURCE_BAD_REQUEST, "无法退出聊天室", status_code=400)


@router.get("/{room_id}/members", response_model=List[MemberResponse])
async def list_members(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    if not await service.is_member(room_id, current_user.id):
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "你不是该聊天室的成员", status_code=403)
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
    service = RoomService(db)
    success = await service.remove_member(room_id, user_id, current_user.id)
    if not success:
        raise AppException(ErrorCode.RESOURCE_BAD_REQUEST, "无法移除该成员", status_code=400)


@router.put("/{room_id}/members/{user_id}", response_model=MemberResponse)
async def update_member_role(
    room_id: str,
    user_id: str,
    data: UpdateMemberRole,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    member = await service.update_member_role(room_id, user_id, current_user.id, data.role)
    if not member:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "成员不存在或无权操作", status_code=404)
    return {
        "id": member.id,
        "user_id": member.user_id,
        "username": member.user.username,
        "role": member.role,
        "joined_at": member.joined_at
    }


@router.post("/{room_id}/invite")
async def generate_invite_code(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    service = RoomService(db)
    room = await service.get_room(room_id)

    if not room:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "聊天室不存在", status_code=404)

    # 1:1 rooms don't support invite codes
    if room.mode == "direct":
        raise AppException(ErrorCode.RESOURCE_BAD_REQUEST, "1:1 聊天室不支持邀请", status_code=400)

    # Check membership
    if not await service.is_member(room_id, current_user.id):
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "你不是该聊天室的成员", status_code=403)

    invite_code = await service.generate_invite_code(room_id)
    return {"invite_code": invite_code}


@router.post("/{room_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_room_read(
    room_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = RoomService(db)
    if not await service.is_member(room_id, current_user.id):
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "你不是该聊天室的成员", status_code=403)
    await service.mark_room_read(room_id, current_user.id)
