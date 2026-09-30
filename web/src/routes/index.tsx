import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/')({ component: Home })

function Home() {
  return (
    <main className="min-h-screen bg-canvas p-8 text-ink">
      <h1 className="text-2xl font-semibold">Chatwooter</h1>
    </main>
  )
}
