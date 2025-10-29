'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function Home() {
  const router = useRouter()

  useEffect(() => {
    // Redirect to dashboard
    router.push('/dashboard')
  }, [router])

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="text-center">
        <h1 className="text-4xl font-bold mb-4">EchoGraph</h1>
        <p className="text-muted-foreground">Loading...</p>
      </div>
    </div>
  )
}
