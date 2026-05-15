import asyncio
from typing import List, Set
from app.services.gateway_client import GatewayClient

CANDIDATE_PORTS = [8642, 8080, 8443, 3000, 5000]
SCAN_HOSTS = ["localhost", "127.0.0.1"]
SCAN_TIMEOUT = 2.0


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


async def scan_local_gateways(exclude_addresses: Set[str] | None = None) -> List[dict]:
    exclude = exclude_addresses or set()
    tasks = []
    for host in SCAN_HOSTS:
        for port in CANDIDATE_PORTS:
            address = f"http://{host}:{port}"
            if address not in exclude:
                tasks.append(_probe(host, port))

    results = await asyncio.gather(*tasks, return_exceptions=True)

    gateways = []
    for r in results:
        if isinstance(r, dict) and r.get("online"):
            gateways.append(r)
    return gateways
