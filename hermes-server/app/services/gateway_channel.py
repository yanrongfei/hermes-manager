"""Unified gateway communication channel with auto-fallback.

Selects HTTP / Bridge / CLI based on machine mode and availability:
- mode == "http": GatewayClient (HTTP API)
- mode == "local":
  1. Try HTTP health check first (api_server might be running)
  2. Try Bridge process
  3. Read local config directly
"""

import asyncio
from typing import AsyncGenerator, List, Optional

from app.models.machine import Machine
from app.services.gateway_client import GatewayClient
from app.services.bridge_client import BridgeClient, list_local_agents
from app.services.local_profile_scanner import scan_local_profiles


def _enrich_with_local_profiles(agents: List[dict], machine_profile: Optional[str] = None) -> List[dict]:
    """Enrich agent entries with local profile info for better display names."""
    try:
        profiles = scan_local_profiles()
    except Exception:
        return agents

    if not profiles:
        return agents

    # Find the matching profile for this machine
    target = None
    if machine_profile:
        target = next((p for p in profiles if p["profile_name"] == machine_profile), None)
    if not target:
        # Use active profile
        target = next((p for p in profiles if p.get("active")), None)
    if not target:
        target = profiles[0]

    model_name = target.get("model", "")
    profile_name = target.get("profile_name", "")

    for agent in agents:
        # Replace default "hermes-agent" name with model name
        if agent.get("name") == "hermes-agent" and model_name:
            agent["name"] = model_name
        # Add better description
        if agent.get("description") in ("hermes", "Model: hermes"):
            parts = []
            if profile_name:
                parts.append(f"Profile: {profile_name}")
            if model_name:
                parts.append(f"Model: {model_name}")
            provider = target.get("provider", "")
            if provider:
                parts.append(f"Provider: {provider}")
            agent["description"] = " · ".join(parts) if parts else "Hermes Agent"

    return agents


class GatewayChannel:
    """Unified interface for gateway communication."""

    def __init__(self, machine: Machine):
        self.machine = machine
        self._http_client: Optional[GatewayClient] = None
        self._bridge_client: Optional[BridgeClient] = None
        self._active_mode: str = machine.mode or "http"

    async def _get_http(self) -> GatewayClient:
        if self._http_client is None:
            self._http_client = GatewayClient(
                self.machine.address, api_key=self.machine.api_key
            )
        return self._http_client

    async def _get_bridge(self) -> BridgeClient:
        if self._bridge_client is None:
            self._bridge_client = BridgeClient()
        return self._bridge_client

    async def health_check(self) -> bool:
        """Check gateway health, trying all available methods."""
        # Always try HTTP first regardless of mode
        http = await self._get_http()
        if await http.health_check():
            self._active_mode = "http"
            return True

        # For local mode, try bridge
        if self.machine.mode == "local":
            bridge = await self._get_bridge()
            if bridge.is_available():
                self._active_mode = "bridge"
                return True
            # Config exists = "healthy enough" for local profiles
            self._active_mode = "local"
            return True

        return False

    async def list_agents(self) -> List[dict]:
        """List available agents, using the best available method."""
        # Try HTTP first
        http = await self._get_http()
        try:
            agents = await http.list_agents()
            if agents:
                self._active_mode = "http"
                # Enrich default agent names with local profile info
                agents = _enrich_with_local_profiles(agents, self.machine.profile_name)
                return agents
        except Exception as e:
            print(f"[GatewayChannel] HTTP list_agents failed: {e}")

        # For local mode, try bridge then config
        if self.machine.mode == "local":
            bridge = await self._get_bridge()
            agents = bridge.list_agents()
            if agents:
                self._active_mode = "bridge"
                return agents

            # Fallback: read from config
            agents = await list_local_agents(self.machine.profile_name)
            if agents:
                self._active_mode = "local"
                return agents

        return []

    async def stream_response(
        self,
        input_text: str,
        model: str,
        instructions: str,
        conversation_history: List[dict],
    ) -> AsyncGenerator[dict, None]:
        """Stream a chat response, using the best available method."""
        # Determine the best method
        await self.health_check()

        if self._active_mode == "http":
            http = await self._get_http()
            async for event in http.stream_response(
                input_text, model, instructions, conversation_history
            ):
                yield event
            return

        # Bridge / local mode: not yet implemented for streaming
        yield {
            "type": "error",
            "error": f"Streaming not yet supported for mode: {self._active_mode}",
        }

    @property
    def active_mode(self) -> str:
        return self._active_mode

    async def close(self):
        if self._http_client:
            await self._http_client.close()
            self._http_client = None
