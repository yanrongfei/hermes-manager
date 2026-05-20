"""Scan local Hermes profiles from ~/.hermes/ directory.

Uses hermes_cli.profiles.list_profiles() when available (hermes-agent
installed locally), falls back to reading config files directly.
"""

import json
import os
import sys
from pathlib import Path
from typing import Any

import yaml


DEFAULT_HERMES_HOME = Path.home() / ".hermes"
AGENT_ROOT_CANDIDATES = [
    DEFAULT_HERMES_HOME / "hermes-agent",
    Path("/opt/hermes/hermes-agent"),
    Path("/usr/local/hermes-agent"),
]


def _hermes_home() -> Path:
    env = os.environ.get("HERMES_HOME")
    if env:
        return Path(env).expanduser().resolve()
    return DEFAULT_HERMES_HOME


def _find_agent_root() -> Path | None:
    explicit = os.environ.get("HERMES_AGENT_ROOT")
    if explicit:
        p = Path(explicit).expanduser()
        if (p / "run_agent.py").exists():
            return p
    for candidate in AGENT_ROOT_CANDIDATES:
        if (candidate / "run_agent.py").exists():
            return candidate
    return None


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


def _read_env(path: Path) -> dict[str, str]:
    """Parse a .env file into a dict."""
    env: dict[str, str] = {}
    if not path.exists():
        return env
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip("\"'")
    except Exception:
        pass
    return env


def _extract_api_key(profile_home: Path) -> str:
    """Extract API_SERVER_KEY from profile's .env file."""
    env = _read_env(profile_home / ".env")
    return env.get("API_SERVER_KEY", "")


def _check_profile_files(profile_home: Path) -> dict[str, Any]:
    """Check for .env, soul.md, and skills directory existence."""
    env_file = profile_home / ".env"
    soul_file = profile_home / "soul.md"
    skills_dir = profile_home / "skills"

    has_env = env_file.exists()
    has_soul = soul_file.exists()
    skills_count = 0

    if skills_dir.is_dir():
        try:
            skills_count = sum(1 for f in skills_dir.iterdir() if f.is_file())
        except Exception:
            pass

    return {
        "has_env": has_env,
        "has_soul": has_soul,
        "skills_count": skills_count,
    }


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

    platforms = cfg.get("platforms") or {}
    if isinstance(platforms, dict):
        api_server = platforms.get("api_server") or {}
        if isinstance(api_server, dict) and api_server.get("enabled"):
            host = api_server.get("host", host)
            port = api_server.get("port", port)
            return {"host": host, "port": port}

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


# ── CLI-based scanning (preferred) ──────────────────────────────

def _scan_via_cli() -> list[dict[str, Any]] | None:
    """Try scanning profiles via hermes_cli.profiles.list_profiles()."""
    agent_root = _find_agent_root()
    if not agent_root:
        return None

    root_str = str(agent_root)
    if root_str not in sys.path:
        sys.path.insert(0, root_str)

    try:
        from hermes_cli.profiles import list_profiles
    except Exception:
        return None

    home = _hermes_home()
    active = _active_profile(home)

    try:
        profile_list = list_profiles()
    except Exception:
        return None

    results = []
    for p in profile_list:
        home_dir = _hermes_home() if p.is_default else p.path
        api_key = _extract_api_key(home_dir)
        file_info = _check_profile_files(home_dir)

        # Get gateway address from config
        cfg = _read_yaml(home_dir / "config.yaml")
        gw_addr = _extract_gateway_address(cfg)
        host = gw_addr["host"]
        if host in ("0.0.0.0", "::", ""):
            host = "127.0.0.1"
        address = f"http://{host}:{gw_addr['port']}"

        gw_info = _gateway_info(home_dir if p.is_default else home)

        results.append({
            "profile_name": p.name,
            "name": p.name,
            "model": p.model or "",
            "provider": p.provider or "",
            "gateway_host": gw_addr["host"],
            "gateway_port": gw_addr["port"],
            "api_server_connected": gw_info["api_server_connected"],
            "running": p.gateway_running,
            "mode": "http" if gw_info["api_server_connected"] else "local",
            "config_path": str(home_dir / "config.yaml"),
            "address": address,
            "online": p.gateway_running,
            "active": p.is_default,
            "api_key": api_key,
            **file_info,
        })

    return results


# ── File-based scanning (fallback) ──────────────────────────────

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
    file_info = _check_profile_files(profile_home)

    if profile_name != "default":
        home_gw = _gateway_info(home)
        if home_gw["running"] and not gw_info["running"]:
            gw_info = home_gw

    host = gateway_addr["host"]
    if host in ("0.0.0.0", "::", ""):
        host = "127.0.0.1"
    address = f"http://{host}:{gateway_addr['port']}"
    mode = "http" if gw_info["api_server_connected"] else "local"
    online = gw_info["running"]
    api_key = _extract_api_key(profile_home)

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
        "api_key": api_key,
        **file_info,
    }


def _scan_via_files() -> list[dict[str, Any]]:
    """Fallback: scan profiles by reading config files directly."""
    home = _hermes_home()
    if not home.exists():
        return []

    profiles: list[dict[str, Any]] = []
    active = _active_profile(home)
    seen: set[str] = set()

    default = _scan_profile(home, "default", home)
    if default:
        default["active"] = active == "default"
        profiles.append(default)
        seen.add("default")

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


# ── Public API ──────────────────────────────────────────────────

def scan_local_profiles() -> list[dict[str, Any]]:
    """Scan ~/.hermes/ for local profiles.

    Tries hermes_cli.profiles.list_profiles() first (if hermes-agent
    is installed locally), falls back to reading config files directly.
    """
    result = _scan_via_cli()
    if result is not None:
        return result
    return _scan_via_files()
