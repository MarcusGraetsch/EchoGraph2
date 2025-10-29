"""SQLAlchemy database models."""

from datetime import datetime
from typing import Optional
from sqlalchemy import (
    Column, Integer, String, Text, DateTime, Enum,
    Float, ForeignKey, JSON, Boolean, Index
)
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import ARRAY
import enum

from database import Base


class DocumentType(str, enum.Enum):
    """Document type enumeration."""
    NORM = "norm"
    GUIDELINE = "guideline"


class DocumentStatus(str, enum.Enum):
    """Document processing status."""
    UPLOADING = "uploading"
    PROCESSING = "processing"
    EXTRACTING = "extracting"
    ANALYZING = "analyzing"
    EMBEDDING = "embedding"
    READY = "ready"
    ERROR = "error"


class RelationshipType(str, enum.Enum):
    """Document relationship types."""
    COMPLIANCE = "compliance"
    CONFLICT = "conflict"
    REFERENCE = "reference"
    SIMILAR = "similar"
    SUPERSEDES = "supersedes"


class ValidationStatus(str, enum.Enum):
    """Validation status for relationships."""
    AUTO_DETECTED = "auto_detected"
    PENDING_REVIEW = "pending_review"
    APPROVED = "approved"
    REJECTED = "rejected"


class Document(Base):
    """Document model."""
    __tablename__ = "documents"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(500), nullable=False, index=True)
    document_type = Column(Enum(DocumentType), nullable=False, index=True)
    file_path = Column(String(1000), nullable=False)
    file_size = Column(Integer)  # Size in bytes
    file_type = Column(String(50))  # PDF, DOCX, etc.

    # Metadata
    author = Column(String(255))
    category = Column(String(100), index=True)
    tags = Column(ARRAY(String))
    description = Column(Text)
    version = Column(String(50))

    # Status
    status = Column(Enum(DocumentStatus), default=DocumentStatus.UPLOADING, index=True)
    error_message = Column(Text)

    # Timestamps
    upload_date = Column(DateTime, default=datetime.utcnow, index=True)
    processed_date = Column(DateTime)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    chunks = relationship("DocumentChunk", back_populates="document", cascade="all, delete-orphan")
    source_relationships = relationship(
        "DocumentRelationship",
        foreign_keys="DocumentRelationship.source_doc_id",
        back_populates="source_document",
        cascade="all, delete-orphan"
    )
    target_relationships = relationship(
        "DocumentRelationship",
        foreign_keys="DocumentRelationship.target_doc_id",
        back_populates="target_document"
    )

    def __repr__(self):
        return f"<Document(id={self.id}, title='{self.title}', type={self.document_type})>"


class DocumentChunk(Base):
    """Document chunk model for storing text segments with embeddings."""
    __tablename__ = "document_chunks"

    id = Column(Integer, primary_key=True, index=True)
    doc_id = Column(Integer, ForeignKey("documents.id", ondelete="CASCADE"), nullable=False, index=True)
    chunk_index = Column(Integer, nullable=False)
    chunk_text = Column(Text, nullable=False)
    char_count = Column(Integer)

    # Embedding stored as array (use pgvector in production)
    embedding = Column(ARRAY(Float))

    # Metadata
    section_title = Column(String(500))
    section_level = Column(Integer)
    page_number = Column(Integer)

    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    document = relationship("Document", back_populates="chunks")

    # Indexes for efficient querying
    __table_args__ = (
        Index('idx_doc_chunk', 'doc_id', 'chunk_index'),
    )

    def __repr__(self):
        return f"<DocumentChunk(id={self.id}, doc_id={self.doc_id}, index={self.chunk_index})>"


class DocumentRelationship(Base):
    """Relationships between documents."""
    __tablename__ = "document_relationships"

    id = Column(Integer, primary_key=True, index=True)
    source_doc_id = Column(Integer, ForeignKey("documents.id", ondelete="CASCADE"), nullable=False, index=True)
    target_doc_id = Column(Integer, ForeignKey("documents.id", ondelete="CASCADE"), nullable=False, index=True)

    relationship_type = Column(Enum(RelationshipType), nullable=False, index=True)
    confidence = Column(Float, nullable=False)  # 0-100%

    # AI-generated summary
    summary = Column(Text)
    details = Column(JSON)  # Additional structured details

    # Validation
    validation_status = Column(
        Enum(ValidationStatus),
        default=ValidationStatus.AUTO_DETECTED,
        index=True
    )
    validated_by = Column(String(255))  # User who validated
    validation_notes = Column(Text)
    validated_at = Column(DateTime)

    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    source_document = relationship(
        "Document",
        foreign_keys=[source_doc_id],
        back_populates="source_relationships"
    )
    target_document = relationship(
        "Document",
        foreign_keys=[target_doc_id],
        back_populates="target_relationships"
    )

    __table_args__ = (
        Index('idx_relationship_docs', 'source_doc_id', 'target_doc_id'),
        Index('idx_relationship_status', 'validation_status', 'created_at'),
    )

    def __repr__(self):
        return f"<DocumentRelationship(id={self.id}, {self.source_doc_id}->{self.target_doc_id}, type={self.relationship_type})>"


class User(Base):
    """User model for authentication."""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    username = Column(String(100), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255))

    # Roles
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)
    is_reviewer = Column(Boolean, default=False)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login = Column(DateTime)

    def __repr__(self):
        return f"<User(id={self.id}, email='{self.email}')>"
