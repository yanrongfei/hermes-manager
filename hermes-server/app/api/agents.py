from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
import uuid
from datetime import datetime
from app.database import get_db
from app.core.deps import get_current_user
from app.core.errors import AppException, ErrorCode
from app.schemas.agent import AgentCreate, AgentUpdate, AgentResponse
from app.services.agent import AgentService
from app.services.gateway_client import GatewayClient
from app.config import get_settings
from app.services.machine import MachineService
from app.models.agent import Agent

router = APIRouter(tags=["agents"])


@router.get("/agents", response_model=List[AgentResponse])
async def list_agents(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AgentService(db)
    return await service.get_user_agents(current_user.id)


@router.get("/machines/{machine_id}/agents", response_model=List[AgentResponse])
async def list_machine_agents(
    machine_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AgentService(db)
    agents = await service.get_machine_agents(machine_id, current_user.id)

    # If no agents in DB, auto-discover from gateway and save them
    if not agents:
        machine_service = MachineService(db)
        machine = await machine_service.get_machine(machine_id, current_user.id)
        if machine:
            settings = get_settings()
            gateway = GatewayClient(machine.address, api_key=machine.api_key)
            try:
                discovered = await gateway.list_agents()
                now = int(datetime.utcnow().timestamp())
                for d in discovered:
                    agent = Agent(
                        id=str(uuid.uuid4()),
                        machine_id=machine_id,
                        remote_id=d.get("remote_id", d.get("id", "")),
                        name=d.get("name", "Agent"),
                        description=d.get("description"),
                        avatar=None,
                        profile=None,
                        invited=False,
                        created_at=now,
                    )
                    db.add(agent)
                await db.commit()
                if discovered:
                    agents = await service.get_machine_agents(machine_id, current_user.id)
            finally:
                await gateway.close()

    return agents


@router.post("/agents", response_model=AgentResponse, status_code=status.HTTP_201_CREATED)
async def create_agent(
    data: AgentCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
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
            invited=data.invited,
        )
    except ValueError as e:
        raise AppException(ErrorCode.RESOURCE_BAD_REQUEST, str(e), status_code=400)


@router.get("/agents/{agent_id}", response_model=AgentResponse)
async def get_agent(
    agent_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AgentService(db)
    agent = await service.get_agent(agent_id)
    if not agent:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "Agent 不存在", status_code=404)
    return agent


@router.put("/agents/{agent_id}", response_model=AgentResponse)
async def update_agent(
    agent_id: str,
    data: AgentUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AgentService(db)
    agent = await service.update_agent(
        agent_id,
        current_user.id,
        name=data.name,
        description=data.description,
        avatar=data.avatar,
        profile=data.profile,
    )
    if not agent:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "Agent 不存在", status_code=404)
    return agent


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
