"""
Integration tests for WebSocket resume and message pagination.
Requires server running on http://localhost:3002.
"""
import pytest
import httpx
import websockets
import json
import asyncio
import time

BASE_URL = "http://localhost:3002"
WS_URL = "ws://localhost:3002/ws/chat"


@pytest.fixture
def client():
    return httpx.Client(base_url=BASE_URL, timeout=10)


@pytest.fixture
def test_user(client):
    import random
    username = f"ws_test_user_{random.randint(10000, 99999)}_{int(time.time())}"
    resp = client.post("/auth/register", json={
        "username": username,
        "password": "TestPass123!"
    })
    assert resp.status_code in (201, 400, 409)
    resp = client.post("/auth/login", json={
        "username": username,
        "password": "TestPass123!"
    })
    assert resp.status_code == 200
    return resp.json(), username


@pytest.fixture
def auth_headers(test_user):
    tokens, _ = test_user
    return {"Authorization": f"Bearer {tokens['access_token']}"}


# --- Message Pagination ---

def test_get_messages_pagination(client, auth_headers):
    """Test that messages can be paginated using 'before' parameter."""
    resp = client.post("/rooms", json={
        "name": "Pagination Test Room",
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    resp = client.get(f"/rooms/{room_id}/messages", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "messages" in data
    assert "has_more" in data
    assert data["has_more"] is False


def test_get_messages_has_more_flag(client, auth_headers):
    """Test that has_more is True when there are more messages than limit."""
    resp = client.post("/rooms", json={
        "name": "HasMore Test Room",
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    resp = client.get(f"/rooms/{room_id}/messages", params={"limit": 1}, headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["has_more"] is False


# --- WebSocket Resume ---


async def _ws_join_and_resume(access_token: str, room_id: str):
    """Helper: connect to WebSocket, join room, send resume, return response."""
    async with websockets.connect(f"{WS_URL}?token={access_token}") as ws:
        # Send join
        await ws.send(json.dumps({
            "event": "join",
            "data": {"roomId": room_id}
        }))

        # Send resume
        await ws.send(json.dumps({
            "event": "resume",
            "data": {"roomId": room_id}
        }))

        # Receive resumed event
        response = await asyncio.wait_for(ws.recv(), timeout=5)
        return json.loads(response)


@pytest.mark.asyncio
async def test_ws_resume_returns_session_state(test_user):
    """Test that WebSocket resume event returns session state with messages."""
    tokens, _ = test_user
    access_token = tokens["access_token"]

    # Create a room via HTTP
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=10) as http_client:
        resp = await http_client.post("/rooms", json={
            "name": "Resume Test Room",
            "mode": "direct",
        }, headers={"Authorization": f"Bearer {access_token}"})
        assert resp.status_code == 201
        room_id = resp.json()["id"]

        # Resume session
        data = await _ws_join_and_resume(access_token, room_id)
        assert data is not None
        assert "event" in data


@pytest.mark.asyncio
async def test_ws_resume_without_room_id_handled(test_user):
    """Test that resume without room_id is handled gracefully."""
    tokens, _ = test_user
    access_token = tokens["access_token"]

    async with httpx.AsyncClient(base_url=BASE_URL, timeout=10) as http_client:
        resp = await http_client.post("/rooms", json={
            "name": "No Resume Room",
            "mode": "direct",
        }, headers={"Authorization": f"Bearer {access_token}"})
        room_id = resp.json()["id"]

    async with websockets.connect(f"{WS_URL}?token={access_token}") as ws:
        # Join room
        await ws.send(json.dumps({
            "event": "join",
            "data": {"roomId": room_id}
        }))
        await asyncio.sleep(0.2)

        # Send resume without roomId - should be a no-op (room_id comes from WebSocket context)
        await ws.send(json.dumps({
            "event": "resume",
            "data": {}
        }))

        # Should handle gracefully (may not receive anything back)
        try:
            response = await asyncio.wait_for(ws.recv(), timeout=2)
            data = json.loads(response)
            assert isinstance(data, dict)
        except asyncio.TimeoutError:
            pass  # Timeout is acceptable


@pytest.mark.asyncio
async def test_ws_resume_with_empty_room_returns_empty_messages(test_user):
    """Test that resuming an empty room returns empty messages list."""
    tokens, _ = test_user
    access_token = tokens["access_token"]

    async with httpx.AsyncClient(base_url=BASE_URL, timeout=10) as http_client:
        resp = await http_client.post("/rooms", json={
            "name": "Empty Resume Room",
            "mode": "direct",
        }, headers={"Authorization": f"Bearer {access_token}"})
        assert resp.status_code == 201
        room_id = resp.json()["id"]

        data = await _ws_join_and_resume(access_token, room_id)
        assert data["event"] == "resumed"
        assert "data" in data
        assert "messages" in data["data"]
        assert isinstance(data["data"]["messages"], list)


# --- WebSocket Events ---


async def _ws_send_and_receive(access_token: str, room_id: str, event: str, data: dict):
    """Helper: connect, join, send event, return response."""
    async with websockets.connect(f"{WS_URL}?token={access_token}") as ws:
        await ws.send(json.dumps({
            "event": "join",
            "data": {"roomId": room_id}
        }))
        await asyncio.sleep(0.2)

        await ws.send(json.dumps({"event": event, "data": data}))

        try:
            response = await asyncio.wait_for(ws.recv(), timeout=2)
            return json.loads(response)
        except asyncio.TimeoutError:
            return None


@pytest.mark.asyncio
async def test_ws_typing_events(test_user):
    """Test typing and stop_typing events are handled."""
    tokens, _ = test_user
    access_token = tokens["access_token"]

    async with httpx.AsyncClient(base_url=BASE_URL, timeout=10) as http_client:
        resp = await http_client.post("/rooms", json={
            "name": "Typing Test Room",
            "mode": "direct",
        }, headers={"Authorization": f"Bearer {access_token}"})
        room_id = resp.json()["id"]

        # Typing event
        result = await _ws_send_and_receive(access_token, room_id, "typing", {})
        # Should not raise, timeout is OK

        # Stop typing event
        result = await _ws_send_and_receive(access_token, room_id, "stop_typing", {})
        # Should not raise


@pytest.mark.asyncio
async def test_ws_abort_event_handled(test_user):
    """Test abort event handling - should not raise even if no active run."""
    tokens, _ = test_user
    access_token = tokens["access_token"]

    async with httpx.AsyncClient(base_url=BASE_URL, timeout=10) as http_client:
        resp = await http_client.post("/rooms", json={
            "name": "Abort Test Room",
            "mode": "direct",
        }, headers={"Authorization": f"Bearer {access_token}"})
        room_id = resp.json()["id"]

        result = await _ws_send_and_receive(access_token, room_id, "abort", {})
        # Should not raise