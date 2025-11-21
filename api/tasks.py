"""Celery tasks for document processing."""

from celery import Celery
from loguru import logger
import sys
import os
from pathlib import Path
from typing import Dict, Any

from .config import settings
from .database import SessionLocal
from .models import (
    Document, DocumentChunk, DocumentStatus,
    DocumentRelationship, DocumentType, RelationshipType, ValidationStatus
)
from ingestion.extractors import DocumentExtractor
from ingestion.storage import StorageClient
from processing.chunking import StructuredChunker
from processing.embeddings import EmbeddingGenerator
from processing.vector_store import VectorStore

# Configure logging
logger.remove()
logger.add(
    sys.stdout,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan> - <level>{message}</level>",
    level=settings.log_level
)

# Initialize Celery app
celery_app = Celery(
    "echograph",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend
)

# Celery configuration
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=3600,  # 1 hour
    task_soft_time_limit=3300,  # 55 minutes
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
)

logger.info("Celery app initialized successfully")
logger.info(f"Broker: {settings.celery_broker_url}")
logger.info(f"Backend: {settings.celery_result_backend}")


@celery_app.task(name="tasks.process_document", bind=True)
def process_document(self, document_id: int):
    """Process a document: extract text, create embeddings, store in vector DB.

    Args:
        document_id: ID of the document to process

    Returns:
        dict: Processing result with status and details
    """
    logger.info(f"[Task {self.request.id}] Processing document {document_id}")
    db = SessionLocal()

    try:
        # Step 1: Get document from database
        document = db.query(Document).filter(Document.id == document_id).first()
        if not document:
            raise ValueError(f"Document {document_id} not found in database")

        logger.info(f"Document found: {document.title} (type: {document.document_type})")

        # Update status to EXTRACTING
        document.status = DocumentStatus.EXTRACTING
        db.commit()

        # Step 2: Download file from MinIO
        storage_client = StorageClient(
            endpoint=settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            bucket=settings.minio_bucket,
            use_ssl=settings.minio_use_ssl
        )

        temp_dir = Path("/tmp/echograph")
        temp_dir.mkdir(exist_ok=True)
        local_file_path = temp_dir / f"{document_id}_{document.title}"

        logger.info(f"Downloading file from MinIO: {document.file_path}")
        success = storage_client.download_file(document.file_path, str(local_file_path))
        if not success:
            raise Exception("Failed to download file from MinIO")

        # Step 3: Extract text from document
        logger.info("Extracting text from document...")
        extractor = DocumentExtractor()
        extraction_result = extractor.extract(str(local_file_path))

        if not extraction_result or not extraction_result.get("text"):
            raise Exception("Text extraction failed or returned empty text")

        extracted_text = extraction_result["text"]
        metadata = extraction_result.get("metadata", {})
        logger.info(f"Extracted {len(extracted_text)} characters from document")

        # Update status to ANALYZING
        document.status = DocumentStatus.ANALYZING
        db.commit()

        # Step 4: Chunk the text
        logger.info("Chunking text...")
        chunker = StructuredChunker(
            chunk_size=settings.chunk_size,
            chunk_overlap=settings.chunk_overlap
        )
        chunks = chunker.chunk_text(extracted_text)
        logger.info(f"Created {len(chunks)} chunks")

        # Update status to EMBEDDING
        document.status = DocumentStatus.EMBEDDING
        db.commit()

        # Step 5: Generate embeddings
        logger.info("Generating embeddings...")
        embedding_gen = EmbeddingGenerator(model_name=settings.embedding_model)
        chunk_texts = [chunk["text"] for chunk in chunks]
        embeddings = embedding_gen.generate_batch(chunk_texts)
        logger.info(f"Generated {len(embeddings)} embeddings")

        # Step 6: Store chunks in PostgreSQL
        logger.info("Storing chunks in PostgreSQL...")
        db_chunks = []
        for i, (chunk, embedding) in enumerate(zip(chunks, embeddings)):
            db_chunk = DocumentChunk(
                document_id=document_id,
                chunk_index=i,
                chunk_text=chunk["text"],
                char_count=len(chunk["text"]),
                section_title=chunk.get("section_title"),
                section_level=chunk.get("section_level"),
                page_number=chunk.get("page_number")
            )
            db.add(db_chunk)
            db_chunks.append(db_chunk)

        db.flush()  # Flush to get chunk IDs
        logger.info(f"Stored {len(db_chunks)} chunks in PostgreSQL")

        # Step 7: Store embeddings in Qdrant
        logger.info("Storing embeddings in Qdrant...")
        vector_store = VectorStore(
            host=settings.qdrant_host,
            port=settings.qdrant_port,
            api_key=settings.qdrant_api_key if settings.qdrant_api_key else None
        )

        # Initialize collections if needed
        vector_store.initialize_collections(vector_size=settings.embedding_dimension)

        # Prepare metadata for Qdrant
        chunk_ids = [chunk.id for chunk in db_chunks]
        chunk_metadata = []
        for chunk, db_chunk in zip(chunks, db_chunks):
            meta = {
                "document_id": document_id,
                "chunk_index": db_chunk.chunk_index,
                "chunk_text": chunk["text"],
                "document_type": document.document_type.value,
                "document_title": document.title,
                "section_title": chunk.get("section_title"),
                "section_level": chunk.get("section_level"),
                "page_number": chunk.get("page_number")
            }
            chunk_metadata.append(meta)

        # Store in Qdrant
        vector_store.store_chunk_embeddings(
            chunk_ids=chunk_ids,
            embeddings=embeddings,
            metadata=chunk_metadata
        )
        logger.info(f"Stored {len(embeddings)} embeddings in Qdrant")

        # Step 8: Update document status to READY
        document.status = DocumentStatus.READY
        db.commit()

        # Cleanup temporary file
        if local_file_path.exists():
            local_file_path.unlink()

        logger.info(f"[Task {self.request.id}] Document {document_id} processed successfully")

        # Optionally trigger relationship extraction
        # Check if there are other documents to compare against
        other_docs_count = db.query(Document).filter(
            Document.id != document_id,
            Document.status == DocumentStatus.READY
        ).count()

        if other_docs_count > 0:
            logger.info(f"Queuing relationship extraction for document {document_id}")
            extract_relationships.delay(document_id)

        return {
            "status": "success",
            "document_id": document_id,
            "chunks_created": len(db_chunks),
            "embeddings_stored": len(embeddings),
            "relationships_queued": other_docs_count > 0,
            "message": "Document processed successfully"
        }

    except Exception as e:
        logger.error(f"[Task {self.request.id}] Error processing document {document_id}: {str(e)}")

        # Update document status to ERROR
        try:
            document = db.query(Document).filter(Document.id == document_id).first()
            if document:
                document.status = DocumentStatus.ERROR
                db.commit()
        except Exception as db_error:
            logger.error(f"Failed to update document status to ERROR: {str(db_error)}")

        return {
            "status": "error",
            "document_id": document_id,
            "error": str(e)
        }
    finally:
        db.close()


@celery_app.task(name="tasks.extract_relationships", bind=True)
def extract_relationships(
    self,
    document_id: int,
    target_doc_ids: list = None,
    threshold: float = 0.75,
    limit_per_chunk: int = 5
):
    """Extract relationships between documents using vector similarity.

    This task finds semantically similar chunks between the source document
    and other documents in the system, then aggregates them into document-level
    relationships.

    Args:
        document_id: ID of the source document to analyze
        target_doc_ids: Optional list of target document IDs to compare against.
                       If None, compares against all other documents.
        threshold: Minimum similarity threshold (0.0 - 1.0)
        limit_per_chunk: Maximum similar chunks to find per source chunk

    Returns:
        dict: Extraction result with status and created relationships
    """
    logger.info(f"[Task {self.request.id}] Extracting relationships for document {document_id}")
    db = SessionLocal()

    try:
        # Step 1: Get source document
        source_doc = db.query(Document).filter(Document.id == document_id).first()
        if not source_doc:
            raise ValueError(f"Document {document_id} not found")

        if source_doc.status != DocumentStatus.READY:
            raise ValueError(f"Document {document_id} is not ready (status: {source_doc.status})")

        logger.info(f"Source document: {source_doc.title} (type: {source_doc.document_type})")

        # Step 2: Initialize vector store
        vector_store = VectorStore(
            host=settings.qdrant_host,
            port=settings.qdrant_port,
            api_key=settings.qdrant_api_key if settings.qdrant_api_key else None
        )

        # Step 3: Find cross-document similarities using vector search
        logger.info(f"Finding similar chunks with threshold {threshold}...")
        similarities = vector_store.find_cross_document_similarities(
            source_doc_id=document_id,
            target_doc_ids=target_doc_ids,
            threshold=threshold,
            limit_per_chunk=limit_per_chunk
        )

        logger.info(f"Found {len(similarities)} chunk-level similarities")

        if not similarities:
            logger.info("No significant similarities found")
            return {
                "status": "success",
                "document_id": document_id,
                "relationships_created": 0,
                "message": "No relationships found above threshold"
            }

        # Step 4: Aggregate chunk similarities to document-level relationships
        doc_similarities = aggregate_document_similarities(similarities, db)
        logger.info(f"Aggregated to {len(doc_similarities)} document-level relationships")

        # Step 5: Determine relationship types and create records
        relationships_created = 0
        for target_doc_id, similarity_data in doc_similarities.items():
            # Skip if relationship already exists
            existing = db.query(DocumentRelationship).filter(
                DocumentRelationship.source_doc_id == document_id,
                DocumentRelationship.target_doc_id == target_doc_id
            ).first()

            if existing:
                logger.info(f"Relationship already exists: {document_id} -> {target_doc_id}")
                continue

            # Get target document info
            target_doc = db.query(Document).filter(Document.id == target_doc_id).first()
            if not target_doc:
                continue

            # Determine relationship type based on document types and similarity
            relationship_type = determine_relationship_type(
                source_doc=source_doc,
                target_doc=target_doc,
                similarity_data=similarity_data
            )

            # Calculate overall confidence score (average of top chunk similarities)
            top_scores = sorted(similarity_data["scores"], reverse=True)[:10]
            confidence = sum(top_scores) / len(top_scores) * 100 if top_scores else 0

            # Create relationship record
            relationship = DocumentRelationship(
                source_doc_id=document_id,
                target_doc_id=target_doc_id,
                relationship_type=relationship_type,
                confidence=round(confidence, 2),
                summary=generate_relationship_summary(
                    source_doc, target_doc, relationship_type, confidence
                ),
                details={
                    "matched_chunks_count": len(similarity_data["chunk_pairs"]),
                    "avg_similarity": round(sum(similarity_data["scores"]) / len(similarity_data["scores"]), 4),
                    "max_similarity": round(max(similarity_data["scores"]), 4),
                    "min_similarity": round(min(similarity_data["scores"]), 4),
                    "matched_sections": list(set(similarity_data.get("sections", []))),
                    "chunk_pairs": similarity_data["chunk_pairs"][:20]  # Store top 20 pairs
                },
                validation_status=ValidationStatus.AUTO_DETECTED
            )
            db.add(relationship)
            relationships_created += 1
            logger.info(f"Created relationship: {source_doc.title} -> {target_doc.title} ({relationship_type.value})")

        db.commit()
        logger.info(f"[Task {self.request.id}] Created {relationships_created} relationships for document {document_id}")

        return {
            "status": "success",
            "document_id": document_id,
            "relationships_created": relationships_created,
            "chunk_similarities_found": len(similarities),
            "message": f"Successfully extracted {relationships_created} relationships"
        }

    except Exception as e:
        logger.error(f"[Task {self.request.id}] Error extracting relationships: {str(e)}")
        db.rollback()
        return {
            "status": "error",
            "document_id": document_id,
            "error": str(e)
        }
    finally:
        db.close()


def aggregate_document_similarities(
    similarities: list,
    db
) -> dict:
    """Aggregate chunk-level similarities to document-level.

    Args:
        similarities: List of tuples (source_chunk_id, target_chunk_id, score, src_payload, tgt_payload)
        db: Database session

    Returns:
        dict: {target_doc_id: {"scores": [...], "chunk_pairs": [...], "sections": [...]}}
    """
    doc_similarities = {}

    for src_chunk_id, tgt_chunk_id, score, src_payload, tgt_payload in similarities:
        target_doc_id = tgt_payload.get("document_id")
        if not target_doc_id:
            continue

        if target_doc_id not in doc_similarities:
            doc_similarities[target_doc_id] = {
                "scores": [],
                "chunk_pairs": [],
                "sections": []
            }

        doc_similarities[target_doc_id]["scores"].append(score)
        doc_similarities[target_doc_id]["chunk_pairs"].append({
            "source_chunk_id": src_chunk_id,
            "target_chunk_id": tgt_chunk_id,
            "similarity": round(score, 4),
            "source_section": src_payload.get("section_title"),
            "target_section": tgt_payload.get("section_title")
        })

        # Track sections for summary
        if src_payload.get("section_title"):
            doc_similarities[target_doc_id]["sections"].append(src_payload["section_title"])
        if tgt_payload.get("section_title"):
            doc_similarities[target_doc_id]["sections"].append(tgt_payload["section_title"])

    return doc_similarities


def determine_relationship_type(
    source_doc: Document,
    target_doc: Document,
    similarity_data: dict
) -> RelationshipType:
    """Determine the type of relationship based on documents and similarity.

    Relationship type logic:
    - norm -> guideline: COMPLIANCE (guideline implements the norm)
    - guideline -> norm: REFERENCE (guideline references the norm)
    - norm -> norm: SIMILAR or SUPERSEDES (based on similarity and version)
    - guideline -> guideline: SIMILAR

    Args:
        source_doc: Source document
        target_doc: Target document
        similarity_data: Aggregated similarity data

    Returns:
        RelationshipType enum value
    """
    source_type = source_doc.document_type
    target_type = target_doc.document_type
    avg_similarity = sum(similarity_data["scores"]) / len(similarity_data["scores"])

    # Norm -> Guideline: typically a compliance relationship
    if source_type == DocumentType.NORM and target_type == DocumentType.GUIDELINE:
        return RelationshipType.COMPLIANCE

    # Guideline -> Norm: typically a reference relationship
    if source_type == DocumentType.GUIDELINE and target_type == DocumentType.NORM:
        return RelationshipType.REFERENCE

    # Norm -> Norm: check for supersedes or similar
    if source_type == DocumentType.NORM and target_type == DocumentType.NORM:
        # High similarity might indicate one supersedes the other
        if avg_similarity > 0.90:
            # If versions exist and are different, might be supersedes
            if source_doc.version and target_doc.version:
                if source_doc.version > target_doc.version:
                    return RelationshipType.SUPERSEDES
            return RelationshipType.SIMILAR
        return RelationshipType.SIMILAR

    # Default to similar for same-type documents
    return RelationshipType.SIMILAR


def generate_relationship_summary(
    source_doc: Document,
    target_doc: Document,
    relationship_type: RelationshipType,
    confidence: float
) -> str:
    """Generate a human-readable summary of the relationship.

    Args:
        source_doc: Source document
        target_doc: Target document
        relationship_type: Type of relationship
        confidence: Confidence score (0-100)

    Returns:
        Summary string
    """
    type_descriptions = {
        RelationshipType.COMPLIANCE: f"'{target_doc.title}' appears to implement or comply with requirements from '{source_doc.title}'",
        RelationshipType.CONFLICT: f"'{source_doc.title}' may contain conflicting requirements with '{target_doc.title}'",
        RelationshipType.REFERENCE: f"'{source_doc.title}' references or is related to '{target_doc.title}'",
        RelationshipType.SIMILAR: f"'{source_doc.title}' shares similar content with '{target_doc.title}'",
        RelationshipType.SUPERSEDES: f"'{source_doc.title}' appears to supersede '{target_doc.title}'"
    }

    summary = type_descriptions.get(
        relationship_type,
        f"'{source_doc.title}' is related to '{target_doc.title}'"
    )

    return f"{summary} (confidence: {confidence:.1f}%)"


@celery_app.task(name="tasks.health_check")
def health_check():
    """Health check task to verify Celery worker is running.

    Returns:
        dict: Health status
    """
    logger.info("Health check task executed")
    return {
        "status": "healthy",
        "message": "Celery worker is running"
    }


# Make celery_app the main Celery application for worker discovery
app = celery_app
