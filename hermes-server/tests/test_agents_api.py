"""
Integration tests for Agent and Room Agent API endpoints.
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
    resp = client.post("/auth/register", json={
        "username": f"agent_test_user_{id(client)}",
        "password": "TestPass123!"
    })
    assert resp.status_code in (201, 400, 409)
    username = f"agent_test_user_{id(client)}"
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


# --- Agent List ---

def test_list_agents(client, auth_headers):
    resp = client.get("/agents", headers=auth_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_list_agents_unauthorized(client):
    resp = client.get("/agents")
    assert resp.status_code in (401, 403)


def test_list_profile_agents_not_found(client, auth_headers):
    resp = client.get("/profiles/nonexistent-id/agents", headers=auth_headers)
    # May return 200 with empty list or 404 depending on implementation
    assert resp.status_code in (200, 404)


# --- Agent Delete ---

def test_delete_agent_not_found(client, auth_headers):
    resp = client.delete("/agents/nonexistent-id", headers=auth_headers)
    assert resp.status_code == 404


# --- Agent Invite ---

def test_invite_agent_not_found(client, auth_headers):
    resp = client.post("/agents/nonexistent-id/invite", headers=auth_headers)
    assert resp.status_code == 404


# --- Room Agent Management ---

def test_list_room_agents_unauthorized(client):
    resp = client.get("/rooms/nonexistent/agents")
    assert resp.status_code in (401, 403)


def test_list_room_agents_not_member(client, auth_headers):
    """Room that doesn't exist → 403 (not a member check fires first)."""
    resp = client.get("/rooms/nonexistent-room/agents", headers=auth_headers)
    assert resp.status_code in (403, 404)


def test_room_agents_after_room_creation(client, auth_headers):
    """Create a room and verify room agents list works."""
    resp = client.post("/rooms", json={
        "name": "Agent Room",
        "agent_ids": ["test-agent-x"],
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    # List room agents — user is owner so should pass membership check
    resp = client.get(f"/rooms/{room_id}/agents", headers=auth_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_add_agent_to_room_not_member(client, auth_headers):
    resp = client.post("/rooms/nonexistent/agents", params={"agent_id": "x"}, headers=auth_headers)
    assert resp.status_code == 403


def test_remove_agent_from_room_not_found(client, auth_headers):
    """Create a room, then try to remove a nonexistent agent."""
    resp = client.post("/rooms", json={
        "name": "Room for Agent Remove",
        "mode": "direct",
    }, headers=auth_headers)
    assert resp.status_code == 201
    room_id = resp.json()["id"]

    resp = client.delete(f"/rooms/{room_id}/agents/nonexistent-agent", headers=auth_headers)
    assert resp.status_code == 404
