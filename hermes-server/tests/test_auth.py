import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from app.services.auth import AuthService
from app.models.user import User
from app.core.security import verify_password, get_password_hash, create_access_token, decode_token

class TestPasswordHashing:
    def test_password_hash_is_different_from_plain(self):
        password = "testpassword123"
        hashed = get_password_hash(password)
        assert hashed != password

    def test_verify_password_correct(self):
        password = "testpassword123"
        hashed = get_password_hash(password)
        assert verify_password(password, hashed) is True

    def test_verify_password_incorrect(self):
        password = "testpassword123"
        hashed = get_password_hash(password)
        assert verify_password("wrongpassword", hashed) is False

class TestTokenCreation:
    def test_create_access_token(self):
        data = {"sub": "user123", "username": "testuser"}
        token = create_access_token(data)
        assert token is not None
        assert isinstance(token, str)

    def test_decode_access_token(self):
        data = {"sub": "user123", "username": "testuser"}
        token = create_access_token(data)
        decoded = decode_token(token)
        assert decoded is not None
        assert decoded.get("sub") == "user123"
        assert decoded.get("username") == "testuser"
        assert decoded.get("type") == "access"

    def test_decode_invalid_token(self):
        result = decode_token("invalid.token.here")
        assert result is None

class TestAuthService:
    @pytest.mark.asyncio
    async def test_get_user_by_username_not_found(self):
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        service = AuthService(mock_db)
        user = await service.get_user_by_username("nonexistent")
        assert user is None

    @pytest.mark.asyncio
    async def test_create_user(self):
        mock_db = AsyncMock()
        mock_db.add = MagicMock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        service = AuthService(mock_db)
        user = await service.create_user("testuser", "password123")

        assert user.username == "testuser"
        assert user.password_hash != "password123"
        mock_db.add.assert_called_once()
        mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_authenticate_user_success(self):
        mock_db = AsyncMock()
        hashed_pw = get_password_hash("password123")

        mock_user = User(username="testuser", password_hash=hashed_pw)
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = mock_user
        mock_db.execute.return_value = mock_result

        service = AuthService(mock_db)
        user = await service.authenticate_user("testuser", "password123")
        assert user is not None
        assert user.username == "testuser"

    @pytest.mark.asyncio
    async def test_authenticate_user_wrong_password(self):
        mock_db = AsyncMock()
        hashed_pw = get_password_hash("password123")

        mock_user = User(username="testuser", password_hash=hashed_pw)
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = mock_user
        mock_db.execute.return_value = mock_result

        service = AuthService(mock_db)
        user = await service.authenticate_user("testuser", "wrongpassword")
        assert user is None

    @pytest.mark.asyncio
    async def test_authenticate_user_not_found(self):
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        service = AuthService(mock_db)
        user = await service.authenticate_user("nonexistent", "password123")
        assert user is None

    def test_create_tokens(self):
        mock_db = MagicMock()
        service = AuthService(mock_db)
        tokens = service.create_tokens("user123", "testuser")

        assert "access_token" in tokens
        assert "refresh_token" in tokens
        assert tokens["access_token"] != tokens["refresh_token"]

    @pytest.mark.asyncio
    async def test_refresh_access_token_invalid_token(self):
        mock_db = AsyncMock()
        service = AuthService(mock_db)
        result = await service.refresh_access_token("invalid.token")
        assert result is None

    @pytest.mark.asyncio
    async def test_refresh_access_token_valid(self):
        mock_db = AsyncMock()
        hashed_pw = get_password_hash("password123")
        mock_user = User(id="user123", username="testuser", password_hash=hashed_pw)

        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = mock_user
        mock_db.execute.return_value = mock_result

        service = AuthService(mock_db)

        # First create a valid refresh token
        refresh_token = service.create_tokens("user123", "testuser")["refresh_token"]
        result = await service.refresh_access_token(refresh_token)

        assert result is not None
        assert "access_token" in result