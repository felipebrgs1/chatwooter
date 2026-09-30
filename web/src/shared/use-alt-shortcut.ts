// Port de dashboard/composables/useKeyboardEvents.js; estes atalhos não dependem do layout QWERTZ.
import { useEffect } from 'react'

export function useAltShortcut(code: string, action: () => void, allowOnFocusedInput = false) {
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (!event.altKey || event.ctrlKey || event.metaKey || event.shiftKey || event.code !== code)
        return

      const target = event.target instanceof HTMLElement ? event.target : document.activeElement
      const typeable = target?.closest(
        'input, textarea, ninja-keys, [contenteditable="true"], .ProseMirror',
      )
      if (typeable && !allowOnFocusedInput) return
      event.preventDefault()
      action()
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [code, action, allowOnFocusedInput])
}
