import time
import asyncio
import json
import logging
import re
from datetime import datetime
from typing import Dict, List, Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db, get_session_maker
from app.core.security import decode_token
from app.config import get_settings
from app.services.room import RoomService
from app.services.message import MessageService
from app.schemas.message import MessageResponse
from app.services.agent import AgentService
from app.services.websocket import manager
from app.services.gateway_channel import GatewayChannel
from app.services.run_executor import RunExecutor
from app.models.user import User as UserModel


async def _update_user_active(user_id: str):
    """Update user's last_active_at timestamp."""
    now = int(time.time())
    async with get_session_maker()() as session:
        result = await session.execute(
            select(UserModel).where(UserModel.id == user_id)
        )
        user = result.scalar_one_or_none()
        if user:
            user.last_active_at = now
            await session.commit()

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
            from app.services.gateway import GatewayService
            from app.models.profile import Profile
            first_agent = room_agents[0]
            # Walk agent -> profile -> gateway
            result = await session.execute(
                select(Profile).where(Profile.id == first_agent.profile_id)
            )
            profile = result.scalar_one_or_none()
            if profile:
                gw_svc = GatewayService(session)
                gateway = await gw_svc.get_gateway(profile.gateway_id, user_id)
                if gateway:
                    return GatewayChannel(gateway)
    from app.models.gateway import Gateway as GatewayModel
    default_gw = GatewayModel(
        address=settings.DEFAULT_GATEWAY_URL,
        api_key=settings.DEFAULT_GATEWAY_API_KEY,
    )
    return GatewayChannel(default_gw)


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


async def _cleanup_executor(room_id: str, message_id: str):
    """Remove executor from active_executors list and process queued messages."""
    if room_id not in active_executors:
        return

    # Remove completed executor
    active_executors[room_id] = [
        e for e in active_executors[room_id] if e.message_id != message_id
    ]

    # If no more executors running, process queued messages
    if not active_executors[room_id]:
        del active_executors[room_id]

        if room_id in message_queues and message_queues[room_id]:
            # Process next queued message
            next_msg = message_queues[room_id].pop(0)
            await manager.send_to_room(room_id, "queue_updated", {
                "queueLength": len(message_queues[room_id]),
            })
            await _start_agent_runs(
                room_id, next_msg["userId"], next_msg["username"], next_msg["content"]
            )


async def _start_agent_runs(room_id: str, user_id: str, username: str, content: str):
    """Start agent runs based on room mode (broadcast/mention)."""
    logger = logging.getLogger("hermes.ws")

    async with get_session_maker()() as session:
        room = await session.execute(
            select(Room).where(Room.id == room_id)
        )
        room = room.scalar_one_or_none()
    if not room:
        logger.warning(f"_start_agent_runs: room {room_id} not found")
        return

    mentioned = _extract_mentions(content)
    gateway = await _get_gateway_for_room(room_id, user_id)
    history = await _format_conversation_history(room_id)

    async with get_session_maker()() as session:
        agent_svc = AgentService(session)
        room_agents = await agent_svc.get_room_agents(room_id)

        # Resolve agent identifier: profile_id > agent_id > room.name (fallback for legacy rooms)
        agent_identifier = room.profile_id or room.agent_id
        if not agent_identifier and not room_agents:
            agent_identifier = room.name
        logger.info(f"_start_agent_runs: room={room_id} mode={room.mode} identifier={agent_identifier} agents={len(room_agents)}")

        if agent_identifier:
            targets = [a for a in room_agents if a.profile_id == agent_identifier or a.name == agent_identifier]
            if not targets:
                targets = None  # signal: use identifier directly
        elif room.mode == "broadcast":
            targets = room_agents
        elif room.mode == "mention":
            targets = [a for a in room_agents if a.name in mentioned]
        else:
            targets = []

        # No targets found
        if targets is not None and not targets:
            logger.warning(f"_start_agent_runs: no targets for room {room_id}, mode={room.mode}, mentioned={mentioned}")
            return

        if targets is None:
            # 1:1 chat with identifier but no agent record — call gateway directly
            agent_name = agent_identifier
            agent_id = f"profile:{agent_identifier}"
            description = ""

            msg_svc = MessageService(session)
            agent_msg = await msg_svc.create_message(
                room_id=room_id,
                sender_id=agent_id,
                sender_type="agent",
                sender_name=agent_name,
                content="",
                is_streaming=True,
            )

            await manager.send_to_room(room_id, "message", {
                "id": agent_msg.id,
                "roomId": room_id,
                "senderId": agent_id,
                "senderType": "agent",
                "senderName": agent_name,
                "content": "",
                "contentType": "text",
                "isStreaming": True,
                "createdAt": agent_msg.created_at,
            })
            await _notify_room_updated(room_id, f"{agent_name} 正在思考...", agent_msg.created_at)

            executor = RunExecutor(
                room_id=room_id,
                message_id=agent_msg.id,
                agent_id=agent_id,
                agent_name=agent_name,
                gateway=gateway,
            )
            if room_id not in active_executors:
                active_executors[room_id] = []
            active_executors[room_id].append(executor)
            asyncio.create_task(_run_with_cleanup(executor, content, history, description))
        else:
            for agent in targets:
                msg_svc = MessageService(session)
                agent_msg = await msg_svc.create_message(
                    room_id=room_id,
                    sender_id=agent.id,
                    sender_type="agent",
                    sender_name=agent.name,
                    content="",
                    is_streaming=True,
                )

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
                await _notify_room_updated(room_id, f"{agent.name} 正在思考...", agent_msg.created_at)

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
                asyncio.create_task(_run_with_cleanup(
                    executor, content, history, agent.description or ""
                ))


async def _run_with_cleanup(executor: RunExecutor, content: str, history: list, instructions: str):
    """Run executor and ensure cleanup on completion."""
    try:
        await executor.execute(
            user_message=content,
            model=settings.DEFAULT_MODEL,
            instructions=instructions,
            history=history,
        )
    finally:
        # Always cleanup, even if execute raises an exception
        await _cleanup_executor(executor.room_id, executor.message_id)

        # Push final room_updated with actual agent response content
        preview = (executor._full_content[:100]
                   if executor._full_content else f"{executor.agent_name}")
        await _notify_room_updated(
            executor.room_id, preview,
            int(time.time()),
        )


# Import Room at module level for type annotation
from app.models.room import Room, RoomMember

router = APIRouter()


async def _notify_room_updated(room_id: str, last_message: str = None, updated_at: int = None):
    """Push room_updated event to all room members not actively in that room's WS."""
    async with get_session_maker()() as session:
        result = await session.execute(
            select(RoomMember).where(RoomMember.room_id == room_id)
        )
        members = list(result.scalars().all())

    active_users = manager.get_active_room_users(room_id)

    for member in members:
        if member.user_id not in active_users:
            await manager.send_to_user(member.user_id, "room_updated", {
                "roomId": room_id,
                "lastMessage": last_message,
                "updatedAt": updated_at,
            })


@router.websocket("/ws/notifications")
async def websocket_notifications(
    websocket: WebSocket,
    token: str = Query(...),
):
    """Global notification WS — pushes room_updated events for all user's rooms."""
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        await websocket.close(code=4001)
        return
    user_id = payload.get("sub")

    await websocket.accept()
    await manager.connect_notification(websocket, user_id)

    try:
        # Keep connection alive; client pings, we just hold the socket
        while True:
            await websocket.receive_text()
    except Exception:
        pass
    finally:
        await manager.disconnect_notification(websocket, user_id)


@router.websocket("/ws/chat")
async def websocket_chat(
    websocket: WebSocket,
    token: str = Query(...),
):
    logger = logging.getLogger("hermes.ws")
    logger.info(f"WebSocket connection attempt, token present: {bool(token)}")

    # Verify token
    payload = decode_token(token)
    logger.info(f"Token decode result: {payload}")
    if not payload or payload.get("type") != "access":
        logger.warning(f"Token invalid or wrong type: payload={payload}")
        await websocket.close(code=4001)
        return
    user_id = payload.get("sub")
    username = payload.get("username", "User")

    await websocket.accept()
    logger.info(f"WebSocket accepted for user {username}")

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
    await _update_user_active(user_id)

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

                await _update_user_active(user_id)

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

                # Notify non-active room members
                preview = content[:100] if len(content) > 100 else content
                await _notify_room_updated(room_id, preview, user_msg.created_at)

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

            elif event == "resume":
                # Resume session: load history from database
                async with get_session_maker()() as session:
                    msg_svc = MessageService(session)
                    messages, has_more = await msg_svc.get_messages(room_id, limit=100)
                await websocket.send_json({
                    "event": "resumed",
                    "data": {
                        "roomId": room_id,
                        "messages": [MessageResponse.model_validate(m).model_dump() for m in messages],
                        "isWorking": room_id in active_executors and bool(active_executors[room_id]),
                        "queueLength": len(message_queues.get(room_id, [])),
                    }
                })

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
