import { useEffect, useRef, useState } from 'react'
import { CheckCircle2, Printer, WalletCards } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { formatUserError } from '../lib/errors'
import type { Database } from '../types/database'
import logo from '../assets/bmt-nu-bungah.webp'

type Account = Database['bmt_db']['Functions']['teller_search_savings_accounts']['Returns'][number]
type Receipt = { transactionId: string; account: Account; amount: number; channel: string; reference: string; createdAt: Date }
const money = (value: number) => new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(value)

function ReceiptSlip({ receipt }: { receipt: Receipt }) {
  return <div id="teller-receipt" className="receipt-slip"><img src={logo} alt="BMT NU Bungah" className="receipt-logo" /><h2>BMT NU MWCNU Bungah</h2><p>Bukti Setoran Tabungan</p><hr /><p>No. transaksi: {receipt.transactionId}</p><p>Waktu: {receipt.createdAt.toLocaleString('id-ID')}</p><p>Status sesi: OPEN</p><p>Rekening: {receipt.account.account_number}</p><p>Nasabah: {receipt.account.full_name}</p><p>Metode: {receipt.channel === 'CASH' ? 'Tunai' : 'Transfer'}</p>{receipt.reference && <p>Referensi: {receipt.reference}</p>}<hr /><p className="receipt-total">{money(receipt.amount)}</p><p>Terbilang: {receipt.amount.toLocaleString('id-ID')} rupiah</p><div className="receipt-signatures"><span>Teller<br /><br />(____________)</span><span>Penyetor<br /><br />(____________)</span></div></div>
}

export function TellerSavingsDeposit({ onComplete, cashSessionOpen }: { onComplete: () => void; cashSessionOpen: boolean }) {
  const [search, setSearch] = useState('')
  const [accounts, setAccounts] = useState<Account[]>([])
  const [selected, setSelected] = useState<Account | null>(null)
  const [amount, setAmount] = useState('')
  const [channel, setChannel] = useState('CASH')
  const [reference, setReference] = useState('')
  const [description, setDescription] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [receipt, setReceipt] = useState<Receipt | null>(null)
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID())
  const searchVersion = useRef(0)
  useEffect(() => {
    const term = search.trim()
    const version = ++searchVersion.current
    if (term.length < 2 || selected?.account_number === term) return
    const timer = window.setTimeout(() => {
      void supabase.rpc('teller_search_savings_accounts', { p_search: term }).then((result) => {
        if (version !== searchVersion.current) return
        if (result.error) setError(formatUserError(result.error))
        else { setAccounts(result.data ?? []); setError('') }
      })
    }, 300)
    return () => window.clearTimeout(timer)
  }, [search, selected?.account_number])
  const reset = () => { setSelected(null); setSearch(''); setAccounts([]); setAmount(''); setReference(''); setDescription(''); setReceipt(null); setError(''); setIdempotencyKey(crypto.randomUUID()) }
  const submit = async () => {
    if (busy) return
    if (channel === 'CASH' && !cashSessionOpen) { setError('Sesi kas belum dibuka'); return }
    if (!selected || selected.status !== 'ACTIVE') { setError('Pilih rekening dengan status ACTIVE.'); return }
    if (!Number.isFinite(Number(amount)) || Number(amount) <= 0) { setError('Nominal setoran harus lebih besar dari 0.'); return }
    if (channel === 'TRANSFER' && !reference.trim()) { setError('Nomor referensi transfer wajib diisi.'); return }
    setBusy(true); setError('')
    try {
      const result = channel === 'CASH'
        ? await supabase.rpc('teller_post_savings_deposit', { p_financial_account_id: selected.financial_account_id, p_amount: Number(amount), p_channel: 'CASH', p_reference_number: undefined, p_description: description.trim() || undefined, p_idempotency_key: idempotencyKey })
        : await supabase.rpc('teller_submit_savings_transfer', { p_financial_account_id: selected.financial_account_id, p_amount: Number(amount), p_reference_number: reference.trim(), p_description: description.trim() || undefined, p_idempotency_key: idempotencyKey })
      if (result.error) throw result.error
      setReceipt({ transactionId: String(result.data), account: selected, amount: Number(amount), channel, reference: reference.trim(), createdAt: new Date() })
      onComplete()
    } catch (cause) { setError(formatUserError(cause)) } finally { setBusy(false) }
  }
  if (receipt) return <section className="role-panel space-y-4"><div className="flex items-center gap-3 text-green-800"><CheckCircle2 /><div><h2 className="text-lg font-bold">{receipt.channel === 'CASH' ? 'Setoran berhasil dicatat' : 'Transfer menunggu verifikasi'}</h2><p className="text-sm">Simpan atau cetak bukti transaksi berikut.</p></div></div><ReceiptSlip receipt={receipt} /><div className="flex flex-wrap gap-3"><button type="button" onClick={() => window.print()} className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-green-800 px-4 font-semibold text-white"><Printer size={16} /> Cetak struk</button><button type="button" onClick={reset} className="min-h-11 rounded-xl border px-4 font-semibold">Setoran baru</button></div></section>
  return <section className="role-panel space-y-4" aria-label="Form setoran teller"><div className="flex items-center gap-3"><WalletCards className="text-green-700" /><div><h2 className="text-lg font-bold">Setoran tabungan</h2><p className="text-sm text-slate-500">Cari rekening, periksa identitas, lalu konfirmasi setoran.</p></div></div>{!cashSessionOpen && channel === 'CASH' && <p role="alert" className="rounded-xl bg-amber-50 p-3 text-sm text-amber-900">Sesi kas belum dibuka. Buka sesi kas teller sebelum menerima setoran tunai.</p>}<label className="block text-sm">Cari nama atau nomor rekening<input value={search} onChange={(event) => { setSearch(event.target.value); setSelected(null) }} className="mt-1 w-full rounded-xl border p-3" placeholder="Ketik minimal 2 karakter…" /></label>{accounts.length > 0 && <div className="space-y-2 rounded-xl border p-2">{accounts.map((account) => <button type="button" key={account.financial_account_id} onClick={() => { setSelected(account); setAccounts([]); setSearch(account.account_number) }} className="block w-full rounded-lg p-3 text-left hover:bg-green-50"><strong>{account.full_name}</strong><span className="block text-sm text-slate-500">{account.account_number} · {account.status} · Saldo {money(Number(account.current_balance))}</span></button>)}</div>}{selected && <div className="rounded-xl border border-green-200 bg-green-50 p-4 text-sm"><p className="font-bold">{selected.full_name}</p><p>Rekening: {selected.account_number}</p><p>Status: <strong>{selected.status}</strong></p><p>Saldo terkini: {money(Number(selected.current_balance))}</p></div>}<div className="grid gap-3 sm:grid-cols-2"><label className="text-sm">Nominal<input type="number" min="1" value={amount} onChange={(event) => setAmount(event.target.value)} className="mt-1 w-full rounded-xl border p-3" /></label><label className="text-sm">Metode<select value={channel} onChange={(event) => setChannel(event.target.value)} className="mt-1 w-full rounded-xl border p-3"><option value="CASH">Tunai</option><option value="TRANSFER">Transfer</option></select></label></div>{channel === 'TRANSFER' && <label className="block text-sm">Referensi transfer<input value={reference} onChange={(event) => setReference(event.target.value)} className="mt-1 w-full rounded-xl border p-3" /></label>}<label className="block text-sm">Catatan<textarea value={description} onChange={(event) => setDescription(event.target.value)} className="mt-1 w-full rounded-xl border p-3" /></label><button type="button" disabled={busy || (channel === 'CASH' && !cashSessionOpen) || !selected || selected.status !== 'ACTIVE'} onClick={() => void submit()} className="min-h-11 w-full rounded-xl bg-green-800 px-4 font-semibold text-white disabled:opacity-50">{busy ? 'Menyimpan…' : channel === 'CASH' ? 'Konfirmasi setoran tunai' : 'Kirim untuk verifikasi transfer'}</button>{error && <p role="alert" className="text-sm text-red-700">{error}</p>}</section>
}
