import api from '@/lib/api'
import { Document, DocumentDetail, Statistics } from '@/types'

export interface ListDocumentsParams {
  page?: number
  page_size?: number
  document_type?: string
  category?: string
  status?: string
  search?: string
}

export interface ListDocumentsResponse {
  total: number
  page: number
  page_size: number
  documents: Document[]
}

export const documentsService = {
  async list(params: ListDocumentsParams = {}): Promise<ListDocumentsResponse> {
    const response = await api.get('/documents', { params })
    return response.data
  },

  async get(id: number): Promise<DocumentDetail> {
    const response = await api.get(`/documents/${id}`)
    return response.data
  },

  async upload(formData: FormData, onProgress?: (progress: number) => void): Promise<Document> {
    const response = await api.post('/documents/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      onUploadProgress: (progressEvent) => {
        if (progressEvent.total) {
          const progress = (progressEvent.loaded / progressEvent.total) * 100
          onProgress?.(progress)
        }
      },
    })
    return response.data
  },

  async update(id: number, data: Partial<Document>): Promise<Document> {
    const response = await api.put(`/documents/${id}`, data)
    return response.data
  },

  async delete(id: number): Promise<void> {
    await api.delete(`/documents/${id}`)
  },

  async getStatistics(): Promise<Statistics> {
    const response = await api.get('/documents/statistics/dashboard')
    return response.data
  },
}
