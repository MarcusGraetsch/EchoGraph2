"""Relationships router."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from datetime import datetime
from loguru import logger

from ..database import get_db
from ..models import DocumentRelationship, Document, ValidationStatus, User
from ..schemas import (
    RelationshipResponse,
    RelationshipDetailResponse,
    RelationshipCreate,
    RelationshipValidate,
    ComparisonRequest,
    ComparisonResponse,
    ComparisonResult
)
from ..keycloak_auth import get_current_active_user, get_current_reviewer, KeycloakUser

router = APIRouter()


@router.post("", response_model=RelationshipResponse, status_code=status.HTTP_201_CREATED)
async def create_relationship(
    relationship_data: RelationshipCreate,
    db: Session = Depends(get_db),
    current_user: KeycloakUser = Depends(get_current_active_user)
):
    """Create a new document relationship.

    Args:
        relationship_data: Relationship data
        db: Database session
        current_user: Current authenticated user

    Returns:
        Created relationship

    Raises:
        HTTPException: If documents not found
    """
    # Verify documents exist
    source_doc = db.query(Document).filter(Document.id == relationship_data.source_doc_id).first()
    target_doc = db.query(Document).filter(Document.id == relationship_data.target_doc_id).first()

    if not source_doc or not target_doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="One or more documents not found"
        )

    # Create relationship
    relationship = DocumentRelationship(
        source_doc_id=relationship_data.source_doc_id,
        target_doc_id=relationship_data.target_doc_id,
        relationship_type=relationship_data.relationship_type,
        confidence=relationship_data.confidence,
        summary=relationship_data.summary,
        details=relationship_data.details
    )

    db.add(relationship)
    db.commit()
    db.refresh(relationship)

    logger.info(f"Relationship created: {relationship.id}")

    return relationship


@router.get("/{relationship_id}", response_model=RelationshipDetailResponse)
async def get_relationship(
    relationship_id: int,
    db: Session = Depends(get_db),
    current_user: KeycloakUser = Depends(get_current_active_user)
):
    """Get relationship by ID.

    Args:
        relationship_id: Relationship ID
        db: Database session
        current_user: Current authenticated user

    Returns:
        Relationship details

    Raises:
        HTTPException: If relationship not found
    """
    relationship = db.query(DocumentRelationship).filter(
        DocumentRelationship.id == relationship_id
    ).first()

    if not relationship:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Relationship not found"
        )

    return relationship


@router.get("/document/{document_id}", response_model=List[RelationshipDetailResponse])
async def get_document_relationships(
    document_id: int,
    validation_status: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: KeycloakUser = Depends(get_current_active_user)
):
    """Get all relationships for a document.

    Args:
        document_id: Document ID
        validation_status: Filter by validation status
        db: Database session
        current_user: Current authenticated user

    Returns:
        List of relationships
    """
    # Verify document exists
    document = db.query(Document).filter(Document.id == document_id).first()
    if not document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document not found"
        )

    # Query relationships where document is source or target
    query = db.query(DocumentRelationship).filter(
        (DocumentRelationship.source_doc_id == document_id) |
        (DocumentRelationship.target_doc_id == document_id)
    )

    if validation_status:
        query = query.filter(DocumentRelationship.validation_status == validation_status)

    relationships = query.all()

    return relationships


@router.post("/{relationship_id}/validate", response_model=RelationshipResponse)
async def validate_relationship(
    relationship_id: int,
    validation_data: RelationshipValidate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_reviewer)
):
    """Validate a relationship (reviewer only).

    Args:
        relationship_id: Relationship ID
        validation_data: Validation data
        db: Database session
        current_user: Current authenticated user (must be reviewer)

    Returns:
        Updated relationship

    Raises:
        HTTPException: If relationship not found
    """
    relationship = db.query(DocumentRelationship).filter(
        DocumentRelationship.id == relationship_id
    ).first()

    if not relationship:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Relationship not found"
        )

    # Update validation
    relationship.validation_status = validation_data.validation_status
    relationship.validation_notes = validation_data.validation_notes
    relationship.validated_by = current_user.email
    relationship.validated_at = datetime.utcnow()

    db.commit()
    db.refresh(relationship)

    logger.info(f"Relationship validated: {relationship.id} - {validation_data.validation_status}")

    return relationship


@router.get("/pending/review", response_model=List[RelationshipDetailResponse])
async def get_pending_relationships(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_reviewer)
):
    """Get pending relationships for review (reviewer only).

    Args:
        limit: Maximum number of results
        db: Database session
        current_user: Current authenticated user (must be reviewer)

    Returns:
        List of pending relationships
    """
    relationships = db.query(DocumentRelationship).filter(
        DocumentRelationship.validation_status.in_([
            ValidationStatus.AUTO_DETECTED,
            ValidationStatus.PENDING_REVIEW
        ])
    ).order_by(DocumentRelationship.created_at.desc()).limit(limit).all()

    return relationships


@router.post("/compare", response_model=ComparisonResponse)
async def compare_documents(
    comparison_request: ComparisonRequest,
    db: Session = Depends(get_db),
    current_user: KeycloakUser = Depends(get_current_active_user)
):
    """Compare multiple documents.

    Args:
        comparison_request: Comparison request with document IDs
        db: Database session
        current_user: Current authenticated user

    Returns:
        Comparison results with relationships

    Raises:
        HTTPException: If documents not found
    """
    # Verify all documents exist
    documents = db.query(Document).filter(
        Document.id.in_(comparison_request.document_ids)
    ).all()

    if len(documents) != len(comparison_request.document_ids):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="One or more documents not found"
        )

    # Find relationships between these documents
    results = []
    total_relationships = 0

    for doc in documents:
        # Get relationships where this document is involved
        relationships = db.query(DocumentRelationship).filter(
            (
                (DocumentRelationship.source_doc_id == doc.id) |
                (DocumentRelationship.target_doc_id == doc.id)
            ) &
            (
                (DocumentRelationship.source_doc_id.in_(comparison_request.document_ids)) &
                (DocumentRelationship.target_doc_id.in_(comparison_request.document_ids))
            ) &
            (DocumentRelationship.confidence >= comparison_request.threshold * 100)
        ).all()

        if relationships:
            results.append(ComparisonResult(
                document_id=doc.id,
                document_title=doc.title,
                document_type=doc.document_type,
                relationships=relationships
            ))
            total_relationships += len(relationships)

    return ComparisonResponse(
        results=results,
        total_relationships=total_relationships
    )


@router.delete("/{relationship_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_relationship(
    relationship_id: int,
    db: Session = Depends(get_db),
    current_user: KeycloakUser = Depends(get_current_active_user)
):
    """Delete a relationship.

    Args:
        relationship_id: Relationship ID
        db: Database session
        current_user: Current authenticated user

    Raises:
        HTTPException: If relationship not found
    """
    relationship = db.query(DocumentRelationship).filter(
        DocumentRelationship.id == relationship_id
    ).first()

    if not relationship:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Relationship not found"
        )

    db.delete(relationship)
    db.commit()

    logger.info(f"Relationship deleted: {relationship_id}")

    return None
