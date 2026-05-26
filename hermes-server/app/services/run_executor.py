import asyncio
import json
from typing import Optional
from app.services.websocket import manager
from app.services.gateway_channel import GatewayChannel


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
        gateway: GatewayChannel,
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
        import logging
        logger = logging.getLogger("hermes.executor")
        logger.info(f"[{self.message_id}] Execute started, model={model}")

        await manager.send_to_room(self.room_id, "run.started", {
            "messageId": self.message_id,
            "agentId": self.agent_id,
            "agentName": self.agent_name,
        })

        self._full_content = ""
        self._reasoning_content = ""

        try:
            async for event in self.gateway.stream_response(
                user_message, model, instructions, history
            ):
                if self._aborted:
                    await manager.send_to_room(self.room_id, "abort.completed", {
                        "messageId": self.message_id
                    })
                    return

                await self._handle_event(event)

            # Stream ended without response.completed — send run.completed manually
            if not self._aborted:
                logger.warning(f"[{self.message_id}] Stream ended without response.completed")
                await manager.send_to_room(self.room_id, "run.completed", {
                    "messageId": self.message_id,
                    "inputTokens": 0,
                    "outputTokens": 0,
                })

        except Exception as e:
            logger.error(f"[{self.message_id}] Execute failed: {type(e).__name__}: {e}")
            await manager.send_to_room(self.room_id, "run.failed", {
                "messageId": self.message_id,
                "error": str(e)
            })

    @staticmethod
    def _extract_text(value) -> str:
        """Extract text from delta which can be a dict or a plain string."""
        if isinstance(value, str):
            return value
        if isinstance(value, dict):
            return value.get("text", "")
        return ""

    async def _handle_event(self, event):
        if not isinstance(event, dict):
            return
        etype = event.get("type", "")

        if etype == "response.output_text.delta":
            text = self._extract_text(event.get("delta"))
            self._full_content += text
            await manager.send_to_room(self.room_id, "message.delta", {
                "messageId": self.message_id,
                "delta": text,
                "full": self._full_content,
            })

        elif etype == "response.reasoning.delta":
            text = self._extract_text(event.get("delta"))
            self._reasoning_content += text
            await manager.send_to_room(self.room_id, "reasoning.delta", {
                "messageId": self.message_id,
                "delta": text,
            })

        elif etype == "response.output_text.done":
            # Some gateways send full text in a 'done' event
            pass

        elif etype == "response.tool_use.started":
            tc = event.get("tool_call", {})
            if not isinstance(tc, dict):
                tc = {}
            await manager.send_to_room(self.room_id, "tool.started", {
                "toolCallId": tc.get("id"),
                "tool": tc.get("name"),
                "preview": str(tc.get("input", {}))[:100],
                "arguments": tc.get("input", {}),
            })

        elif etype == "response.tool_use.completed":
            tc = event.get("tool_call", {})
            if not isinstance(tc, dict):
                tc = {}
            await manager.send_to_room(self.room_id, "tool.completed", {
                "toolCallId": tc.get("id"),
                "output": str(tc.get("output", ""))[:500],
                "duration": (tc.get("execution_ms") or 0) / 1000,
                "error": tc.get("error"),
            })

        elif etype == "response.completed":
            # Gateway nests usage inside response object
            resp_obj = event.get("response", {})
            usage = resp_obj.get("usage", {}) if isinstance(resp_obj, dict) else {}
            if not isinstance(usage, dict):
                usage = {}
            await manager.send_to_room(self.room_id, "run.completed", {
                "messageId": self.message_id,
                "inputTokens": usage.get("input_tokens", 0),
                "outputTokens": usage.get("output_tokens", 0),
            })
            # Persist the final message content to database
            from app.database import get_session_maker
            from app.services.message import MessageService
            extra = {"reasoning_content": self._reasoning_content} if self._reasoning_content else None
            session = get_session_maker()()
            async with session:
                msg_svc = MessageService(session)
                await msg_svc.update_message(
                    message_id=self.message_id,
                    content=self._full_content,
                    extra=json.dumps(extra) if extra else None,
                    is_streaming=False,
                )

        elif etype == "response.failed":
            error = event.get("error", {})
            await manager.send_to_room(self.room_id, "run.failed", {
                "messageId": self.message_id,
                "error": error.get("type", "unknown") if isinstance(error, dict) else str(error),
            })

    def abort(self):
        """Signal the executor to abort the current run."""
        self._aborted = True
