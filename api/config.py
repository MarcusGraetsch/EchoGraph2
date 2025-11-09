"""Configuration management for API service."""

from typing import List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """API settings loaded from environment variables."""

    # API Configuration
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    api_secret_key: str = "change-this-to-a-random-secret-key"
    api_algorithm: str = "HS256"
    api_access_token_expire_minutes: int = 30

    # Database
    database_url: str = "postgresql://echograph:changeme@localhost:5432/echograph"

    # Vector Store
    qdrant_host: str = "localhost"
    qdrant_port: int = 6333
    qdrant_api_key: str = ""

    # MinIO / S3
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "echograph-documents"
    minio_use_ssl: bool = False

    # Document Processing
    max_upload_size_mb: int = 100
    chunk_size: int = 512
    chunk_overlap: int = 50
    ocr_enabled: bool = True

    # Celery / Redis
    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/0"
    celery_result_backend: str = "redis://localhost:6379/0"

    # Security
    allowed_origins: Union[List[str], str] = [
        "http://localhost:3000",
        "http://localhost:8000"
    ]
    cors_allow_credentials: bool = True

    @field_validator('allowed_origins', mode='before')
    @classmethod
    def parse_allowed_origins(cls, v):
        """Parse ALLOWED_ORIGINS from comma-separated string to list."""
        if isinstance(v, str):
            # Split by comma and strip whitespace
            return [origin.strip() for origin in v.split(',') if origin.strip()]
        return v

    # Monitoring
    sentry_dsn: str = ""
    enable_metrics: bool = True
    log_level: str = "INFO"

    # Embedding
    embedding_model: str = "sentence-transformers/multi-qa-mpnet-base-dot-v1"
    embedding_dimension: int = 768

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )


settings = Settings()
