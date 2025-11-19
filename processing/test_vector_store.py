"""
Simple test script for Qdrant vector store.

Run this to verify Qdrant integration works:
    python processing/test_vector_store.py
"""

from vector_store import VectorStore
import numpy as np


def main():
    print("🔍 Testing Qdrant Vector Store Integration\n")

    # Initialize vector store
    print("1. Connecting to Qdrant...")
    store = VectorStore(host="localhost", port=6333)
    print("   ✅ Connected!")

    # Initialize collections
    print("\n2. Initializing collections (768-dim vectors)...")
    store.initialize_collections(vector_size=768)
    print("   ✅ Collections initialized!")

    # Health check
    print("\n3. Running health check...")
    healthy = store.health_check()
    if healthy:
        print("   ✅ Qdrant is healthy!")
    else:
        print("   ❌ Qdrant health check failed!")
        return

    # Get collection info
    print("\n4. Getting collection info...")
    chunks_info = store.get_collection_info("chunks")
    print(f"   Chunks collection:")
    print(f"     - Vectors: {chunks_info['vectors_count']}")
    print(f"     - Points: {chunks_info['points_count']}")
    print(f"     - Vector size: {chunks_info['config']['vector_size']}")
    print(f"     - Distance: {chunks_info['config']['distance']}")

    # Test storing embeddings
    print("\n5. Testing embedding storage...")
    # Create dummy embeddings (768-dimensional)
    test_embeddings = [
        np.random.rand(768).tolist(),
        np.random.rand(768).tolist(),
        np.random.rand(768).tolist()
    ]

    test_metadata = [
        {
            "document_id": 999,
            "chunk_index": 0,
            "chunk_text": "This is a test norm about data protection",
            "document_type": "norm",
            "document_title": "Test Norm A"
        },
        {
            "document_id": 999,
            "chunk_index": 1,
            "chunk_text": "This section covers privacy requirements",
            "document_type": "norm",
            "document_title": "Test Norm A"
        },
        {
            "document_id": 1000,
            "chunk_index": 0,
            "chunk_text": "Our company guidelines for data security",
            "document_type": "guideline",
            "document_title": "Test Guideline B"
        }
    ]

    count = store.store_chunk_embeddings(
        chunk_ids=[99901, 99902, 99903],
        embeddings=test_embeddings,
        metadata=test_metadata
    )
    print(f"   ✅ Stored {count} test embeddings!")

    # Test semantic search
    print("\n6. Testing semantic search...")
    query_vector = np.random.rand(768).tolist()
    results = store.search_similar_chunks(
        query_vector=query_vector,
        limit=3,
        score_threshold=0.0  # Low threshold for test data
    )
    print(f"   Found {len(results)} results:")
    for i, result in enumerate(results, 1):
        print(f"     {i}. Chunk {result.id} (score: {result.score:.3f})")
        print(f"        Text: {result.payload.get('chunk_text', 'N/A')[:50]}...")

    # Test filtered search
    print("\n7. Testing filtered search (norms only)...")
    results = store.search_similar_chunks(
        query_vector=query_vector,
        limit=3,
        score_threshold=0.0,
        filters={"document_type": "norm"}
    )
    print(f"   Found {len(results)} norm chunks:")
    for result in results:
        print(f"     - {result.payload.get('document_title')}")

    # Clean up test data
    print("\n8. Cleaning up test data...")
    store.delete_document_vectors(999)
    store.delete_document_vectors(1000)
    print("   ✅ Test data deleted!")

    print("\n" + "="*50)
    print("🎉 All tests passed! Qdrant integration working!")
    print("="*50)


if __name__ == "__main__":
    main()
