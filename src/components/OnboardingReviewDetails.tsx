import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { formatUserError } from '../lib/errors'
import { StatusBadge } from './StatusBadge'
import { ErrorState, LoadingState } from './DashboardStates'

async function loadDetails(id: string) {
  const [application, addresses, employment, history] = await Promise.all([
    supabase.from('onboarding_applications').select('full_name,nik,birth_place,birth_date,phone,mother_name,occupation,monthly_income,source_of_funds').eq('id', id).single(),
    supabase.from('onboarding_addresses').select('address,province,city,district,village,postal_code').eq('application_id', id),
    supabase.from('onboarding_employment').select('employment_type,occupation,monthly_income').eq('application_id', id),
    supabase.from('onboarding_status_history').select('id,to_status,changed_at,reason').eq('application_id', id).order('changed_at'),
  ])
  const error = application.error ?? addresses.error ?? employment.error ?? history.error
  if (error) throw error
  return { application: application.data, addresses: addresses.data ?? [], employment: employment.data ?? [], history: history.data ?? [] }
}
const labels: Record<string, string> = { full_name: 'Nama lengkap', nik: 'NIK', birth_place: 'Tempat lahir', birth_date: 'Tanggal lahir', phone: 'Telepon', mother_name: 'Nama ibu', occupation: 'Pekerjaan', monthly_income: 'Pendapatan bulanan', source_of_funds: 'Sumber dana' }
export function OnboardingReviewDetails({ id, onClose }: { id: string; onClose?: () => void }) {
  const [data, setData] = useState<Awaited<ReturnType<typeof loadDetails>> | null>(null)
  const [error, setError] = useState('')
  const [revision, setRevision] = useState(0)
  useEffect(() => {
    let active = true
    void loadDetails(id).then((data) => { if (active) { setData(data); setError('') } }).catch((error: unknown) => { if (active) setError(formatUserError(error)) })
    return () => { active = false }
  }, [id, revision])
  if (error) return <ErrorState message={error} onRetry={() => setRevision((v) => v + 1)} />
  if (!data) return <LoadingState />
  return <section className="rounded-xl border bg-white p-5"><div className="mb-5 flex items-center justify-between gap-3"><h3 className="font-bold">Berkas pemeriksaan dan riwayat</h3>{onClose && <button type="button" onClick={onClose} className="min-h-11 rounded-xl border px-3 text-sm font-semibold">Tutup</button>}</div><dl className="grid gap-4 sm:grid-cols-2">{Object.entries(data.application ?? {}).map(([key, value]) => <div key={key}><dt className="text-sm text-slate-600">{labels[key] ?? key}</dt><dd className="break-words">{value == null ? 'Belum diisi' : String(value)}</dd></div>)}</dl><div className="mt-5"><h4 className="font-semibold">Alamat</h4>{data.addresses.map((address, index) => <p key={index}>{Object.values(address).filter(Boolean).join(', ')}</p>)}</div><div className="mt-5"><h4 className="font-semibold">Pekerjaan</h4>{data.employment.map((item, index) => <p key={index}>{item.employment_type} · {item.occupation} · Rp {Number(item.monthly_income).toLocaleString('id-ID')}</p>)}</div><h4 className="mt-5 font-semibold">Riwayat proses</h4>{!data.history.length && <p>Belum ada riwayat yang dapat diakses.</p>}<ol className="mt-3 space-y-3">{data.history.map((entry) => <li key={entry.id} className="border-l-2 border-green-700 pl-4"><StatusBadge value={entry.to_status} /><p className="text-sm">{new Date(entry.changed_at).toLocaleString('id-ID')}</p>{entry.reason && <p>{entry.reason}</p>}</li>)}</ol></section>
}
