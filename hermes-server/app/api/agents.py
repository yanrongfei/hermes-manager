from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.database import get_db
from app.core.deps import get_current_user
from app.core.errors import AppException, ErrorCode
from app.schemas.agent import AgentResponse
from app.services.agent import AgentService
from app.services.room import RoomService

router = APIRouter(tags=["agents"])


@router.get("/agents", response_model=List[AgentResponse])
async def list_agents(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AgentService(db)
    return await service.get_user_agents(current_user.id)


@router.get("/profiles/{profile_id}/agents", response_model=List[AgentResponse])
async def list_profile_agents(
    profile_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AgentService(db)
    return await service.get_profile_agents(profile_id)


@router.delete("/agents/{agent_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_agent(
    agent_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AgentService(db)
    success = await service.delete_agent(agent_id, current_user.id)
    if not success:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "Agent 不存在", status_code=404)


@router.post("/agents/{agent_id}/invite", response_model=AgentResponse)
async def invite_agent(
    agent_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AgentService(db)
    agent = await service.invite_agent(agent_id, current_user.id)
    if not agent:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "Agent 不存在", status_code=404)
    return agent


# ── Room Agent management ──────────────────────────────────────

@router.get("/rooms/{room_id}/agents", response_model=List[AgentResponse])
async def list_room_agents(
    room_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    room_service = RoomService(db)
    if not await room_service.is_member(room_id, current_user.id):
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "你不是该聊天室的成员", status_code=403)
    service = AgentService(db)
    return await service.get_room_agents(room_id)


@router.post("/rooms/{room_id}/agents", status_code=status.HTTP_201_CREATED)
async def add_agent_to_room(
    room_id: str,
    agent_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    room_service = RoomService(db)
    if not await room_service.is_member(room_id, current_user.id):
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "你不是该聊天室的成员", status_code=403)
    service = AgentService(db)
    return await service.add_agent_to_room(room_id, agent_id)


@router.delete("/rooms/{room_id}/agents/{agent_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_agent_from_room(
    room_id: str,
    agent_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    room_service = RoomService(db)
    if not await room_service.is_member(room_id, current_user.id):
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "你不是该聊天室的成员", status_code=403)
    service = AgentService(db)
    success = await service.remove_agent_from_room(room_id, agent_id)
    if not success:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "该 Agent 不在此聊天室中", status_code=404)
