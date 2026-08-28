export function GooglePlayIcon({ className = "size-6" }: { className?: string }) {
  return <svg viewBox="0 0 24 24" aria-hidden="true" className={className}>
    <path fill="#00D7FE" d="M3.6 2.2c-.4.4-.6 1-.6 1.7v16.2c0 .7.2 1.3.6 1.7l9.5-9.8-9.5-9.8Z" />
    <path fill="#00F076" d="M16.3 8.7 5.5 2.5c-.7-.4-1.4-.4-1.9-.1l9.5 9.6 3.2-3.3Z" />
    <path fill="#FFCE00" d="m13.1 12 3.2 3.3 3.7-2.1c1.1-.6 1.1-1.7 0-2.3l-3.7-2.1-3.2 3.2Z" />
    <path fill="#F34A55" d="M3.6 21.8c.5.3 1.2.3 1.9-.1l10.8-6.3-3.2-3.3-9.5 9.7Z" />
  </svg>;
}

export function WindowsIcon({ className = "size-6" }: { className?: string }) {
  return <svg viewBox="0 0 24 24" aria-hidden="true" className={className} fill="currentColor">
    <path d="M2.5 4.8 10.8 3.6v7.6H2.5V4.8Zm9.4-1.4 9.6-1.4v9.2h-9.6V3.4ZM2.5 12.3h8.3v7.6l-8.3-1.2v-6.4Zm9.4 0h9.6v9.2l-9.6-1.4v-7.8Z" />
  </svg>;
}
