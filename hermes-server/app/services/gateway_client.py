import httpx
import json
from typing import AsyncGenerator, List, Optional


class GatewayClient:
    """Client for communicating with Hermes Gateway."""

    def __init__(self, gateway_url: str, api_key: Optional[str] = None):
        # Normalize URL: add http:// scheme if missing
        url = gateway_url.strip()
        if "://" not in url:
            url = "http://" + url
        url = url.rstrip("/")
        headers = {"Authorization": f"Bearer {api_key}"} if api_key else {}
        self.client = httpx.AsyncClient(
            base_url=url,
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
            if resp.status_code != 200:
                error = resp.json().get("error", {}) if resp.headers.get("content-type", "").startswith("application/json") else {}
                msg = error.get("message", resp.text[:200]) if isinstance(error, dict) else str(error)
                print(f"[GatewayClient] /v1/models returned {resp.status_code}: {msg}")
                return []
            data = resp.json()
            models = data.get("data", []) if isinstance(data, dict) else []
            return [
                {
                    "id": m.get("id", ""),
                    "name": m.get("id", "Agent"),
                    "description": f"Model: {m.get('owned_by', 'unknown')}",
                    "remote_id": m.get("id", ""),
                }
                for m in models
            ]
        except Exception as e:
            print(f"[GatewayClient] list_agents error: {e}")
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

    async def start_run(
        self,
        input_text: str,
        model: str,
        instructions: str,
        conversation_history: List[dict],
        session_id: Optional[str] = None,
    ) -> dict:
        """POST /v1/runs — start an agent run, return run metadata."""
        payload = {
            "input": input_text,
            "model": model,
            "instructions": instructions,
            "conversation_history": conversation_history,
        }
        if session_id:
            payload["session_id"] = session_id
        resp = await self.client.post("/v1/runs", json=payload)
        resp.raise_for_status()
        return resp.json()

    async def stream_run_events(self, run_id: str) -> AsyncGenerator[dict, None]:
        """GET /v1/runs/{run_id}/events — SSE stream of structured agent events."""
        async with self.client.stream("GET", f"/v1/runs/{run_id}/events") as resp:
            async for line in resp.aiter_lines():
                stripped = line.strip()
                if not stripped or stripped.startswith(":"):
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
