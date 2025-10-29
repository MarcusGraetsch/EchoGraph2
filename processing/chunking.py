"""Text chunking utilities with structure awareness."""

from typing import List, Dict
import re
from loguru import logger


class DocumentChunker:
    """Intelligent document chunking that respects structure."""

    def __init__(self, chunk_size: int = 512, chunk_overlap: int = 50):
        """Initialize chunker.

        Args:
            chunk_size: Target size of each chunk in characters
            chunk_overlap: Overlap between chunks in characters
        """
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def chunk_text(self, text: str, metadata: Dict = None) -> List[Dict]:
        """Split text into overlapping chunks.

        Args:
            text: Text to chunk
            metadata: Optional metadata to attach to chunks

        Returns:
            List of chunk dictionaries with text and metadata
        """
        if not text or not text.strip():
            return []

        # Try to split by paragraphs first
        paragraphs = self._split_paragraphs(text)

        chunks = []
        current_chunk = ""
        chunk_index = 0

        for para in paragraphs:
            # If paragraph itself is larger than chunk_size, split it
            if len(para) > self.chunk_size:
                # Save current chunk if it exists
                if current_chunk:
                    chunks.append(self._create_chunk(current_chunk, chunk_index, metadata))
                    chunk_index += 1
                    current_chunk = ""

                # Split large paragraph
                sub_chunks = self._split_large_text(para)
                for sub_chunk in sub_chunks:
                    chunks.append(self._create_chunk(sub_chunk, chunk_index, metadata))
                    chunk_index += 1

            # If adding this paragraph exceeds chunk_size, save current chunk
            elif len(current_chunk) + len(para) > self.chunk_size:
                if current_chunk:
                    chunks.append(self._create_chunk(current_chunk, chunk_index, metadata))
                    chunk_index += 1

                # Start new chunk with overlap
                if self.chunk_overlap > 0 and current_chunk:
                    overlap_text = current_chunk[-self.chunk_overlap:]
                    current_chunk = overlap_text + "\n\n" + para
                else:
                    current_chunk = para
            else:
                # Add paragraph to current chunk
                if current_chunk:
                    current_chunk += "\n\n" + para
                else:
                    current_chunk = para

        # Add final chunk
        if current_chunk:
            chunks.append(self._create_chunk(current_chunk, chunk_index, metadata))

        logger.info(f"Created {len(chunks)} chunks from text of length {len(text)}")
        return chunks

    def _split_paragraphs(self, text: str) -> List[str]:
        """Split text into paragraphs.

        Args:
            text: Text to split

        Returns:
            List of paragraphs
        """
        # Split on double newlines or multiple newlines
        paragraphs = re.split(r'\n\s*\n', text)
        # Filter out empty paragraphs
        return [p.strip() for p in paragraphs if p.strip()]

    def _split_large_text(self, text: str) -> List[str]:
        """Split large text into smaller chunks by sentences.

        Args:
            text: Text to split

        Returns:
            List of text chunks
        """
        # Split by sentences
        sentences = re.split(r'(?<=[.!?])\s+', text)

        chunks = []
        current_chunk = ""

        for sentence in sentences:
            if len(current_chunk) + len(sentence) > self.chunk_size:
                if current_chunk:
                    chunks.append(current_chunk.strip())

                # Handle overlap
                if self.chunk_overlap > 0 and current_chunk:
                    overlap_text = current_chunk[-self.chunk_overlap:]
                    current_chunk = overlap_text + " " + sentence
                else:
                    current_chunk = sentence
            else:
                if current_chunk:
                    current_chunk += " " + sentence
                else:
                    current_chunk = sentence

        if current_chunk:
            chunks.append(current_chunk.strip())

        return chunks

    def _create_chunk(self, text: str, index: int, metadata: Dict = None) -> Dict:
        """Create a chunk dictionary.

        Args:
            text: Chunk text
            index: Chunk index
            metadata: Optional metadata

        Returns:
            Chunk dictionary
        """
        chunk = {
            "text": text.strip(),
            "chunk_index": index,
            "char_count": len(text),
        }

        if metadata:
            chunk["metadata"] = metadata

        return chunk


class StructuredChunker(DocumentChunker):
    """Chunker that preserves document structure (headings, sections)."""

    def chunk_document(
        self,
        text: str,
        structure: List[Dict] = None,
        metadata: Dict = None
    ) -> List[Dict]:
        """Chunk document while preserving structure.

        Args:
            text: Document text
            structure: Optional structure info (headings, sections)
            metadata: Optional metadata

        Returns:
            List of structured chunks
        """
        if not structure:
            # Fall back to basic chunking
            return self.chunk_text(text, metadata)

        chunks = []
        chunk_index = 0

        for section in structure:
            section_text = section.get("text", "")
            section_meta = {
                **(metadata or {}),
                "section_title": section.get("title", ""),
                "section_level": section.get("level", 0),
            }

            # Chunk the section
            section_chunks = self.chunk_text(section_text, section_meta)

            # Update chunk indices
            for chunk in section_chunks:
                chunk["chunk_index"] = chunk_index
                chunks.append(chunk)
                chunk_index += 1

        return chunks
