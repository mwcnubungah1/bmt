import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { formatUserError } from '../lib/errors'
import { ErrorState, LoadingState } from './DashboardStates'
import { Users, ClipboardCheck, Landmark, CalendarClock } from 'lucide-react'
import { TellerSavingsDeposit } from './TellerSavingsDeposit'
import { TellerCashSession } from './TellerCashSession'
import { TellerLoanOperations } from './TellerLoanOperations'
import { ManagerSavingsProducts } from './ManagerSavingsProducts'

const labels: Record<string, string> = { customers: 'Nasabah dalam akses Anda', onboarding_pending: 'Pendaftaran menunggu', loans_pending: 'Pembiayaan menunggu', followups_due: 'Tindak lanjut jatuh tempo' }
const icons = [Users, ClipboardCheck, Landmark, CalendarClock]
export function WorkSummary({ role = '', onNavigate = (view, status) => { window.location.href = `${window.location.pathname}?view=${view}${status ? `&status=${status}` : ''}` } }: { role?: string; onNavigate?: (view: string, status?: string) => void }) {
  const [data, setData] = useState<Record<string, number> | null>(null)
  const [error, setError] = useState('')
  const [revision, setRevision] = useState(0)
  const [cashSessionOpen, setCashSessionOpen] = useState(false)
  const handleCashSession = useCallback((open: boolean) => { setCashSessionOpen(open); setRevision((v) => v + 1) }, [])
  const download = () => {
    if (!data) return
    const csv = '\uFEFFIndikator,Jumlah\r\n' + Object.entries(labels).map(([key, label]) => `${label},${Number(data[key] ?? 0)}`).join('\r\n')
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }))
    const link = document.createElement('a')
    link.href = url; link.download = 'ringkasan-bmt.csv'; link.click()
    window.setTimeout(() => URL.revokeObjectURL(url), 1000)
  }
  useEffect(() => {
    let active = true
    void supabase.rpc('workbench_summary').then(({ data, error }) => {
      if (!active) return
      if (error) setError(formatUserError(error))
      else { setData(data as Record<string, number>); setError('') }
    })
    return () => { active = false }
  }, [revision])
  return <><section aria-label="Ringkasan pekerjaan" className="space-y-3">
    <div className="flex flex-wrap justify-between gap-3"><h2 className="font-bold">Ringkasan pekerjaan</h2><button className="rounded-lg border px-3 text-sm" onClick={() => setRevision((v) => v + 1)}>Perbarui ringkasan</button></div>
    <p className="text-xs text-slate-500">Ringkasan seluruh data sesuai hak akses Anda.</p>
    <button disabled={!data || Boolean(error)} onClick={download} className="rounded-lg border px-3 text-sm">Unduh ringkasan CSV</button>
    {error ? <ErrorState message={error} onRetry={() => setRevision((v) => v + 1)} /> : !data ? <LoadingState /> : <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">{Object.entries(labels).map(([key, label], index) => { const Icon = icons[index]; const clickable = key === 'loans_pending'; const content = <><div className={`mb-4 inline-flex rounded-xl p-3 ${index === 3 ? 'bg-amber-50 text-amber-700' : 'bg-green-50 text-green-800'}`}><Icon size={22} /></div><p className="text-sm text-slate-600">{label}</p><p className="mt-2 text-3xl font-bold tabular-nums">{data[key] ?? 0}</p>{clickable && <p className="mt-2 text-xs font-semibold text-green-700">Buka pengajuan →</p>}</>; return clickable ? <button key={key} type="button" onClick={() => onNavigate?.('loan_applications', 'SUBMITTED')} className="role-panel text-left transition hover:border-green-500 hover:shadow-md">{content}</button> : <div key={key} className="role-panel">{content}</div> })}</div>}
  </section>{['teller', 'superadmin'].includes(role.toLowerCase()) && <><TellerCashSession onChange={handleCashSession} /><TellerSavingsDeposit cashSessionOpen={cashSessionOpen} onComplete={() => setRevision((v) => v + 1)} /><TellerLoanOperations cashSessionOpen={cashSessionOpen} onComplete={() => setRevision((v) => v + 1)} /></>}{['manager', 'superadmin'].includes(role.toLowerCase()) && <ManagerSavingsProducts />}</>
}
