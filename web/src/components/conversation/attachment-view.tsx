// Anexos de uma mensagem: porta de bubbles/{Image,Video,Audio,File}.vue e chips/*.vue (sem galeria).
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import type { Attachment } from '../../api/types'
import { Icon } from '../next/icon'
import { fileNameOf } from './file-name'

function ImageAttachment({ attachment }: { attachment: Attachment }) {
  const { t } = useTranslation()
  const [broken, setBroken] = useState(false)
  if (broken) {
    return (
      <div className="flex items-center gap-1 rounded-lg text-center text-n-slate-11">
        <Icon name="ph-image-broken" className="size-4" />
        <p className="mb-0">{t('COMPONENTS.MEDIA.IMAGE_UNAVAILABLE')}</p>
      </div>
    )
  }
  return (
    <div className="group relative overflow-hidden rounded-lg">
      <img src={attachment.data_url} alt="" onError={() => setBroken(true)} />
    </div>
  )
}

function FileAttachment({ attachment }: { attachment: Attachment }) {
  const { t } = useTranslation()
  const name = fileNameOf(attachment.data_url, t('CONVERSATION.UNKNOWN_FILE_TYPE'))
  return (
    <div className="flex items-center gap-2 p-2 text-n-slate-12">
      <span className="grid size-8 place-content-center rounded-lg bg-n-alpha-3">
        <Icon name="ph-file" className="size-4" />
      </span>
      <span className="min-w-0 flex-1 truncate">{name}</span>
      <a
        href={attachment.data_url}
        target="_blank"
        rel="noopener noreferrer"
        download
        className="flex items-center gap-1 text-n-slate-11 hover:text-n-slate-12"
      >
        <Icon name="ph-download-simple" className="size-4" />
        <span className="sr-only">{t('CONVERSATION.DOWNLOAD')}</span>
      </a>
    </div>
  )
}

export function AttachmentView({ attachment }: { attachment: Attachment }) {
  switch (attachment.file_type) {
    case 'image':
      return <ImageAttachment attachment={attachment} />
    case 'video':
      return <video controls className="max-w-full rounded-lg" src={attachment.data_url} />
    case 'audio':
      return <audio controls className="p-2" src={attachment.data_url} />
    default:
      return <FileAttachment attachment={attachment} />
  }
}
