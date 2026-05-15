import asyncio
import socket
from typing import List, Set
from app.services.gateway_client import GatewayClient

CANDIDATE_PORTS = [8642, 8080, 8443, 3000, 5000]
SCAN_TIMEOUT = 2.0


def _get_local_ips() -> list[str]:
    """Get all local IP addresses (excluding loopback)."""
    ips = []
    try:
        # Get IPs from network interfaces via UDP trick
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        ips.append(local_ip)
    except Exception:
        pass
    # Also try hostname resolution for LAN IP
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
    hosts = ["localhost", "127.0.0.1"]
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
            return {"address": address, "name": None, "online": True}
    except Exception:
        pass
    finally:
        await client.close()
    return None


def _is_lan_ip(host: str) -> bool:
    """True if host looks like a LAN IP (not localhost/loopback)."""
    return host not in ("localhost", "127.0.0.1", "127.0.1.1")


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

    gateways = []
    seen_ports: set[int] = set()
    for r in results:
        if isinstance(r, dict) and r.get("online"):
            url = r["address"]
            # url format: http://host:port
            host = url.split("//")[1].split(":")[0]
            port = int(url.split(":")[-1])
            is_lan = _is_lan_ip(host)
            if port not in seen_ports:
                # First time seeing this port — always add
                seen_ports.add(port)
                gateways.append(r)
            elif is_lan:
                # Same port found from LAN IP — replace the loopback entry
                gateways = [g if int(g["address"].split(":")[-1]) != port else r for g in gateways]
    return gateways
