'use client'

import { useState, useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import {
  FileText,
  X,
  GitCompare,
  AlertCircle,
  CheckCircle,
  ChevronDown,
  ChevronUp,
  Link as LinkIcon,
  ArrowRight,
  Loader2,
  RefreshCw,
} from 'lucide-react'
import { documentApi, relationshipsApi } from '@/lib/api'
import {
  Document,
  DocumentType,
  DocumentRelationship,
  RelationshipType,
  ValidationStatus,
} from '@/types'

interface DocumentCompareProps {
  onClose: () => void
}

// Helper to get relationship type label
function getRelationshipTypeLabel(type: RelationshipType): string {
  switch (type) {
    case RelationshipType.COMPLIANCE:
      return 'Compliance'
    case RelationshipType.CONFLICT:
      return 'Conflict'
    case RelationshipType.REFERENCE:
      return 'Reference'
    case RelationshipType.SIMILAR:
      return 'Similar'
    case RelationshipType.SUPERSEDES:
      return 'Supersedes'
    default:
      return type
  }
}

// Helper to get relationship type badge color
function getRelationshipTypeBadge(type: RelationshipType): string {
  switch (type) {
    case RelationshipType.COMPLIANCE:
      return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
    case RelationshipType.CONFLICT:
      return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
    case RelationshipType.REFERENCE:
      return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
    case RelationshipType.SIMILAR:
      return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
    case RelationshipType.SUPERSEDES:
      return 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200'
    default:
      return 'bg-gray-100 text-gray-800'
  }
}

// Helper to get validation status badge
function getValidationStatusBadge(status: ValidationStatus): { color: string; label: string } {
  switch (status) {
    case ValidationStatus.APPROVED:
      return { color: 'bg-green-100 text-green-800', label: 'Approved' }
    case ValidationStatus.REJECTED:
      return { color: 'bg-red-100 text-red-800', label: 'Rejected' }
    case ValidationStatus.PENDING_REVIEW:
      return { color: 'bg-yellow-100 text-yellow-800', label: 'Pending Review' }
    case ValidationStatus.AUTO_DETECTED:
      return { color: 'bg-blue-100 text-blue-800', label: 'Auto Detected' }
    default:
      return { color: 'bg-gray-100 text-gray-800', label: status }
  }
}

// Helper to get doc type badge
function getDocTypeBadge(type: DocumentType): string {
  return type === DocumentType.NORM
    ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
    : 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
}

// Relationship card component
function RelationshipCard({
  relationship,
  sourceDoc,
  targetDoc,
}: {
  relationship: DocumentRelationship
  sourceDoc?: Document
  targetDoc?: Document
}) {
  const [expanded, setExpanded] = useState(false)
  const validationBadge = getValidationStatusBadge(relationship.validation_status)

  return (
    <Card className="mb-4">
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <LinkIcon className="h-5 w-5 text-muted-foreground" />
            <span
              className={`px-2 py-1 rounded-full text-xs font-medium ${getRelationshipTypeBadge(
                relationship.relationship_type
              )}`}
            >
              {getRelationshipTypeLabel(relationship.relationship_type)}
            </span>
            <span className={`px-2 py-1 rounded-full text-xs font-medium ${validationBadge.color}`}>
              {validationBadge.label}
            </span>
          </div>
          <div className="text-sm font-semibold text-muted-foreground">
            {relationship.confidence.toFixed(1)}% confidence
          </div>
        </div>
      </CardHeader>
      <CardContent>
        {/* Document connection visualization */}
        <div className="flex items-center justify-between gap-4 mb-4">
          <div className="flex-1 p-3 bg-muted rounded-lg">
            <div className="flex items-center gap-2 mb-1">
              <FileText className="h-4 w-4" />
              <span className="font-medium text-sm truncate">
                {sourceDoc?.title || `Document #${relationship.source_doc_id}`}
              </span>
            </div>
            {sourceDoc && (
              <span
                className={`px-2 py-0.5 rounded-full text-xs font-medium ${getDocTypeBadge(
                  sourceDoc.document_type
                )}`}
              >
                {sourceDoc.document_type === DocumentType.NORM ? 'Norm' : 'Guideline'}
              </span>
            )}
          </div>

          <div className="flex flex-col items-center">
            <ArrowRight className="h-6 w-6 text-muted-foreground" />
          </div>

          <div className="flex-1 p-3 bg-muted rounded-lg">
            <div className="flex items-center gap-2 mb-1">
              <FileText className="h-4 w-4" />
              <span className="font-medium text-sm truncate">
                {targetDoc?.title || `Document #${relationship.target_doc_id}`}
              </span>
            </div>
            {targetDoc && (
              <span
                className={`px-2 py-0.5 rounded-full text-xs font-medium ${getDocTypeBadge(
                  targetDoc.document_type
                )}`}
              >
                {targetDoc.document_type === DocumentType.NORM ? 'Norm' : 'Guideline'}
              </span>
            )}
          </div>
        </div>

        {/* Summary */}
        {relationship.summary && (
          <p className="text-sm text-muted-foreground mb-3">{relationship.summary}</p>
        )}

        {/* Expandable details */}
        {relationship.details && (
          <div>
            <button
              onClick={() => setExpanded(!expanded)}
              className="flex items-center gap-1 text-sm text-primary hover:underline"
            >
              {expanded ? (
                <>
                  <ChevronUp className="h-4 w-4" /> Hide details
                </>
              ) : (
                <>
                  <ChevronDown className="h-4 w-4" /> Show details
                </>
              )}
            </button>

            {expanded && (
              <div className="mt-3 p-3 bg-muted/50 rounded-lg text-sm">
                <div className="grid grid-cols-2 gap-2 mb-2">
                  <div>
                    <span className="text-muted-foreground">Matched chunks: </span>
                    <span className="font-medium">
                      {relationship.details.matched_chunks_count || 'N/A'}
                    </span>
                  </div>
                  <div>
                    <span className="text-muted-foreground">Avg similarity: </span>
                    <span className="font-medium">
                      {relationship.details.avg_similarity
                        ? `${(relationship.details.avg_similarity * 100).toFixed(1)}%`
                        : 'N/A'}
                    </span>
                  </div>
                  <div>
                    <span className="text-muted-foreground">Max similarity: </span>
                    <span className="font-medium">
                      {relationship.details.max_similarity
                        ? `${(relationship.details.max_similarity * 100).toFixed(1)}%`
                        : 'N/A'}
                    </span>
                  </div>
                  <div>
                    <span className="text-muted-foreground">Min similarity: </span>
                    <span className="font-medium">
                      {relationship.details.min_similarity
                        ? `${(relationship.details.min_similarity * 100).toFixed(1)}%`
                        : 'N/A'}
                    </span>
                  </div>
                </div>

                {relationship.details.matched_sections &&
                  relationship.details.matched_sections.length > 0 && (
                    <div className="mt-2">
                      <span className="text-muted-foreground">Matched sections: </span>
                      <div className="flex flex-wrap gap-1 mt-1">
                        {relationship.details.matched_sections.slice(0, 5).map((section: string, i: number) => (
                          <span
                            key={i}
                            className="px-2 py-0.5 bg-background rounded text-xs"
                          >
                            {section}
                          </span>
                        ))}
                        {relationship.details.matched_sections.length > 5 && (
                          <span className="text-xs text-muted-foreground">
                            +{relationship.details.matched_sections.length - 5} more
                          </span>
                        )}
                      </div>
                    </div>
                  )}
              </div>
            )}
          </div>
        )}

        {/* Metadata footer */}
        <div className="mt-3 pt-3 border-t flex items-center justify-between text-xs text-muted-foreground">
          <span>Created: {new Date(relationship.created_at).toLocaleDateString()}</span>
          {relationship.validated_by && (
            <span>Validated by: {relationship.validated_by}</span>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

export default function DocumentCompare({ onClose }: DocumentCompareProps) {
  const [selectedDocIds, setSelectedDocIds] = useState<number[]>([])
  const [threshold, setThreshold] = useState(0.7)
  const [isComparing, setIsComparing] = useState(false)
  const [comparisonResult, setComparisonResult] = useState<any>(null)
  const [comparisonError, setComparisonError] = useState<string | null>(null)

  // Fetch available documents
  const { data: documentsResponse, isLoading: isLoadingDocuments } = useQuery({
    queryKey: ['documents-for-compare'],
    queryFn: async () => {
      const response = await documentApi.list()
      return response.data
    },
  })

  const documents: Document[] = documentsResponse?.documents || []

  // Toggle document selection
  const toggleDocumentSelection = (docId: number) => {
    setSelectedDocIds((prev) => {
      if (prev.includes(docId)) {
        return prev.filter((id) => id !== docId)
      }
      if (prev.length >= 5) {
        return prev // Max 5 documents
      }
      return [...prev, docId]
    })
  }

  // Handle comparison
  const handleCompare = async () => {
    if (selectedDocIds.length < 2) {
      setComparisonError('Please select at least 2 documents to compare')
      return
    }

    setIsComparing(true)
    setComparisonError(null)

    try {
      const response = await relationshipsApi.compare(selectedDocIds, threshold)
      setComparisonResult(response.data)
    } catch (error: any) {
      console.error('Comparison failed:', error)
      setComparisonError(error.response?.data?.detail || error.message || 'Comparison failed')
    } finally {
      setIsComparing(false)
    }
  }

  // Get document by ID helper
  const getDocById = (id: number): Document | undefined => {
    return documents.find((d) => d.id === id)
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-background rounded-lg max-w-5xl w-full max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="p-6 border-b flex-shrink-0">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-2xl font-bold flex items-center gap-2">
                <GitCompare className="h-6 w-6" />
                Compare Documents
              </h2>
              <p className="text-sm text-muted-foreground mt-1">
                Select documents to find and view relationships between them
              </p>
            </div>
            <button
              onClick={onClose}
              className="text-muted-foreground hover:text-foreground"
            >
              <X className="h-6 w-6" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {/* Document selection */}
          <div className="mb-6">
            <h3 className="font-semibold mb-3">
              Select Documents ({selectedDocIds.length}/5 selected)
            </h3>

            {isLoadingDocuments ? (
              <div className="flex items-center justify-center py-8">
                <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
              </div>
            ) : documents.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <FileText className="h-12 w-12 mx-auto mb-2 opacity-50" />
                <p>No documents available</p>
                <p className="text-sm">Upload documents to compare them</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 max-h-64 overflow-y-auto">
                {documents
                  .filter((doc) => doc.status === 'ready')
                  .map((doc) => (
                    <div
                      key={doc.id}
                      onClick={() => toggleDocumentSelection(doc.id)}
                      className={`p-3 border rounded-lg cursor-pointer transition-colors ${
                        selectedDocIds.includes(doc.id)
                          ? 'border-primary bg-primary/5'
                          : 'border-border hover:bg-muted/50'
                      }`}
                    >
                      <div className="flex items-start gap-2">
                        <div
                          className={`w-5 h-5 rounded border flex items-center justify-center flex-shrink-0 mt-0.5 ${
                            selectedDocIds.includes(doc.id)
                              ? 'bg-primary border-primary'
                              : 'border-muted-foreground'
                          }`}
                        >
                          {selectedDocIds.includes(doc.id) && (
                            <CheckCircle className="h-4 w-4 text-primary-foreground" />
                          )}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="font-medium text-sm truncate">{doc.title}</p>
                          <span
                            className={`px-2 py-0.5 rounded-full text-xs font-medium ${getDocTypeBadge(
                              doc.document_type
                            )}`}
                          >
                            {doc.document_type === DocumentType.NORM ? 'Norm' : 'Guideline'}
                          </span>
                        </div>
                      </div>
                    </div>
                  ))}
              </div>
            )}
          </div>

          {/* Threshold slider */}
          <div className="mb-6">
            <label className="block text-sm font-medium mb-2">
              Minimum Confidence Threshold: {(threshold * 100).toFixed(0)}%
            </label>
            <input
              type="range"
              min="0"
              max="100"
              value={threshold * 100}
              onChange={(e) => setThreshold(parseInt(e.target.value) / 100)}
              className="w-full"
            />
            <div className="flex justify-between text-xs text-muted-foreground">
              <span>0%</span>
              <span>50%</span>
              <span>100%</span>
            </div>
          </div>

          {/* Compare button */}
          <div className="mb-6">
            <Button
              className="w-full"
              onClick={handleCompare}
              disabled={selectedDocIds.length < 2 || isComparing}
            >
              {isComparing ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Comparing...
                </>
              ) : (
                <>
                  <GitCompare className="h-4 w-4 mr-2" />
                  Compare {selectedDocIds.length} Documents
                </>
              )}
            </Button>
            {selectedDocIds.length < 2 && (
              <p className="text-sm text-muted-foreground text-center mt-2">
                Select at least 2 documents to compare
              </p>
            )}
          </div>

          {/* Error display */}
          {comparisonError && (
            <div className="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
              <div className="flex items-center gap-2 text-red-600 dark:text-red-400">
                <AlertCircle className="h-5 w-5" />
                <span className="font-medium">Comparison failed</span>
              </div>
              <p className="text-sm text-red-500 mt-1">{comparisonError}</p>
            </div>
          )}

          {/* Comparison results */}
          {comparisonResult && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-semibold">
                  Relationships Found ({comparisonResult.total_relationships})
                </h3>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleCompare}
                  disabled={isComparing}
                >
                  <RefreshCw className={`h-4 w-4 mr-1 ${isComparing ? 'animate-spin' : ''}`} />
                  Refresh
                </Button>
              </div>

              {comparisonResult.total_relationships === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  <LinkIcon className="h-12 w-12 mx-auto mb-2 opacity-50" />
                  <p className="font-medium">No relationships found</p>
                  <p className="text-sm">
                    Try lowering the confidence threshold or selecting different documents
                  </p>
                </div>
              ) : (
                <div>
                  {comparisonResult.results.map((result: any) =>
                    result.relationships.map((rel: DocumentRelationship) => (
                      <RelationshipCard
                        key={rel.id}
                        relationship={rel}
                        sourceDoc={getDocById(rel.source_doc_id)}
                        targetDoc={getDocById(rel.target_doc_id)}
                      />
                    ))
                  )}
                </div>
              )}
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
