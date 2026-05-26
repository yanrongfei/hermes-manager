"""
Unit tests for WebSocket chat logic.
Tests the ws.py helper functions and ConnectionManager without real WebSocket connections.
"""
import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from app.api.ws import _extract_mentions, active_executors, message_queues
from app.services.websocket import ConnectionManager


class TestExtractMentions:
    def test_single_mention(self):
        assert _extract_mentions("@alice hello") == ["alice"]

    def test_multiple_mentions(self):
        assert _extract_mentions("@alice @bob hello") == ["alice", "bob"]

    def test_no_mentions(self):
        assert _extract_mentions("hello world") == []

    def test_mention_with_underscore(self):
        assert _extract_mentions("@my_agent do stuff") == ["my_agent"]

    def test_duplicate_mentions(self):
        result = _extract_mentions("@alice @alice hello")
        assert result == ["alice", "alice"]

    def test_empty_content(self):
        assert _extract_mentions("") == []


class TestFormatConversationHistory:
    @pytest.mark.asyncio
    async def test_format_conversation_history_with_messages(self):
        # Requires database setup - skip unit test, covered in integration tests
        pass


class TestConnectionManager:
    def setup_method(self):
        self.mgr = ConnectionManager()

    def _make_ws(self, ws_id="ws-1"):
        ws = MagicMock()
        ws.send_text = AsyncMock()
        ws.__hash__ = lambda self_ws: hash(ws_id)
        ws.__eq__ = lambda self_ws, other: ws_id == getattr(other, '_test_id', None)
        ws._test_id = ws_id
        return ws

    @pytest.mark.asyncio
    async def test_connect_and_disconnect(self):
        ws = self._make_ws("ws-1")
        await self.mgr.connect(ws, "room-1", "user-1")
        assert "room-1" in self.mgr.active_connections
        assert ws in self.mgr.active_connections["room-1"]
        assert self.mgr.user_connections[ws] == "user-1"

        await self.mgr.disconnect(ws)
        assert "room-1" not in self.mgr.active_connections
        assert ws not in self.mgr.user_connections

    @pytest.mark.asyncio
    async def test_multiple_connections_same_room(self):
        ws1 = self._make_ws("ws-1")
        ws2 = self._make_ws("ws-2")
        await self.mgr.connect(ws1, "room-1", "user-1")
        await self.mgr.connect(ws2, "room-1", "user-2")
        assert len(self.mgr.active_connections["room-1"]) == 2

        await self.mgr.disconnect(ws1)
        assert len(self.mgr.active_connections["room-1"]) == 1
        assert ws2 in self.mgr.active_connections["room-1"]

    @pytest.mark.asyncio
    async def test_send_to_room(self):
        ws1 = self._make_ws("ws-1")
        ws2 = self._make_ws("ws-2")
        await self.mgr.connect(ws1, "room-1", "user-1")
        await self.mgr.connect(ws2, "room-1", "user-2")

        await self.mgr.send_to_room("room-1", "test_event", {"key": "value"})
        ws1.send_text.assert_called_once()
        ws2.send_text.assert_called_once()
        import json
        msg = json.loads(ws1.send_text.call_args[0][0])
        assert msg["event"] == "test_event"
        assert msg["data"]["key"] == "value"

    @pytest.mark.asyncio
    async def test_broadcast_excludes_sender(self):
        ws1 = self._make_ws("ws-1")
        ws2 = self._make_ws("ws-2")
        await self.mgr.connect(ws1, "room-1", "user-1")
        await self.mgr.connect(ws2, "room-1", "user-2")

        await self.mgr.broadcast_to_room("room-1", "typing", {"userId": "user-1"}, exclude=ws1)
        ws1.send_text.assert_not_called()
        ws2.send_text.assert_called_once()

    @pytest.mark.asyncio
    async def test_send_to_empty_room(self):
        # Should not raise
        await self.mgr.send_to_room("nonexistent", "event", {})

    @pytest.mark.asyncio
    async def test_disconnect_nonexistent(self):
        ws = self._make_ws("ws-x")
        # Should not raise
        await self.mgr.disconnect(ws)


class TestExecutorCleanup:
    @pytest.mark.asyncio
    async def test_cleanup_removes_executor(self):
        from app.api.ws import _cleanup_executor
        mock_exec = MagicMock()
        mock_exec.message_id = "msg-1"
        active_executors["room-1"] = [mock_exec]

        with patch("app.api.ws.manager") as mock_mgr:
            mock_mgr.send_to_room = AsyncMock()
            await _cleanup_executor("room-1", "msg-1")

        assert "room-1" not in active_executors

    @pytest.mark.asyncio
    async def test_cleanup_nothing_for_unknown_room(self):
        from app.api.ws import _cleanup_executor
        # Should not raise
        await _cleanup_executor("nonexistent", "msg-1")
