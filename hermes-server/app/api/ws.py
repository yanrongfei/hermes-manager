import asyncio
import json
import re
from typing import Dict, List, Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db, get_session_maker
from app.core.security import decode_token
from app.config import get_settings
from app.services.room import RoomService
from app.services.message import MessageService
from app.services.agent import AgentService
from app.services.websocket import manager
from app.services.gateway_channel import GatewayChannel
from app.services.run_executor import RunExecutor

settings = get_settings()

# In-memory state for active runs and message queues
# room_id -> list of active executors
active_executors: Dict[str, List[RunExecutor]] = {}
# room_id -> pending message queue
message_queues: Dict[str, List[dict]] = {}


def _extract_mentions(content: str) -> List[str]:
    """Extract @agent names from message content."""
    matches = re.findall(r"@(\w+)", content)
    return matches


async def _get_gateway_for_room(room_id: str, user_id: str) -> GatewayChannel:
    """
    Get the Gateway channel for a room.

    Priority: 1) Room's agents' gateways, 2) Default config.
    """
    async with get_session_maker()() as session:
        agent_svc = AgentService(session)
        room_agents = await agent_svc.get_room_agents(room_id)
        if room_agents:
            from app.services.machine import MachineService
            machine_svc = MachineService(session)
            first_agent = room_agents[0]
            machine = await machine_svc.get_machine(first_agent.machine_id, user_id)
            if machine:
                return GatewayChannel(machine)
    from app.models.machine import Machine as MachineModel
    default_machine = MachineModel(
        address=settings.DEFAULT_GATEWAY_URL,
        api_key=settings.DEFAULT_GATEWAY_API_KEY,
        mode="http",
    )
    return GatewayChannel(default_machine)


async def _format_conversation_history(room_id: str, limit: int = 50) -> List[dict]:
    """Get recent messages formatted for Gateway conversation_history."""
    async with get_session_maker()() as session:
        msg_svc = MessageService(session)
        messages, _ = await msg_svc.get_messages(room_id, limit=limit)
        history = []
        for msg in messages:
            role = "assistant" if msg.sender_type == "agent" else "user"
            entry: dict = {"role": role, "content": msg.content}
            # Parse extra for tool calls
            if msg.extra:
                try:
                    extra = json.loads(msg.extra)
                    if extra.get("tool_calls"):
                        entry["tool_calls"] = extra["tool_calls"]
                    if extra.get("reasoning"):
                        entry["reasoning_content"] = extra["reasoning"]
                except json.JSONDecodeError:
                    pass
            history.append(entry)
        return history


async def _start_agent_runs(room_id: str, user_id: str, username: str, content: str):
    """Start agent runs based on room mode (broadcast/mention)."""
    room_service = RoomService(None)
    async with get_session_maker()() as session:
        room = await session.execute(
            select(Room).where(Room.id == room_id)
        )
        room = room.scalar_one_or_none()
    if not room:
        return

    mentioned = _extract_mentions(content)
    gateway = await _get_gateway_for_room(room_id, user_id)
    history = await _format_conversation_history(room_id)

    async with get_session_maker()() as session:
        agent_svc = AgentService(session)
        room_agents = await agent_svc.get_room_agents(room_id)

        if room.mode == "broadcast":
            targets = room_agents
        elif room.mode == "mention":
            targets = [a for a in room_agents if a.name in mentioned]
        else:
            targets = []

        if not targets:
            return

        for agent in targets:
            msg_svc = MessageService(session)
            # Create empty agent message (streaming)
            agent_msg = await msg_svc.create_message(
                room_id=room_id,
                sender_id=agent.id,
                sender_type="agent",
                sender_name=agent.name,
                content="",
                is_streaming=True,
            )

            # Broadcast the new agent message
            await manager.send_to_room(room_id, "message", {
                "id": agent_msg.id,
                "roomId": room_id,
                "senderId": agent.id,
                "senderType": "agent",
                "senderName": agent.name,
                "content": "",
                "contentType": "text",
                "isStreaming": True,
                "createdAt": agent_msg.created_at,
            })

            # Start run executor
            executor = RunExecutor(
                room_id=room_id,
                message_id=agent_msg.id,
                agent_id=agent.id,
                agent_name=agent.name,
                gateway=gateway,
            )
            if room_id not in active_executors:
                active_executors[room_id] = []
            active_executors[room_id].append(executor)
            asyncio.create_task(executor.execute(
                user_message=content,
                model=settings.DEFAULT_MODEL,
                instructions=agent.description or "",
                history=history,
            ))


# Import Room at module level for type annotation
from app.models.room import Room

router = APIRouter()


@router.websocket("/ws/chat")
async def websocket_chat(
    websocket: WebSocket,
    token: str = Query(...),
):
    # Verify token
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        await websocket.close(code=4001)
        return
    user_id = payload.get("sub")
    username = payload.get("username", "User")

    # Join room
    try:
        data = await websocket.receive_json()
    except Exception:
        await websocket.close(code=4002)
        return

    event = data.get("event")
    if event != "join":
        await websocket.close(code=4002)
        return

    room_id = data.get("data", {}).get("roomId")
    if not room_id:
        await websocket.close(code=4003)
        return

    async with get_session_maker()() as session:
        room_service = RoomService(session)
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
                if not content or not content.strip():
                    continue

                # Create user message
                async with get_session_maker()() as session:
                    msg_svc = MessageService(session)
                    user_msg = await msg_svc.create_message(
                        room_id=room_id,
                        sender_id=user_id,
                        sender_type="user",
                        sender_name=username,
                        content=content,
                    )
                    await manager.broadcast_to_room(
                        room_id,
                        "message",
                        {
                            "id": user_msg.id,
                            "roomId": room_id,
                            "senderId": user_id,
                            "senderType": "user",
                            "senderName": username,
                            "content": content,
                            "contentType": "text",
                            "isStreaming": False,
                            "createdAt": user_msg.created_at,
                        }
                    )

                # Check if agents are busy
                if room_id in active_executors and active_executors[room_id]:
                    # Queue the message
                    if room_id not in message_queues:
                        message_queues[room_id] = []
                    message_queues[room_id].append({
                        "userId": user_id,
                        "username": username,
                        "content": content,
                    })
                    await manager.send_to_room(room_id, "queue_updated", {
                        "queueLength": len(message_queues[room_id]),
                    })
                else:
                    # Start agent runs
                    await _start_agent_runs(room_id, user_id, username, content)

            elif event == "abort":
                # Abort all running agents in this room
                if room_id in active_executors:
                    for executor in active_executors[room_id]:
                        executor.abort()
                    await manager.send_to_room(room_id, "abort.started", {})

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

        # Abort all running executors for this room
        if room_id in active_executors:
            for executor in active_executors[room_id]:
                executor.abort()
            del active_executors[room_id]

        await manager.broadcast_to_room(
            room_id,
            "member_left",
            {"userId": user_id, "roomId": room_id}
        )
