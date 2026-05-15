from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    APP_NAME: str = "Hermes App"
    DEBUG: bool = True

    # JWT
    JWT_SECRET_KEY: str = "your-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./hermes.db"

    # Gateway (default fallback when no user gateway is configured)
    DEFAULT_GATEWAY_URL: str = "http://localhost:8642"
    DEFAULT_GATEWAY_API_KEY: str = ""
    DEFAULT_MODEL: str = "claude-sonnet-4-20250514"

    # API key for authenticating with Hermes Gateway
    API_SERVER_KEY: str = ""

    model_config = SettingsConfigDict(env_file=".env")


@lru_cache()
def get_settings() -> Settings:
    return Settings()
