from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db, get_session_maker
from app.core.security import decode_token
from app.services.room import RoomService
from app.services.message import MessageService
from app.services.websocket import manager

router = APIRouter()

@router.websocket("/ws/chat")
async def websocket_chat(
    websocket: WebSocket,
    token: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    # Verify token
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        await websocket.close(code=4001)
        return
    user_id = payload.get("sub")

    # Join room
    data = await websocket.receive_json()
    event = data.get("event")
    if event != "join":
        await websocket.close(code=4002)
        return

    room_id = data.get("data", {}).get("roomId")
    if not room_id:
        await websocket.close(code=4003)
        return

    room_service = RoomService(db)
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
                async with get_session_maker()() as session:
                    message_service = MessageService(session)
                    msg = await message_service.create_message(
                        room_id=room_id,
                        sender_id=user_id,
                        sender_type="user",
                        sender_name=payload.get("username", "User"),
                        content=content
                    )
                    await manager.broadcast_to_room(
                        room_id,
                        "message",
                        {
                            "id": msg.id,
                            "roomId": room_id,
                            "senderId": user_id,
                            "senderType": "user",
                            "senderName": msg.sender_name,
                            "content": msg.content,
                            "contentType": msg.content_type,
                            "createdAt": msg.created_at
                        }
                    )

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
        await manager.broadcast_to_room(
            room_id,
            "member_left",
            {"userId": user_id, "roomId": room_id}
        )