"""Configuration for processing module."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Processing settings."""

    # Embedding configuration
    embedding_model: str = "sentence-transformers/multi-qa-mpnet-base-dot-v1"
    embedding_dimension: int = 768
    use_gpu: bool = False

    # Chunking configuration
    chunk_size: int = 512
    chunk_overlap: int = 50

    # Vector store
    qdrant_host: str = "localhost"
    qdrant_port: int = 6333
    qdrant_api_key: str = ""

    # Database
    database_url: str = "postgresql://echograph:changeme@localhost:5432/echograph"

    # Optional AI APIs
    openai_api_key: str = ""
    openai_model: str = "gpt-4-turbo-preview"
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-3-sonnet-20240229"
    cohere_api_key: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )


settings = Settings()
