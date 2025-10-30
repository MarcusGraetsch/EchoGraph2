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
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
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

  // Search documents
  search: async (query: string) => {
    return api.post('/search/', { query })
  },
}

export default api
