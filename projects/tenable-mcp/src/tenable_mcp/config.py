from functools import lru_cache

from pydantic import Field, HttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    nessus_base_url: HttpUrl = Field(
        ...,
        description="Nessus scanner URL (e.g. https://10.2.190.78:8834)",
    )
    nessus_username: str = Field(...)
    nessus_password: str = Field(...)
    nessus_verify_ssl: bool = Field(default=False)
    nessus_readonly: bool = Field(
        default=False,
        description="Block mutating Nessus API calls (POST create/launch/stop)",
    )
    nessus_cache_ttl_seconds: int = Field(default=300, ge=0)
    nessus_export_ttl_seconds: int = Field(default=3600, ge=0)
    nessus_db_path: str = Field(default="./data/inventory.db")

    mcp_host: str = Field(default="0.0.0.0")
    mcp_port: int = Field(default=8095)

    @field_validator("nessus_base_url", mode="before")
    @classmethod
    def _normalize_base_url(cls, value: object) -> object:
        if isinstance(value, str) and value and not value.startswith(("http://", "https://")):
            return f"https://{value}"
        return value

    @property
    def nessus_base_url_str(self) -> str:
        return str(self.nessus_base_url).rstrip("/")


@lru_cache
def get_settings() -> Settings:
    return Settings()
