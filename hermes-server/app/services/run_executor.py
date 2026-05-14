import asyncio
import json
from typing import Optional
from app.services.websocket import manager
from app.services.gateway_client import GatewayClient


class RunExecutor:
    """
    Executes a single agent run against Hermes Gateway.

    Receives user message → calls Gateway SSE → pushes events to room via WebSocket.
    """

    def __init__(
        self,
        room_id: str,
        message_id: str,
        agent_id: str,
        agent_name: str,
        gateway: GatewayClient,
    ):
        self.room_id = room_id
        self.message_id = message_id
        self.agent_id = agent_id
        self.agent_name = agent_name
        self.gateway = gateway
        self._aborted = False

    async def execute(
        self,
        user_message: str,
        model: str,
        instructions: str,
        history: list[dict],
    ):
        """Run the agent and stream events to the room."""
        await manager.send_to_room(self.room_id, "run.started", {
            "messageId": self.message_id,
            "agentId": self.agent_id,
            "agentName": self.agent_name,
        })

        full_content = ""
        reasoning_content = ""

        try:
            async for event in self.gateway.stream_response(
                user_message, model, instructions, history
            ):
                if self._aborted:
                    await manager.send_to_room(self.room_id, "abort.completed", {
                        "messageId": self.message_id
                    })
                    return

                await self._handle_event(event, full_content, reasoning_content)

        except Exception as e:
            await manager.send_to_room(self.room_id, "run.failed", {
                "messageId": self.message_id,
                "error": str(e)
            })

    async def _handle_event(
        self,
        event: dict,
        content_buf: str,
        reasoning_buf: str,
    ):
        etype = event.get("type", "")

        if etype == "response.output_text.delta":
            delta = event.get("delta", {})
            text = delta.get("text", "")
            content_buf += text
            await manager.send_to_room(self.room_id, "message.delta", {
                "messageId": self.message_id,
                "delta": text,
                "full": content_buf,
            })

        elif etype == "response.reasoning.delta":
            delta = event.get("delta", {})
            text = delta.get("text", "")
            reasoning_buf += text
            await manager.send_to_room(self.room_id, "reasoning.delta", {
                "messageId": self.message_id,
                "delta": text,
            })

        elif etype == "response.tool_use.started":
            tc = event.get("tool_call", {})
            await manager.send_to_room(self.room_id, "tool.started", {
                "toolCallId": tc.get("id"),
                "tool": tc.get("name"),
                "preview": str(tc.get("input", {}))[:100],
                "arguments": tc.get("input", {}),
            })

        elif etype == "response.tool_use.completed":
            tc = event.get("tool_call", {})
            await manager.send_to_room(self.room_id, "tool.completed", {
                "toolCallId": tc.get("id"),
                "output": str(tc.get("output", ""))[:500],
                "duration": tc.get("execution_ms", 0) / 1000,
                "error": tc.get("error"),
            })

        elif etype == "response.completed":
            usage = event.get("usage", {})
            await manager.send_to_room(self.room_id, "run.completed", {
                "messageId": self.message_id,
                "inputTokens": usage.get("input_tokens", 0),
                "outputTokens": usage.get("output_tokens", 0),
            })

        elif etype == "response.failed":
            error = event.get("error", {})
            await manager.send_to_room(self.room_id, "run.failed", {
                "messageId": self.message_id,
                "error": error.get("type", "unknown") if isinstance(error, dict) else str(error),
            })

    def abort(self):
        """Signal the executor to abort the current run."""
        self._aborted = True
