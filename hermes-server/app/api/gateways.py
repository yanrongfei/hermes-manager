"""
Gateway Management and Proxy API.

This module provides:
1. CRUD for user-configured Gateway connections
2. Proxy endpoints to forward requests to Hermes Gateway
"""

import httpx
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.core.deps import get_current_user
from app.core.errors import AppException, ErrorCode
from app.models.machine import Machine
from app.schemas.machine import MachineCreate, MachineUpdate, MachineResponse
from app.services.gateway_client import GatewayClient
from app.services.gateway_discovery import scan_local_gateways
from app.services.local_profile_scanner import scan_local_profiles
from app.services.gateway_channel import GatewayChannel
from app.config import get_settings

settings = get_settings()
router = APIRouter(tags=["gateways"])


# ── Gateway CRUD ─────────────────────────────────────────────────

@router.get("/gateways", response_model=List[MachineResponse])
async def list_gateways(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Machine).where(Machine.user_id == current_user.id)
    )
    machines = list(result.scalars().all())
    return [_machine_to_response(m) for m in machines]


@router.get("/gateways/discover", response_model=List[dict])
async def discover_gateways(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Machine).where(Machine.user_id == current_user.id)
    )
    existing_machines = list(result.scalars().all())
    existing_addresses = {m.address for m in existing_machines}
    existing_profiles = {m.profile_name for m in existing_machines if m.profile_name}

    # HTTP gateway discovery
    http_gateways = await scan_local_gateways(exclude_addresses=existing_addresses)

    # Track addresses already found by HTTP scan to avoid duplicates
    seen_addresses = {g["address"] for g in http_gateways}

    # Local profile discovery
    local_profiles = scan_local_profiles()
    local_results = []
    for p in local_profiles:
        if p["profile_name"] not in existing_profiles:
            # Skip if HTTP scan already found this address
            if p["address"] in seen_addresses:
                continue
            seen_addresses.add(p["address"])
            local_results.append({
                "profile_name": p["profile_name"],
                "name": p.get("name", p["profile_name"]),
                "address": p["address"],
                "mode": p["mode"],
                "model": p.get("model", ""),
                "provider": p.get("provider", ""),
                "online": p.get("online", False),
                "active": p.get("active", False),
                "api_server_connected": p.get("api_server_connected", False),
                "api_key": p.get("api_key", ""),
            })

    return http_gateways + local_results


@router.post("/gateways", response_model=MachineResponse, status_code=201)
async def create_gateway(
    data: MachineCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    gateway = GatewayClient(data.address, api_key=data.api_key)
    is_healthy = await gateway.health_check()
    await gateway.close()

    # Local mode doesn't require HTTP health check
    if data.mode == "local" and not is_healthy:
        is_healthy = True

    if not is_healthy:
        raise AppException(ErrorCode.GATEWAY_UNREACHABLE, f"网关 {data.address} 无法连接", status_code=400)

    machine = Machine(
        user_id=current_user.id,
        name=data.name,
        address=data.address,
        api_key=data.api_key,
        mode=data.mode,
        profile_name=data.profile_name,
    )
    db.add(machine)
    await db.commit()
    await db.refresh(machine)
    return _machine_to_response(machine)


@router.get("/gateways/{gateway_id}", response_model=MachineResponse)
async def get_gateway(
    gateway_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    machine = await _get_user_gateway(db, gateway_id, current_user.id)
    if not machine:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
    return _machine_to_response(machine)


@router.delete("/gateways/{gateway_id}", status_code=204)
async def delete_gateway(
    gateway_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    machine = await _get_user_gateway(db, gateway_id, current_user.id)
    if not machine:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
    await db.delete(machine)
    await db.commit()


@router.post("/gateways/{gateway_id}/test", response_model=dict)
async def test_gateway(
    gateway_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    machine = await _get_user_gateway(db, gateway_id, current_user.id)
    if not machine:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)

    channel = GatewayChannel(machine)
    try:
        is_healthy = await channel.health_check()
        return {"gateway_id": gateway_id, "online": is_healthy, "mode": channel.active_mode}
    finally:
        await channel.close()


@router.patch("/gateways/{gateway_id}", response_model=MachineResponse)
async def update_gateway(
    gateway_id: str,
    data: MachineUpdate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    machine = await _get_user_gateway(db, gateway_id, current_user.id)
    if not machine:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
    if data.name is not None:
        machine.name = data.name
    if data.api_key is not None:
        machine.api_key = data.api_key
    await db.commit()
    await db.refresh(machine)
    return _machine_to_response(machine)


@router.get("/gateways/{gateway_id}/agents", response_model=List[dict])
async def discover_agents(
    gateway_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    machine = await _get_user_gateway(db, gateway_id, current_user.id)
    if not machine:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)

    channel = GatewayChannel(machine)
    try:
        agents = await channel.list_agents()
        return agents
    finally:
        await channel.close()


# ── Gateway Proxy ───────────────────────────────────────────────

@router.api_route("/proxy/gateway/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_to_gateway(
    path: str,
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    gateway_id: Optional[str] = Query(None),
):
    if gateway_id:
        machine = await _get_user_gateway(db, gateway_id, current_user.id)
        if not machine:
            raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
        gateway_url = machine.address
    else:
        gateway_url = settings.DEFAULT_GATEWAY_URL

    upstream_url = f"{gateway_url}/{path}"
    body = await request.body()

    headers = {}
    for key, value in request.headers.items():
        if key.lower() not in ("host", "content-length"):
            headers[key] = value

    async with httpx.AsyncClient(timeout=60.0) as client:
        upstream = httpx.Request(
            method=request.method,
            url=upstream_url,
            headers=headers,
            content=body or None,
        )
        response = await client.send(upstream)

    from fastapi.responses import Response
    return Response(
        content=response.content,
        status_code=response.status_code,
        headers=dict(response.headers),
    )


# ── Helpers ───────────────────────────────────────────────────

async def _get_user_gateway(db: AsyncSession, gateway_id: str, user_id: str) -> Optional[Machine]:
    result = await db.execute(
        select(Machine).where(
            Machine.id == gateway_id,
            Machine.user_id == user_id
        )
    )
    return result.scalar_one_or_none()


def _machine_to_response(machine: Machine) -> MachineResponse:
    return MachineResponse(
        id=machine.id,
        name=machine.name,
        address=machine.address,
        api_key=machine.api_key,
        mode=machine.mode or "http",
        profile_name=machine.profile_name,
        created_at=machine.created_at,
    )
