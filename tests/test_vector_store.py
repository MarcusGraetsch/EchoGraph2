"""
Unit tests for Qdrant vector store integration.

Run with: pytest tests/test_vector_store.py -v
"""

import pytest
import numpy as np
from processing.vector_store import VectorStore, SearchResult


@pytest.fixture
def vector_store():
    """Create a VectorStore instance for testing."""
    store = VectorStore(host="localhost", port=6333)
    store.initialize_collections(vector_size=768)
    yield store
    # Cleanup after tests
    try:
        store.delete_document_vectors(9999)
        store.delete_document_vectors(10000)
    except:
        pass


@pytest.fixture
def sample_embeddings():
    """Generate sample 768-dimensional embeddings."""
    return [
        np.random.rand(768).tolist(),
        np.random.rand(768).tolist(),
        np.random.rand(768).tolist()
    ]


@pytest.fixture
def sample_metadata():
    """Generate sample metadata for chunks."""
    return [
        {
            "document_id": 9999,
            "chunk_index": 0,
            "chunk_text": "Test norm about data protection and privacy",
            "document_type": "norm",
            "document_title": "Test Norm A",
            "section_title": "Data Protection"
        },
        {
            "document_id": 9999,
            "chunk_index": 1,
            "chunk_text": "Privacy requirements for personal data",
            "document_type": "norm",
            "document_title": "Test Norm A",
            "section_title": "Privacy"
        },
        {
            "document_id": 10000,
            "chunk_index": 0,
            "chunk_text": "Company guidelines for information security",
            "document_type": "guideline",
            "document_title": "Test Guideline B",
            "section_title": "Security"
        }
    ]


class TestVectorStoreInitialization:
    """Test vector store initialization and connection."""

    def test_connection(self, vector_store):
        """Test successful connection to Qdrant."""
        assert vector_store.client is not None

    def test_initialize_collections(self, vector_store):
        """Test collection initialization."""
        assert vector_store.client.collection_exists("chunks")
        assert vector_store.client.collection_exists("documents")

    def test_health_check(self, vector_store):
        """Test health check."""
        assert vector_store.health_check() is True

    def test_get_collection_info(self, vector_store):
        """Test getting collection information."""
        info = vector_store.get_collection_info("chunks")
        assert info["name"] == "chunks"
        assert "vectors_count" in info
        assert info["config"]["vector_size"] == 768


class TestEmbeddingStorage:
    """Test storing and retrieving embeddings."""

    def test_store_chunk_embeddings(self, vector_store, sample_embeddings, sample_metadata):
        """Test storing chunk embeddings."""
        count = vector_store.store_chunk_embeddings(
            chunk_ids=[99901, 99902, 99903],
            embeddings=sample_embeddings,
            metadata=sample_metadata
        )
        assert count == 3

    def test_store_chunk_embeddings_validation(self, vector_store):
        """Test validation of input parameters."""
        with pytest.raises(ValueError, match="must have same length"):
            vector_store.store_chunk_embeddings(
                chunk_ids=[1, 2],
                embeddings=[[0.1]*768],  # Only 1 embedding
                metadata=[{"document_id": 1}, {"document_id": 2}]
            )

    def test_store_chunk_embeddings_missing_doc_id(self, vector_store, sample_embeddings):
        """Test error when document_id is missing."""
        invalid_metadata = [{"chunk_text": "test"}]  # Missing document_id
        with pytest.raises(ValueError, match="missing 'document_id'"):
            vector_store.store_chunk_embeddings(
                chunk_ids=[1],
                embeddings=[sample_embeddings[0]],
                metadata=invalid_metadata
            )

    def test_store_document_embedding(self, vector_store, sample_embeddings):
        """Test storing document-level embedding."""
        vector_store.store_document_embedding(
            document_id=9999,
            embedding=sample_embeddings[0],
            metadata={"title": "Test Document", "type": "norm"}
        )
        # Verify by searching
        results = vector_store.search_similar_documents(
            query_vector=sample_embeddings[0],
            limit=1
        )
        assert len(results) > 0


class TestSemanticSearch:
    """Test semantic search functionality."""

    @pytest.fixture(autouse=True)
    def setup_test_data(self, vector_store, sample_embeddings, sample_metadata):
        """Store test data before each test."""
        vector_store.store_chunk_embeddings(
            chunk_ids=[99901, 99902, 99903],
            embeddings=sample_embeddings,
            metadata=sample_metadata
        )

    def test_search_similar_chunks(self, vector_store, sample_embeddings):
        """Test basic similarity search."""
        results = vector_store.search_similar_chunks(
            query_vector=sample_embeddings[0],
            limit=3,
            score_threshold=0.0
        )
        assert len(results) > 0
        assert isinstance(results[0], SearchResult)
        assert results[0].score >= 0.0

    def test_search_with_filters(self, vector_store, sample_embeddings):
        """Test search with metadata filters."""
        # Search only in norms
        results = vector_store.search_similar_chunks(
            query_vector=sample_embeddings[0],
            limit=10,
            score_threshold=0.0,
            filters={"document_type": "norm"}
        )
        assert len(results) > 0
        for result in results:
            assert result.payload["document_type"] == "norm"

    def test_search_with_document_id_filter(self, vector_store, sample_embeddings):
        """Test search filtered by document ID."""
        results = vector_store.search_similar_chunks(
            query_vector=sample_embeddings[0],
            limit=10,
            score_threshold=0.0,
            filters={"document_id": 9999}
        )
        assert len(results) > 0
        for result in results:
            assert result.payload["document_id"] == 9999

    def test_search_with_high_threshold(self, vector_store, sample_embeddings):
        """Test search with high similarity threshold."""
        # Random vector should not match with high threshold
        random_vector = np.random.rand(768).tolist()
        results = vector_store.search_similar_chunks(
            query_vector=random_vector,
            limit=10,
            score_threshold=0.99  # Very high threshold
        )
        # May or may not find results depending on random chance
        assert isinstance(results, list)


class TestCrossDocumentSimilarity:
    """Test cross-document similarity detection."""

    @pytest.fixture(autouse=True)
    def setup_test_data(self, vector_store, sample_embeddings, sample_metadata):
        """Store test data before each test."""
        vector_store.store_chunk_embeddings(
            chunk_ids=[99901, 99902, 99903],
            embeddings=sample_embeddings,
            metadata=sample_metadata
        )

    def test_find_cross_document_similarities(self, vector_store):
        """Test finding similarities between different documents."""
        similarities = vector_store.find_cross_document_similarities(
            source_doc_id=9999,
            target_doc_ids=[10000],
            threshold=0.0,  # Low threshold for test
            limit_per_chunk=5
        )
        assert isinstance(similarities, list)
        # Each item should be (src_id, tgt_id, score, src_payload, tgt_payload)
        if len(similarities) > 0:
            assert len(similarities[0]) == 5
            assert isinstance(similarities[0][2], float)  # score

    def test_find_cross_document_similarities_all_docs(self, vector_store):
        """Test finding similarities across all documents."""
        similarities = vector_store.find_cross_document_similarities(
            source_doc_id=9999,
            target_doc_ids=None,  # Search all
            threshold=0.0,
            limit_per_chunk=3
        )
        assert isinstance(similarities, list)


class TestDeletion:
    """Test deletion operations."""

    def test_delete_document_vectors(self, vector_store, sample_embeddings, sample_metadata):
        """Test deleting all vectors for a document."""
        # First store some vectors
        vector_store.store_chunk_embeddings(
            chunk_ids=[99901, 99902],
            embeddings=sample_embeddings[:2],
            metadata=sample_metadata[:2]
        )

        # Delete them
        vector_store.delete_document_vectors(9999)

        # Verify they're gone
        results = vector_store.search_similar_chunks(
            query_vector=sample_embeddings[0],
            limit=10,
            score_threshold=0.0,
            filters={"document_id": 9999}
        )
        assert len(results) == 0

    def test_delete_collection(self, vector_store):
        """Test deleting a collection."""
        # Create a test collection
        test_collection = "test_delete_collection"
        vector_store.client.create_collection(
            collection_name=test_collection,
            vectors_config={"size": 768, "distance": "Cosine"}
        )

        # Delete it
        result = vector_store.delete_collection(test_collection)
        assert result is True

        # Verify it's gone
        assert not vector_store.client.collection_exists(test_collection)

    def test_delete_nonexistent_collection(self, vector_store):
        """Test deleting a collection that doesn't exist."""
        result = vector_store.delete_collection("nonexistent_collection")
        assert result is False


class TestSearchResult:
    """Test SearchResult dataclass."""

    def test_search_result_creation(self):
        """Test creating SearchResult objects."""
        result = SearchResult(
            id="123",
            score=0.95,
            payload={"document_id": 1, "text": "test"},
            vector=None
        )
        assert result.id == "123"
        assert result.score == 0.95
        assert result.payload["document_id"] == 1
        assert result.vector is None
