'use client'

import { useMemo, useState } from 'react'
import Link from 'next/link'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { FileText, Trash2, Eye, Filter, RefreshCw, Search } from 'lucide-react'
import { documentsService, ListDocumentsParams } from '@/services/documents'
import { DocumentStatus, DocumentType } from '@/types'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { useKeycloak } from '@/lib/keycloak'

type FilterState = Pick<ListDocumentsParams, 'document_type' | 'status' | 'search'>

const STATUS_LABELS: Record<DocumentStatus, string> = {
  [DocumentStatus.UPLOADING]: 'Uploading',
  [DocumentStatus.PROCESSING]: 'Processing',
  [DocumentStatus.EXTRACTING]: 'Extracting',
  [DocumentStatus.ANALYZING]: 'Analyzing',
  [DocumentStatus.EMBEDDING]: 'Embedding',
  [DocumentStatus.READY]: 'Ready',
  [DocumentStatus.ERROR]: 'Error',
}

const TYPE_LABELS: Record<DocumentType, string> = {
  [DocumentType.NORM]: 'Norm / Regulation',
  [DocumentType.GUIDELINE]: 'Guideline',
}

const PAGE_SIZES = [10, 20, 50]

export default function DocumentsPage() {
  const { authenticated, login, register, loading } = useKeycloak()
  const queryClient = useQueryClient()

  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [filters, setFilters] = useState<FilterState>({
    document_type: undefined,
    status: undefined,
    search: undefined,
  })
  const [searchInput, setSearchInput] = useState('')

  const { data, isLoading, isFetching, isPlaceholderData } = useQuery({
    queryKey: ['documents', { page, pageSize, filters }],
    queryFn: () =>
      documentsService.list({
        page,
        page_size: pageSize,
        document_type: filters.document_type,
        status: filters.status,
        search: filters.search,
      }),
    placeholderData: (previousData) => previousData,
    enabled: authenticated,
  })

  const deleteMutation = useMutation({
    mutationFn: (id: number) => documentsService.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['documents'] })
    },
  })

  const handleApplyFilters = () => {
    setPage(1)
    setFilters((prev) => ({
      ...prev,
      document_type: prev.document_type || undefined,
      status: prev.status || undefined,
      search: searchInput.trim() || undefined,
    }))
  }

  const handleClearFilters = () => {
    setPage(1)
    setSearchInput('')
    setFilters({
      document_type: undefined,
      status: undefined,
      search: undefined,
    })
  }

  const totalPages = useMemo(() => {
    if (!data?.total) return 1
    return Math.max(1, Math.ceil(data.total / pageSize))
  }, [data?.total, pageSize])

  const isDeleting = deleteMutation.isPending

  if (!authenticated && !loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center px-4">
        <Card className="max-w-lg w-full">
          <CardHeader>
            <CardTitle className="text-xl">Sign in to view documents</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <p className="text-sm text-muted-foreground">
              You need to be logged in to see the document library.
            </p>
            <div className="flex gap-3">
              <Button onClick={login} className="flex-1">Login</Button>
              <Button variant="outline" onClick={register} className="flex-1">Register</Button>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="container mx-auto px-4 py-8 space-y-6">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h1 className="text-3xl font-bold">Documents</h1>
            <p className="text-sm text-muted-foreground">
              Browse, filter, and manage uploaded documents.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => queryClient.invalidateQueries({ queryKey: ['documents'] })}
              disabled={isLoading || isFetching}
            >
              <RefreshCw className="h-4 w-4 mr-1" />
              Refresh
            </Button>
          </div>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Filter className="h-4 w-4" />
              Filters
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
              <div className="space-y-2">
                <label className="text-sm font-medium">Search</label>
                <div className="flex gap-2">
                  <input
                    className="w-full px-3 py-2 border rounded-md border-border focus:outline-none focus:ring-2 focus:ring-ring"
                    placeholder="Title, author, description..."
                    value={searchInput}
                    onChange={(e) => setSearchInput(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handleApplyFilters()}
                  />
                  <Button variant="outline" onClick={handleApplyFilters}>
                    <Search className="h-4 w-4" />
                  </Button>
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium">Type</label>
                <select
                  className="w-full px-3 py-2 border rounded-md border-border focus:outline-none focus:ring-2 focus:ring-ring"
                  value={filters.document_type || ''}
                  onChange={(e) =>
                    setFilters((prev) => ({ ...prev, document_type: e.target.value || undefined }))
                  }
                >
                  <option value="">All</option>
                  <option value={DocumentType.NORM}>{TYPE_LABELS[DocumentType.NORM]}</option>
                  <option value={DocumentType.GUIDELINE}>{TYPE_LABELS[DocumentType.GUIDELINE]}</option>
                </select>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium">Status</label>
                <select
                  className="w-full px-3 py-2 border rounded-md border-border focus:outline-none focus:ring-2 focus:ring-ring"
                  value={filters.status || ''}
                  onChange={(e) =>
                    setFilters((prev) => ({ ...prev, status: e.target.value || undefined }))
                  }
                >
                  <option value="">All</option>
                  {Object.values(DocumentStatus).map((status) => (
                    <option key={status} value={status}>
                      {STATUS_LABELS[status]}
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium">Page size</label>
                <select
                  className="w-full px-3 py-2 border rounded-md border-border focus:outline-none focus:ring-2 focus:ring-ring"
                  value={pageSize}
                  onChange={(e) => {
                    setPageSize(Number(e.target.value))
                    setPage(1)
                  }}
                >
                  {PAGE_SIZES.map((size) => (
                    <option key={size} value={size}>
                      {size} per page
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="flex gap-2">
              <Button onClick={handleApplyFilters} disabled={isLoading}>
                Apply
              </Button>
              <Button variant="outline" onClick={handleClearFilters} disabled={isLoading}>
                Clear
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="flex items-center gap-2">
              <FileText className="h-4 w-4" />
              Library
            </CardTitle>
            <div className="text-sm text-muted-foreground">
              {isFetching ? 'Refreshing…' : isLoading ? 'Loading…' : `${data?.total ?? 0} documents`}
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-muted/60">
                  <tr className="text-left">
                    <th className="px-4 py-3">Title</th>
                    <th className="px-4 py-3">Type</th>
                    <th className="px-4 py-3">Status</th>
                    <th className="px-4 py-3">Uploaded</th>
                    <th className="px-4 py-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {isLoading ? (
                    <tr>
                      <td colSpan={5} className="px-4 py-6 text-center text-muted-foreground">
                        Loading documents...
                      </td>
                    </tr>
                  ) : !data?.documents?.length ? (
                    <tr>
                      <td colSpan={5} className="px-4 py-6 text-center text-muted-foreground">
                        No documents found. Try adjusting filters or upload a new document.
                      </td>
                    </tr>
                  ) : (
                    data.documents.map((doc) => {
                      const uploadDate = doc.upload_date
                        ? new Date(doc.upload_date).toLocaleString()
                        : '—'
                      const isAbsoluteFile = doc.file_path?.startsWith('http')
                      const downloadUrl = isAbsoluteFile
                        ? doc.file_path
                        : undefined

                      return (
                        <tr key={doc.id} className="border-t last:border-b">
                          <td className="px-4 py-3 max-w-xs">
                            <div className="font-medium truncate">{doc.title}</div>
                            <div className="text-xs text-muted-foreground truncate">
                              {doc.description || 'No description'}
                            </div>
                          </td>
                          <td className="px-4 py-3">
                            <span className="rounded-full bg-muted px-2 py-1 text-xs">
                              {TYPE_LABELS[doc.document_type]}
                            </span>
                          </td>
                          <td className="px-4 py-3">
                            <span
                              className={`rounded-full px-2 py-1 text-xs ${
                                doc.status === DocumentStatus.READY
                                  ? 'bg-green-100 text-green-800'
                                  : doc.status === DocumentStatus.ERROR
                                  ? 'bg-red-100 text-red-700'
                                  : 'bg-amber-100 text-amber-800'
                              }`}
                            >
                              {STATUS_LABELS[doc.status]}
                            </span>
                          </td>
                          <td className="px-4 py-3 whitespace-nowrap">{uploadDate}</td>
                          <td className="px-4 py-3">
                            <div className="flex justify-end gap-2">
                              <Button
                                variant="outline"
                                size="sm"
                                asChild
                                title="View metadata"
                              >
                                <Link href={`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/api/documents/${doc.id}`} target="_blank">
                                  <Eye className="h-4 w-4 mr-1" />
                                  View
                                </Link>
                              </Button>
                              {downloadUrl && (
                                <Button
                                  variant="outline"
                                  size="sm"
                                  asChild
                                  title="Download file"
                                >
                                  <a href={downloadUrl} target="_blank" rel="noreferrer">
                                    <FileText className="h-4 w-4 mr-1" />
                                    Download
                                  </a>
                                </Button>
                              )}
                              <Button
                                variant="destructive"
                                size="sm"
                                onClick={() => {
                                  if (confirm(`Delete "${doc.title}"? This cannot be undone.`)) {
                                    deleteMutation.mutate(doc.id)
                                  }
                                }}
                                disabled={isDeleting}
                              >
                                <Trash2 className="h-4 w-4 mr-1" />
                                Delete
                              </Button>
                            </div>
                          </td>
                        </tr>
                      )
                    })
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination */}
            {data?.documents?.length ? (
              <div className="flex items-center justify-between px-4 py-3 border-t text-sm">
                <div className="text-muted-foreground">
                  Page {page} of {totalPages} — Showing {data.documents.length} of {data.total} documents
                </div>
                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                    disabled={page === 1 || isLoading}
                  >
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                    disabled={page >= totalPages || isLoading}
                  >
                    Next
                  </Button>
                </div>
              </div>
            ) : null}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
