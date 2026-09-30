const icons: Record<string, string> = { telegram: 'ph-telegram-logo', whatsapp: 'ph-whatsapp-logo' }

/** Nome do ícone Phosphor do canal (ChannelIcon.vue), para quem desenha o ícone por nome (ex.: opções de filtro). */
export function channelIconName(channel: string) {
  return icons[channel.replace(/^Channel::/, '').toLowerCase()] ?? 'ph-tray'
}
