import axios from 'axios'

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'

export const api = axios.create({
  baseURL: `${API_URL}/api`,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Store for Keycloak token
let keycloakToken: string | null = null

// Function to set Keycloak token (called by KeycloakProvider)
export const setKeycloakToken = (token: string | null) => {
  keycloakToken = token
}

// Add auth token to requests
api.interceptors.request.use((config) => {
  // Use Keycloak token if available, otherwise fall back to localStorage
  const token = keycloakToken || localStorage.getItem('token')
  console.log('🌐 API Request:', config.url)
  console.log('🔑 Token available:', token ? 'YES' : 'NO')
  if (token) {
    console.log('🔑 Token length:', token.length)
    config.headers.Authorization = `Bearer ${token}`
  } else {
    console.warn('⚠️ No token available for request!')
  }
  return config
})

// Handle auth errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Clear old localStorage token if present
      localStorage.removeItem('token')
      // Token expired or invalid - Keycloak will handle re-authentication
      console.error('Authentication failed - token may be expired')
    }
    return Promise.reject(error)
  }
)

// Document API functions
export const documentApi = {
  // Upload a document
  upload: async (
    file: File,
    documentType: 'norm' | 'guideline',
    onProgress?: (progress: number) => void
  ) => {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('document_type', documentType)
    formData.append('title', file.name)

    return api.post('/documents/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      onUploadProgress: (progressEvent) => {
        if (onProgress && progressEvent.total) {
          const progress = Math.round((progressEvent.loaded * 100) / progressEvent.total)
          onProgress(progress)
        }
      },
    })
  },

  // Get all documents
  list: async () => {
    return api.get('/documents/')
  },

  // Get document by ID
  get: async (id: number) => {
    return api.get(`/documents/${id}`)
  },

  // Search documents (semantic search)
  search: async (
    query: string,
    options?: {
      document_type?: 'norm' | 'guideline'
      limit?: number
      threshold?: number
    }
  ) => {
    return api.post('/search/', {
      query,
      document_type: options?.document_type,
      limit: options?.limit || 20,
      threshold: options?.threshold || 0.5,
    })
  },

  // Get dashboard statistics
  getStatistics: async () => {
    return api.get('/documents/statistics/dashboard')
  },

  // Delete a document
  delete: async (id: number) => {
    return api.delete(`/documents/${id}`)
  },
}

// Relationships API functions
export const relationshipsApi = {
  // Get all relationships for a document
  getByDocument: async (documentId: number, validationStatus?: string) => {
    const params = validationStatus ? `?validation_status=${validationStatus}` : ''
    return api.get(`/relationships/document/${documentId}${params}`)
  },

  // Get a single relationship by ID
  get: async (id: number) => {
    return api.get(`/relationships/${id}`)
  },

  // Compare multiple documents
  compare: async (documentIds: number[], threshold: number = 0.7) => {
    return api.post('/relationships/compare', {
      document_ids: documentIds,
      threshold,
    })
  },

  // Get pending relationships for review
  getPending: async (limit: number = 50) => {
    return api.get(`/relationships/pending/review?limit=${limit}`)
  },

  // Validate a relationship
  validate: async (
    relationshipId: number,
    validationStatus: 'approved' | 'rejected' | 'pending_review',
    notes?: string
  ) => {
    return api.post(`/relationships/${relationshipId}/validate`, {
      validation_status: validationStatus,
      validation_notes: notes,
    })
  },

  // Delete a relationship
  delete: async (id: number) => {
    return api.delete(`/relationships/${id}`)
  },
}

export default api
