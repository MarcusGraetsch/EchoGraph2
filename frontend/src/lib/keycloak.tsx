'use client'

/**
 * Keycloak Authentication Context
 *
 * This module provides Keycloak OIDC authentication for the EchoGraph frontend.
 * It handles login, logout, token management, and provides user information.
 */

import React, { createContext, useContext, useEffect, useState, useCallback } from 'react'
import Keycloak from 'keycloak-js'
import { setKeycloakToken } from './api'

// Keycloak configuration from environment variables
const KEYCLOAK_URL = process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080'
const KEYCLOAK_REALM = process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'echograph'
const KEYCLOAK_CLIENT_ID = process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'echograph-frontend'

// User information interface
export interface KeycloakUser {
  id: string
  username: string
  email?: string
  emailVerified: boolean
  firstName?: string
  lastName?: string
  roles: string[]
  isAdmin: boolean
}

// Keycloak context interface
interface KeycloakContextType {
  keycloak: Keycloak | null
  authenticated: boolean
  user: KeycloakUser | null
  token: string | null
  login: () => void
  logout: () => void
  register: () => void
  updateToken: () => Promise<boolean>
  hasRole: (role: string) => boolean
  isAdmin: boolean
  loading: boolean
}

// Create context
const KeycloakContext = createContext<KeycloakContextType>({
  keycloak: null,
  authenticated: false,
  user: null,
  token: null,
  login: () => {},
  logout: () => {},
  register: () => {},
  updateToken: async () => false,
  hasRole: () => false,
  isAdmin: false,
  loading: true,
})

// Custom hook to use Keycloak context
export const useKeycloak = () => {
  const context = useContext(KeycloakContext)
  if (!context) {
    throw new Error('useKeycloak must be used within KeycloakProvider')
  }
  return context
}

// Keycloak Provider component
export const KeycloakProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [keycloak, setKeycloak] = useState<Keycloak | null>(null)
  const [authenticated, setAuthenticated] = useState(false)
  const [user, setUser] = useState<KeycloakUser | null>(null)
  const [token, setToken] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  // Extract user information from Keycloak token
  const extractUser = useCallback((kc: Keycloak): KeycloakUser | null => {
    if (!kc.tokenParsed) return null

    const tokenParsed = kc.tokenParsed as any
    const realmRoles = tokenParsed.realm_access?.roles || []
    const isAdmin = realmRoles.includes('admin') || realmRoles.includes('echograph-admin')

    return {
      id: tokenParsed.sub || '',
      username: tokenParsed.preferred_username || '',
      email: tokenParsed.email,
      emailVerified: tokenParsed.email_verified || false,
      firstName: tokenParsed.given_name,
      lastName: tokenParsed.family_name,
      roles: realmRoles,
      isAdmin,
    }
  }, [])

  // Initialize Keycloak
  useEffect(() => {
    const initKeycloak = async () => {
      try {
        // Create Keycloak instance
        const kc = new Keycloak({
          url: KEYCLOAK_URL,
          realm: KEYCLOAK_REALM,
          clientId: KEYCLOAK_CLIENT_ID,
        })

        // Initialize Keycloak
        const authenticated = await kc.init({
          onLoad: 'check-sso',
          pkceMethod: 'S256',
          checkLoginIframe: false,
        })

        setKeycloak(kc)
        setAuthenticated(authenticated)

        if (authenticated) {
          const token = kc.token || null
          setToken(token)
          setKeycloakToken(token)
          setUser(extractUser(kc))
        }

        // Set up token refresh
        kc.onTokenExpired = () => {
          kc.updateToken(30)
            .then((refreshed) => {
              if (refreshed) {
                const token = kc.token || null
                setToken(token)
                setKeycloakToken(token)
                console.log('Token refreshed')
              }
            })
            .catch(() => {
              console.error('Failed to refresh token')
              setAuthenticated(false)
              setToken(null)
              setKeycloakToken(null)
              setUser(null)
            })
        }

        setLoading(false)
      } catch (error) {
        console.error('Keycloak initialization error:', error)
        setLoading(false)
      }
    }

    initKeycloak()
  }, [extractUser])

  // Login function
  const login = useCallback(() => {
    keycloak?.login()
  }, [keycloak])

  // Logout function
  const logout = useCallback(() => {
    keycloak?.logout()
  }, [keycloak])

  // Register function
  const register = useCallback(() => {
    keycloak?.register()
  }, [keycloak])

  // Update token function
  const updateToken = useCallback(async (): Promise<boolean> => {
    if (!keycloak) return false

    try {
      const refreshed = await keycloak.updateToken(30)
      if (refreshed) {
        const token = keycloak.token || null
        setToken(token)
        setKeycloakToken(token)
        setUser(extractUser(keycloak))
      }
      return true
    } catch (error) {
      console.error('Failed to update token:', error)
      setAuthenticated(false)
      setToken(null)
      setKeycloakToken(null)
      setUser(null)
      return false
    }
  }, [keycloak, extractUser])

  // Check if user has a specific role
  const hasRole = useCallback(
    (role: string): boolean => {
      return user?.roles.includes(role) || false
    },
    [user]
  )

  // Check if user is admin
  const isAdmin = user?.isAdmin || false

  const value: KeycloakContextType = {
    keycloak,
    authenticated,
    user,
    token,
    login,
    logout,
    register,
    updateToken,
    hasRole,
    isAdmin,
    loading,
  }

  return (
    <KeycloakContext.Provider value={value}>
      {children}
    </KeycloakContext.Provider>
  )
}

// HOC to protect routes that require authentication
export const withAuth = <P extends object>(
  Component: React.ComponentType<P>
): React.FC<P> => {
  return function AuthenticatedComponent(props: P) {
    const { authenticated, login, loading } = useKeycloak()

    useEffect(() => {
      if (!loading && !authenticated) {
        login()
      }
    }, [authenticated, login, loading])

    if (loading) {
      return (
        <div className="flex items-center justify-center min-h-screen">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
            <p className="mt-4 text-gray-600">Loading...</p>
          </div>
        </div>
      )
    }

    if (!authenticated) {
      return null
    }

    return <Component {...props} />
  }
}
