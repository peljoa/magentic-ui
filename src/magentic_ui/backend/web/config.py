# api/config.py

from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # Database settings
    DATABASE_URI: str = "sqlite:///./magentic_ui.db"
    UPGRADE_DATABASE: bool = False

    # Application settings
    API_DOCS: bool = False
    CLEANUP_INTERVAL: int = 300  # 5 minutes
    SESSION_TIMEOUT: int = 3600 * 24  # 24 hour
    CONFIG_DIR: str = "configs"  # Default config directory relative to app_root
    DEFAULT_USER_ID: str = "guestuser@gmail.com"

    # Security settings
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # MSAL Authentication settings
    AZURE_CLIENT_ID: str = ""
    AZURE_CLIENT_SECRET: str = ""
    AZURE_TENANT_ID: str = ""
    AZURE_AUTHORITY: Optional[str] = None
    REDIRECT_URI: str = "http://localhost:8088/auth/callback"
    SCOPES: list[str] = ["User.Read"]

    # Redis settings for session storage
    REDIS_URL: str = "redis://localhost:6379"

    # Rate limiting
    RATE_LIMIT_REQUESTS: int = 100
    RATE_LIMIT_WINDOW: int = 60  # seconds

    # CORS settings
    CORS_ORIGINS: list[str] = [
        "http://localhost:8088",
        "http://127.0.0.1:8088",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]

    # Production security settings
    ENVIRONMENT: str = "development"  # development, staging, production
    HTTPS_ONLY: bool = False
    SECURE_COOKIES: bool = False

    model_config = {"env_prefix": "MAGENTIC_UI_"}

    @property
    def azure_authority_url(self) -> str:
        if self.AZURE_AUTHORITY:
            return self.AZURE_AUTHORITY
        return f"https://login.microsoftonline.com/{self.AZURE_TENANT_ID}"


settings = Settings()
