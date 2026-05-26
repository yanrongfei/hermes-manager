import json
import asyncio
from typing import Dict, Set
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        # room_id -> set of websockets
        self.active_connections: Dict[str, Set[WebSocket]] = {}
        # websocket -> user_id
        self.user_connections: Dict[WebSocket, str] = {}
        # websocket -> room_id
        self.room_connections: Dict[WebSocket, str] = {}
        # user_id -> set of notification websockets (global, not room-bound)
        self.notification_sockets: Dict[str, Set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, room_id: str, user_id: str):
        async with self._lock:
            if room_id not in self.active_connections:
                self.active_connections[room_id] = set()
            self.active_connections[room_id].add(websocket)
            self.user_connections[websocket] = user_id
            self.room_connections[websocket] = room_id

    async def disconnect(self, websocket: WebSocket):
        async with self._lock:
            room_id = self.room_connections.get(websocket)
            if room_id and room_id in self.active_connections:
                self.active_connections[room_id].discard(websocket)
                if not self.active_connections[room_id]:
                    del self.active_connections[room_id]
            self.user_connections.pop(websocket, None)
            self.room_connections.pop(websocket, None)

    async def send_to_room(self, room_id: str, event: str, data: dict):
        if room_id not in self.active_connections:
            return
        message = json.dumps({"event": event, "data": data})
        dead_connections = set()
        async with self._lock:
            for connection in self.active_connections[room_id]:
                try:
                    await connection.send_text(message)
                except Exception:
                    dead_connections.add(connection)
        for dead in dead_connections:
            await self.disconnect(dead)

    async def broadcast_to_room(self, room_id: str, event: str, data: dict, exclude: WebSocket = None):
        if room_id not in self.active_connections:
            return
        message = json.dumps({"event": event, "data": data})
        dead_connections = set()
        async with self._lock:
            for connection in self.active_connections[room_id]:
                if connection != exclude:
                    try:
                        await connection.send_text(message)
                    except Exception:
                        dead_connections.add(connection)
        for dead in dead_connections:
            await self.disconnect(dead)

    # --- Notification (user-level) connections ---

    async def connect_notification(self, websocket: WebSocket, user_id: str):
        async with self._lock:
            if user_id not in self.notification_sockets:
                self.notification_sockets[user_id] = set()
            self.notification_sockets[user_id].add(websocket)

    async def disconnect_notification(self, websocket: WebSocket, user_id: str):
        async with self._lock:
            if user_id in self.notification_sockets:
                self.notification_sockets[user_id].discard(websocket)
                if not self.notification_sockets[user_id]:
                    del self.notification_sockets[user_id]

    async def send_to_user(self, user_id: str, event: str, data: dict):
        """Send an event to all notification sockets of a user."""
        sockets = self.notification_sockets.get(user_id)
        if not sockets:
            return
        message = json.dumps({"event": event, "data": data})
        dead = set()
        for ws in list(sockets):
            try:
                await ws.send_text(message)
            except Exception:
                dead.add(ws)
        for d in dead:
            await self.disconnect_notification(d, user_id)

    def get_active_room_users(self, room_id: str) -> Set[str]:
        """Return user_ids currently connected to a room's WS."""
        users = set()
        for ws, uid in self.user_connections.items():
            if self.room_connections.get(ws) == room_id:
                users.add(uid)
        return users

manager = ConnectionManager()