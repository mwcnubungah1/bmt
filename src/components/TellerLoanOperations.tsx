import { useEffect, useState } from 'react'
import { Banknote, CheckCircle2, RefreshCw } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { formatUserError } from '../lib/errors'

type ApprovedApplication = { id: string; application_number: string; requested_amount: number; status: string; customer_id: string }
type Schedule = { id: string; installment_no: number; due_date: string; total_due: number; principal_paid: number; margin_paid: number; penalty_paid: number; other_paid: number; status: string; loan_account_id: string }
const money = (value: number) => new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(value)

export function TellerLoanOperations({ cashSessionOpen, onComplete }: { cashSessionOpen: boolean; onComplete: () => void }) {
  const [applications, setApplications] = useState<ApprovedApplication[]>([])
  const [schedules, setSchedules] = useState<Schedule[]>([])
  const [applicationId, setApplicationId] = useState('')
  const [scheduleId, setScheduleId] = useState('')
  const [amount, setAmount] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const load = async () => {
    setError('')
    const [applicationResult, scheduleResult] = await Promise.all([
      supabase.from('loan_applications').select('id,application_number,requested_amount,status,customer_id').eq('status', 'APPROVED').order('created_at', { ascending: false }),
      supabase.from('loan_schedules').select('id,installment_no,due_date,total_due,principal_paid,margin_paid,penalty_paid,other_paid,status,loan_account_id').in('status', ['DUE', 'PARTIAL', 'OVERDUE']).order('due_date', { ascending: true }),
    ])
    if (applicationResult.error) throw applicationResult.error
    if (scheduleResult.error) throw scheduleResult.error
    setApplications((applicationResult.data ?? []) as ApprovedApplication[])
    setSchedules((scheduleResult.data ?? []) as Schedule[])
  }

  useEffect(() => {
    const timer = window.setTimeout(() => { void load().catch((cause) => setError(formatUserError(cause))) }, 0)
    return () => window.clearTimeout(timer)
  }, [])

  const disburse = async () => {
    if (!applicationId || !cashSessionOpen) return
    setBusy(true); setError(''); setMessage('')
    try {
      await supabase.rpc('teller_disburse_loan', { p_loan_application_id: applicationId, p_idempotency_key: crypto.randomUUID() }).then(({ error: cause }) => { if (cause) throw cause })
      setMessage('Pembiayaan berhasil dicairkan dan jadwal angsuran telah dibuat.'); setApplicationId(''); await load(); onComplete()
    } catch (cause) { setError(formatUserError(cause)) } finally { setBusy(false) }
  }

  const pay = async () => {
    if (!scheduleId || !amount || !cashSessionOpen) return
    setBusy(true); setError(''); setMessage('')
    try {
      await supabase.rpc('teller_pay_loan_installment', { p_loan_schedule_id: scheduleId, p_amount: Number(amount), p_idempotency_key: crypto.randomUUID() }).then(({ error: cause }) => { if (cause) throw cause })
      setMessage('Pembayaran angsuran berhasil dibukukan.'); setScheduleId(''); setAmount(''); await load(); onComplete()
    } catch (cause) { setError(formatUserError(cause)) } finally { setBusy(false) }
  }

  return <section className="role-panel space-y-5" aria-label="Operasional pembiayaan teller"><div className="flex flex-wrap items-center justify-between gap-3"><div className="flex items-center gap-3"><Banknote className="text-green-700" /><div><h2 className="font-bold">Pencairan & angsuran pembiayaan</h2><p className="text-sm text-slate-500">Cairkan pengajuan yang sudah disetujui dan terima pembayaran angsuran.</p></div></div><button type="button" onClick={() => void load()} className="inline-flex min-h-10 items-center gap-2 rounded-xl border px-3 text-sm"><RefreshCw size={15} /> Perbarui</button></div>{!cashSessionOpen && <p role="alert" className="rounded-xl bg-amber-50 p-3 text-sm text-amber-900">Buka sesi kas terlebih dahulu sebelum melakukan pencairan atau menerima pembayaran.</p>}<div className="grid gap-4 lg:grid-cols-2"><div className="rounded-2xl border border-green-100 bg-green-50/50 p-4"><h3 className="font-bold">Siap dicairkan</h3><select value={applicationId} onChange={(event) => setApplicationId(event.target.value)} className="mt-3 min-h-11 w-full rounded-xl border bg-white p-3"><option value="">Pilih pengajuan disetujui</option>{applications.map((item) => <option key={item.id} value={item.id}>{item.application_number} · {money(Number(item.requested_amount))}</option>)}</select><button type="button" disabled={busy || !cashSessionOpen || !applicationId} onClick={() => void disburse()} className="mt-3 min-h-11 w-full rounded-xl bg-green-800 px-4 font-semibold text-white disabled:opacity-50">{busy ? 'Memproses…' : 'Cairkan pembiayaan'}</button></div><div className="rounded-2xl border border-blue-100 bg-blue-50/50 p-4"><h3 className="font-bold">Terima angsuran tunai</h3><select value={scheduleId} onChange={(event) => setScheduleId(event.target.value)} className="mt-3 min-h-11 w-full rounded-xl border bg-white p-3"><option value="">Pilih tagihan</option>{schedules.map((item) => { const remaining = Number(item.total_due) - Number(item.principal_paid) - Number(item.margin_paid) - Number(item.penalty_paid) - Number(item.other_paid); return <option key={item.id} value={item.id}>Angsuran {item.installment_no} · {money(remaining)} · {item.status}</option> })}</select><input type="number" min="1" value={amount} onChange={(event) => setAmount(event.target.value)} className="mt-3 min-h-11 w-full rounded-xl border bg-white p-3" placeholder="Nominal pembayaran" /><button type="button" disabled={busy || !cashSessionOpen || !scheduleId || !amount} onClick={() => void pay()} className="mt-3 min-h-11 w-full rounded-xl bg-blue-800 px-4 font-semibold text-white disabled:opacity-50">{busy ? 'Memproses…' : 'Buku pembayaran angsuran'}</button></div></div>{error && <p role="alert" className="text-sm text-red-700">{error}</p>}{message && <p role="status" className="flex items-center gap-2 text-sm text-green-800"><CheckCircle2 size={16} />{message}</p>}</section>
}
