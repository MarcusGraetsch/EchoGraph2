"""Embedding generation using sentence-transformers and optional APIs."""

from typing import List, Union, Optional
import numpy as np
from sentence_transformers import SentenceTransformer
from loguru import logger

from .config import settings


class EmbeddingGenerator:
    """Generate embeddings for text chunks."""

    def __init__(self, model_name: Optional[str] = None, use_gpu: Optional[bool] = None):
        """Initialize embedding generator.

        Args:
            model_name: Name of the sentence-transformer model
            use_gpu: Whether to use GPU (if available)
        """
        self.model_name = model_name or settings.embedding_model
        self.use_gpu = use_gpu if use_gpu is not None else settings.use_gpu

        device = "cuda" if self.use_gpu else "cpu"

        logger.info(f"Loading embedding model: {self.model_name} on {device}")
        self.model = SentenceTransformer(self.model_name, device=device)

        # Get embedding dimension
        self.embedding_dim = self.model.get_sentence_embedding_dimension()
        logger.info(f"Embedding dimension: {self.embedding_dim}")

    def generate_embedding(self, text: str) -> np.ndarray:
        """Generate embedding for a single text.

        Args:
            text: Text to embed

        Returns:
            Embedding vector as numpy array
        """
        if not text or not text.strip():
            return np.zeros(self.embedding_dim)

        embedding = self.model.encode(text, convert_to_numpy=True)
        return embedding

    def generate_embeddings(
        self,
        texts: List[str],
        batch_size: int = 32,
        show_progress: bool = True
    ) -> np.ndarray:
        """Generate embeddings for multiple texts.

        Args:
            texts: List of texts to embed
            batch_size: Batch size for processing
            show_progress: Whether to show progress bar

        Returns:
            Array of embeddings
        """
        if not texts:
            return np.array([])

        logger.info(f"Generating embeddings for {len(texts)} texts")

        embeddings = self.model.encode(
            texts,
            batch_size=batch_size,
            show_progress_bar=show_progress,
            convert_to_numpy=True
        )

        return embeddings

    def compute_similarity(
        self,
        embedding1: np.ndarray,
        embedding2: np.ndarray
    ) -> float:
        """Compute cosine similarity between two embeddings.

        Args:
            embedding1: First embedding
            embedding2: Second embedding

        Returns:
            Similarity score (0-1)
        """
        # Normalize embeddings
        norm1 = np.linalg.norm(embedding1)
        norm2 = np.linalg.norm(embedding2)

        if norm1 == 0 or norm2 == 0:
            return 0.0

        # Compute cosine similarity
        similarity = np.dot(embedding1, embedding2) / (norm1 * norm2)

        # Ensure result is in [0, 1] range
        similarity = (similarity + 1) / 2

        return float(similarity)


class OpenAIEmbedding:
    """Generate embeddings using OpenAI API (optional)."""

    def __init__(self, api_key: Optional[str] = None):
        """Initialize OpenAI embedding generator.

        Args:
            api_key: OpenAI API key
        """
        self.api_key = api_key or settings.openai_api_key

        if not self.api_key:
            raise ValueError("OpenAI API key is required")

        try:
            from openai import OpenAI
            self.client = OpenAI(api_key=self.api_key)
            self.model = "text-embedding-3-small"
            self.embedding_dim = 1536
            logger.info(f"Initialized OpenAI embeddings with model: {self.model}")
        except ImportError:
            raise ImportError("openai package is required for OpenAI embeddings")

    def generate_embedding(self, text: str) -> np.ndarray:
        """Generate embedding using OpenAI API.

        Args:
            text: Text to embed

        Returns:
            Embedding vector
        """
        if not text or not text.strip():
            return np.zeros(self.embedding_dim)

        response = self.client.embeddings.create(
            model=self.model,
            input=text
        )

        embedding = np.array(response.data[0].embedding)
        return embedding

    def generate_embeddings(self, texts: List[str]) -> np.ndarray:
        """Generate embeddings for multiple texts.

        Args:
            texts: List of texts to embed

        Returns:
            Array of embeddings
        """
        if not texts:
            return np.array([])

        response = self.client.embeddings.create(
            model=self.model,
            input=texts
        )

        embeddings = np.array([item.embedding for item in response.data])
        return embeddings


def get_embedding_generator(
    provider: str = "local",
    **kwargs
) -> Union[EmbeddingGenerator, OpenAIEmbedding]:
    """Factory function to get embedding generator.

    Args:
        provider: Embedding provider ("local", "openai")
        **kwargs: Additional arguments for the generator

    Returns:
        Embedding generator instance
    """
    if provider == "local":
        return EmbeddingGenerator(**kwargs)
    elif provider == "openai":
        return OpenAIEmbedding(**kwargs)
    else:
        raise ValueError(f"Unknown embedding provider: {provider}")
