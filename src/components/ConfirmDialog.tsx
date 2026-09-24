import { useEffect, useId, useRef, useState, type ReactNode } from 'react'
import { formatUserError } from '../lib/errors'

export function ConfirmDialog({ title, children, onConfirm, onClose }: {
  title: string; children: ReactNode; onConfirm: () => Promise<void>; onClose: () => void
}) {
  const dialog = useRef<HTMLDialogElement>(null)
  const locked = useRef(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const titleId = useId()
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null
    const element = dialog.current
    element?.showModal()
    return () => { element?.close(); previous?.focus() }
  }, [])
  const confirm = async () => {
    if (locked.current) return
    locked.current = true
    setBusy(true)
    try { await onConfirm(); onClose() }
    catch (error) { setError(formatUserError(error)) }
    finally { locked.current = false; setBusy(false) }
  }
  return <dialog ref={dialog} aria-labelledby={titleId} onCancel={(event) => { event.preventDefault(); if (!locked.current) onClose() }} className="confirmation">
    <h2 id={titleId} className="text-xl font-bold">{title}</h2>
    <div className="my-5 space-y-3">{children}</div>
    {error && <p role="alert" className="text-red-800">{error}</p>}
    <p className="text-sm text-slate-600">Periksa kembali data sebelum melanjutkan.</p>
    <div className="mt-6 flex justify-end gap-3">
      <button autoFocus disabled={busy} onClick={onClose} className="rounded-lg border px-4">Batal</button>
      <button disabled={busy} onClick={() => void confirm()} className="rounded-lg bg-green-800 px-4 text-white">{busy ? 'Memproses…' : 'Konfirmasi'}</button>
    </div>
  </dialog>
}
