from functools import lru_cache

from pydantic import Field, HttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    defectdojo_base_url: HttpUrl = Field(
        ...,
        description="DefectDojo base URL (no trailing slash)",
    )
    defectdojo_api_key: str = Field(...)
    defectdojo_verify_ssl: bool = Field(default=True)
    defectdojo_readonly: bool = Field(
        default=False,
        description="Block mutating DefectDojo API calls when true",
    )
    defectdojo_cache_ttl_seconds: int = Field(default=120)

    mcp_host: str = Field(default="0.0.0.0")
    mcp_port: int = Field(default=8096)

    @field_validator("defectdojo_base_url", mode="before")
    @classmethod
    def _normalize_base_url(cls, value: object) -> object:
        if isinstance(value, str) and value and not value.startswith(("http://", "https://")):
            return f"http://{value}"
        return value

    @property
    def defectdojo_base_url_str(self) -> str:
        return str(self.defectdojo_base_url).rstrip("/")


@lru_cache
def get_settings() -> Settings:
    return Settings()
