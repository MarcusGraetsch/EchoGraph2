"""Documents router."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_
from datetime import datetime
import os
import uuid
import sys
from pathlib import Path
from loguru import logger

from ingestion.storage import StorageClient
from ..database import get_db
from ..models import Document, DocumentType, DocumentStatus, User
from ..schemas import (
    DocumentResponse,
    DocumentCreate,
    DocumentUpdate,
    DocumentListResponse,
    DocumentDetailResponse,
    Statistics
)
from ..keycloak_auth import get_current_active_user, KeycloakUser
from ..config import settings

router = APIRouter()

# Initialize storage client
storage_client = StorageClient()


@router.post("/upload", response_model=DocumentResponse, status_code=status.HTTP_201_CREATED)
async def upload_document(
    file: UploadFile = File(...),
    title: str = Form(...),
    document_type: str = Form(...),
    author: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    version: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: KeycloakUser = Depends(get_current_active_user)
):
    """Upload a new document.

    Args:
        file: Document file
        title: Document title
        document_type: Type of document (norm or guideline)
        author: Document author
        category: Document category
        description: Document description
        version: Document version
        db: Database session

    Returns:
        Created document

    Raises:
        HTTPException: If file type not supported or upload fails
    """
    # Validate file type
    file_extension = os.path.splitext(file.filename)[1].lower()
    if file_extension not in [".pdf", ".docx", ".doc"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported file type. Only PDF and DOCX are supported."
        )

    # Validate document type
    try:
        doc_type = DocumentType(document_type.lower())
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid document type. Must be 'norm' or 'guideline'."
        )

    # Generate unique filename
    file_id = str(uuid.uuid4())
    filename = f"{file_id}{file_extension}"
    file_path = os.path.join(settings.minio_bucket, filename)

    # Create document record with UPLOADING status
    document = Document(
        title=title,
        document_type=doc_type,
        file_path=file_path,
        file_type=file_extension[1:],  # Remove dot
        author=author,
        category=category,
        description=description,
        version=version,
        status=DocumentStatus.UPLOADING
    )

    db.add(document)
    db.commit()
    db.refresh(document)

    try:
        # Upload file to MinIO
        logger.info(f"Uploading file {filename} to MinIO...")

        # Read file content
        file_content = await file.read()
        file_size = len(file_content)

        # Reset file pointer for storage client
        from io import BytesIO
        file_stream = BytesIO(file_content)

        # Upload to MinIO
        object_name = storage_client.upload_fileobj(
            file_stream,
            filename,
            file_size,
            content_type=file.content_type
        )

        if object_name is None:
            # Upload failed
            document.status = DocumentStatus.FAILED
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to upload file to storage"
            )

        # Update document status to PROCESSING
        document.status = DocumentStatus.PROCESSING
        db.commit()

        logger.info(f"Document uploaded successfully: {document.id} - {document.title}")

        # Trigger Celery task for document processing
        from ..tasks import process_document
        process_document.delay(document.id)
        logger.info(f"Queued processing task for document {document.id}")

    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        # Handle any other errors
        logger.error(f"Error uploading document {document.id}: {str(e)}")
        document.status = DocumentStatus.FAILED
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload document: {str(e)}"
        )

    return document


@router.get("", response_model=DocumentListResponse)
async def list_documents(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    document_type: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: KeycloakUser = Depends(get_current_active_user)
):
    """List documents with pagination and filters.

    Args:
        page: Page number
        page_size: Number of items per page
        document_type: Filter by document type
        category: Filter by category
        status: Filter by status
        search: Search in title, author, description
        db: Database session

    Returns:
        Paginated list of documents
    """
    query = db.query(Document)

    # Apply filters
    if document_type:
        query = query.filter(Document.document_type == document_type)

    if category:
        query = query.filter(Document.category == category)

    if status:
        query = query.filter(Document.status == status)

    if search:
        search_filter = f"%{search}%"
        query = query.filter(
            or_(
                Document.title.ilike(search_filter),
                Document.author.ilike(search_filter),
                Document.description.ilike(search_filter)
            )
        )

    # Get total count
    total = query.count()

    # Paginate
    offset = (page - 1) * page_size
    documents = query.order_by(Document.upload_date.desc()).offset(offset).limit(page_size).all()

    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "documents": documents
    }


@router.get("/{document_id}", response_model=DocumentDetailResponse)
async def get_document(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: KeycloakUser = Depends(get_current_active_user)
):
    """Get document by ID.

    Args:
        document_id: Document ID
        db: Database session

    Returns:
        Document details

    Raises:
        HTTPException: If document not found
    """
    document = db.query(Document).filter(Document.id == document_id).first()

    if not document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document not found"
        )

    return document


@router.put("/{document_id}", response_model=DocumentResponse)
async def update_document(
    document_id: int,
    document_update: DocumentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update document metadata.

    Args:
        document_id: Document ID
        document_update: Updated document data
        db: Database session
        current_user: Current authenticated user

    Returns:
        Updated document

    Raises:
        HTTPException: If document not found
    """
    document = db.query(Document).filter(Document.id == document_id).first()

    if not document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document not found"
        )

    # Update fields
    update_data = document_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(document, field, value)

    document.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(document)

    logger.info(f"Document updated: {document.id} - {document.title}")

    return document


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Delete a document.

    Args:
        document_id: Document ID
        db: Database session
        current_user: Current authenticated user

    Raises:
        HTTPException: If document not found
    """
    document = db.query(Document).filter(Document.id == document_id).first()

    if not document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document not found"
        )

    # Delete file from MinIO
    try:
        # Extract filename from file_path
        filename = os.path.basename(document.file_path)

        logger.info(f"Deleting file {filename} from MinIO...")
        success = storage_client.delete_file(filename)

        if not success:
            logger.warning(f"Failed to delete file {filename} from MinIO, but continuing with DB deletion")
    except Exception as e:
        logger.error(f"Error deleting file from MinIO: {str(e)}")
        # Continue with DB deletion even if MinIO deletion fails

    # Delete from database
    db.delete(document)
    db.commit()

    logger.info(f"Document deleted: {document_id}")

    return None


@router.get("/statistics/dashboard", response_model=Statistics)
async def get_statistics(
    db: Session = Depends(get_db)
    # Temporarily disabled auth for testing
    # current_user: User = Depends(get_current_active_user)
):
    """Get dashboard statistics.

    Args:
        db: Database session
        current_user: Current authenticated user

    Returns:
        Statistics
    """
    from ..models import DocumentRelationship, ValidationStatus

    total_documents = db.query(Document).count()
    total_norms = db.query(Document).filter(Document.document_type == DocumentType.NORM).count()
    total_guidelines = db.query(Document).filter(Document.document_type == DocumentType.GUIDELINE).count()

    total_relationships = db.query(DocumentRelationship).count()
    pending_validations = db.query(DocumentRelationship).filter(
        DocumentRelationship.validation_status == ValidationStatus.PENDING_REVIEW
    ).count()
    approved_relationships = db.query(DocumentRelationship).filter(
        DocumentRelationship.validation_status == ValidationStatus.APPROVED
    ).count()
    rejected_relationships = db.query(DocumentRelationship).filter(
        DocumentRelationship.validation_status == ValidationStatus.REJECTED
    ).count()

    return {
        "total_documents": total_documents,
        "total_norms": total_norms,
        "total_guidelines": total_guidelines,
        "total_relationships": total_relationships,
        "pending_validations": pending_validations,
        "approved_relationships": approved_relationships,
        "rejected_relationships": rejected_relationships
    }
