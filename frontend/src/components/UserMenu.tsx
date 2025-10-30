'use client'

/**
 * User Menu Component
 *
 * Displays user authentication status and provides login/logout functionality.
 * Shows user information when authenticated.
 */

import { useKeycloak } from '@/lib/keycloak'
import { Button } from '@/components/ui/button'
import { User, LogOut, LogIn, UserPlus } from 'lucide-react'

export function UserMenu() {
  const { authenticated, user, login, logout, register, loading } = useKeycloak()

  if (loading) {
    return (
      <div className="flex items-center space-x-2">
        <div className="h-8 w-8 rounded-full bg-gray-200 animate-pulse"></div>
      </div>
    )
  }

  if (!authenticated) {
    return (
      <div className="flex items-center space-x-2">
        <Button
          variant="ghost"
          size="sm"
          onClick={register}
          className="flex items-center space-x-1"
        >
          <UserPlus className="h-4 w-4" />
          <span>Register</span>
        </Button>
        <Button
          size="sm"
          onClick={login}
          className="flex items-center space-x-1"
        >
          <LogIn className="h-4 w-4" />
          <span>Login</span>
        </Button>
      </div>
    )
  }

  return (
    <div className="flex items-center space-x-3">
      <div className="flex items-center space-x-2 px-3 py-1 bg-gray-100 rounded-lg">
        <User className="h-4 w-4 text-gray-600" />
        <div className="flex flex-col">
          <span className="text-sm font-medium text-gray-900">
            {user?.firstName || user?.username}
          </span>
          {user?.isAdmin && (
            <span className="text-xs text-blue-600 font-medium">Admin</span>
          )}
        </div>
      </div>
      <Button
        variant="ghost"
        size="sm"
        onClick={logout}
        className="flex items-center space-x-1"
      >
        <LogOut className="h-4 w-4" />
        <span>Logout</span>
      </Button>
    </div>
  )
}
