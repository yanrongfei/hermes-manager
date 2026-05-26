"""Gateway Management and Proxy API."""

import time
import httpx
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.database import get_db
from app.core.deps import get_current_user
from app.core.errors import AppException, ErrorCode
from app.models.gateway import Gateway
from app.models.profile import Profile
from app.models.agent import Agent
from app.schemas.gateway import GatewayCreate, GatewayUpdate, GatewayResponse
from app.schemas.profile import ProfileResponse, ProfileUpdate
from app.services.gateway_client import GatewayClient
from app.services.gateway_channel import GatewayChannel
from app.services.gateway_sync import GatewaySyncService
from app.services.gateway_discovery import scan_local_gateways
from app.services.local_profile_scanner import scan_local_profiles
from app.config import get_settings

settings = get_settings()
router = APIRouter(tags=["gateways"])


# ── Gateway CRUD ─────────────────────────────────────────────────

@router.get("/gateways", response_model=List[GatewayResponse])
async def list_gateways(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Gateway).where(Gateway.user_id == current_user.id)
    )
    gateways = list(result.scalars().all())

    response = []
    for gw in gateways:
        p_count = await _count_profiles(db, gw.id)
        a_count = await _count_agents(db, gw.id)
        response.append(GatewayResponse(
            id=gw.id,
            name=gw.name,
            address=gw.address,
            api_key=gw.api_key,
            status=gw.status or "unknown",
            last_seen=gw.last_seen,
            created_at=gw.created_at,
            profile_count=p_count,
            agent_count=a_count,
        ))
    return response


@router.post("/gateways/stop", response_model=dict)
async def stop_gateway(
    current_user=Depends(get_current_user),
    profile: str = Query(..., description="Profile name to stop"),
):
    """Stop a local gateway process by profile name."""
    import os
    import signal
    import time
    import json
    from pathlib import Path

    home = Path.home() / ".hermes"
    profile_dir = home if profile == "default" else home / "profiles" / profile
    pid_file = profile_dir / "gateway.pid"
    state_file = profile_dir / "gateway_state.json"

    pid = None
    running = False

    # Read PID from gateway.pid (JSON format: {"pid": 123})
    if pid_file.exists():
        try:
            data = json.loads(pid_file.read_text().strip())
            pid = data.get("pid")
            if isinstance(pid, str):
                pid = int(pid) if pid.isdigit() else None
        except Exception:
            pass

    # Fallback to gateway_state.json
    if not pid and state_file.exists():
        try:
            data = json.loads(state_file.read_text().strip())
            if data.get("gateway_state") in ("running", "starting"):
                pid = data.get("pid")
                if isinstance(pid, str):
                    pid = int(pid) if pid.isdigit() else None
        except Exception:
            pass

    # Verify process is alive
    if pid:
        try:
            os.kill(pid, 0)
            running = True
        except OSError:
            pid = None
            running = False

    if not running or not pid:
        return {"success": True, "message": f"Gateway for profile '{profile}' is not running"}

    # Try hermes gateway stop CLI first
    hermes_bin = None
    for candidate in [
        Path.home() / ".local" / "bin" / "hermes",
        Path("/opt/hermes/bin/hermes"),
        Path("/usr/local/bin/hermes"),
    ]:
        if candidate.exists():
            hermes_bin = str(candidate)
            break

    if hermes_bin:
        try:
            import subprocess
            env = os.environ.copy()
            env["HERMES_HOME"] = str(profile_dir)
            subprocess.run(
                [hermes_bin, "gateway", "stop"],
                capture_output=True,
                timeout=15,
                env=env,
            )
        except Exception:
            pass

    # Wait briefly for graceful shutdown
    try:
        for _ in range(30):
            try:
                os.kill(pid, 0)
                time.sleep(0.1)
            except OSError:
                break
        else:
            os.kill(pid, signal.SIGKILL)
    except OSError:
        pass

    return {"success": True, "message": f"Gateway for profile '{profile}' stopped", "pid": pid}


@router.get("/gateways/status", response_model=List[dict])
async def list_gateway_status(
    current_user=Depends(get_current_user),
):
    """List all local profile gateway statuses.

    Returns profile name, IP/port, running status, PID, and stop capability.
    """
    from app.services.local_profile_scanner import scan_local_profiles

    profiles = scan_local_profiles()
    return [
        {
            "profile": p.get("profile_name", p.get("name", "")),
            "host": p.get("gateway_host", "127.0.0.1"),
            "port": p.get("gateway_port", 8642),
            "url": p.get("address", ""),
            "running": p.get("online", False) or p.get("running", False),
            "pid": p.get("pid"),
            "mode": p.get("mode", "local"),
            "api_server_connected": p.get("api_server_connected", False),
            "model": p.get("model", ""),
            "provider": p.get("provider", ""),
            "profile_path": p.get("config_path", ""),
            "skills_count": p.get("skills_count", 0),
            "has_env": p.get("has_env", False),
            "has_soul": p.get("has_soul", False),
        }
        for p in profiles
    ]


@router.get("/gateways/discover", response_model=List[dict])
async def discover_gateways(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Gateway).where(Gateway.user_id == current_user.id)
    )
    existing = list(result.scalars().all())
    existing_addresses = {g.address for g in existing}

    http_gateways = await scan_local_gateways(exclude_addresses=existing_addresses)

    local_profiles = scan_local_profiles()
    local_api_keys: dict[str, str] = {}
    for p in local_profiles:
        if p.get("api_key"):
            local_api_keys[p["address"]] = p["api_key"]

    for g in http_gateways:
        addr = g.get("address", "")
        if not g.get("api_key") and addr in local_api_keys:
            g["api_key"] = local_api_keys[addr]

    seen_addresses = {g["address"] for g in http_gateways}

    local_results = []
    for p in local_profiles:
        if p["address"] not in existing_addresses and p["address"] not in seen_addresses:
            seen_addresses.add(p["address"])
            local_results.append({
                "profile_name": p["profile_name"],
                "name": p.get("name", p["profile_name"]),
                "address": p["address"],
                "model": p.get("model", ""),
                "provider": p.get("provider", ""),
                "online": p.get("online", False),
                "active": p.get("active", False),
                "api_key": p.get("api_key", ""),
            })

    return http_gateways + local_results


@router.post("/gateways", response_model=GatewayResponse, status_code=201)
async def create_gateway(
    data: GatewayCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    client = GatewayClient(data.address, api_key=data.api_key)
    is_healthy = await client.health_check()
    await client.close()

    if not is_healthy:
        raise AppException(ErrorCode.GATEWAY_UNREACHABLE, f"网关 {data.address} 无法连接", status_code=400)

    now = int(time.time())
    gateway = Gateway(
        user_id=current_user.id,
        name=data.name,
        address=data.address,
        api_key=data.api_key,
        status="online",
        last_seen=now,
    )
    db.add(gateway)
    await db.commit()
    await db.refresh(gateway)

    # Auto-sync on first add
    sync_service = GatewaySyncService(db)
    await sync_service.sync_gateway(gateway.id, current_user.id)

    await db.refresh(gateway)
    p_count = await _count_profiles(db, gateway.id)
    a_count = await _count_agents(db, gateway.id)
    return GatewayResponse(
        id=gateway.id, name=gateway.name, address=gateway.address,
        api_key=gateway.api_key, status=gateway.status or "unknown",
        last_seen=gateway.last_seen, created_at=gateway.created_at,
        profile_count=p_count, agent_count=a_count,
    )


@router.get("/gateways/{gateway_id}", response_model=GatewayResponse)
async def get_gateway(
    gateway_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    gw = await _get_user_gateway(db, gateway_id, current_user.id)
    if not gw:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
    p_count = await _count_profiles(db, gw.id)
    a_count = await _count_agents(db, gw.id)
    return GatewayResponse(
        id=gw.id, name=gw.name, address=gw.address,
        api_key=gw.api_key, status=gw.status or "unknown",
        last_seen=gw.last_seen, created_at=gw.created_at,
        profile_count=p_count, agent_count=a_count,
    )


@router.patch("/gateways/{gateway_id}", response_model=GatewayResponse)
async def update_gateway(
    gateway_id: str,
    data: GatewayUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    gw = await _get_user_gateway(db, gateway_id, current_user.id)
    if not gw:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
    if data.name is not None:
        gw.name = data.name
    if data.api_key is not None:
        gw.api_key = data.api_key
    await db.commit()
    await db.refresh(gw)
    p_count = await _count_profiles(db, gw.id)
    a_count = await _count_agents(db, gw.id)
    return GatewayResponse(
        id=gw.id, name=gw.name, address=gw.address,
        api_key=gw.api_key, status=gw.status or "unknown",
        last_seen=gw.last_seen, created_at=gw.created_at,
        profile_count=p_count, agent_count=a_count,
    )


@router.delete("/gateways/{gateway_id}", status_code=204)
async def delete_gateway(
    gateway_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    gw = await _get_user_gateway(db, gateway_id, current_user.id)
    if not gw:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
    await db.delete(gw)
    await db.commit()


@router.post("/gateways/{gateway_id}/test", response_model=dict)
async def test_gateway(
    gateway_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    gw = await _get_user_gateway(db, gateway_id, current_user.id)
    if not gw:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
    channel = GatewayChannel(gw)
    try:
        is_healthy = await channel.health_check()
        gw.status = "online" if is_healthy else "offline"
        if is_healthy:
            import time
            gw.last_seen = int(time.time())
        await db.commit()
        return {"gateway_id": gateway_id, "online": is_healthy}
    finally:
        await channel.close()


@router.post("/gateways/{gateway_id}/sync", response_model=dict)
async def sync_gateway(
    gateway_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    gw = await _get_user_gateway(db, gateway_id, current_user.id)
    if not gw:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
    sync_service = GatewaySyncService(db)
    return await sync_service.sync_gateway(gateway_id, current_user.id)


@router.get("/gateways/{gateway_id}/profiles", response_model=List[ProfileResponse])
async def list_gateway_profiles(
    gateway_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    gw = await _get_user_gateway(db, gateway_id, current_user.id)
    if not gw:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)

    result = await db.execute(
        select(Profile).where(Profile.gateway_id == gateway_id)
    )
    profiles = list(result.scalars().all())

    response = []
    for p in profiles:
        a_count = await _count_profile_agents(db, p.id)
        response.append(ProfileResponse(
            id=p.id, gateway_id=p.gateway_id, remote_name=p.remote_name,
            alias=p.alias, model=p.model, provider=p.provider,
            skills=p.skills, description=p.description,
            synced_at=p.synced_at, created_at=p.created_at,
            agent_count=a_count,
        ))
    return response


# ── Profile endpoints ────────────────────────────────────────────

@router.get("/profiles/{profile_id}", response_model=ProfileResponse)
async def get_profile(
    profile_id: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Profile).where(Profile.id == profile_id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "Profile 不存在", status_code=404)

    # Verify ownership
    gw_result = await db.execute(
        select(Gateway).where(Gateway.id == profile.gateway_id, Gateway.user_id == current_user.id)
    )
    if not gw_result.scalar_one_or_none():
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "无权访问该资源", status_code=403)

    a_count = await _count_profile_agents(db, profile.id)
    return ProfileResponse(
        id=profile.id, gateway_id=profile.gateway_id, remote_name=profile.remote_name,
        alias=profile.alias, model=profile.model, provider=profile.provider,
        skills=profile.skills, description=profile.description,
        synced_at=profile.synced_at, created_at=profile.created_at,
        agent_count=a_count,
    )


@router.patch("/profiles/{profile_id}", response_model=ProfileResponse)
async def update_profile(
    profile_id: str,
    data: ProfileUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Profile).where(Profile.id == profile_id))
    profile = result.scalar_one_or_none()
    if not profile:
        raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "Profile 不存在", status_code=404)

    gw_result = await db.execute(
        select(Gateway).where(Gateway.id == profile.gateway_id, Gateway.user_id == current_user.id)
    )
    if not gw_result.scalar_one_or_none():
        raise AppException(ErrorCode.RESOURCE_FORBIDDEN, "无权访问该资源", status_code=403)

    if data.alias is not None:
        profile.alias = data.alias
    await db.commit()
    await db.refresh(profile)

    a_count = await _count_profile_agents(db, profile.id)
    return ProfileResponse(
        id=profile.id, gateway_id=profile.gateway_id, remote_name=profile.remote_name,
        alias=profile.alias, model=profile.model, provider=profile.provider,
        skills=profile.skills, description=profile.description,
        synced_at=profile.synced_at, created_at=profile.created_at,
        agent_count=a_count,
    )


# ── Gateway Proxy ───────────────────────────────────────────────

@router.api_route("/proxy/gateway/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy_to_gateway(
    path: str,
    request: Request,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    gateway_id: Optional[str] = Query(None),
):
    if gateway_id:
        gw = await _get_user_gateway(db, gateway_id, current_user.id)
        if not gw:
            raise AppException(ErrorCode.RESOURCE_NOT_FOUND, "网关不存在", status_code=404)
        gateway_url = gw.address
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


# ── Helpers ─────────────────────────────────────────────────────

async def _get_user_gateway(db: AsyncSession, gateway_id: str, user_id: str) -> Optional[Gateway]:
    result = await db.execute(
        select(Gateway).where(Gateway.id == gateway_id, Gateway.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def _count_profiles(db: AsyncSession, gateway_id: str) -> int:
    result = await db.execute(
        select(func.count(Profile.id)).where(Profile.gateway_id == gateway_id)
    )
    return result.scalar() or 0


async def _count_agents(db: AsyncSession, gateway_id: str) -> int:
    result = await db.execute(
        select(func.count(Agent.id))
        .join(Profile)
        .where(Profile.gateway_id == gateway_id)
    )
    return result.scalar() or 0


async def _count_profile_agents(db: AsyncSession, profile_id: str) -> int:
    result = await db.execute(
        select(func.count(Agent.id)).where(Agent.profile_id == profile_id)
    )
    return result.scalar() or 0
