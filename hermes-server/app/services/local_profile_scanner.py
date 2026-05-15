"""Scan local Hermes profiles from ~/.hermes/ directory."""

import json
import os
from pathlib import Path
from typing import Any

import yaml


DEFAULT_HERMES_HOME = Path.home() / ".hermes"


def _hermes_home() -> Path:
    env = os.environ.get("HERMES_HOME")
    if env:
        return Path(env).expanduser().resolve()
    return DEFAULT_HERMES_HOME


def _read_yaml(path: Path) -> dict[str, Any]:
    try:
        if path.exists():
            return yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception:
        pass
    return {}


def _read_json(path: Path) -> dict[str, Any]:
    try:
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {}


def _active_profile(home: Path) -> str:
    ap = home / "active_profile"
    if ap.exists():
        return ap.read_text(encoding="utf-8").strip() or "default"
    return "default"


def _extract_model_info(cfg: dict[str, Any]) -> dict[str, str]:
    model_cfg = cfg.get("model") or {}
    if isinstance(model_cfg, str):
        return {"default": model_cfg}
    return {
        "default": model_cfg.get("default", ""),
        "provider": model_cfg.get("provider", ""),
    }


def _extract_gateway_address(cfg: dict[str, Any]) -> dict[str, Any]:
    """Extract gateway host/port from global.gateway or platforms.api_server."""
    host = "127.0.0.1"
    port = 8642

    # Check platforms.api_server first
    platforms = cfg.get("platforms") or {}
    if isinstance(platforms, dict):
        api_server = platforms.get("api_server") or {}
        if isinstance(api_server, dict) and api_server.get("enabled"):
            host = api_server.get("host", host)
            port = api_server.get("port", port)
            return {"host": host, "port": port}

    # Fallback to global.gateway
    global_cfg = cfg.get("global") or {}
    gateway = global_cfg.get("gateway") or {}
    if isinstance(gateway, dict):
        host = gateway.get("host", host)
        port = gateway.get("port", port)

    return {"host": host, "port": port}


def _gateway_info(home: Path) -> dict[str, Any]:
    """Read gateway state and determine running/api_server status."""
    state = _read_json(home / "gateway_state.json")
    pid_info = _read_json(home / "gateway.pid")

    running = state.get("gateway_state") == "running" if state else False
    pid = state.get("pid") or pid_info.get("pid")

    # Check if api_server platform is connected
    api_server_connected = False
    platforms_state = state.get("platforms") or {}
    api_server_state = platforms_state.get("api_server") or {}
    if api_server_state.get("state") == "connected":
        api_server_connected = True

    return {
        "running": running,
        "pid": pid,
        "api_server_connected": api_server_connected,
    }


def _scan_profile(profile_home: Path, profile_name: str, home: Path) -> dict[str, Any] | None:
    config_path = profile_home / "config.yaml"
    if not config_path.exists():
        return None

    cfg = _read_yaml(config_path)
    if not cfg:
        return None

    model_info = _extract_model_info(cfg)
    gateway_addr = _extract_gateway_address(cfg)
    gw_info = _gateway_info(home if profile_name == "default" else profile_home)

    # For non-default profiles, also check home gateway state
    if profile_name != "default":
        home_gw = _gateway_info(home)
        # If home gateway is running, it might be serving this profile
        if home_gw["running"] and not gw_info["running"]:
            gw_info = home_gw

    address = f"http://{gateway_addr['host']}:{gateway_addr['port']}"
    mode = "http" if gw_info["api_server_connected"] else "local"
    online = gw_info["running"]

    return {
        "profile_name": profile_name,
        "name": profile_name,
        "model": model_info.get("default", ""),
        "provider": model_info.get("provider", ""),
        "gateway_host": gateway_addr["host"],
        "gateway_port": gateway_addr["port"],
        "api_server_connected": gw_info["api_server_connected"],
        "running": gw_info["running"],
        "pid": gw_info["pid"],
        "mode": mode,
        "config_path": str(config_path),
        "address": address,
        "online": online,
    }


def scan_local_profiles() -> list[dict[str, Any]]:
    """Scan ~/.hermes/ for local profiles and return their info."""
    home = _hermes_home()
    if not home.exists():
        return []

    profiles: list[dict[str, Any]] = []
    active = _active_profile(home)
    seen: set[str] = set()

    # Default profile (~/.hermes/config.yaml)
    default = _scan_profile(home, "default", home)
    if default:
        default["active"] = active == "default"
        profiles.append(default)
        seen.add("default")

    # Named profiles (~/.hermes/profiles/<name>/)
    profiles_dir = home / "profiles"
    if profiles_dir.is_dir():
        for entry in sorted(profiles_dir.iterdir()):
            if entry.is_dir() and entry.name not in seen:
                profile = _scan_profile(entry, entry.name, home)
                if profile:
                    profile["active"] = active == entry.name
                    profiles.append(profile)
                    seen.add(entry.name)

    return profiles
