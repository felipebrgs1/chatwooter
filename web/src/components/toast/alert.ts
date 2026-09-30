// Barramento de toasts: equivale ao `useAlert` do Chatwoot (emitter 'newToastMessage').
export interface Toast {
  id: number
  message: string
  duration: number
}

type Listener = (toast: Toast) => void

const DEFAULT_DURATION = 2500
const listeners = new Set<Listener>()
let nextId = 1

export function showAlert(message: string, options: { duration?: number } = {}) {
  const toast = { id: nextId++, message, duration: options.duration ?? DEFAULT_DURATION }
  listeners.forEach((listener) => listener(toast))
}

export function subscribeToAlerts(listener: Listener) {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}
