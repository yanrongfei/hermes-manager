import asyncio
import socket
from typing import List, Set
from app.services.gateway_client import GatewayClient

CANDIDATE_PORTS = [8642]
SCAN_TIMEOUT = 2.0


def _get_local_ips() -> list[str]:
    """Get all local IP addresses (excluding loopback)."""
    ips = []
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        ips.append(local_ip)
    except Exception:
        pass
    try:
        hostname = socket.gethostname()
        resolved = socket.gethostbyname(hostname)
        if resolved not in ips and resolved != "127.0.0.1":
            ips.append(resolved)
    except Exception:
        pass
    return ips


def _expand_scan_hosts() -> list[str]:
    """Build the list of hosts to scan, including LAN IPs."""
    hosts = ["localhost", "127.0.0.1", "0.0.0.0"]
    for ip in _get_local_ips():
        if ip not in hosts:
            hosts.append(ip)
    return hosts


async def _probe(host: str, port: int) -> dict | None:
    address = f"http://{host}:{port}"
    client = GatewayClient(address)
    try:
        client.client.timeout = SCAN_TIMEOUT
        healthy = await client.health_check()
        if healthy:
            print(f"[Gateway Discovery] Found gateway at {address}")
            return {"address": address, "name": None, "online": True}
        else:
            print(f"[Gateway Discovery] Health check failed for {address}")
    except Exception as e:
        print(f"[Gateway Discovery] Failed to probe {address}: {e}")
    finally:
        await client.close()
    return None


def _normalize_host(host: str) -> str:
    """Normalize wildcard/loopback addresses to 127.0.0.1."""
    if host in ("0.0.0.0", "::", ""):
        return "127.0.0.1"
    if host == "localhost":
        return "127.0.0.1"
    return host


def _is_real_lan_ip(host: str) -> bool:
    """True if host is a real LAN IP (not loopback/wildcard)."""
    return host not in ("localhost", "127.0.0.1", "127.0.1.1", "0.0.0.0", "::", "")


async def scan_local_gateways(exclude_addresses: Set[str] | None = None) -> List[dict]:
    exclude = exclude_addresses or set()
    scan_hosts = _expand_scan_hosts()
    tasks = []
    for host in scan_hosts:
        for port in CANDIDATE_PORTS:
            address = f"http://{host}:{port}"
            if address not in exclude:
                tasks.append(_probe(host, port))

    results = await asyncio.gather(*tasks, return_exceptions=True)

    # Group by port, keep only one entry per port preferring LAN IP
    by_port: dict[int, list[dict]] = {}
    for r in results:
        if isinstance(r, dict) and r.get("online"):
            url = r["address"]
            port = int(url.split(":")[-1])
            by_port.setdefault(port, []).append(r)

    gateways = []
    for port, entries in by_port.items():
        # Prefer real LAN IP, fallback to first entry
        lan = [e for e in entries if _is_real_lan_ip(e["address"].split("//")[1].split(":")[0])]
        chosen = lan[0] if lan else entries[0]
        # Normalize the address
        host = chosen["address"].split("//")[1].split(":")[0]
        norm = _normalize_host(host)
        chosen["address"] = f"http://{norm}:{port}"
        gateways.append(chosen)

    return gateways
