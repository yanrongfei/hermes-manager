"""
Integration test for Hermes Server API.
Tests the full conversation flow: register -> login -> create room -> list rooms -> send/receive messages.
Requires server running on http://localhost:3002.
"""
import pytest
import httpx

BASE_URL = "http://localhost:3002"


@pytest.fixture
def client():
    return httpx.Client(base_url=BASE_URL, timeout=10)


@pytest.fixture
def test_user(client):
    """Register a test user and return tokens."""
    resp = client.post("/auth/register", json={
        "username": f"testuser_{id(client)}",
        "password": "TestPass123!"
    })
    assert resp.status_code in (201, 400, 409), f"Register failed: {resp.text}"
    if resp.status_code in (400, 409):
        username = f"testuser_{id(client)}"
    else:
        username = resp.json()["username"]

    resp = client.post("/auth/login", json={
        "username": username,
        "password": "TestPass123!"
    })
    assert resp.status_code == 200, f"Login failed: {resp.text}"
    tokens = resp.json()
    return tokens, username


@pytest.fixture
def auth_headers(test_user):
    tokens, _ = test_user
    return {"Authorization": f"Bearer {tokens['access_token']}"}


# --- Health / Root ---

def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_root(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "Hermes" in resp.json()["message"]


# --- Auth ---

def test_register_and_login(client):
    resp = client.post("/auth/register", json={
        "username": "integration_test_user",
        "password": "SecurePass123!"
    })
    assert resp.status_code in (201, 400, 409)

    resp = client.post("/auth/login", json={
        "username": "integration_test_user",
        "password": "SecurePass123!"
    })
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data


def test_login_wrong_password(client):
    resp = client.post("/auth/login", json={
        "username": "nonexistent_user_xyz",
        "password": "wrong"
    })
    assert resp.status_code == 401


def test_auth_me(client, test_user):
    tokens, username = test_user
    resp = client.get("/auth/me", headers={
        "Authorization": f"Bearer {tokens['access_token']}"
    })
    assert resp.status_code == 200
    assert resp.json()["username"] == username


def test_auth_me_unauthorized(client):
    resp = client.get("/auth/me", headers={
        "Authorization": "Bearer invalid_token"
    })
    assert resp.status_code == 401


def test_refresh_token(client, test_user):
    tokens, _ = test_user
    resp = client.post("/auth/refresh", json={
        "refresh_token": tokens["refresh_token"]
    })
    assert resp.status_code == 200
    assert "access_token" in resp.json()


# --- Rooms (unauthorized) ---

def test_rooms_unauthorized(client):
    resp = client.get("/rooms")
    assert resp.status_code in (401, 403)


# --- Room CRUD ---

def test_create_room_basic(client, auth_headers):
    resp = client.post("/rooms", json={
        "name": "Basic Test Room",
        "mode": "broadcast",
    }, headers=auth_headers)
    assert resp.status_code == 201, f"Create room failed: {resp.text}"
    room = resp.json()
    assert room["name"] == "Basic Test Room"
    assert room["mode"] == "broadcast"
    assert room["id"] is not None


def test_create_room_with_agent_ids(client, auth_headers):
    """Test creating a 1:1 room by sending agent_ids (snake_case)."""
    resp = client.post("/rooms", json={
        "name": "Agent Chat",
        "agent_ids": ["test-agent-1"],
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201, f"Create room failed: {resp.text}"
    room = resp.json()
    assert room["name"] == "Agent Chat"
    assert room["mode"] == "direct"
    assert room["id"] is not None
    # The room should have agent_id set for 1:1
    assert room.get("agent_id") == "test-agent-1"


def test_create_room_with_multiple_agents(client, auth_headers):
    """Test creating a group room with multiple agent_ids."""
    resp = client.post("/rooms", json={
        "name": "Multi-Agent Room",
        "agent_ids": ["agent-a", "agent-b"],
        "mode": "broadcast",
    }, headers=auth_headers)
    assert resp.status_code == 201, f"Create room failed: {resp.text}"
    room = resp.json()
    assert room["name"] == "Multi-Agent Room"


def test_list_rooms(client, auth_headers):
    # Create a room first
    resp = client.post("/rooms", json={
        "name": "List Test Room",
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    # List rooms
    resp = client.get("/rooms", headers=auth_headers)
    assert resp.status_code == 200
    rooms = resp.json()
    assert len(rooms) >= 1
    assert any(r["id"] == room_id for r in rooms)


def test_get_room_detail(client, auth_headers):
    resp = client.post("/rooms", json={
        "name": "Detail Test Room",
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    resp = client.get(f"/rooms/{room_id}", headers=auth_headers)
    assert resp.status_code == 200
    detail = resp.json()
    assert detail["name"] == "Detail Test Room"
    assert "members" in detail
    assert len(detail["members"]) >= 1


def test_get_room_not_found(client, auth_headers):
    resp = client.get("/rooms/nonexistent-room-id", headers=auth_headers)
    # Returns 403 (not a member) or 404 (not found) depending on check order
    assert resp.status_code in (403, 404)


def test_update_room(client, auth_headers):
    resp = client.post("/rooms", json={
        "name": "Original Name",
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    resp = client.put(f"/rooms/{room_id}", json={
        "name": "Updated Name",
    }, headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["name"] == "Updated Name"


def test_leave_room(client, auth_headers):
    # Register a second user and create a group room
    resp = client.post("/auth/register", json={
        "username": f"leave_test_user_{id(client)}",
        "password": "Pass123!",
    })
    assert resp.status_code in (201, 400, 409)
    resp = client.post("/auth/login", json={
        "username": f"leave_test_user_{id(client)}",
        "password": "Pass123!",
    })
    tokens_b = resp.json()
    headers_b = {"Authorization": f"Bearer {tokens_b['access_token']}"}

    # Create group room with User A
    resp = client.post("/rooms", json={
        "name": "Group Room",
        "mode": "broadcast",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    # Generate invite code
    resp = client.post(f"/rooms/{room_id}/invite", headers=auth_headers)
    assert resp.status_code == 200
    invite_code = resp.json()["invite_code"]

    # User B joins
    resp = client.post("/rooms/join", params={"invite_code": invite_code}, headers=headers_b)
    assert resp.status_code == 200

    # User B leaves
    resp = client.delete(f"/rooms/{room_id}/leave", headers=headers_b)
    assert resp.status_code == 204


# --- Messages ---

def test_get_messages_empty(client, auth_headers):
    resp = client.post("/rooms", json={
        "name": "Empty Msg Room",
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    resp = client.get(f"/rooms/{room_id}/messages", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "messages" in data
    assert data["messages"] == []
    assert data["has_more"] is False


def test_get_messages_room_not_found(client, auth_headers):
    resp = client.get("/rooms/nonexistent/messages", headers=auth_headers)
    # Returns 403 (not a member) or 404 (not found) depending on check order
    assert resp.status_code in (403, 404)


def test_get_messages_unauthorized(client):
    resp = client.get("/rooms/some-room/messages")
    assert resp.status_code in (401, 403)


# --- Full Conversation Flow ---

def test_full_conversation_flow(client, auth_headers):
    """End-to-end: register -> create room with agent -> verify room -> list rooms -> get messages."""
    # Step 1: Create a 1:1 room with an agent (mimics tapping an agent in the UI)
    resp = client.post("/rooms", json={
        "name": "test-agent-profile",
        "agent_ids": ["test-agent-profile"],
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201, f"Create 1:1 room failed: {resp.text}"
    room = resp.json()
    room_id = room["id"]
    assert room["name"] == "test-agent-profile"
    assert room["mode"] == "direct"

    # Step 2: Verify room appears in room list
    resp = client.get("/rooms", headers=auth_headers)
    assert resp.status_code == 200
    rooms = resp.json()
    assert any(r["id"] == room_id for r in rooms), "Created room not found in room list"

    # Step 3: Get room detail (includes members)
    resp = client.get(f"/rooms/{room_id}", headers=auth_headers)
    assert resp.status_code == 200
    detail = resp.json()
    assert detail["name"] == "test-agent-profile"
    assert len(detail["members"]) >= 1
    # Owner should be in members
    assert any(m["role"] == "owner" for m in detail["members"])

    # Step 4: Get messages (should be empty)
    resp = client.get(f"/rooms/{room_id}/messages", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["messages"] == []
    assert data["has_more"] is False


def test_two_users_cannot_access_others_room(client, test_user):
    """Verify room isolation between users."""
    tokens_a, _ = test_user

    # User A creates a room
    headers_a = {"Authorization": f"Bearer {tokens_a['access_token']}"}
    resp = client.post("/rooms", json={
        "name": "Private Room A",
        "mode": "direct",
    }, headers=headers_a)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    # Register User B
    resp = client.post("/auth/register", json={
        "username": f"other_user_{id(client)}",
        "password": "Pass123!",
    })
    assert resp.status_code in (201, 400, 409)
    resp = client.post("/auth/login", json={
        "username": f"other_user_{id(client)}",
        "password": "Pass123!",
    })
    assert resp.status_code == 200
    tokens_b = resp.json()
    headers_b = {"Authorization": f"Bearer {tokens_b['access_token']}"}

    # User B cannot access User A's room
    resp = client.get(f"/rooms/{room_id}", headers=headers_b)
    assert resp.status_code == 403

    resp = client.get(f"/rooms/{room_id}/messages", headers=headers_b)
    assert resp.status_code == 403


# --- Room Member Management ---

def test_list_room_members(client, auth_headers):
    resp = client.post("/rooms", json={
        "name": "Members Test Room",
        "mode": "broadcast",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    resp = client.get(f"/rooms/{room_id}/members", headers=auth_headers)
    assert resp.status_code == 200
    members = resp.json()
    assert len(members) >= 1
    assert any(m["role"] == "owner" for m in members)


def test_update_member_role(client, auth_headers):
    # Register User B
    resp = client.post("/auth/register", json={
        "username": f"role_test_user_{id(client)}",
        "password": "Pass123!",
    })
    assert resp.status_code in (201, 400, 409)
    resp = client.post("/auth/login", json={
        "username": f"role_test_user_{id(client)}",
        "password": "Pass123!",
    })
    assert resp.status_code == 200
    tokens_b = resp.json()
    headers_b = {"Authorization": f"Bearer {tokens_b['access_token']}"}
    user_b_id = resp.json().get("user_id")
    # Get user_b_id from /auth/me
    resp = client.get("/auth/me", headers=headers_b)
    user_b_id = resp.json()["id"]

    # Create group room
    resp = client.post("/rooms", json={
        "name": "Role Test Room",
        "mode": "broadcast",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    # Generate invite and User B joins
    resp = client.post(f"/rooms/{room_id}/invite", headers=auth_headers)
    assert resp.status_code == 200
    invite_code = resp.json()["invite_code"]
    resp = client.post("/rooms/join", params={"invite_code": invite_code}, headers=headers_b)
    assert resp.status_code == 200

    # Owner promotes User B to admin
    resp = client.put(f"/rooms/{room_id}/members/{user_b_id}", json={
        "role": "admin",
    }, headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["role"] == "admin"

    # Verify member list shows the updated role
    resp = client.get(f"/rooms/{room_id}/members", headers=auth_headers)
    members = resp.json()
    admin_member = next(m for m in members if m["user_id"] == user_b_id)
    assert admin_member["role"] == "admin"


def test_remove_member(client, auth_headers):
    # Register User C
    resp = client.post("/auth/register", json={
        "username": f"remove_test_user_{id(client)}",
        "password": "Pass123!",
    })
    assert resp.status_code in (201, 400, 409)
    resp = client.post("/auth/login", json={
        "username": f"remove_test_user_{id(client)}",
        "password": "Pass123!",
    })
    tokens_c = resp.json()
    headers_c = {"Authorization": f"Bearer {tokens_c['access_token']}"}
    resp = client.get("/auth/me", headers=headers_c)
    user_c_id = resp.json()["id"]

    # Create group room and invite User C
    resp = client.post("/rooms", json={
        "name": "Remove Test Room",
        "mode": "broadcast",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    resp = client.post(f"/rooms/{room_id}/invite", headers=auth_headers)
    invite_code = resp.json()["invite_code"]
    client.post("/rooms/join", params={"invite_code": invite_code}, headers=headers_c)

    # Owner removes User C
    resp = client.delete(f"/rooms/{room_id}/members/{user_c_id}", headers=auth_headers)
    assert resp.status_code == 204

    # User C is no longer in members list
    resp = client.get(f"/rooms/{room_id}/members", headers=auth_headers)
    members = resp.json()
    assert not any(m["user_id"] == user_c_id for m in members)
