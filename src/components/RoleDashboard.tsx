import { useEffect, useState, type ReactNode } from 'react'
import { ArrowUpRight, CalendarDays, ClipboardCheck, CreditCard, FilePlus2, Users, Wallet, type LucideIcon } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { formatUserError } from '../lib/errors'
import type { DashboardRow } from '../lib/dashboard-data'
import { WorkSummary } from './WorkSummary'
import { MarketingFollowups } from './MarketingFollowups'
import { CustomerNotices } from './CustomerNotices'
import { StatusBadge } from './StatusBadge'
import { ErrorState, LoadingState } from './DashboardStates'
import { RefreshButton } from './DashboardShell'

const money = (value: number) => new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(value)
const date = (value: unknown) => value ? new Date(String(value)).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' }) : '—'
const sum = (rows: DashboardRow[], key: string) => rows.reduce((total, row) => total + Number(row[key] ?? 0), 0)
const remaining = (row: DashboardRow) => Math.max(0, Number(row.total_due ?? 0) - ['principal_paid', 'margin_paid', 'penalty_paid', 'other_paid'].reduce((total, key) => total + Number(row[key] ?? 0), 0))
type Action = { label: string; hint: string; target: string; icon: LucideIcon }

function Panel({ title, children, onOpen }: { title: string; children: ReactNode; onOpen?: () => void }) {
  return <section className="role-panel"><div className="mb-5 flex flex-wrap items-center justify-between gap-2"><h2 className="text-lg font-bold">{title}</h2>{onOpen && <button onClick={onOpen} className="inline-flex min-h-11 items-center gap-1 text-sm font-semibold text-green-800">Lihat semua <ArrowUpRight size={16} /></button>}</div>{children}</section>
}

export function RoleDashboard({ role, onNavigate }: { role: string; onNavigate: (name: string, status?: string) => void }) {
  const customer = role === 'nasabah'
  const manager = ['manager', 'superadmin'].includes(role)
  const marketing = role === 'marketing'
  const [data, setData] = useState<Record<string, DashboardRow[]> | null>(null)
  const [error, setError] = useState('')
  const [revision, setRevision] = useState(0)
  useEffect(() => {
    let active = true
    const load = async () => {
      const results = customer ? await Promise.all([
        supabase.rpc('portal_get_savings_accounts'), supabase.rpc('portal_get_loan_accounts'),
        supabase.rpc('portal_get_loan_schedules', { p_limit: 25, p_offset: 0 }),
        supabase.rpc('portal_get_transactions', { p_limit: 5, p_offset: 0 }),
      ]) : await Promise.all([
        supabase.from('onboarding_applications').select('id,full_name,status,created_at').in('status', manager ? ['MANAGER_REVIEW', 'APPROVED'] : ['TELLER_REVIEW', 'RETURNED']).order('created_at', { ascending: false }).limit(5),
        supabase.from('loan_applications').select('id,application_number,requested_amount,status').in('status', ['SUBMITTED', 'REVIEW']).order('created_at', { ascending: false }).limit(5),
        supabase.from('transactions').select('id,transaction_number,amount,status').order('created_at', { ascending: false }).limit(5),
      ])
      const failed = results.find((result) => result.error)
      if (failed?.error) throw failed.error
      const keys = customer ? ['savings', 'loans', 'schedules', 'transactions'] : ['registrations', 'applications', 'transactions']
      if (active) { setData(Object.fromEntries(keys.map((key, index) => [key, results[index].data as unknown as DashboardRow[] ?? []]))); setError('') }
    }
    void load().catch((cause: unknown) => { if (active) setError(formatUserError(cause)) })
    return () => { active = false }
  }, [customer, manager, revision])
  const actions: Action[] = customer ? [
    { label: 'Bayar angsuran', hint: 'Periksa tagihan dan bayar', target: 'portal_get_loan_schedules', icon: CreditCard },
    { label: 'Ajukan pembiayaan', hint: 'Mulai pengajuan Anda', target: 'portal_get_loan_applications', icon: FilePlus2 },
    { label: 'Lihat mutasi', hint: 'Riwayat transaksi rekening', target: 'portal_get_transactions', icon: Wallet },
  ] : manager ? [
    { label: 'Tinjau pembiayaan', hint: 'Periksa pengajuan masuk', target: 'loan_applications', icon: ClipboardCheck },
    { label: 'Persetujuan nasabah', hint: 'Review dan finalisasi CIF', target: 'onboarding_applications', icon: Users },
    { label: 'Pantau transaksi', hint: 'Aktivitas dalam akses Anda', target: 'transactions', icon: Wallet },
  ] : marketing ? [
    { label: 'Nasabah dampingan', hint: 'Kelola hubungan nasabah', target: 'customers', icon: Users },
    { label: 'Pantau pendaftaran', hint: 'Tindak lanjuti kelengkapan', target: 'onboarding_applications', icon: FilePlus2 },
    { label: 'Pengajuan pembiayaan', hint: 'Pantau proses pengajuan', target: 'loan_applications', icon: ClipboardCheck },
  ] : [
    { label: 'Lihat pembayaran', hint: 'Periksa catatan transaksi', target: 'transactions', icon: CreditCard },
    { label: 'Cari nasabah', hint: 'Temukan nama dan nomor CIF', target: 'customers', icon: Users },
    { label: 'Periksa pendaftaran', hint: 'Verifikasi nasabah baru', target: 'onboarding_applications', icon: ClipboardCheck },
  ]
  const schedules = [...(data?.schedules ?? [])].sort((a, b) => String(a.due_date).localeCompare(String(b.due_date)))
  const next = schedules.find((row) => remaining(row) > 0)
  const list = (rows: DashboardRow[], kind: 'transactions' | 'applications' | 'registrations') => rows.length ? <ul className="divide-y divide-slate-100">{rows.map((row) => <li key={String(row.id)} className="flex flex-wrap items-center justify-between gap-3 py-4"><div className="min-w-0"><p className="break-words text-sm font-semibold">{String(row.full_name ?? row.application_number ?? row.transaction_number ?? 'Transaksi')}</p><p className="mt-1 text-xs text-slate-500">{kind === 'registrations' ? date(row.created_at) : money(Number(row.amount ?? row.requested_amount ?? 0))}</p></div><StatusBadge value={row.status} /></li>)}</ul> : <p className="py-8 text-sm text-slate-500">Belum ada data untuk ditampilkan.</p>
  return <div className="space-y-6">
    <div className="flex flex-wrap items-center justify-between gap-2"><div><p className="text-xs font-semibold uppercase tracking-widest text-green-700">{customer ? 'Layanan keuangan Anda' : marketing ? 'Hubungan & pertumbuhan' : manager ? 'Kinerja & persetujuan' : 'Pelayanan harian'}</p><h2 className="mt-1 text-2xl font-bold">Dashboard {customer ? 'Nasabah' : manager ? 'Manager' : marketing ? 'Marketing' : 'Teller'}</h2></div><RefreshButton onClick={() => { setData(null); setError(''); setRevision((v) => v + 1) }} /></div>
    <div className="grid gap-3 md:grid-cols-3">{actions.map(({ label, hint, target, icon: Icon }, index) => <button key={target} onClick={() => onNavigate(target)} className={`role-action ${index === 0 ? 'role-action-primary' : ''}`}><Icon size={27} className="shrink-0" /><span className="flex-1 text-left"><span className="block font-bold">{label}</span><span className="mt-1 block text-xs opacity-80">{hint}</span></span><ArrowUpRight size={18} /></button>)}</div>
    {!customer && <WorkSummary role={role} />}
    {error ? <ErrorState message={error} onRetry={() => { setError(''); setRevision((v) => v + 1) }} /> : !data ? <LoadingState /> : customer ? <>
      <div className="grid gap-4 md:grid-cols-3"><div className="role-panel role-balance"><Wallet size={24} /><p className="mt-5 text-sm">Sisa pokok pembiayaan</p><p className="mt-2 break-words text-2xl font-bold">{money(sum(data.loans, 'outstanding_principal'))}</p><p className="mt-3 text-xs opacity-80">Margin dan biaya lain ditampilkan pada angsuran.</p></div><div className="role-panel"><CalendarDays size={24} className="text-green-700" /><p className="mt-5 text-sm text-slate-600">Tagihan belum lunas terdekat*</p><p className="mt-2 text-2xl font-bold">{next ? date(next.due_date) : 'Tidak ada tagihan'}</p><p className="mt-3 font-semibold">{next ? money(remaining(next)) : 'Dari jadwal yang dimuat'}</p></div><button onClick={() => onNavigate('portal_get_savings_accounts')} className="role-panel text-left"><Wallet size={24} className="text-green-700" /><p className="mt-5 text-sm text-slate-600">Saldo simpanan tersedia</p><p className="mt-2 break-words text-2xl font-bold">{money(sum(data.savings, 'available_balance'))}</p><p className="mt-3 text-sm text-green-700">Lihat rekening →</p></button></div>
      <div className="grid gap-5 xl:grid-cols-[1.5fr_1fr]"><Panel title="Jadwal angsuran" onOpen={() => onNavigate('portal_get_loan_schedules')}><p className="mb-4 text-xs text-slate-500">*Ringkasan dari 25 jadwal pertama. Buka semua angsuran untuk jadwal lengkap.</p><div className="grid gap-3 sm:grid-cols-3">{schedules.slice(0, 6).map((row) => <div key={String(row.id)} className="rounded-xl border border-green-100 bg-green-50/50 p-4"><p className="text-xs text-slate-500">Angsuran {String(row.installment_no)} · {String(row.account_number ?? 'Rekening belum tersedia')}</p><p className="my-2 text-sm font-bold">{date(row.due_date)}</p><StatusBadge value={row.status} /><p className="mt-2 text-sm">{money(remaining(row))}</p></div>)}</div>{!schedules.length && <p className="py-5 text-sm text-slate-500">Belum ada jadwal angsuran.</p>}</Panel><CustomerNotices /></div>
      <Panel title="Transaksi terbaru" onOpen={() => onNavigate('portal_get_transactions')}>{list(data.transactions, 'transactions')}</Panel>
    </> : <div className="grid items-start gap-5 xl:grid-cols-[1.4fr_1fr]">
      <Panel title={manager ? 'Pembiayaan menunggu keputusan' : 'Pendaftaran perlu ditinjau'} onOpen={() => onNavigate(manager ? 'loan_applications' : 'onboarding_applications')}>{list(manager ? data.applications : data.registrations, manager ? 'applications' : 'registrations')}<button className="mt-4 min-h-11 w-full rounded-xl bg-green-800 px-4 font-semibold text-white" onClick={() => onNavigate(manager ? 'loan_applications' : 'onboarding_applications')}>Buka ruang pemeriksaan →</button></Panel>
      <Panel title="Perlu perhatian"><div className="rounded-xl border border-amber-100 bg-amber-50 p-4"><p className="font-semibold">{manager ? 'Persetujuan pendaftaran' : marketing ? 'Tindak lanjut nasabah' : 'Kelengkapan data nasabah'}</p><p className="mt-2 text-sm leading-6 text-slate-600">{manager ? 'Periksa dokumen, lanjutkan persetujuan, dan finalisasi CIF untuk pendaftaran yang telah disetujui.' : 'Pastikan identitas dan berkas lengkap sebelum meneruskan pengajuan ke tahap berikutnya.'}</p><button onClick={() => onNavigate('onboarding_applications')} className="mt-3 min-h-11 text-sm font-bold text-green-800">Buka pendaftaran →</button></div><p className="mt-5 text-xs leading-5 text-slate-500">Daftar menampilkan maksimal 5 catatan terbaru sesuai hak akses Anda.</p></Panel>
      <div className="xl:col-span-2"><Panel title="Transaksi terbaru" onOpen={() => onNavigate('transactions')}>{list(data.transactions, 'transactions')}</Panel></div>
    </div>}
    {marketing && <MarketingFollowups />}
  </div>
}
