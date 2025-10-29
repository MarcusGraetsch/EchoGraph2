"""Search router for semantic search."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from loguru import logger

from ..database import get_db
from ..models import DocumentChunk, Document, User
from ..schemas import SearchRequest, SearchResponse, SearchResult
from ..auth import get_current_active_user

router = APIRouter()


@router.post("", response_model=SearchResponse)
async def semantic_search(
    search_request: SearchRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Perform semantic search across documents.

    Args:
        search_request: Search request with query and filters
        db: Database session
        current_user: Current authenticated user

    Returns:
        Search results with similar chunks
    """
    # TODO: Implement actual semantic search with embeddings
    # For now, return a simple text search

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

    # Format results
    results = []
    for chunk, document in chunks:
        # TODO: Calculate actual similarity score
        similarity = 0.85  # Placeholder

        results.append(SearchResult(
            document_id=document.id,
            document_title=document.title,
            document_type=document.document_type,
            chunk_id=chunk.id,
            chunk_text=chunk.chunk_text[:500],  # Truncate to 500 chars
            similarity=similarity
        ))

    logger.info(f"Search completed: '{search_request.query}' - {len(results)} results")

    return SearchResponse(
        query=search_request.query,
        results=results,
        total=len(results)
    )
