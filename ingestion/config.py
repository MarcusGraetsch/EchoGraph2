"""Configuration management for document ingestion service."""

import os
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database
    database_url: str = "postgresql://echograph:changeme@localhost:5432/echograph"

    # MinIO / S3
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "echograph-documents"
    minio_use_ssl: bool = False

    # Processing
    max_upload_size_mb: int = 100
    chunk_size: int = 512
    chunk_overlap: int = 50
    ocr_enabled: bool = True

    # Data paths
    data_raw_path: str = "./data/raw"
    data_processed_path: str = "./data/processed"

    # Logging
    log_level: str = "INFO"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )


settings = Settings()
