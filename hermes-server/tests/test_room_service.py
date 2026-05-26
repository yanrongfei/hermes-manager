"""
Unit tests for RoomService using mocked database.
Tests room creation (basic, 1:1 with agent_id, group with agent_ids),
room membership, and room stats.
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from app.services.room import RoomService
from app.models.room import Room, RoomMember


@pytest.fixture
def mock_db():
    db = AsyncMock()
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


@pytest.fixture
def service(mock_db):
    return RoomService(mock_db)


def _make_room(id="room-1", name="Test Room", owner_id="user-1", mode="direct",
                agent_id=None, invite_code=None):
    room = Room(
        id=id, name=name, owner_id=owner_id, mode=mode,
        agent_id=agent_id, invite_code=invite_code,
    )
    return room


class TestCreateRoom:
    @pytest.mark.asyncio
    async def test_create_basic_room(self, service, mock_db):
        room = _make_room()
        mock_db.refresh.side_effect = [room, room]

        result = await service.create_room(
            owner_id="user-1", name="Test Room", mode="direct",
        )

        assert mock_db.add.call_count >= 2  # room + owner member
        mock_db.commit.assert_called()
        assert result.name == "Test Room"

    @pytest.mark.asyncio
    async def test_create_1v1_room_with_agent_id(self, service, mock_db):
        """1:1 room: pass a single agent_id to link the room directly."""
        room = _make_room(agent_id="agent-1")
        mock_db.refresh.side_effect = [room, room]

        result = await service.create_room(
            owner_id="user-1", name="Agent Chat", mode="direct",
            agent_id="agent-1",
        )

        assert result.agent_id == "agent-1"
        mock_db.commit.assert_called()

    @pytest.mark.asyncio
    async def test_create_group_room_with_agent_ids(self, service, mock_db):
        """Group room: pass multiple agent_ids to create RoomAgent entries."""
        room = _make_room(mode="broadcast")
        mock_db.refresh.side_effect = [room, room]

        result = await service.create_room(
            owner_id="user-1", name="Group", mode="broadcast",
            agent_ids=["agent-a", "agent-b"],
        )

        # Room + owner member + 2 RoomAgent entries = 4 add calls
        assert mock_db.add.call_count == 4
        mock_db.commit.assert_called()

    @pytest.mark.asyncio
    async def test_create_room_adds_owner_as_member(self, service, mock_db):
        room = _make_room()
        mock_db.refresh.side_effect = [room, room]

        await service.create_room(owner_id="user-1", name="Room", mode="direct")

        # Check that a RoomMember was added
        added_objects = [call[0][0] for call in mock_db.add.call_args_list]
        member_added = any(isinstance(obj, RoomMember) for obj in added_objects)
        assert member_added, "Owner should be added as a room member"

        member_obj = next(obj for obj in added_objects if isinstance(obj, RoomMember))
        assert member_obj.role == "owner"
        assert member_obj.user_id == "user-1"


class TestGetRoom:
    @pytest.mark.asyncio
    async def test_get_room_found(self, service, mock_db):
        room = _make_room()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = room
        mock_db.execute.return_value = mock_result

        result = await service.get_room("room-1")
        assert result is not None
        assert result.id == "room-1"

    @pytest.mark.asyncio
    async def test_get_room_not_found(self, service, mock_db):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        result = await service.get_room("nonexistent")
        assert result is None


class TestMembership:
    @pytest.mark.asyncio
    async def test_is_member_true(self, service, mock_db):
        mock_member = MagicMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = mock_member
        mock_db.execute.return_value = mock_result

        assert await service.is_member("room-1", "user-1") is True

    @pytest.mark.asyncio
    async def test_is_member_false(self, service, mock_db):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        assert await service.is_member("room-1", "user-1") is False

    @pytest.mark.asyncio
    async def test_leave_room_success(self, service, mock_db):
        mock_member = MagicMock()
        mock_member.role = "member"
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = mock_member
        mock_db.execute.return_value = mock_result

        result = await service.leave_room("room-1", "user-1")
        assert result is True
        mock_db.delete.assert_called_once_with(mock_member)

    @pytest.mark.asyncio
    async def test_leave_room_owner_cannot_leave(self, service, mock_db):
        mock_member = MagicMock()
        mock_member.role = "owner"
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = mock_member
        mock_db.execute.return_value = mock_result

        result = await service.leave_room("room-1", "owner-user")
        assert result is False
        mock_db.delete.assert_not_called()

    @pytest.mark.asyncio
    async def test_leave_room_not_member(self, service, mock_db):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        result = await service.leave_room("room-1", "stranger")
        assert result is False


class TestInviteCode:
    @pytest.mark.asyncio
    async def test_generate_invite_code_creates_new(self, service, mock_db):
        room = _make_room(mode="broadcast", invite_code=None)
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = room
        mock_db.execute.return_value = mock_result
        mock_db.refresh.side_effect = [room]

        code = await service.generate_invite_code("room-1")
        assert code is not None
        assert len(code) > 0
        mock_db.commit.assert_called()

    @pytest.mark.asyncio
    async def test_generate_invite_code_returns_existing(self, service, mock_db):
        room = _make_room(mode="broadcast", invite_code="existing-code")
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = room
        mock_db.execute.return_value = mock_result

        code = await service.generate_invite_code("room-1")
        assert code == "existing-code"
        mock_db.commit.assert_not_called()

    @pytest.mark.asyncio
    async def test_generate_invite_code_direct_room_refused(self, service, mock_db):
        room = _make_room(mode="direct")
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = room
        mock_db.execute.return_value = mock_result

        code = await service.generate_invite_code("room-1")
        assert code is None

    @pytest.mark.asyncio
    async def test_generate_invite_code_room_not_found(self, service, mock_db):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        code = await service.generate_invite_code("nonexistent")
        assert code is None


class TestRoomStats:
    @pytest.mark.asyncio
    async def test_get_room_stats_empty_room(self, service, mock_db):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        with patch.object(service, 'get_room_members', return_value=[]):
            with patch('app.api.ws.active_executors', {}):
                stats = await service.get_room_stats("room-1")

        assert stats["member_count"] == 0
        assert stats["online_count"] == 0
        assert stats["has_running_tasks"] is False
        assert stats["running_tasks_count"] == 0
        assert stats["last_message"] is None
