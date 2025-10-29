"""Pydantic schemas for API request/response validation."""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, EmailStr
from enum import Enum


# Enums
class DocumentTypeEnum(str, Enum):
    """Document type."""
    NORM = "norm"
    GUIDELINE = "guideline"


class DocumentStatusEnum(str, Enum):
    """Document status."""
    UPLOADING = "uploading"
    PROCESSING = "processing"
    EXTRACTING = "extracting"
    ANALYZING = "analyzing"
    EMBEDDING = "embedding"
    READY = "ready"
    ERROR = "error"


class RelationshipTypeEnum(str, Enum):
    """Relationship type."""
    COMPLIANCE = "compliance"
    CONFLICT = "conflict"
    REFERENCE = "reference"
    SIMILAR = "similar"
    SUPERSEDES = "supersedes"


class ValidationStatusEnum(str, Enum):
    """Validation status."""
    AUTO_DETECTED = "auto_detected"
    PENDING_REVIEW = "pending_review"
    APPROVED = "approved"
    REJECTED = "rejected"


# Document Schemas
class DocumentBase(BaseModel):
    """Base document schema."""
    title: str = Field(..., min_length=1, max_length=500)
    document_type: DocumentTypeEnum
    author: Optional[str] = None
    category: Optional[str] = None
    tags: Optional[List[str]] = []
    description: Optional[str] = None
    version: Optional[str] = None


class DocumentCreate(DocumentBase):
    """Schema for creating a document."""
    pass


class DocumentUpdate(BaseModel):
    """Schema for updating a document."""
    title: Optional[str] = Field(None, min_length=1, max_length=500)
    author: Optional[str] = None
    category: Optional[str] = None
    tags: Optional[List[str]] = None
    description: Optional[str] = None
    version: Optional[str] = None


class DocumentChunkResponse(BaseModel):
    """Schema for document chunk response."""
    id: int
    chunk_index: int
    chunk_text: str
    char_count: int
    section_title: Optional[str]
    page_number: Optional[int]

    class Config:
        from_attributes = True


class DocumentResponse(DocumentBase):
    """Schema for document response."""
    id: int
    file_path: str
    file_size: Optional[int]
    file_type: Optional[str]
    status: DocumentStatusEnum
    error_message: Optional[str]
    upload_date: datetime
    processed_date: Optional[datetime]
    updated_at: datetime

    class Config:
        from_attributes = True


class DocumentDetailResponse(DocumentResponse):
    """Detailed document response with chunks."""
    chunks: List[DocumentChunkResponse] = []

    class Config:
        from_attributes = True


class DocumentListResponse(BaseModel):
    """Paginated list of documents."""
    total: int
    page: int
    page_size: int
    documents: List[DocumentResponse]


# Relationship Schemas
class RelationshipBase(BaseModel):
    """Base relationship schema."""
    source_doc_id: int
    target_doc_id: int
    relationship_type: RelationshipTypeEnum
    confidence: float = Field(..., ge=0, le=100)
    summary: Optional[str] = None
    details: Optional[Dict[str, Any]] = None


class RelationshipCreate(RelationshipBase):
    """Schema for creating a relationship."""
    pass


class RelationshipValidate(BaseModel):
    """Schema for validating a relationship."""
    validation_status: ValidationStatusEnum
    validation_notes: Optional[str] = None


class RelationshipResponse(RelationshipBase):
    """Schema for relationship response."""
    id: int
    validation_status: ValidationStatusEnum
    validated_by: Optional[str]
    validation_notes: Optional[str]
    validated_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class RelationshipDetailResponse(RelationshipResponse):
    """Detailed relationship with document info."""
    source_document: DocumentResponse
    target_document: DocumentResponse

    class Config:
        from_attributes = True


# Comparison Schemas
class ComparisonRequest(BaseModel):
    """Schema for document comparison request."""
    document_ids: List[int] = Field(..., min_items=2, max_items=5)
    threshold: float = Field(0.7, ge=0, le=1)


class ComparisonResult(BaseModel):
    """Schema for comparison result."""
    document_id: int
    document_title: str
    document_type: DocumentTypeEnum
    relationships: List[RelationshipResponse]


class ComparisonResponse(BaseModel):
    """Schema for comparison response."""
    results: List[ComparisonResult]
    total_relationships: int


# Search Schemas
class SearchRequest(BaseModel):
    """Schema for semantic search request."""
    query: str = Field(..., min_length=1)
    document_type: Optional[DocumentTypeEnum] = None
    limit: int = Field(10, ge=1, le=100)
    threshold: float = Field(0.5, ge=0, le=1)


class SearchResult(BaseModel):
    """Schema for search result."""
    document_id: int
    document_title: str
    document_type: DocumentTypeEnum
    chunk_id: int
    chunk_text: str
    similarity: float


class SearchResponse(BaseModel):
    """Schema for search response."""
    query: str
    results: List[SearchResult]
    total: int


# Upload Schemas
class UploadProgress(BaseModel):
    """Schema for upload progress."""
    filename: str
    status: str
    progress: float = Field(..., ge=0, le=100)
    message: Optional[str] = None


# User Schemas
class UserBase(BaseModel):
    """Base user schema."""
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=100)
    full_name: Optional[str] = None


class UserCreate(UserBase):
    """Schema for creating a user."""
    password: str = Field(..., min_length=8)


class UserResponse(UserBase):
    """Schema for user response."""
    id: int
    is_active: bool
    is_admin: bool
    is_reviewer: bool
    created_at: datetime
    last_login: Optional[datetime]

    class Config:
        from_attributes = True


# Authentication Schemas
class Token(BaseModel):
    """Schema for authentication token."""
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Schema for token data."""
    email: Optional[str] = None


# Statistics
class Statistics(BaseModel):
    """Schema for dashboard statistics."""
    total_documents: int
    total_norms: int
    total_guidelines: int
    total_relationships: int
    pending_validations: int
    approved_relationships: int
    rejected_relationships: int
