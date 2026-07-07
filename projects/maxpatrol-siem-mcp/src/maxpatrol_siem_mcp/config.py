from functools import lru_cache
from urllib.parse import urlparse

from pydantic import Field, HttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    siem_base_url: HttpUrl = Field(
        ...,
        description="Корневой URL MaxPatrol SIEM API (без trailing slash)",
    )
    siem_client_id: str = Field(default="mpx")
    siem_client_secret: str = Field(...)
    siem_username: str = Field(...)
    siem_password: str = Field(...)
    siem_scope: str = Field(default="offline_access mpx.api")
    siem_verify_ssl: bool = Field(default=True)
    siem_readonly: bool = Field(
        default=True,
        description="Block mutating SIEM API calls (DELETE/PUT/PATCH and non-whitelist POST)",
    )
    siem_token_port: int = Field(
        default=3334,
        description="Порт OAuth token endpoint (PT MC)",
    )

    mcp_host: str = Field(default="0.0.0.0")
    mcp_port: int = Field(default=8094)

    @field_validator("siem_base_url", mode="before")
    @classmethod
    def _normalize_base_url(cls, value: object) -> object:
        if isinstance(value, str) and value and not value.startswith(("http://", "https://")):
            return f"https://{value}"
        return value

    @property
    def siem_base_url_str(self) -> str:
        return str(self.siem_base_url).rstrip("/")

    @property
    def token_url(self) -> str:
        return f"{self.siem_mc_base_url}/connect/token"

    @property
    def siem_mc_base_url(self) -> str:
        parsed = urlparse(self.siem_base_url_str)
        scheme = parsed.scheme or "https"
        host = parsed.hostname or parsed.netloc.split(":")[0]
        return f"{scheme}://{host}:{self.siem_token_port}"


@lru_cache
def get_settings() -> Settings:
    return Settings()
