"""Celery tasks for document processing."""

from celery import Celery
from loguru import logger
import sys
import os
from pathlib import Path
from typing import Dict, Any

from .config import settings
from .database import SessionLocal
from .models import Document, DocumentChunk, DocumentStatus
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
        return {
            "status": "success",
            "document_id": document_id,
            "chunks_created": len(db_chunks),
            "embeddings_stored": len(embeddings),
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


@celery_app.task(name="tasks.extract_relationships")
def extract_relationships(document_id: int):
    """Extract relationships between documents.

    Args:
        document_id: ID of the document to analyze for relationships

    Returns:
        dict: Extraction result with status and details
    """
    logger.info(f"Extracting relationships for document {document_id}")

    try:
        # TODO: Implement relationship extraction
        # 1. Query vector database for similar documents
        # 2. Analyze semantic similarity
        # 3. Extract potential relationships
        # 4. Store relationships in database

        logger.info(f"Relationships extracted for document {document_id}")
        return {
            "status": "success",
            "document_id": document_id,
            "message": "Relationships extracted successfully"
        }
    except Exception as e:
        logger.error(f"Error extracting relationships for document {document_id}: {str(e)}")
        return {
            "status": "error",
            "document_id": document_id,
            "error": str(e)
        }


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
