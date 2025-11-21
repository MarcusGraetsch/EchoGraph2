"""Search router for semantic search using Qdrant vector database."""

from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from loguru import logger

from ..database import get_db
from ..models import DocumentChunk, Document, User
from ..schemas import SearchRequest, SearchResponse, SearchResult, DocumentTypeEnum
from ..keycloak_auth import get_current_active_user, KeycloakUser
from ..config import settings

from processing.embeddings import EmbeddingGenerator
from processing.vector_store import VectorStore

router = APIRouter()

# Lazy-loaded singleton instances to avoid loading models on import
_embedding_generator: Optional[EmbeddingGenerator] = None
_vector_store: Optional[VectorStore] = None


def get_embedding_generator() -> EmbeddingGenerator:
    """Get or create the embedding generator singleton."""
    global _embedding_generator
    if _embedding_generator is None:
        logger.info("Initializing embedding generator for search...")
        _embedding_generator = EmbeddingGenerator()
    return _embedding_generator


def get_vector_store() -> VectorStore:
    """Get or create the vector store singleton."""
    global _vector_store
    if _vector_store is None:
        logger.info("Connecting to Qdrant vector store for search...")
        _vector_store = VectorStore(
            host=settings.qdrant_host,
            port=settings.qdrant_port,
            api_key=settings.qdrant_api_key if settings.qdrant_api_key else None
        )
    return _vector_store


@router.post("", response_model=SearchResponse)
async def semantic_search(
    search_request: SearchRequest,
    db: Session = Depends(get_db),
    current_user: KeycloakUser = Depends(get_current_active_user)
):
    """Perform semantic search across documents using vector similarity.

    This endpoint generates an embedding for the search query and finds
    semantically similar document chunks using Qdrant vector database.

    Args:
        search_request: Search request with query, filters, and threshold
        db: Database session
        current_user: Current authenticated user

    Returns:
        Search results with similar chunks ranked by similarity score
    """
    try:
        # Get singleton instances
        embedding_generator = get_embedding_generator()
        vector_store = get_vector_store()

        # Generate embedding for the search query
        logger.info(f"Generating embedding for query: '{search_request.query}'")
        query_embedding = embedding_generator.generate_embedding(search_request.query)

        # Build filters for Qdrant search
        qdrant_filters = {}
        if search_request.document_type:
            qdrant_filters["document_type"] = search_request.document_type.value

        # Search for similar chunks in Qdrant
        logger.info(f"Searching Qdrant with threshold: {search_request.threshold}")
        search_results = vector_store.search_similar_chunks(
            query_vector=query_embedding.tolist(),
            limit=search_request.limit,
            score_threshold=search_request.threshold,
            filters=qdrant_filters if qdrant_filters else None
        )

        # Map Qdrant results to response format
        results = []
        seen_chunks = set()  # Avoid duplicate chunks

        for result in search_results:
            chunk_id = int(result.id)

            # Skip duplicates
            if chunk_id in seen_chunks:
                continue
            seen_chunks.add(chunk_id)

            # Get document info from payload or fetch from DB
            payload = result.payload
            document_id = payload.get("document_id")
            document_title = payload.get("document_title", "Unknown")
            document_type = payload.get("document_type", "norm")
            chunk_text = payload.get("chunk_text", "")

            # If payload is incomplete, fetch from database
            if not document_title or document_title == "Unknown":
                chunk = db.query(DocumentChunk).filter(
                    DocumentChunk.id == chunk_id
                ).first()

                if chunk:
                    document = db.query(Document).filter(
                        Document.id == chunk.doc_id
                    ).first()

                    if document:
                        document_id = document.id
                        document_title = document.title
                        document_type = document.document_type.value
                        chunk_text = chunk.chunk_text

            # Skip if we couldn't find the document
            if not document_id:
                logger.warning(f"Could not find document for chunk {chunk_id}")
                continue

            results.append(SearchResult(
                document_id=document_id,
                document_title=document_title,
                document_type=DocumentTypeEnum(document_type),
                chunk_id=chunk_id,
                chunk_text=chunk_text[:500] if chunk_text else "",  # Truncate to 500 chars
                similarity=round(result.score, 4)
            ))

        logger.info(f"Semantic search completed: '{search_request.query}' - {len(results)} results")

        return SearchResponse(
            query=search_request.query,
            results=results,
            total=len(results)
        )

    except Exception as e:
        logger.error(f"Semantic search failed: {str(e)}")
        # Fall back to text-based search if vector search fails
        return await fallback_text_search(search_request, db)


async def fallback_text_search(
    search_request: SearchRequest,
    db: Session
) -> SearchResponse:
    """Fallback to text-based search when vector search is unavailable.

    Args:
        search_request: Search request
        db: Database session

    Returns:
        Text-based search results
    """
    logger.warning("Falling back to text-based search")

    query_filter = f"%{search_request.query}%"

    # Query chunks that match the text
    chunks_query = db.query(DocumentChunk, Document).join(
        Document, DocumentChunk.doc_id == Document.id
    ).filter(
        DocumentChunk.chunk_text.ilike(query_filter)
    )

    # Apply document type filter if specified
    if search_request.document_type:
        chunks_query = chunks_query.filter(
            Document.document_type == search_request.document_type
        )

    chunks = chunks_query.limit(search_request.limit).all()

    # Format results with placeholder similarity
    results = []
    for chunk, document in chunks:
        results.append(SearchResult(
            document_id=document.id,
            document_title=document.title,
            document_type=document.document_type,
            chunk_id=chunk.id,
            chunk_text=chunk.chunk_text[:500],
            similarity=0.5  # Placeholder for text search
        ))

    logger.info(f"Fallback search completed: '{search_request.query}' - {len(results)} results")

    return SearchResponse(
        query=search_request.query,
        results=results,
        total=len(results)
    )


@router.get("/health")
async def search_health_check():
    """Check health of search subsystem (embedding model and vector store).

    Returns:
        Health status of embedding generator and Qdrant connection
    """
    health_status = {
        "embedding_generator": "unknown",
        "vector_store": "unknown",
        "overall": "unhealthy"
    }

    try:
        # Check embedding generator
        embedding_generator = get_embedding_generator()
        test_embedding = embedding_generator.generate_embedding("health check")
        if test_embedding is not None and len(test_embedding) > 0:
            health_status["embedding_generator"] = "healthy"
            health_status["embedding_dimension"] = len(test_embedding)
    except Exception as e:
        health_status["embedding_generator"] = f"unhealthy: {str(e)}"

    try:
        # Check vector store connection
        vector_store = get_vector_store()
        if vector_store.health_check():
            health_status["vector_store"] = "healthy"

            # Get collection info
            chunks_info = vector_store.get_collection_info("chunks")
            health_status["chunks_collection"] = chunks_info
        else:
            health_status["vector_store"] = "unhealthy: collections not found"
    except Exception as e:
        health_status["vector_store"] = f"unhealthy: {str(e)}"

    # Overall status
    if (health_status["embedding_generator"] == "healthy" and
        health_status["vector_store"] == "healthy"):
        health_status["overall"] = "healthy"

    return health_status
