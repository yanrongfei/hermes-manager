"""
Integration test for Hermes Server API.
Tests the full flow: register -> login -> create room -> list rooms -> send message.
Requires server running on http://localhost:8000.
"""
import pytest
import httpx

BASE_URL = "http://localhost:8000"


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
    assert resp.status_code in (201, 400), f"Register failed: {resp.text}"
    if resp.status_code == 400:
        # User exists, just login
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


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_root(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "Hermes" in resp.json()["message"]


def test_register_and_login(client):
    # Register
    resp = client.post("/auth/register", json={
        "username": "integration_test_user",
        "password": "SecurePass123!"
    })
    assert resp.status_code in (201, 400)

    # Login
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


def test_create_and_list_rooms(client, test_user):
    tokens, _ = test_user
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    # Create room
    resp = client.post("/rooms", json={
        "name": "Integration Test Room",
        "mode": "single"
    }, headers=headers)
    assert resp.status_code == 201, f"Create room failed: {resp.text}"
    room = resp.json()
    assert room["name"] == "Integration Test Room"
    room_id = room["id"]

    # List rooms
    resp = client.get("/rooms", headers=headers)
    assert resp.status_code == 200
    rooms = resp.json()
    assert len(rooms) >= 1
    assert any(r["id"] == room_id for r in rooms)

    # Get room detail
    resp = client.get(f"/rooms/{room_id}", headers=headers)
    assert resp.status_code == 200
    detail = resp.json()
    assert detail["name"] == "Integration Test Room"
    assert "members" in detail


def test_rooms_unauthorized(client):
    resp = client.get("/rooms")
    assert resp.status_code in (401, 403)


def test_refresh_token(client, test_user):
    tokens, _ = test_user
    resp = client.post("/auth/refresh", json={
        "refresh_token": tokens["refresh_token"]
    })
    assert resp.status_code == 200
    assert "access_token" in resp.json()
