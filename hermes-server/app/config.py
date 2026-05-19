import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


def _load_hermes_env():
    """Auto-read ~/.hermes/.env for gateway config if not set in local .env."""
    hermes_env = Path.home() / ".hermes" / ".env"
    if not hermes_env.exists():
        return
    hermes_vars = {}
    try:
        for line in hermes_env.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            hermes_vars[key.strip()] = value.strip().strip("'\"")
    except Exception:
        return

    # Prefer API_SERVER_KEY (gateway auth), fallback to HERMES_GATEWAY_TOKEN
    if "DEFAULT_GATEWAY_API_KEY" not in os.environ:
        key = hermes_vars.get("API_SERVER_KEY") or hermes_vars.get("HERMES_GATEWAY_TOKEN", "")
        if key:
            os.environ["DEFAULT_GATEWAY_API_KEY"] = key


_load_hermes_env()


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

    model_config = SettingsConfigDict(env_file=".env")


@lru_cache()
def get_settings() -> Settings:
    return Settings()
