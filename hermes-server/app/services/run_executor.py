import asyncio
import json
from typing import Optional
from app.services.websocket import manager
from app.services.gateway_channel import GatewayChannel


class RunExecutor:
    """
    Executes a single agent run against Hermes Gateway via /v1/runs API.

    POST /v1/runs → run_id
    GET  /v1/runs/{run_id}/events → SSE with message.delta, reasoning.available, tool.*, run.completed
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
            result = await self.gateway.start_run(
                user_message, model, instructions, history
            )
            run_id = result.get("run_id") or result.get("id")
            if not run_id:
                raise ValueError(f"Gateway did not return run_id: {result}")

            logger.info(f"[{self.message_id}] Run started: {run_id}")

            async for event in self.gateway.stream_run_events(run_id):
                if self._aborted:
                    await manager.send_to_room(self.room_id, "abort.completed", {
                        "messageId": self.message_id
                    })
                    return

                await self._handle_run_event(event)

            if not self._aborted:
                logger.warning(f"[{self.message_id}] Stream ended without run.completed")
                await self._persist_and_complete(input_tokens=0, output_tokens=0)

        except Exception as e:
            logger.error(f"[{self.message_id}] Execute failed: {type(e).__name__}: {e}")
            await manager.send_to_room(self.room_id, "run.failed", {
                "messageId": self.message_id,
                "error": str(e)
            })

    async def _handle_run_event(self, event):
        if not isinstance(event, dict):
            return
        etype = event.get("event") or event.get("type", "")

        if etype == "message.delta":
            text = event.get("delta", "")
            if text:
                self._full_content += text
                await manager.send_to_room(self.room_id, "message.delta", {
                    "messageId": self.message_id,
                    "delta": text,
                    "full": self._full_content,
                })

        elif etype == "reasoning.available":
            text = event.get("text", "")
            if text:
                self._reasoning_content = text
                await manager.send_to_room(self.room_id, "reasoning.delta", {
                    "messageId": self.message_id,
                    "delta": text,
                })

        elif etype == "tool.started":
            await manager.send_to_room(self.room_id, "tool.started", {
                "toolCallId": event.get("tool_call_id"),
                "tool": event.get("tool", ""),
                "preview": str(event.get("preview", ""))[:100],
                "arguments": event.get("arguments", {}),
            })

        elif etype == "tool.completed":
            await manager.send_to_room(self.room_id, "tool.completed", {
                "toolCallId": event.get("tool_call_id"),
                "output": str(event.get("output", ""))[:500],
                "duration": (event.get("duration_ms") or event.get("duration") or 0) / 1000,
                "error": event.get("error"),
            })

        elif etype in ("run.completed", "done"):
            input_tokens = event.get("input_tokens", 0)
            output_tokens = event.get("output_tokens", 0)
            await self._persist_and_complete(input_tokens, output_tokens)

    async def _persist_and_complete(self, input_tokens: int, output_tokens: int):
        await manager.send_to_room(self.room_id, "run.completed", {
            "messageId": self.message_id,
            "inputTokens": input_tokens,
            "outputTokens": output_tokens,
        })
        if self._full_content:
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

    def abort(self):
        """Signal the executor to abort the current run."""
        self._aborted = True
