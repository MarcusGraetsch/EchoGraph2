export enum DocumentType {
  NORM = 'norm',
  GUIDELINE = 'guideline',
}

export enum DocumentStatus {
  UPLOADING = 'uploading',
  PROCESSING = 'processing',
  EXTRACTING = 'extracting',
  ANALYZING = 'analyzing',
  EMBEDDING = 'embedding',
  READY = 'ready',
  ERROR = 'error',
}

export enum RelationshipType {
  COMPLIANCE = 'compliance',
  CONFLICT = 'conflict',
  REFERENCE = 'reference',
  SIMILAR = 'similar',
  SUPERSEDES = 'supersedes',
}

export enum ValidationStatus {
  AUTO_DETECTED = 'auto_detected',
  PENDING_REVIEW = 'pending_review',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

export interface Document {
  id: number
  title: string
  document_type: DocumentType
  file_path: string
  file_size?: number
  file_type?: string
  author?: string
  category?: string
  tags?: string[]
  description?: string
  version?: string
  status: DocumentStatus
  error_message?: string
  upload_date: string
  processed_date?: string
  updated_at: string
}

export interface DocumentChunk {
  id: number
  chunk_index: number
  chunk_text: string
  char_count: number
  section_title?: string
  page_number?: number
}

export interface DocumentDetail extends Document {
  chunks: DocumentChunk[]
}

export interface DocumentRelationship {
  id: number
  source_doc_id: number
  target_doc_id: number
  relationship_type: RelationshipType
  confidence: number
  summary?: string
  details?: Record<string, any>
  validation_status: ValidationStatus
  validated_by?: string
  validation_notes?: string
  validated_at?: string
  created_at: string
  updated_at: string
}

export interface DocumentRelationshipDetail extends DocumentRelationship {
  source_document: Document
  target_document: Document
}

export interface UploadProgress {
  filename: string
  status: string
  progress: number
  message?: string
}

export interface Statistics {
  total_documents: number
  total_norms: number
  total_guidelines: number
  total_relationships: number
  pending_validations: number
  approved_relationships: number
  rejected_relationships: number
}

export interface User {
  id: number
  email: string
  username: string
  full_name?: string
  is_active: boolean
  is_admin: boolean
  is_reviewer: boolean
  created_at: string
  last_login?: string
}
