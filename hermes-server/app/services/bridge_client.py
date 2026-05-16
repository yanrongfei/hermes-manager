"""Client for communicating with Hermes Agent Bridge process."""

import asyncio
import json
import os
import socket
import sys
from pathlib import Path
from typing import Any, Optional

from app.services.local_profile_scanner import _hermes_home


DEFAULT_ENDPOINT = (
    "tcp://127.0.0.1:18765"
    if os.name == "nt"
    else "ipc:///tmp/hermes-agent-bridge.sock"
)


def _discover_agent_root() -> Optional[Path]:
    """Find hermes-agent installation directory."""
    home = _hermes_home()
    candidates = [
        home / "hermes-agent",
        Path.home() / ".hermes" / "hermes-agent",
        Path("/opt/hermes/hermes-agent"),
        Path("/usr/local/hermes-agent"),
    ]
    for candidate in candidates:
        if (candidate / "run_agent.py").exists():
            return candidate
    return None


def _bridge_script_path() -> Optional[Path]:
    """Find the bridge script from hermes-web-ui if available."""
    candidates = [
        _hermes_home() / "webui" / "packages" / "server" / "src" / "services" / "hermes" / "agent-bridge" / "hermes_bridge.py",
        Path.home() / "tool" / "hermes-web-ui" / "packages" / "server" / "src" / "services" / "hermes" / "agent-bridge" / "hermes_bridge.py",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


class BridgeClient:
    """Communicate with a running Hermes Agent Bridge via IPC socket."""

    def __init__(self, endpoint: Optional[str] = None):
        self.endpoint = endpoint or DEFAULT_ENDPOINT

    def _connect_unix(self, sock_path: str) -> socket.socket:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(5.0)
        sock.connect(sock_path)
        return sock

    def _connect_tcp(self, host: str, port: int) -> socket.socket:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5.0)
        sock.connect((host, port))
        return sock

    def _connect(self) -> socket.socket:
        if self.endpoint.startswith("ipc://"):
            sock_path = self.endpoint.removeprefix("ipc://")
            return self._connect_unix(sock_path)
        elif self.endpoint.startswith("tcp://"):
            parts = self.endpoint.removeprefix("tcp://").split(":")
            host = parts[0]
            port = int(parts[1])
            return self._connect_tcp(host, port)
        raise ValueError(f"Unsupported endpoint: {self.endpoint}")

    def _send_request(self, action: str, **kwargs) -> dict[str, Any]:
        """Send a JSON request to the bridge and return the response."""
        req = {"action": action, **kwargs}
        payload = json.dumps(req, ensure_ascii=False, default=str) + "\n"

        try:
            sock = self._connect()
            sock.sendall(payload.encode("utf-8"))

            chunks: list[bytes] = []
            while True:
                chunk = sock.recv(65536)
                if not chunk:
                    break
                chunks.append(chunk)
                if b"\n" in chunk:
                    break

            sock.close()

            if not chunks:
                return {"ok": False, "error": "empty response from bridge"}

            line = b"".join(chunks).split(b"\n", 1)[0].strip()
            return json.loads(line.decode("utf-8"))
        except FileNotFoundError:
            return {"ok": False, "error": "bridge socket not found"}
        except ConnectionRefusedError:
            return {"ok": False, "error": "bridge not running"}
        except socket.timeout:
            return {"ok": False, "error": "bridge connection timed out"}
        except Exception as e:
            return {"ok": False, "error": str(e)}

    def ping(self) -> bool:
        resp = self._send_request("ping")
        return resp.get("ok", False) and resp.get("pong", False)

    def list_agents(self) -> list[dict[str, Any]]:
        """List agents via bridge. Returns agent info dicts."""
        resp = self._send_request("list")
        if not resp.get("ok"):
            return []
        sessions = resp.get("sessions", [])
        return [
            {
                "id": s.get("session_id", ""),
                "name": s.get("config", {}).get("model", "Agent"),
                "description": "local bridge session",
                "remote_id": s.get("session_id", ""),
            }
            for s in sessions
        ]

    def is_available(self) -> bool:
        """Check if bridge is reachable."""
        return self.ping()


async def list_local_agents(profile_name: Optional[str] = None) -> list[dict[str, Any]]:
    """Discover local agents from all hermes profiles via CLI or config.

    Returns one agent entry per profile.
    """
    import yaml
    from app.services.local_profile_scanner import _hermes_home, _read_yaml, scan_local_profiles

    profiles = scan_local_profiles()
    if not profiles:
        return []

    results = []
    for p in profiles:
        model = p.get("model", "Hermes")
        provider = p.get("provider", "")
        desc_parts = [f"Profile: {p['profile_name']}"]
        if model:
            desc_parts.append(f"Model: {model}")
        if provider:
            desc_parts.append(f"Provider: {provider}")

        results.append({
            "id": p["profile_name"],
            "name": p["profile_name"],
            "description": " · ".join(desc_parts),
            "remote_id": p["profile_name"],
        })

    return results
