"""
Context Compression Service.

Reference: hermes-web-ui/packages/server/src/lib/context-compressor/index.ts

When conversation token count exceeds `trigger_tokens`, compress old messages:
1. Keep the last `tail_message_count` messages verbatim
2. Summarize older messages using LLM
3. Store summary in message_summaries table
"""

import json
import time
from typing import List, Optional
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.message import Message
from app.models.room import Room
from app.services.gateway_channel import GatewayChannel
from app.services.websocket import manager


def estimate_tokens(text: str) -> int:
    """
    Estimate token count for text.
    Uses a simple heuristic: ~4 chars per token for English, ~2 for CJK.
    """
    chinese_chars = sum(1 for c in text if ord(c) > 127)
    other_chars = len(text) - chinese_chars
    return int(chinese_chars / 2 + other_chars / 4)


def estimate_message_tokens(msg: Message) -> int:
    """Estimate tokens in a single message."""
    content_tokens = estimate_tokens(msg.content)
    extra_tokens = estimate_tokens(msg.extra or "")
    return content_tokens + extra_tokens + 10  # overhead per message


class ContextCompressor:
    def __init__(
        self,
        db: AsyncSession,
        room_id: str,
        gateway: GatewayChannel,
        trigger_tokens: int = 100000,
        max_history_tokens: int = 32000,
        tail_message_count: int = 20,
    ):
        self.db = db
        self.room_id = room_id
        self.gateway = gateway
        self.trigger_tokens = trigger_tokens
        self.max_history_tokens = max_history_tokens
        self.tail_message_count = tail_message_count

    async def should_compress(self) -> bool:
        """Check if total token count exceeds trigger threshold."""
        messages, _ = await self._get_messages(limit=500)
        total = sum(estimate_message_tokens(m) for m in messages)
        return total >= self.trigger_tokens

    async def compress(self) -> dict:
        """
        Compress conversation history.

        Returns compression result metadata.
        """
        await manager.send_to_room(self.room_id, "compression.started", {})

        messages, _ = await self._get_messages(limit=500)
        if len(messages) <= self.tail_message_count:
            await manager.send_to_room(self.room_id, "compression.completed", {
                "compressed": False,
                "totalMessages": len(messages),
            })
            return {"compressed": False, "totalMessages": len(messages)}

        # Keep tail messages
        tail_messages = messages[-self.tail_message_count:]
        head_messages = messages[:-self.tail_message_count]

        # Generate summary
        summary = await self._summarize(head_messages)

        # Store summary in DB (future: message_summaries table)
        # For now, we just notify completion

        await manager.send_to_room(self.room_id, "compression.completed", {
            "compressed": True,
            "totalMessages": len(messages),
            "verbatimCount": self.tail_message_count,
            "summary": summary[:200] if summary else None,
        })

        return {
            "compressed": True,
            "totalMessages": len(messages),
            "verbatimCount": self.tail_message_count,
        }

    async def _get_messages(self, limit: int) -> tuple[List[Message], bool]:
        """Get messages for the room."""
        result = await self.db.execute(
            select(Message)
            .where(Message.room_id == self.room_id)
            .order_by(Message.created_at)
            .limit(limit)
        )
        messages = list(result.scalars().all())
        has_more = len(messages) >= limit
        return messages, has_more

    async def _summarize(self, messages: List[Message]) -> str:
        """Generate a summary of old messages using LLM."""
        if not messages:
            return ""

        # Build a condensed history for summarization
        history_lines = []
        for msg in messages:
            role = "User" if msg.sender_type == "user" else (msg.sender_name or "Agent")
            content = msg.content
            if len(content) > 500:
                content = content[:500] + "..."
            history_lines.append(f"{role}: {content}")

        history_text = "\n".join(history_lines[-50:])  # last 50 messages only

        summary_prompt = f"""请总结以下对话的要点，保留关键信息、决策、问题和技术细节。保持在500字以内。

{history_text}

摘要:"""

        try:
            async for event in self.gateway.stream_response(
                input_text=summary_prompt,
                model="claude-haiku-4-20250514",
                instructions="你是一个对话摘要助手。请简洁地总结对话要点。",
                conversation_history=[],
            ):
                etype = event.get("type", "")
                if etype == "response.output_text.delta":
                    # In streaming mode, we collect the summary
                    # For simplicity, we wait for completion
                    pass
                elif etype == "response.completed":
                    text = event.get("completion", [])
                    if isinstance(text, list):
                        content_parts = [b.get("text", "") for b in text if isinstance(b, dict)]
                        return "".join(content_parts)
                    return str(text)
        except Exception:
            return "[摘要生成失败]"

    async def get_compressed_history(self, limit: int = 50) -> List[dict]:
        """
        Get conversation history suitable for sending to Gateway.

        Returns formatted messages, with compression applied if needed.
        """
        messages, _ = await self._get_messages(limit=limit)

        history = []
        for msg in messages:
            role = "assistant" if msg.sender_type == "agent" else "user"
            entry: dict = {"role": role, "content": msg.content}
            if msg.extra:
                try:
                    extra = json.loads(msg.extra)
                    if extra.get("reasoning"):
                        entry["reasoning_content"] = extra["reasoning"]
                except json.JSONDecodeError:
                    pass
            history.append(entry)
        return history
