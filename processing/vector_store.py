"""
Qdrant Vector Store Integration

This module provides a clean interface for storing and retrieving document embeddings
using Qdrant vector database. Supports both document-level and chunk-level embeddings
with metadata filtering and semantic search.

Architecture:
- Two collections: 'documents' (document-level) and 'chunks' (chunk-level)
- Hybrid search: vector similarity + metadata filters
- Batch operations for performance
- Automatic collection initialization
"""

from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    VectorParams,
    PointStruct,
    Filter,
    FieldCondition,
    MatchValue,
    Range,
    SearchParams,
)
from loguru import logger
import uuid


@dataclass
class SearchResult:
    """Result from vector search."""
    id: str
    score: float
    payload: Dict[str, Any]
    vector: Optional[List[float]] = None


class VectorStore:
    """
    Qdrant vector store for document embeddings.

    Collections:
    - 'documents': Document-level embeddings (one per document)
    - 'chunks': Chunk-level embeddings (multiple per document)

    Usage:
        store = VectorStore(host="localhost", port=6333)
        store.initialize_collections(vector_size=768)

        # Store chunk embeddings
        store.store_chunk_embeddings(
            chunk_ids=[1, 2, 3],
            embeddings=[[0.1, 0.2, ...], ...],
            metadata=[{"doc_id": 1, "text": "..."}, ...]
        )

        # Search similar chunks
        results = store.search_similar_chunks(
            query_vector=[0.1, 0.2, ...],
            limit=10,
            filters={"document_type": "norm"}
        )
    """

    def __init__(
        self,
        host: str = "localhost",
        port: int = 6333,
        api_key: Optional[str] = None,
        timeout: int = 60
    ):
        """
        Initialize Qdrant client.

        Args:
            host: Qdrant server host
            port: Qdrant server port
            api_key: API key for authentication (optional)
            timeout: Request timeout in seconds
        """
        self.client = QdrantClient(
            host=host,
            port=port,
            api_key=api_key,
            timeout=timeout
        )
        self.documents_collection = "documents"
        self.chunks_collection = "chunks"

        logger.info(f"Connected to Qdrant at {host}:{port}")


    def initialize_collections(self, vector_size: int = 768) -> None:
        """
        Initialize Qdrant collections if they don't exist.

        Creates two collections:
        1. 'documents' - Document-level embeddings
        2. 'chunks' - Chunk-level embeddings (main collection)

        Args:
            vector_size: Dimensionality of embedding vectors (default: 768 for sentence-transformers)
        """
        # Create documents collection (ignore if already exists)
        try:
            self.client.create_collection(
                collection_name=self.documents_collection,
                vectors_config=VectorParams(
                    size=vector_size,
                    distance=Distance.COSINE  # Cosine similarity for semantic search
                )
            )
            logger.info(f"Created collection: {self.documents_collection}")
        except Exception as e:
            # Collection likely already exists (409 Conflict)
            if "already exists" in str(e).lower() or "409" in str(e):
                logger.info(f"Collection already exists: {self.documents_collection}")
            else:
                logger.error(f"Failed to create collection {self.documents_collection}: {e}")
                raise

        # Create chunks collection (ignore if already exists)
        try:
            self.client.create_collection(
                collection_name=self.chunks_collection,
                vectors_config=VectorParams(
                    size=vector_size,
                    distance=Distance.COSINE
                )
            )
            logger.info(f"Created collection: {self.chunks_collection}")
        except Exception as e:
            # Collection likely already exists (409 Conflict)
            if "already exists" in str(e).lower() or "409" in str(e):
                logger.info(f"Collection already exists: {self.chunks_collection}")
            else:
                logger.error(f"Failed to create collection {self.chunks_collection}: {e}")
                raise


    def delete_collection(self, collection_name: str) -> bool:
        """
        Delete a collection.

        Args:
            collection_name: Name of collection to delete

        Returns:
            True if deleted, False if didn't exist
        """
        try:
            self.client.get_collection(collection_name)
            self.client.delete_collection(collection_name)
            logger.info(f"Deleted collection: {collection_name}")
            return True
        except Exception:
            logger.warning(f"Collection does not exist: {collection_name}")
            return False


    def store_chunk_embeddings(
        self,
        chunk_ids: List[int],
        embeddings: List[List[float]],
        metadata: List[Dict[str, Any]]
    ) -> int:
        """
        Store chunk embeddings in Qdrant (batch operation).

        Metadata should include:
        - document_id: ID of parent document
        - chunk_index: Position in document
        - chunk_text: The actual text content
        - section_title: Section heading (optional)
        - section_level: Heading level (optional)
        - page_number: Page number (optional)
        - document_type: "norm" or "guideline"
        - document_title: Parent document title

        Args:
            chunk_ids: List of chunk IDs from database
            embeddings: List of embedding vectors
            metadata: List of metadata dicts (one per chunk)

        Returns:
            Number of chunks stored

        Example:
            store.store_chunk_embeddings(
                chunk_ids=[1, 2, 3],
                embeddings=[[0.1, ...], [0.2, ...], [0.3, ...]],
                metadata=[
                    {"document_id": 1, "chunk_text": "...", "document_type": "norm"},
                    {"document_id": 1, "chunk_text": "...", "document_type": "norm"},
                    {"document_id": 1, "chunk_text": "...", "document_type": "norm"}
                ]
            )
        """
        if len(chunk_ids) != len(embeddings) != len(metadata):
            raise ValueError("chunk_ids, embeddings, and metadata must have same length")

        # Create points for batch upload
        points = []
        for chunk_id, embedding, meta in zip(chunk_ids, embeddings, metadata):
            # Ensure all required fields are present
            if "document_id" not in meta:
                raise ValueError(f"Metadata for chunk {chunk_id} missing 'document_id'")

            # Qdrant accepts int or UUID as ID (version 1.7.0)
            point = PointStruct(
                id=chunk_id,  # Use int directly, not string
                vector=embedding,
                payload=meta
            )
            points.append(point)

        # Batch upload to Qdrant
        self.client.upsert(
            collection_name=self.chunks_collection,
            points=points
        )

        logger.info(f"Stored {len(points)} chunk embeddings in Qdrant")
        return len(points)


    def store_document_embedding(
        self,
        document_id: int,
        embedding: List[float],
        metadata: Dict[str, Any]
    ) -> None:
        """
        Store a document-level embedding.

        This is useful for document-to-document similarity without going through chunks.

        Args:
            document_id: Document ID from database
            embedding: Document-level embedding vector
            metadata: Document metadata (title, type, etc.)
        """
        point = PointStruct(
            id=document_id,  # Use int directly
            vector=embedding,
            payload=metadata
        )

        self.client.upsert(
            collection_name=self.documents_collection,
            points=[point]
        )

        logger.info(f"Stored document embedding: {document_id}")


    def search_similar_chunks(
        self,
        query_vector: List[float],
        limit: int = 20,
        score_threshold: float = 0.7,
        filters: Optional[Dict[str, Any]] = None
    ) -> List[SearchResult]:
        """
        Search for similar chunks using vector similarity.

        Args:
            query_vector: Query embedding vector
            limit: Maximum number of results
            score_threshold: Minimum similarity score (0-1)
            filters: Optional metadata filters, e.g.:
                     {"document_type": "norm", "document_id": 123}

        Returns:
            List of SearchResult objects

        Example:
            # Find similar chunks in norms only
            results = store.search_similar_chunks(
                query_vector=embedding,
                limit=10,
                score_threshold=0.75,
                filters={"document_type": "norm"}
            )
        """
        # Build filter conditions
        query_filter = None
        if filters:
            conditions = []
            for key, value in filters.items():
                if isinstance(value, (int, str)):
                    conditions.append(
                        FieldCondition(
                            key=key,
                            match=MatchValue(value=value)
                        )
                    )
                elif isinstance(value, dict) and "gte" in value:
                    # Range filter: {"score": {"gte": 0.8}}
                    conditions.append(
                        FieldCondition(
                            key=key,
                            range=Range(gte=value.get("gte"), lte=value.get("lte"))
                        )
                    )

            if conditions:
                query_filter = Filter(must=conditions)

        # Search in Qdrant
        search_results = self.client.search(
            collection_name=self.chunks_collection,
            query_vector=query_vector,
            limit=limit,
            score_threshold=score_threshold,
            query_filter=query_filter,
            with_payload=True,
            with_vectors=False  # Don't return vectors to save bandwidth
        )

        # Convert to SearchResult objects
        results = []
        for hit in search_results:
            result = SearchResult(
                id=str(hit.id),  # Convert to string for consistency
                score=hit.score,
                payload=hit.payload or {}
            )
            results.append(result)

        logger.info(f"Found {len(results)} similar chunks (threshold: {score_threshold})")
        return results


    def search_similar_documents(
        self,
        query_vector: List[float],
        limit: int = 10,
        score_threshold: float = 0.7,
        filters: Optional[Dict[str, Any]] = None
    ) -> List[SearchResult]:
        """
        Search for similar documents using document-level embeddings.

        Args:
            query_vector: Query embedding vector
            limit: Maximum number of results
            score_threshold: Minimum similarity score
            filters: Optional metadata filters

        Returns:
            List of SearchResult objects
        """
        query_filter = None
        if filters:
            conditions = []
            for key, value in filters.items():
                conditions.append(
                    FieldCondition(key=key, match=MatchValue(value=value))
                )
            query_filter = Filter(must=conditions)

        search_results = self.client.search(
            collection_name=self.documents_collection,
            query_vector=query_vector,
            limit=limit,
            score_threshold=score_threshold,
            query_filter=query_filter,
            with_payload=True
        )

        results = [
            SearchResult(
                id=str(hit.id),
                score=hit.score,
                payload=hit.payload or {}
            )
            for hit in search_results
        ]

        logger.info(f"Found {len(results)} similar documents")
        return results


    def find_cross_document_similarities(
        self,
        source_doc_id: int,
        target_doc_ids: Optional[List[int]] = None,
        threshold: float = 0.75,
        limit_per_chunk: int = 5
    ) -> List[Tuple[str, str, float, Dict, Dict]]:
        """
        Find similar chunks between documents (for relationship detection).

        This is the core function for discovering relationships between norms.
        For each chunk in source document, find similar chunks in target documents.

        Args:
            source_doc_id: Source document ID
            target_doc_ids: List of target document IDs (if None, search all documents)
            threshold: Minimum similarity score
            limit_per_chunk: Max similar chunks to find per source chunk

        Returns:
            List of tuples: (source_chunk_id, target_chunk_id, similarity_score, source_payload, target_payload)

        Example:
            # Find similarities between norm A and norm B
            similarities = store.find_cross_document_similarities(
                source_doc_id=1,
                target_doc_ids=[2],
                threshold=0.80
            )

            for src_id, tgt_id, score, src_meta, tgt_meta in similarities:
                print(f"Chunk {src_id} similar to {tgt_id} (score: {score})")
        """
        # Get all chunks from source document
        source_chunks = self.client.scroll(
            collection_name=self.chunks_collection,
            scroll_filter=Filter(
                must=[FieldCondition(key="document_id", match=MatchValue(value=source_doc_id))]
            ),
            limit=1000,  # Adjust based on expected chunk count
            with_vectors=True,
            with_payload=True
        )

        similarities = []

        # For each source chunk, find similar chunks in target documents
        for point in source_chunks[0]:  # scroll returns (points, next_offset)
            source_chunk_id = str(point.id)
            source_vector = point.vector
            source_payload = point.payload

            # Build filter for target documents
            filters = {"document_id": {"$ne": source_doc_id}}  # Exclude same document
            if target_doc_ids:
                # Search only in specified target documents
                for target_id in target_doc_ids:
                    target_filter = Filter(
                        must=[FieldCondition(key="document_id", match=MatchValue(value=target_id))]
                    )

                    results = self.client.search(
                        collection_name=self.chunks_collection,
                        query_vector=source_vector,
                        limit=limit_per_chunk,
                        score_threshold=threshold,
                        query_filter=target_filter,
                        with_payload=True
                    )

                    for hit in results:
                        similarities.append((
                            source_chunk_id,
                            str(hit.id),
                            hit.score,
                            source_payload,
                            hit.payload
                        ))
            else:
                # Search in all documents except source
                exclude_filter = Filter(
                    must_not=[FieldCondition(key="document_id", match=MatchValue(value=source_doc_id))]
                )

                results = self.client.search(
                    collection_name=self.chunks_collection,
                    query_vector=source_vector,
                    limit=limit_per_chunk,
                    score_threshold=threshold,
                    query_filter=exclude_filter,
                    with_payload=True
                )

                for hit in results:
                    similarities.append((
                        source_chunk_id,
                        str(hit.id),
                        hit.score,
                        source_payload,
                        hit.payload
                    ))

        logger.info(f"Found {len(similarities)} cross-document similarities for doc {source_doc_id}")
        return similarities


    def delete_document_vectors(self, document_id: int) -> None:
        """
        Delete all vectors associated with a document.

        Args:
            document_id: Document ID to delete
        """
        # Delete from chunks collection
        self.client.delete(
            collection_name=self.chunks_collection,
            points_selector=Filter(
                must=[FieldCondition(key="document_id", match=MatchValue(value=document_id))]
            )
        )

        # Delete from documents collection
        try:
            self.client.delete(
                collection_name=self.documents_collection,
                points_selector=[document_id]  # Use int directly
            )
        except Exception as e:
            logger.warning(f"Could not delete document embedding: {e}")

        logger.info(f"Deleted all vectors for document {document_id}")


    def get_collection_info(self, collection_name: str) -> Dict[str, Any]:
        """
        Get information about a collection.

        Args:
            collection_name: Name of collection

        Returns:
            Collection info dict with vector count, etc.
        """
        try:
            info = self.client.get_collection(collection_name)
            return {
                "name": collection_name,
                "vectors_count": getattr(info, 'vectors_count', 0),
                "points_count": getattr(info, 'points_count', 0),
                "status": str(getattr(info, 'status', 'unknown'))
            }
        except Exception as e:
            logger.error(f"Failed to get collection info: {e}")
            return {
                "name": collection_name,
                "error": str(e)
            }


    def health_check(self) -> bool:
        """
        Check if Qdrant is healthy and collections exist.

        Returns:
            True if healthy, False otherwise
        """
        try:
            # Simple check: just try to get collections list
            collections = self.client.get_collections()
            collection_names = [c.name for c in collections.collections]

            chunks_exist = self.chunks_collection in collection_names
            docs_exist = self.documents_collection in collection_names

            if chunks_exist and docs_exist:
                logger.info("Qdrant health check passed")
                return True
            else:
                logger.warning(f"Missing collections. Found: {collection_names}")
                return False
        except Exception as e:
            logger.error(f"Qdrant health check failed: {e}")
            return False
