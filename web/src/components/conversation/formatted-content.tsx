// Equivale a MessageFormatter + v-dompurify-html do Chatwoot, mas sem HTML: o texto do cliente nunca é
// interpretado, só os tokens markdown que reconhecemos viram elementos React.
import { Fragment, type ReactNode } from 'react'

const TOKEN = /(\*\*[^*\n]+\*\*|\*[^*\s][^*\n]*\*|_[^_\s][^_\n]*_|`[^`\n]+`|https?:\/\/[^\s<]+)/g
const TRAILING = /[).,;:!?]+$/

function inline(text: string): ReactNode[] {
  return text.split(TOKEN).map((part, i) => {
    if (part.startsWith('**') && part.endsWith('**') && part.length > 4)
      return <strong key={i}>{part.slice(2, -2)}</strong>
    if (part.startsWith('`') && part.endsWith('`') && part.length > 2)
      return <code key={i}>{part.slice(1, -1)}</code>
    if (
      (part.startsWith('*') && part.endsWith('*')) ||
      (part.startsWith('_') && part.endsWith('_'))
    )
      return part.length > 2 ? <em key={i}>{part.slice(1, -1)}</em> : part
    if (/^https?:\/\//.test(part)) {
      const trailing = TRAILING.exec(part)?.[0] ?? ''
      const url = part.slice(0, part.length - trailing.length)
      return (
        <Fragment key={i}>
          <a href={url} target="_blank" rel="noopener noreferrer nofollow" className="underline">
            {url}
          </a>
          {trailing}
        </Fragment>
      )
    }
    return part
  })
}

export function FormattedContent({ content }: { content: string }) {
  return (
    <span className="whitespace-pre-wrap break-words [&_code]:rounded [&_code]:bg-n-alpha-black1 [&_code]:px-1">
      {content.split('\n').map((line, i) => (
        <Fragment key={i}>
          {i > 0 && <br />}
          {inline(line)}
        </Fragment>
      ))}
    </span>
  )
}
