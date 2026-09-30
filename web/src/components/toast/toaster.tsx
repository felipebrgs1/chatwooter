// Porta de v3/components/SnackBar/Container.vue + Item.vue (sem a variante com link de ação, que ninguém usa ainda).
import { useEffect, useState } from 'react'

import { subscribeToAlerts, type Toast } from './alert'

export function Toaster() {
  const [toasts, setToasts] = useState<Toast[]>([])

  useEffect(
    () =>
      subscribeToAlerts((toast) => {
        setToasts((current) => [...current, toast])
        window.setTimeout(() => {
          setToasts((current) => current.filter((t) => t.id !== toast.id))
        }, toast.duration)
      }),
    [],
  )

  return (
    <div className="fixed left-0 right-0 top-10 z-50 mx-auto max-w-[40rem] overflow-hidden text-center">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          role="status"
          className="mb-4 inline-flex min-w-[22rem] max-w-[40rem] items-center justify-center rounded-md bg-n-slate-12 px-4 py-3 drop-shadow-md dark:bg-n-slate-7"
        >
          <div className="text-sm font-medium text-white">{toast.message}</div>
        </div>
      ))}
    </div>
  )
}
