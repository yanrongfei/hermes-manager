"""
Gateway Management and Proxy API.

This module provides:
1. CRUD for user-configured Gateway connections
2. Proxy endpoints to forward requests to Hermes Gateway
"""

import httpx
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.core.deps import get_current_user
from app.models.machine import Machine  # Reuse existing Machine table as Gateway store
from app.schemas.machine import MachineCreate, MachineUpdate, MachineResponse
from app.services.gateway_client import GatewayClient
from app.config import get_settings

settings = get_settings()
router = APIRouter(tags=["gateways"])


# ── Gateway CRUD ─────────────────────────────────────────────────

@router.get("/gateways", response_model=List[MachineResponse])
async def list_gateways(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all gateways configured by the user."""
    result = await db.execute(
        select(Machine).where(Machine.user_id == current_user.id)
    )
    machines = list(result.scalars().all())
    return [_machine_to_response(m) for m in machines]


@router.post("/gateways", response_model=MachineResponse, status_code=201)
async def create_gateway(
    data: MachineCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Add a new Gateway connection."""
    # Verify connectivity
    gateway = GatewayClient(data.address)
    is_healthy = await gateway.health_check()
    await gateway.close()

    if not is_healthy:
        raise HTTPException(
            status_code=400,
            detail=f"Gateway at {data.address} is not reachable"
        )

    machine = Machine(
        user_id=current_user.id,
        name=data.name,
        address=data.address,
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
    """Get a specific gateway."""
    machine = await _get_user_gateway(db, gateway_id, current_user.id)
    if not machine:
        raise HTTPException(status_code=404, detail="Gateway not found")
    return _machine_to_response(machine)


@router.delete("/gateways/{gateway_id}", status_code=204)
async def delete_gateway(
    gateway_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a gateway."""
    machine = await _get_user_gateway(db, gateway_id, current_user.id)
    if not machine:
        raise HTTPException(status_code=404, detail="Gateway not found")
    await db.delete(machine)
    await db.commit()


@router.post("/gateways/{gateway_id}/test", response_model=dict)
async def test_gateway(
    gateway_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Test connectivity to a gateway."""
    machine = await _get_user_gateway(db, gateway_id, current_user.id)
    if not machine:
        raise HTTPException(status_code=404, detail="Gateway not found")

    gateway = GatewayClient(machine.address)
    is_healthy = await gateway.health_check()
    await gateway.close()

    return {"gateway_id": gateway_id, "online": is_healthy}


@router.get("/gateways/{gateway_id}/agents", response_model=List[dict])
async def discover_agents(
    gateway_id: str,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Discover available agents/profiles from a gateway."""
    machine = await _get_user_gateway(db, gateway_id, current_user.id)
    if not machine:
        raise HTTPException(status_code=404, detail="Gateway not found")

    gateway = GatewayClient(machine.address)
    try:
        agents = await gateway.list_agents()
        return agents
    finally:
        await gateway.close()


# ── Gateway Proxy ───────────────────────────────────────────────

@router.api_route("/proxy/gateway/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_to_gateway(
    path: str,
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    gateway_id: Optional[str] = Query(None),
):
    """
    Proxy requests to Hermes Gateway.

    If gateway_id is provided, use that specific gateway.
    Otherwise, use the first available gateway for the user.
    """
    if gateway_id:
        machine = await _get_user_gateway(db, gateway_id, current_user.id)
        if not machine:
            raise HTTPException(status_code=404, detail="Gateway not found")
        gateway_url = machine.address
    else:
        # Use default
        gateway_url = settings.DEFAULT_GATEWAY_URL

    # Build upstream URL
    upstream_url = f"{gateway_url}/{path}"

    # Read request body
    body = await request.body()

    # Forward headers (except host)
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
        created_at=machine.created_at,
    )
