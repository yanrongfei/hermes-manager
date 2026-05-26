"""Unified gateway communication channel.

Provides HTTP-based communication with Hermes Gateway for:
- Health checks
- Listing agents/profiles
- Streaming responses
"""

from typing import AsyncGenerator, List, Optional

from app.models.gateway import Gateway
from app.services.gateway_client import GatewayClient


class GatewayChannel:
    """Unified interface for gateway communication."""

    def __init__(self, gateway: Gateway):
        self.gateway = gateway
        self._http_client: Optional[GatewayClient] = None

    async def _get_http(self) -> GatewayClient:
        if self._http_client is None:
            self._http_client = GatewayClient(
                self.gateway.address, api_key=self.gateway.api_key
            )
        return self._http_client

    async def health_check(self) -> bool:
        http = await self._get_http()
        return await http.health_check()

    async def list_agents(self) -> List[dict]:
        http = await self._get_http()
        try:
            return await http.list_agents()
        except Exception as e:
            print(f"[GatewayChannel] list_agents error: {e}")
            return []

    async def stream_response(
        self,
        input_text: str,
        model: str,
        instructions: str,
        conversation_history: List[dict],
    ) -> AsyncGenerator[dict, None]:
        http = await self._get_http()
        async for event in http.stream_response(
            input_text, model, instructions, conversation_history
        ):
            yield event

    async def start_run(
        self,
        input_text: str,
        model: str,
        instructions: str,
        history: List[dict],
        session_id: Optional[str] = None,
    ) -> dict:
        http = await self._get_http()
        return await http.start_run(input_text, model, instructions, history, session_id)

    async def stream_run_events(self, run_id: str) -> AsyncGenerator[dict, None]:
        http = await self._get_http()
        async for event in http.stream_run_events(run_id):
            yield event

    async def close(self):
        if self._http_client:
            await self._http_client.close()
            self._http_client = None
