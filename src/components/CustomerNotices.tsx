import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { StatusBadge } from './StatusBadge'
import { formatUserError } from '../lib/errors'
import type { DashboardRow } from '../lib/dashboard-data'

export function CustomerNotices() {
  const [items, setItems] = useState<DashboardRow[]>([])
  const [error, setError] = useState('')
  const [revision, setRevision] = useState(0)
  useEffect(() => {
    let active = true
    void supabase.rpc('portal_get_onboarding_applications').then(({ data, error }) => {
      if (!active) return
      if (error) setError(formatUserError(error))
      else { setItems((data ?? []) as DashboardRow[]); setError('') }
    })
    const timer = window.setInterval(() => { if (document.visibilityState === 'visible') setRevision((v) => v + 1) }, 60000)
    return () => { active = false; window.clearInterval(timer) }
  }, [revision])
  return <section className="rounded-xl border bg-white p-4" aria-label="Pemberitahuan pendaftaran"><div className="flex justify-between gap-3"><h2 className="font-bold">Kabar pendaftaran Anda</h2><button onClick={() => setRevision((v) => v + 1)} className="rounded-lg border px-3">Perbarui status</button></div><p className="text-sm text-slate-600">Diperiksa otomatis setiap menit saat halaman aktif.</p>{error && <p role="alert">{error}</p>}<div aria-live="polite">{items.map((item, index) => <p className="mt-3" key={String(item.id ?? index)}><StatusBadge value={item.status} /> {String(item.return_reason ?? '')}</p>)}</div></section>
}
