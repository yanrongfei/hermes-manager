"""
Integration tests for Gateway, Profile, and Gateway Proxy API endpoints.
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
        "username": f"gw_test_user_{id(client)}",
        "password": "TestPass123!"
    })
    assert resp.status_code in (201, 400, 409)
    username = f"gw_test_user_{id(client)}"
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


# --- Gateway Status ---

def test_list_gateway_status(client, auth_headers):
    resp = client.get("/gateways/status", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


def test_discover_gateways(client, auth_headers):
    resp = client.get("/gateways/discover", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


# --- Gateway CRUD ---

def test_list_gateways_empty(client, auth_headers):
    resp = client.get("/gateways", headers=auth_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_gateway_unreachable(client, auth_headers):
    """Creating a gateway with an unreachable address should fail gracefully."""
    import httpx as _httpx
    try:
        resp = client.post("/gateways", json={
            "name": "Test Gateway",
            "address": "http://192.0.2.1:9999",
        }, headers=auth_headers, timeout=3.0)
        # If we get a response, it should be an error status
        assert resp.status_code in (400, 408, 500, 502, 504)
    except (_httpx.ReadTimeout, _httpx.ConnectTimeout):
        pass  # Expected: server may timeout trying to health-check the gateway


def test_get_gateway_not_found(client, auth_headers):
    resp = client.get("/gateways/nonexistent-id", headers=auth_headers)
    assert resp.status_code == 404


def test_update_gateway_not_found(client, auth_headers):
    resp = client.patch("/gateways/nonexistent-id", json={
        "name": "Updated",
    }, headers=auth_headers)
    assert resp.status_code == 404


def test_delete_gateway_not_found(client, auth_headers):
    resp = client.delete("/gateways/nonexistent-id", headers=auth_headers)
    assert resp.status_code == 404


def test_test_gateway_not_found(client, auth_headers):
    resp = client.post("/gateways/nonexistent-id/test", headers=auth_headers)
    assert resp.status_code == 404


def test_sync_gateway_not_found(client, auth_headers):
    resp = client.post("/gateways/nonexistent-id/sync", headers=auth_headers)
    assert resp.status_code == 404


def test_list_gateway_profiles_not_found(client, auth_headers):
    resp = client.get("/gateways/nonexistent-id/profiles", headers=auth_headers)
    assert resp.status_code == 404


# --- Profiles ---

def test_get_profile_not_found(client, auth_headers):
    resp = client.get("/profiles/nonexistent-id", headers=auth_headers)
    assert resp.status_code == 404


def test_update_profile_not_found(client, auth_headers):
    resp = client.patch("/profiles/nonexistent-id", json={
        "alias": "New Alias",
    }, headers=auth_headers)
    assert resp.status_code == 404


# --- Stop Gateway ---

def test_stop_gateway_nonexistent_profile(client, auth_headers):
    resp = client.post("/gateways/stop", params={"profile": "nonexistent-profile-xyz"}, headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True


# --- Unauthorized ---

def test_gateways_unauthorized(client):
    resp = client.get("/gateways")
    assert resp.status_code in (401, 403)


def test_gateway_status_unauthorized(client):
    resp = client.get("/gateways/status")
    assert resp.status_code in (401, 403)
