'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import {
  FileText,
  X,
  ExternalLink,
  ChevronDown,
  ChevronUp,
  AlertCircle,
  CheckCircle,
  Search as SearchIcon,
} from 'lucide-react'
import { SearchResult, SearchResponse, DocumentType } from '@/types'

interface SearchResultsProps {
  results: SearchResponse | null
  isLoading?: boolean
  error?: string | null
  onClose: () => void
  onResultClick?: (result: SearchResult) => void
}

// Helper to format similarity as percentage
function formatSimilarity(score: number): string {
  return `${(score * 100).toFixed(1)}%`
}

// Helper to get document type badge styles
function getDocTypeStyles(docType: DocumentType): string {
  switch (docType) {
    case DocumentType.NORM:
      return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
    case DocumentType.GUIDELINE:
      return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
    default:
      return 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200'
  }
}

// Helper to get similarity color
function getSimilarityColor(score: number): string {
  if (score >= 0.8) return 'text-green-600 dark:text-green-400'
  if (score >= 0.6) return 'text-yellow-600 dark:text-yellow-400'
  return 'text-orange-600 dark:text-orange-400'
}

// Single search result item component
function SearchResultItem({
  result,
  onClick,
}: {
  result: SearchResult
  onClick?: (result: SearchResult) => void
}) {
  const [expanded, setExpanded] = useState(false)

  return (
    <div className="border rounded-lg p-4 hover:bg-muted/50 transition-colors">
      <div className="flex items-start justify-between gap-4">
        <div className="flex-1 min-w-0">
          {/* Document title and type */}
          <div className="flex items-center gap-2 mb-2">
            <FileText className="h-4 w-4 text-muted-foreground flex-shrink-0" />
            <h4 className="font-medium truncate">{result.document_title}</h4>
            <span
              className={`px-2 py-0.5 rounded-full text-xs font-medium ${getDocTypeStyles(
                result.document_type
              )}`}
            >
              {result.document_type === DocumentType.NORM ? 'Norm' : 'Guideline'}
            </span>
          </div>

          {/* Chunk text preview */}
          <div className="text-sm text-muted-foreground">
            <p className={expanded ? '' : 'line-clamp-2'}>{result.chunk_text}</p>
            {result.chunk_text.length > 200 && (
              <button
                onClick={() => setExpanded(!expanded)}
                className="text-primary hover:underline text-xs mt-1 flex items-center gap-1"
              >
                {expanded ? (
                  <>
                    <ChevronUp className="h-3 w-3" /> Show less
                  </>
                ) : (
                  <>
                    <ChevronDown className="h-3 w-3" /> Show more
                  </>
                )}
              </button>
            )}
          </div>
        </div>

        {/* Similarity score and actions */}
        <div className="flex flex-col items-end gap-2">
          <div
            className={`text-sm font-semibold ${getSimilarityColor(result.similarity)}`}
          >
            {formatSimilarity(result.similarity)}
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => onClick?.(result)}
            className="text-xs"
          >
            <ExternalLink className="h-3 w-3 mr-1" />
            View
          </Button>
        </div>
      </div>

      {/* Metadata footer */}
      <div className="mt-3 pt-3 border-t flex items-center gap-4 text-xs text-muted-foreground">
        <span>Document ID: {result.document_id}</span>
        <span>Chunk ID: {result.chunk_id}</span>
      </div>
    </div>
  )
}

export default function SearchResults({
  results,
  isLoading,
  error,
  onClose,
  onResultClick,
}: SearchResultsProps) {
  const [filterType, setFilterType] = useState<DocumentType | 'all'>('all')

  // Filter results by document type
  const filteredResults = results?.results.filter((r) => {
    if (filterType === 'all') return true
    return r.document_type === filterType
  })

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-background rounded-lg max-w-4xl w-full max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="p-6 border-b flex-shrink-0">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-2xl font-bold flex items-center gap-2">
                <SearchIcon className="h-6 w-6" />
                Search Results
              </h2>
              {results && (
                <p className="text-sm text-muted-foreground mt-1">
                  Found {results.total} results for &quot;{results.query}&quot;
                </p>
              )}
            </div>
            <button
              onClick={onClose}
              className="text-muted-foreground hover:text-foreground"
            >
              <X className="h-6 w-6" />
            </button>
          </div>

          {/* Filter buttons */}
          {results && results.total > 0 && (
            <div className="flex gap-2 mt-4">
              <Button
                variant={filterType === 'all' ? 'default' : 'outline'}
                size="sm"
                onClick={() => setFilterType('all')}
              >
                All ({results.results.length})
              </Button>
              <Button
                variant={filterType === DocumentType.NORM ? 'default' : 'outline'}
                size="sm"
                onClick={() => setFilterType(DocumentType.NORM)}
              >
                Norms ({results.results.filter((r) => r.document_type === DocumentType.NORM).length})
              </Button>
              <Button
                variant={filterType === DocumentType.GUIDELINE ? 'default' : 'outline'}
                size="sm"
                onClick={() => setFilterType(DocumentType.GUIDELINE)}
              >
                Guidelines ({results.results.filter((r) => r.document_type === DocumentType.GUIDELINE).length})
              </Button>
            </div>
          )}
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {/* Loading state */}
          {isLoading && (
            <div className="flex flex-col items-center justify-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mb-4"></div>
              <p className="text-muted-foreground">Searching documents...</p>
            </div>
          )}

          {/* Error state */}
          {error && (
            <div className="flex flex-col items-center justify-center py-12 text-red-500">
              <AlertCircle className="h-12 w-12 mb-4" />
              <p className="font-medium">Search failed</p>
              <p className="text-sm text-muted-foreground mt-1">{error}</p>
            </div>
          )}

          {/* Empty state */}
          {!isLoading && !error && results && results.total === 0 && (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <FileText className="h-12 w-12 mb-4 opacity-50" />
              <p className="font-medium">No results found</p>
              <p className="text-sm mt-1">Try adjusting your search query or filters</p>
            </div>
          )}

          {/* Results list */}
          {!isLoading && !error && filteredResults && filteredResults.length > 0 && (
            <div className="space-y-4">
              {filteredResults.map((result, index) => (
                <SearchResultItem
                  key={`${result.document_id}-${result.chunk_id}-${index}`}
                  result={result}
                  onClick={onResultClick}
                />
              ))}
            </div>
          )}

        </div>

        {/* Footer */}
        <div className="p-4 border-t flex justify-end gap-2 flex-shrink-0">
          <Button variant="outline" onClick={onClose}>
            Close
          </Button>
        </div>
      </div>
    </div>
  )
}
