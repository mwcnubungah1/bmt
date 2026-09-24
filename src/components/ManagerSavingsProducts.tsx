import { useEffect, useState } from 'react'
import { RefreshCw, Settings2 } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { formatUserError } from '../lib/errors'

type SavingsProduct = { product_id: string; account_code: string; minimum_monthly_deposit: number; dormant_after_days: number | null; products: { code: string; name: string } | { code: string; name: string }[] | null }
const productName = (product: SavingsProduct['products']) => Array.isArray(product) ? product[0]?.name : product?.name

export function ManagerSavingsProducts() {
  const [items, setItems] = useState<SavingsProduct[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState('')
  const [message, setMessage] = useState('')
  const load = async () => { setLoading(true); const result = await supabase.from('savings_products').select('product_id,account_code,minimum_monthly_deposit,dormant_after_days,products(code,name)').order('account_code'); if (result.error) setMessage(formatUserError(result.error)); else setItems((result.data ?? []) as unknown as SavingsProduct[]); setLoading(false) }
  useEffect(() => { const timer = window.setTimeout(() => { void load() }, 0); return () => window.clearTimeout(timer) }, [])
  const save = async (item: SavingsProduct, minimum: string, dormant: string) => { setSaving(item.product_id); setMessage(''); try { await supabase.rpc('manager_update_savings_product_rules', { p_product_id: item.product_id, p_minimum_monthly_deposit: Number(minimum), p_dormant_after_days: dormant ? Number(dormant) : null }).throwOnError(); setMessage('Aturan produk tabungan berhasil disimpan.'); await load() } catch (cause) { setMessage(formatUserError(cause)) } finally { setSaving('') } }
  return <section className="rounded-2xl border border-[#dce8d8] bg-white p-5"><div className="flex flex-wrap items-center justify-between gap-3"><div><h3 className="flex items-center gap-2 font-bold"><Settings2 size={18} className="text-[#16843a]" /> Aturan produk tabungan</h3><p className="text-sm text-[#475569]">Atur minimum setoran bulanan dan batas rekening menjadi dormant.</p></div><button type="button" aria-label="Muat ulang produk tabungan" onClick={() => void load()} className="inline-flex min-h-11 items-center gap-2 rounded-xl border px-3"><RefreshCw size={15} /> Muat ulang</button></div>{loading ? <p role="status" className="mt-4 text-sm">Memuat produk tabungan…</p> : <div className="mt-4 space-y-3">{items.map((item) => <SavingsRuleRow key={item.product_id} item={item} saving={saving === item.product_id} onSave={save} />)}{!items.length && <p className="text-sm text-slate-500">Belum ada produk tabungan.</p>}</div>}{message && <p role="status" className="mt-4 text-sm text-[#365844]">{message}</p>}</section>
}

function SavingsRuleRow({ item, saving, onSave }: { item: SavingsProduct; saving: boolean; onSave: (item: SavingsProduct, minimum: string, dormant: string) => void }) {
  const [minimum, setMinimum] = useState(String(item.minimum_monthly_deposit ?? 0))
  const [dormant, setDormant] = useState(item.dormant_after_days == null ? '' : String(item.dormant_after_days))
  return <div className="grid gap-3 rounded-xl bg-[#f5f9f3] p-4 md:grid-cols-[1.2fr_1fr_1fr_auto] md:items-end"><div><p className="font-semibold">{productName(item.products) ?? item.account_code}</p><p className="text-xs text-slate-500">Kode rekening {item.account_code}</p></div><label className="text-sm">Minimum setoran/bulan<input type="number" min="0" value={minimum} onChange={(event) => setMinimum(event.target.value)} className="mt-1 min-h-10 w-full rounded-lg border bg-white p-2" /></label><label className="text-sm">Dormant setelah (hari)<input type="number" min="1" value={dormant} onChange={(event) => setDormant(event.target.value)} placeholder="Tidak otomatis" className="mt-1 min-h-10 w-full rounded-lg border bg-white p-2" /></label><button type="button" disabled={saving} onClick={() => onSave(item, minimum, dormant)} className="min-h-10 rounded-lg bg-green-800 px-4 text-sm font-semibold text-white disabled:opacity-50">{saving ? 'Menyimpan…' : 'Simpan'}</button></div>
}
