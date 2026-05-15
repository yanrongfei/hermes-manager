import httpx
import json
from typing import AsyncGenerator, List, Optional


class GatewayClient:
    """Client for communicating with Hermes Gateway."""

    def __init__(self, gateway_url: str, api_key: Optional[str] = None):
        headers = {"Authorization": f"Bearer {api_key}"} if api_key else {}
        self.client = httpx.AsyncClient(
            base_url=gateway_url,
            headers=headers,
            timeout=180.0
        )

    async def health_check(self) -> bool:
        """Check if Gateway is reachable."""
        try:
            resp = await self.client.get("/health")
            return resp.status_code == 200
        except Exception:
            return False

    async def list_models(self) -> List[dict]:
        """List available models from Gateway."""
        resp = await self.client.get("/v1/models")
        data = resp.json()
        return data.get("data", []) if isinstance(data, dict) else []

    async def list_agents(self) -> List[dict]:
        """List available agents/profiles from Gateway.
        
        Gateway does not implement /v1/profiles (returns 404).
        We use /v1/models which returns the current profile as a model entry.
        """
        try:
            resp = await self.client.get("/v1/models")
            data = resp.json()
            models = data.get("data", []) if isinstance(data, dict) else []
            # Transform model entries to agent-like dicts for the frontend
            return [
                {
                    "id": m.get("id", ""),
                    "name": m.get("root") or m.get("id", "Agent"),
                    "description": m.get("owned_by", "hermes"),
                    "remote_id": m.get("id", ""),
                }
                for m in models
            ]
        except Exception:
            return []

    async def stream_response(
        self,
        input_text: str,
        model: str,
        instructions: str,
        conversation_history: List[dict],
    ) -> AsyncGenerator[dict, None]:
        """
        Send a streaming request to Gateway /v1/responses.

        Yields SSE events from the Gateway.
        """
        payload = {
            "input": input_text,
            "model": model,
            "instructions": instructions,
            "conversation_history": conversation_history,
            "stream": True,
            "store": False,
        }
        async with self.client.stream("POST", "/v1/responses", json=payload) as resp:
            async for line in resp.aiter_lines():
                stripped = line.strip()
                if not stripped or stripped == "event: ping":
                    continue
                if stripped.startswith("data: "):
                    try:
                        data = json.loads(stripped[6:])
                        yield data
                    except json.JSONDecodeError:
                        continue

    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()
