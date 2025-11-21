'use client'

import { useState, useRef } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import {
  FileText,
  Upload,
  Search,
  GitCompare,
  CheckCircle,
  AlertCircle,
  X,
  Loader2,
  User,
  LogOut,
  LogIn
} from 'lucide-react'
import { documentApi } from '@/lib/api'
import { useKeycloak } from '@/lib/keycloak'

interface FileUploadStatus {
  file: File
  progress: number
  status: 'pending' | 'uploading' | 'success' | 'error'
  error?: string
}

export default function Dashboard() {
  const { authenticated, user, login, logout, register, loading } = useKeycloak()
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedFiles, setSelectedFiles] = useState<File[]>([])
  const [isDragging, setIsDragging] = useState(false)
  const [showUploadModal, setShowUploadModal] = useState(false)
  const [showSettings, setShowSettings] = useState(false)
  const [documentType, setDocumentType] = useState<'norm' | 'guideline'>('norm')
  const [uploadStatuses, setUploadStatuses] = useState<FileUploadStatus[]>([])
  const [isUploading, setIsUploading] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Dashboard statistics (auto-refresh every 30s)
  const {
    data: stats,
    isLoading: isLoadingStats,
    isFetching: isFetchingStats,
    error: statsError,
    refetch: refetchStats,
  } = useQuery({
    queryKey: ['dashboard-statistics'],
    queryFn: async () => {
      const response = await documentApi.getStatistics()
      return response.data
    },
    enabled: authenticated,
    refetchInterval: 30_000,
    refetchOnMount: true,
  })

  // Handle file selection
  const handleFileSelect = (files: FileList | null) => {
    if (files) {
      const fileArray = Array.from(files)
      setSelectedFiles(prev => [...prev, ...fileArray])
      setShowUploadModal(true)
    }
  }

  // Handle drag and drop
  const handleDragEnter = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(true)
  }

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)

    const files = e.dataTransfer.files
    handleFileSelect(files)
  }

  // Handle search
  const handleSearch = async () => {
    if (!searchQuery.trim()) return

    try {
      const response = await documentApi.search(searchQuery)
      console.log('Search results:', response.data)

      // TODO: Phase 2 - Display search results in a proper UI
      // For now, log to console
      if (response.data.results && response.data.results.length > 0) {
        alert(`Found ${response.data.results.length} results!\n\nCheck console for details.\n\n(Search results UI will be implemented in Phase 2)`)
      } else {
        alert('No results found. Try a different search query.')
      }
    } catch (error: any) {
      console.error('Search failed:', error)
      alert(`Search failed: ${error.response?.data?.detail || error.message}`)
    }
  }

  // Handle settings
  const handleSettings = () => {
    setShowSettings(true)
  }

  // Remove file from selection
  const removeFile = (index: number) => {
    setSelectedFiles(prev => prev.filter((_, i) => i !== index))
  }

  // Handle file upload
  const handleUpload = async () => {
    if (selectedFiles.length === 0 || !documentType) return

    setIsUploading(true)

    // Initialize upload statuses
    const statuses: FileUploadStatus[] = selectedFiles.map(file => ({
      file,
      progress: 0,
      status: 'pending' as const
    }))
    setUploadStatuses(statuses)

    // Upload files sequentially
    for (let i = 0; i < selectedFiles.length; i++) {
      try {
        // Update status to uploading
        setUploadStatuses(prev =>
          prev.map((status, idx) =>
            idx === i ? { ...status, status: 'uploading' } : status
          )
        )

        // Upload file
        await documentApi.upload(
          selectedFiles[i],
          documentType,
          (progress) => {
            setUploadStatuses(prev =>
              prev.map((status, idx) =>
                idx === i ? { ...status, progress } : status
              )
            )
          }
        )

        // Update status to success
        setUploadStatuses(prev =>
          prev.map((status, idx) =>
            idx === i ? { ...status, status: 'success', progress: 100 } : status
          )
        )
      } catch (error: any) {
        // Update status to error
        setUploadStatuses(prev =>
          prev.map((status, idx) =>
            idx === i
              ? {
                  ...status,
                  status: 'error',
                  error: error.response?.data?.detail || error.message || 'Upload failed'
                }
              : status
          )
        )
      }
    }

    setIsUploading(false)

    // If all uploads successful, close modal after delay and refresh stats
    setTimeout(() => {
      const allSuccess = uploadStatuses.every(s => s.status === 'success')
      if (allSuccess) {
        setShowUploadModal(false)
        setSelectedFiles([])
        setUploadStatuses([])
        // Refresh dashboard statistics
        refetchStats()
      }
    }, 2000)
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold">EchoGraph</h1>
              <p className="text-sm text-muted-foreground">Document Compliance & Comparison Platform</p>
            </div>
            <div className="flex items-center gap-3">
              {!loading && (
                <>
                  {authenticated && user ? (
                    <>
                      <div className="flex items-center gap-2 px-3 py-1.5 bg-muted rounded-md">
                        <User className="h-4 w-4" />
                        <span className="text-sm">{user.username || user.email}</span>
                      </div>
                      <Button variant="outline" onClick={handleSettings}>Settings</Button>
                      <Button onClick={() => setShowUploadModal(true)}>Upload Document</Button>
                      <Button variant="outline" onClick={logout}>
                        <LogOut className="h-4 w-4 mr-2" />
                        Logout
                      </Button>
                    </>
                  ) : (
                    <>
                      <Button variant="outline" onClick={login}>
                        <LogIn className="h-4 w-4 mr-2" />
                        Login
                      </Button>
                      <Button onClick={register}>Register</Button>
                    </>
                  )}
                </>
              )}
              {loading && (
                <div className="flex items-center gap-2 text-muted-foreground">
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span className="text-sm">Loading...</span>
                </div>
              )}
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        {/* Welcome Section */}
        <div className="mb-8">
          <h2 className="text-2xl font-semibold mb-2">Welcome to EchoGraph</h2>
          <p className="text-muted-foreground">
            Manage your norms, regulations, and company guidelines with AI-powered compliance analysis.
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Documents</CardTitle>
              <FileText className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {isLoadingStats ? '...' : stats?.total_documents ?? 0}
              </div>
              <p className="text-xs text-muted-foreground">
                {stats?.total_documents === 0 ? 'No documents uploaded yet' : 'Uploaded documents'}
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Norms & Regulations</CardTitle>
              <AlertCircle className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {isLoadingStats ? '...' : stats?.total_norms ?? 0}
              </div>
              <p className="text-xs text-muted-foreground">Official standards</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Company Guidelines</CardTitle>
              <CheckCircle className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {isLoadingStats ? '...' : stats?.total_guidelines ?? 0}
              </div>
              <p className="text-xs text-muted-foreground">Internal policies</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Relationships</CardTitle>
              <GitCompare className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {isLoadingStats ? '...' : stats?.total_relationships ?? 0}
              </div>
              <p className="text-xs text-muted-foreground">AI-detected connections</p>
            </CardContent>
          </Card>
        </div>

        {/* Stats state */}
        {statsError && (
          <div className="mb-4 text-sm text-red-600">
            Failed to load statistics. Please retry.
          </div>
        )}
        {isFetchingStats && !isLoadingStats && (
          <div className="mb-4 text-sm text-muted-foreground">
            Refreshing statistics…
          </div>
        )}

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Upload className="h-5 w-5" />
                Upload Documents
              </CardTitle>
              <CardDescription>
                Add new norms, regulations, or company guidelines to the system
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div
                className={`border-2 border-dashed rounded-lg p-8 text-center transition-colors ${
                  isDragging ? 'border-primary bg-primary/5' : 'border-border'
                }`}
                onDragEnter={handleDragEnter}
                onDragLeave={handleDragLeave}
                onDragOver={handleDragOver}
                onDrop={handleDrop}
              >
                <Upload className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
                <p className="text-sm text-muted-foreground mb-4">
                  Drag and drop files here, or click to browse
                </p>
                <input
                  ref={fileInputRef}
                  type="file"
                  multiple
                  className="hidden"
                  onChange={(e) => handleFileSelect(e.target.files)}
                  accept=".pdf,.docx,.doc"
                />
                <Button onClick={() => fileInputRef.current?.click()}>Select Files</Button>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Search className="h-5 w-5" />
                Search Documents
              </CardTitle>
              <CardDescription>
                Find documents using semantic search powered by AI
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <input
                  type="text"
                  placeholder="Search for documents, requirements, or clauses..."
                  className="w-full px-4 py-2 border border-border rounded-md focus:outline-none focus:ring-2 focus:ring-ring"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
                />
                <Button className="w-full" onClick={handleSearch}>
                  <Search className="h-4 w-4 mr-2" />
                  Search
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Recent Activity */}
        <Card>
          <CardHeader>
            <CardTitle>Recent Activity</CardTitle>
            <CardDescription>Latest changes and updates to your documents</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-center py-8 text-muted-foreground">
              <FileText className="h-12 w-12 mx-auto mb-2 opacity-50" />
              <p>No recent activity</p>
              <p className="text-sm">Upload your first document to get started</p>
            </div>
          </CardContent>
        </Card>
      </main>

      {/* Upload Modal */}
      {showUploadModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-background rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-2xl font-bold">Upload Documents</h2>
                <button
                  onClick={() => {
                    setShowUploadModal(false)
                    setSelectedFiles([])
                  }}
                  className="text-muted-foreground hover:text-foreground"
                >
                  <X className="h-6 w-6" />
                </button>
              </div>

              {/* File upload area */}
              <div
                className={`border-2 border-dashed rounded-lg p-8 mb-4 text-center transition-colors ${
                  isDragging ? 'border-primary bg-primary/5' : 'border-border'
                }`}
                onDragEnter={handleDragEnter}
                onDragLeave={handleDragLeave}
                onDragOver={handleDragOver}
                onDrop={handleDrop}
              >
                <Upload className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
                <p className="text-sm text-muted-foreground mb-4">
                  Drag and drop files here, or click to browse
                </p>
                <p className="text-xs text-muted-foreground mb-4">
                  Supported formats: PDF, DOCX, DOC
                </p>
                <Button onClick={() => fileInputRef.current?.click()}>
                  <Upload className="h-4 w-4 mr-2" />
                  Select Files
                </Button>
              </div>

              {/* Selected files list */}
              {selectedFiles.length > 0 && (
                <div className="mb-4">
                  <h3 className="font-semibold mb-2">Selected Files ({selectedFiles.length})</h3>
                  <div className="space-y-2 max-h-48 overflow-y-auto">
                    {selectedFiles.map((file, index) => {
                      const status = uploadStatuses[index]
                      return (
                        <div key={index} className="p-3 bg-muted rounded-md">
                          <div className="flex items-center justify-between mb-2">
                            <div className="flex items-center gap-2 flex-1 min-w-0">
                              {status?.status === 'success' ? (
                                <CheckCircle className="h-4 w-4 text-green-500 flex-shrink-0" />
                              ) : status?.status === 'error' ? (
                                <AlertCircle className="h-4 w-4 text-red-500 flex-shrink-0" />
                              ) : status?.status === 'uploading' ? (
                                <Loader2 className="h-4 w-4 animate-spin flex-shrink-0" />
                              ) : (
                                <FileText className="h-4 w-4 flex-shrink-0" />
                              )}
                              <span className="text-sm truncate">{file.name}</span>
                              <span className="text-xs text-muted-foreground flex-shrink-0">
                                ({(file.size / 1024).toFixed(1)} KB)
                              </span>
                            </div>
                            {!status && (
                              <button
                                onClick={() => removeFile(index)}
                                className="text-muted-foreground hover:text-destructive flex-shrink-0"
                                disabled={isUploading}
                              >
                                <X className="h-4 w-4" />
                              </button>
                            )}
                          </div>
                          {status && status.status === 'uploading' && (
                            <Progress value={status.progress} className="h-2" />
                          )}
                          {status?.status === 'error' && (
                            <p className="text-xs text-red-500 mt-1">{status.error}</p>
                          )}
                          {status?.status === 'success' && (
                            <p className="text-xs text-green-600 mt-1">Upload successful!</p>
                          )}
                        </div>
                      )
                    })}
                  </div>
                </div>
              )}

              {/* Document type selection */}
              {selectedFiles.length > 0 && (
                <div className="mb-4">
                  <label className="block text-sm font-medium mb-2">Document Type</label>
                  <select
                    className="w-full px-4 py-2 border border-border rounded-md focus:outline-none focus:ring-2 focus:ring-ring"
                    value={documentType}
                    onChange={(e) => setDocumentType(e.target.value as 'norm' | 'guideline')}
                    disabled={isUploading}
                  >
                    <option value="norm">Norm / Regulation</option>
                    <option value="guideline">Company Guideline</option>
                  </select>
                </div>
              )}

              {/* Action buttons */}
              <div className="flex gap-2 justify-end">
                <Button
                  variant="outline"
                  onClick={() => {
                    setShowUploadModal(false)
                    setSelectedFiles([])
                    setUploadStatuses([])
                  }}
                  disabled={isUploading}
                >
                  {isUploading ? 'Uploading...' : 'Cancel'}
                </Button>
                <Button
                  onClick={handleUpload}
                  disabled={selectedFiles.length === 0 || isUploading}
                >
                  {isUploading ? (
                    <>
                      <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                      Uploading...
                    </>
                  ) : (
                    <>Upload {selectedFiles.length > 0 && `(${selectedFiles.length})`}</>
                  )}
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Settings Modal */}
      {showSettings && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-background rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-2xl font-bold">Settings</h2>
                <button
                  onClick={() => setShowSettings(false)}
                  className="text-muted-foreground hover:text-foreground"
                >
                  <X className="h-6 w-6" />
                </button>
              </div>

              <div className="space-y-6">
                <div>
                  <h3 className="text-lg font-semibold mb-3">General Settings</h3>
                  <div className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium mb-2">API Endpoint</label>
                      <input
                        type="text"
                        defaultValue="http://localhost:8000"
                        className="w-full px-4 py-2 border border-border rounded-md focus:outline-none focus:ring-2 focus:ring-ring"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium mb-2">Theme</label>
                      <select className="w-full px-4 py-2 border border-border rounded-md focus:outline-none focus:ring-2 focus:ring-ring">
                        <option value="light">Light</option>
                        <option value="dark">Dark</option>
                        <option value="system">System</option>
                      </select>
                    </div>
                  </div>
                </div>

                <div>
                  <h3 className="text-lg font-semibold mb-3">About</h3>
                  <p className="text-sm text-muted-foreground mb-2">
                    EchoGraph - Document Compliance & Comparison Platform
                  </p>
                  <p className="text-xs text-muted-foreground">
                    Version 0.1.0 | MIT License
                  </p>
                </div>
              </div>

              <div className="flex gap-2 justify-end mt-6">
                <Button onClick={() => setShowSettings(false)}>Close</Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
