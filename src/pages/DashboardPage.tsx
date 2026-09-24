import { RoleDashboard } from '../components/RoleDashboard'
import { MobileNavigation } from '../components/MobileNavigation'
import { CustomerNotices } from '../components/CustomerNotices'
import { WorkSummary } from '../components/WorkSummary'
import { MarketingFollowups } from '../components/MarketingFollowups'
import { OnboardingReviewDetails } from '../components/OnboardingReviewDetails'
import { ConfirmDialog } from '../components/ConfirmDialog'
import { StatusBadge } from '../components/StatusBadge'
import { useSearchParams } from 'react-router-dom'
import { useEffect, useMemo, useState } from 'react'
import { CheckCircle2, ChevronLeft, ChevronRight, Download, FileText, LoaderCircle } from 'lucide-react'
import { useAuth } from '../contexts/auth-context'
import { formatUserError } from '../lib/errors'
import { supabase } from '../lib/supabase'
import { Link } from 'react-router-dom'
import { useDashboardRows } from '../hooks/use-dashboard-rows'
import { reviewOnboarding, type WorkflowAction, type ReviewInput } from '../lib/onboarding-workflow'
import { CUSTOMER_SOURCES, createDocumentDownload, fetchOnboardingDocuments, STAFF_SOURCES, type DashboardRow, type DocumentRow } from '../lib/dashboard-data'
import { DashboardShell, RefreshButton } from '../components/DashboardShell'
import { EmptyState, ErrorState, LoadingState } from '../components/DashboardStates'
import { CustomerFinancialActions } from '../components/CustomerFinancialActions'
import { ManagerLoanProducts } from '../components/ManagerLoanProducts'

function LoanReviewPanel({ row, role, onDone }: { row: DashboardRow; role: string; onDone: () => void }) {
  const [busy, setBusy] = useState(false); const [message, setMessage] = useState('')
  const [decision, setDecision] = useState<'REVIEW' | 'APPROVE' | 'REJECT' | null>(null)
  const [reason, setReason] = useState('')
  const review = async (decision: 'REVIEW' | 'APPROVE' | 'REJECT') => { if (!row.id || busy) return; if (decision === 'REJECT' && !reason.trim()) { setMessage('Isi alasan penolakan.'); return }; setBusy(true); setMessage(''); try { await supabase.rpc('staff_review_loan_application', { p_application_id: String(row.id), p_decision: decision, p_reason: decision === 'REJECT' ? reason.trim() : undefined }).throwOnError(); setMessage(decision === 'REJECT' ? 'Pengajuan ditolak.' : decision === 'REVIEW' ? 'Pengajuan masuk tahap pemeriksaan.' : 'Pengajuan disetujui.'); onDone() } catch (error) { setMessage(formatUserError(error)) } finally { setBusy(false) } }
  const status = String(row.status ?? ''); const canManager = role.toLowerCase().includes('manager') || role.toLowerCase().includes('superadmin')
  return <section className="rounded-2xl border border-amber-200 bg-amber-50 p-5"><h3 className="font-bold">Review pengajuan kredit</h3><p className="mt-1 text-sm">Status: <strong>{status}</strong></p><label className="mt-4 block text-sm">Alasan keputusan (wajib untuk penolakan)<textarea value={reason} onChange={(event) => setReason(event.target.value)} className="mt-2 block w-full rounded-lg border bg-white p-3" /></label>{decision && <ConfirmDialog title="Konfirmasi keputusan pembiayaan" onClose={() => setDecision(null)} onConfirm={() => review(decision)}><p>Pengajuan: {String(row.application_number ?? row.id)}</p><p>Keputusan: {decision === 'APPROVE' ? 'Setujui' : decision === 'REJECT' ? 'Tolak' : 'Mulai pemeriksaan'}</p><p>{reason}</p></ConfirmDialog>}{canManager && <div className="mt-4 flex flex-wrap gap-2">{status === 'SUBMITTED' && <button disabled={busy} type="button" onClick={() => setDecision('REVIEW')} className="min-h-11 rounded-xl border bg-white px-4 text-sm font-semibold">Periksa data</button>}{status === 'REVIEW' && <><button disabled={busy} type="button" onClick={() => setDecision('APPROVE')} className="min-h-11 rounded-xl bg-[#16843a] px-4 text-sm font-semibold text-white">Setujui</button><button disabled={busy} type="button" onClick={() => { if (!reason.trim()) { setMessage('Isi alasan penolakan.'); return }; setDecision('REJECT') }} className="min-h-11 rounded-xl border border-red-200 bg-white px-4 text-sm font-semibold text-red-700">Tolak</button></>}</div>}{message && <p role="status" className="mt-3 text-sm">{message}</p>}</section>
}

type Props = { staff?: boolean; role?: string }
const labels: Record<string, string> = { full_name: 'Nama lengkap', cif_number: 'Nomor CIF', status: 'Status', created_at: 'Tanggal dibuat', account_number: 'Nomor rekening', account_type: 'Jenis rekening', application_number: 'Nomor pengajuan', requested_amount: 'Jumlah pengajuan', transaction_number: 'Nomor transaksi', amount: 'Jumlah', balance: 'Saldo', available_balance: 'Saldo tersedia' }
const formatLabel = (value: string) => labels[value] ?? value.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
const formatValue = (value: unknown, column: string) => {
  if (value == null || value === '') return '—'
  if (column.includes('amount') || column.includes('balance') || column.includes('principal')) return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(Number(value))
  if (column.endsWith('_at') || column.endsWith('_date')) { const date = new Date(String(value)); if (!Number.isNaN(date.getTime())) return new Intl.DateTimeFormat('id-ID', { dateStyle: 'medium' }).format(date) }
  return String(value)
}

function DataTable({ rows, selectedId, onSelect }: { rows: DashboardRow[]; selectedId: string | null; onSelect: (row: DashboardRow) => void }) {
  const columns = Object.keys(rows[0] ?? {}).filter((key) => key !== 'id')
  return <>
    <div className="hidden overflow-x-auto md:block"><table className="w-full text-left text-sm"><caption className="sr-only">Daftar data layanan BMT</caption><thead className="bg-[#f0f5ed]"><tr><th className="px-5 py-3 text-xs font-semibold text-[#557360]">Detail</th>{columns.map((column) => <th key={column} className="whitespace-nowrap px-5 py-3 font-semibold text-[#557360]">{formatLabel(column)}</th>)}</tr></thead><tbody>{rows.map((row, index) => { const rowId = String(row.id ?? index); return <tr key={rowId} onClick={() => onSelect(row)} className={`cursor-pointer border-t border-[#e8efe5] transition-colors hover:bg-[#f4f8f1] ${selectedId === rowId ? 'bg-[#e3f0df]' : ''}`}><td className="px-5 py-3"><button type="button" onClick={(event) => { event.stopPropagation(); onSelect(row) }} className="min-h-11 rounded-lg bg-[#eaf5eb] px-3 font-semibold text-[#1d7042] hover:bg-[#d9ecd9]">Lihat detail</button></td>{columns.map((column) => <td key={column} className="whitespace-nowrap px-5 py-4 text-[#365844]">{column === 'status' ? <StatusBadge value={row[column]} /> : formatValue(row[column], column)}</td>)}</tr> })}</tbody></table></div>
    <div className="space-y-3 p-4 md:hidden">{rows.map((row, index) => <button key={String(row.id ?? index)} type="button" onClick={() => onSelect(row)} className={`block min-h-11 w-full rounded-2xl border p-4 text-left shadow-sm transition-colors ${selectedId === String(row.id ?? index) ? 'border-[#1d7042] bg-[#eaf5eb]' : 'border-[#dce8d8] bg-white'}`}>{columns.slice(0, 4).map((column) => <span key={column} className="flex justify-between gap-4 border-b border-[#eef3eb] py-2 last:border-0"><span className="text-xs text-[#475569]">{formatLabel(column)}</span><span className="max-w-[60%] truncate text-sm font-semibold text-[#365844]">{column === 'status' ? <StatusBadge value={row[column]} /> : formatValue(row[column], column)}</span></span>)}<span className="mt-3 block text-sm font-bold text-[#1d7042]">Buka detail →</span></button>)}</div>
  </>
}

function Pagination({ page, hasNextPage, onPrevious, onNext }: { page: number; hasNextPage: boolean; onPrevious: () => void; onNext: () => void }) {
  return <div className="flex flex-wrap items-center justify-between gap-3 border-t border-[#e8efe5] px-5 py-4"><button type="button" disabled={page === 0} onClick={onPrevious} className="inline-flex min-h-11 items-center gap-1 rounded-lg border border-[#d4e2d0] px-4 py-2 text-sm disabled:opacity-50"><ChevronLeft size={16} /> Sebelumnya</button><span className="text-sm text-[#475569]">Halaman {page + 1}</span><button type="button" disabled={!hasNextPage} onClick={onNext} className="inline-flex min-h-11 items-center gap-1 rounded-lg border border-[#d4e2d0] px-4 py-2 text-sm disabled:opacity-50">Berikutnya <ChevronRight size={16} /></button></div>
}

export function DashboardPage({ staff = false, role = '' }: Props) {
  const { profile, signOut } = useAuth()
  const sources = staff ? STAFF_SOURCES : CUSTOMER_SOURCES
  const [params, setParams] = useSearchParams()
  const home = !params.get('view') || params.get('view') === 'home'
  const defaultSource = role === 'teller' || role === 'manager' ? 1 : staff ? 0 : 2
  const selected = Math.max(0, sources.findIndex((item) => item.name === (params.get('view') ?? sources[defaultSource].name)))
  const page = Math.max(0, Number(params.get('page')) || 0)
  const setPage = (change: (previous: number) => number) => setParams((previous) => { previous.set('page', String(change(page))); return previous })
  const [pendingWorkflow, setPendingWorkflow] = useState<{ action: WorkflowAction; input: ReviewInput } | null>(null)
  const [selectedRow, setSelectedRow] = useState<DashboardRow | null>(null)
  const [actionMessage, setActionMessage] = useState('')
  const [actionBusy, setActionBusy] = useState(false)
  const source = sources[selected] ?? sources[0]
  const { rows, loading, error, hasNextPage, reload } = useDashboardRows(staff, source, page, params.get('search') ?? '', params.get('status') ?? '')
  useEffect(() => {
    if (staff) return
    let active = true
    void supabase.rpc('ensure_customer_savings_account').then(({ error: accountError }) => {
      if (active && accountError) {
        setActionMessage(formatUserError(accountError))
      }
    })
    return () => { active = false }
  }, [staff])
  const isOnboarding = staff && source.name === 'onboarding_applications'; const columns = useMemo(() => Object.keys(rows[0] ?? {}).filter((key) => key !== 'id'), [rows])
  const selectSource = (index: number) => { setParams({ view: String(sources[index].name) }); setSelectedRow(null); setActionMessage('') }
  const runWorkflow = async (action: WorkflowAction, input: ReviewInput) => {
    if (!selectedRow?.id || actionBusy) return
    setActionBusy(true)
    setActionMessage('')
    try {
      await reviewOnboarding(String(selectedRow.id), action, input)
      setSelectedRow(null)
      setActionMessage('Pendaftaran berhasil diproses.')
      reload()
    } catch (error) { setActionMessage(formatUserError(error)) }
    finally { setActionBusy(false) }
  }
  if (home) return <DashboardShell role={staff ? role : 'nasabah'} profile={profile} sources={sources} selected={-1} onHome={() => setParams({ view: 'home' })} onSelect={selectSource} onSignOut={() => void signOut()}><RoleDashboard role={staff ? role : 'nasabah'} onNavigate={(name, status) => { setSelectedRow(null); setParams({ view: name, ...(status ? { status } : {}) }) }} /><MobileNavigation sources={sources} selected={-1} onSelect={selectSource} staff={staff} /></DashboardShell>
  return <DashboardShell onHome={() => { setSelectedRow(null); setParams({ view: 'home' }) }} role={staff ? role : 'nasabah'} profile={profile} sources={sources} selected={selected} onSelect={selectSource} onSignOut={() => void signOut()}>{staff ? <WorkSummary /> : <CustomerNotices />}{role === 'marketing' && <MarketingFollowups />}<div className="flex flex-wrap items-center justify-between gap-3"><div><p className="text-sm text-[#475569]">{staff ? `Ruang kerja ${role}` : 'Ringkasan layanan dan aktivitas Anda'}</p><h2 className="mt-1 text-2xl font-bold">{source.label}</h2></div><RefreshButton onClick={() => reload()} /></div>{staff && <form key={String(source.name)} className="workbench grid gap-3 rounded-xl border bg-white p-4 sm:grid-cols-3" onSubmit={(event) => { event.preventDefault(); const values = new FormData(event.currentTarget); setSelectedRow(null); setParams({ view: String(source.name), search: String(values.get('search') ?? ''), status: String(values.get('status') ?? '') }) }}><label>Cari nama atau nomor<input name="search" defaultValue={params.get('search') ?? ''} type="search" /></label><label>Status<select name="status" defaultValue={params.get('status') ?? ''}><option value="">Semua status</option>{(source.name === 'onboarding_applications' ? ['DRAFT','RETURNED','TELLER_REVIEW','MANAGER_REVIEW','APPROVED','COMPLETED'] : source.name === 'loan_applications' ? ['SUBMITTED','REVIEW','APPROVED','REJECTED'] : []).map((status) => <option key={status}>{status}</option>)}</select></label><button className="self-end rounded-lg bg-green-800 px-4 text-white">Terapkan filter</button></form>}<MobileNavigation sources={sources} selected={selected} onSelect={selectSource} staff={staff} />{!staff && <CustomerFinancialActions sourceName={String(source.name)} rows={rows} onComplete={() => reload()} />}{staff && ['manager', 'superadmin'].includes(role) && source.name === 'loan_applications' && <ManagerLoanProducts />}{selectedRow && isOnboarding && <div className="detail-modal" role="dialog" aria-modal="true"><div className="detail-modal-card"><OnboardingReviewDetails key={String(selectedRow.id)} id={String(selectedRow.id)} onClose={() => setSelectedRow(null)} />{isOnboarding && <WorkflowPanel key={`workflow-${String(selectedRow.id)}`} row={selectedRow} role={role} busy={actionBusy} message={actionMessage} onAction={(action, input) => { if ((action === 'teller' || action === 'manager') && !input.signature) { setActionMessage('Unggah tanda tangan Anda sebelum menyetujui.'); return }; if (action === 'return' && !input.reason.trim()) { setActionMessage('Isi alasan pengembalian.'); return }; setPendingWorkflow({ action, input }) }} />}</div></div>}{selectedRow && !isOnboarding && <div className="detail-modal" role="dialog" aria-modal="true"><div className="detail-modal-card"><RecordDetailPanel key={String(source.name) + String(selectedRow.id)} onboarding={false} row={selectedRow} staff={staff} columns={columns} onClose={() => setSelectedRow(null)} />{staff && source.name === "loan_applications" && <LoanReviewPanel row={selectedRow} role={role} onDone={() => { setSelectedRow(null); reload() }} />}</div></div>}{pendingWorkflow && <ConfirmDialog title="Konfirmasi proses pendaftaran" onClose={() => setPendingWorkflow(null)} onConfirm={() => runWorkflow(pendingWorkflow.action, pendingWorkflow.input)}><p>Nasabah: {String(selectedRow?.full_name ?? '')}</p><p>{pendingWorkflow.action === 'return' ? 'Kembalikan untuk diperbaiki' : pendingWorkflow.action === 'finalize' ? 'Finalisasi CIF' : 'Setujui dan lanjutkan pemeriksaan'}</p><p>{pendingWorkflow.input.reason}</p></ConfirmDialog>}{actionMessage && <p role="status" className="rounded-xl border p-4 text-sm">{actionMessage}</p>}{!staff && source.name === 'portal_get_onboarding_applications' && <Link className="inline-flex items-center rounded-xl bg-green-700 px-4 py-2 text-white" to="/nasabah/formulir">Buka formulir pendaftaran</Link>}<section className="overflow-hidden rounded-2xl border border-[#dce8d8] bg-[#fbfcf8] shadow-[0_8px_28px_rgba(32,75,43,0.05)]"><div className="border-b border-[#e3ebdf] px-5 py-4"><p className="text-sm text-[#475569]">{columns.length ? `${rows.length} data ditampilkan · klik baris untuk melihat detail` : 'Informasi layanan Anda'}</p></div>{loading ? <LoadingState /> : error ? <ErrorState message={error} onRetry={() => reload()} /> : !rows.length ? <EmptyState message="Belum ada informasi di sini" /> : <><DataTable rows={rows} selectedId={String(selectedRow?.id ?? '')} onSelect={setSelectedRow} />{(staff || source.paginated) && <Pagination page={page} hasNextPage={hasNextPage} onPrevious={() => { setSelectedRow(null); setPage((value) => Math.max(0, value - 1)) }} onNext={() => { setSelectedRow(null); setPage((value) => value + 1) }} />}</>}</section></DashboardShell>
}

function RecordDetailPanel({ row, columns, staff, onboarding, onClose }: { row: DashboardRow; columns: string[]; staff: boolean; onboarding: boolean; onClose: () => void }) {
  const [documents, setDocuments] = useState<DocumentRow[]>([])
  const [loadingDocuments, setLoadingDocuments] = useState(false)
  const [documentError, setDocumentError] = useState('')
  const [downloading, setDownloading] = useState<string | null>(null)
  const applicationId = onboarding && typeof row.id === 'string' ? row.id : null
  useEffect(() => {
    if (!applicationId || (!staff && !row.status)) return
    let active = true
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setLoadingDocuments(true)
    void fetchOnboardingDocuments(applicationId, staff).then((result) => { if (active) setDocuments(result) }).catch((error: unknown) => { if (active) setDocumentError(formatUserError(error)) }).finally(() => { if (active) setLoadingDocuments(false) })
    return () => { active = false }
  }, [applicationId, row.status, staff])
  const download = async (document: DocumentRow) => {
    setDownloading(document.id); setDocumentError('')
    try { window.open(await createDocumentDownload(document), '_blank', 'noopener,noreferrer') } catch (error) { setDocumentError(formatUserError(error)) } finally { setDownloading(null) }
  }
  return <section className="rounded-2xl border border-[#cfe4d0] bg-white p-5 shadow-sm" aria-live="polite"><div className="flex items-start justify-between gap-4"><div><p className="text-xs font-bold uppercase tracking-[0.16em] text-[#475569]">Detail formulir</p><h3 className="mt-1 text-xl font-bold text-[#204e31]">{String(row.full_name ?? row.transaction_number ?? row.account_number ?? 'Data layanan')}</h3></div><button type="button" onClick={onClose} className="min-h-11 rounded-xl border border-[#d4e2d0] px-3 text-sm font-semibold text-[#557360]">Tutup</button></div><div className="mt-4 grid gap-3 sm:grid-cols-2">{columns.map((column) => <div key={column} className="rounded-xl bg-[#f5f9f3] p-3"><p className="text-xs text-[#475569]">{formatLabel(column)}</p><p className="mt-1 break-words text-sm font-semibold text-[#365844]">{column === 'status' ? <StatusBadge value={row[column]} /> : formatValue(row[column], column)}</p></div>)}</div>{applicationId && <div className="mt-5 rounded-xl border border-[#dce8d8] p-4"><h4 className="font-semibold">Dokumen formulir</h4>{loadingDocuments && <p className="mt-3 flex items-center gap-2 text-sm text-[#475569]"><LoaderCircle className="animate-spin" size={16} /> Memuat dokumen…</p>}{!loadingDocuments && !documents.length && <p className="mt-3 text-sm text-[#475569]">Belum ada dokumen yang dapat diunduh.</p>}{documentError && <p role="alert" className="mt-3 text-sm text-red-700">{documentError}</p>}<div className="mt-3 space-y-2">{documents.map((document) => <div key={document.id} className="flex flex-wrap items-center justify-between gap-3 rounded-lg bg-[#f5f9f3] p-3"><div><p className="font-medium">{formatLabel(document.document_type)}</p><p className="text-xs text-[#475569]">{document.mime_type ?? 'Dokumen'} · {document.status}</p></div><button type="button" disabled={downloading === document.id} onClick={() => void download(document)} className="inline-flex min-h-11 items-center gap-2 rounded-lg bg-[#1d7042] px-3 text-sm font-semibold text-white disabled:opacity-50"><Download size={15} /> {downloading === document.id ? 'Menyiapkan…' : 'Unduh'}</button></div>)}</div></div>}</section>
}

function WorkflowPanel({ row, role, busy, message, onAction }: { row: DashboardRow; role: string; busy: boolean; message: string; onAction: (action: WorkflowAction, input: ReviewInput) => void }) { const [signature, setSignature] = useState<File | null>(null); const [verified, setVerified] = useState(false); const [reason, setReason] = useState(''); const status = String(row.status ?? ''); return <section className="rounded-2xl border border-green-100 bg-green-50 p-5"><div className="flex items-start gap-3"><FileText className="mt-0.5 text-green-700" size={20} /><div><h3 className="font-bold">Review pendaftaran</h3><p className="mt-1 text-sm text-slate-600">Status: <strong>{status}</strong></p></div></div><div className="mt-4 space-y-3"><label className="flex items-center gap-3 text-sm"><input type="checkbox" checked={verified} onChange={(event) => setVerified(event.target.checked)} />Saya telah mencocokkan identitas, alamat, pekerjaan, dan dokumen.</label><label className="block text-sm">Tanda tangan staf (PNG/JPG, maksimal 2 MB)<input type="file" accept="image/png,image/jpeg" onChange={(event) => setSignature(event.target.files?.[0] ?? null)} className="mt-2 block w-full" /></label><label className="block text-sm">Alasan pengembalian<textarea value={reason} onChange={(event) => setReason(event.target.value)} className="mt-2 block w-full rounded-lg border bg-white p-3" /></label></div><div className="mt-4 flex flex-wrap gap-2">{status === 'TELLER_REVIEW' && (role.includes('teller') || role.includes('superadmin')) && <><button disabled={busy || !verified} type="button" onClick={() => { if (!verified) return; onAction('teller', { signature, reason }) }} className="min-h-11 rounded-xl bg-green-700 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">Tanda tangan & teruskan</button><button disabled={busy} type="button" onClick={() => onAction('return', { signature, reason })} className="min-h-11 rounded-xl border border-red-200 bg-white px-4 py-2 text-sm text-red-700 disabled:opacity-50">Kembalikan</button></>}{status === 'MANAGER_REVIEW' && (role.includes('manager') || role.includes('superadmin')) && <button disabled={busy} type="button" onClick={() => onAction('manager', { signature, reason })} className="min-h-11 rounded-xl bg-green-700 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">Setujui & tanda tangan</button>}{status === 'APPROVED' && (role.includes('manager') || role.includes('superadmin')) && <button disabled={busy} type="button" onClick={() => onAction('finalize', { signature, reason })} className="min-h-11 rounded-xl bg-green-700 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">Finalisasi CIF</button>}</div>{message && <p className="mt-3 flex items-center gap-2 text-sm text-slate-700"><CheckCircle2 size={16} />{message}</p>}</section> }










