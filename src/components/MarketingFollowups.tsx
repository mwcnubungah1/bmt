import { useEffect, useRef, useState, type FormEvent } from 'react'
import { supabase } from '../lib/supabase'
import type { Database } from '../types/database'
import { formatUserError } from '../lib/errors'
import { useAuth } from '../contexts/auth-context'

type Followup = Database['bmt_db']['Tables']['customer_followups']['Row']
export function MarketingFollowups() {
  const { user } = useAuth()
  const [items, setItems] = useState<Followup[]>([])
  const [customers, setCustomers] = useState<Array<{ id: string; name: string }>>([])
  const [customer, setCustomer] = useState('')
  const [note, setNote] = useState('')
  const [due, setDue] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [loading, setLoading] = useState(true)
  const [revision, setRevision] = useState(0)
  const lock = useRef(false)
  const [checkedAt, setCheckedAt] = useState(() => Date.now())
  useEffect(() => {
    if (!user) return
    let active = true
    void Promise.all([
      supabase.from('customer_followups').select('*').eq('owner_id', user.id).order('completed').order('due_at').limit(100),
      supabase.from('customer_marketing').select('customer_id,customers(id,full_name)').eq('marketing_user_id', user.id).eq('is_active', true).lte('assigned_from', new Date().toISOString()).or(`assigned_until.is.null,assigned_until.gte.${new Date().toISOString()}`).limit(100),
    ]).then(([tasks, assignments]) => {
      if (tasks.error) throw tasks.error
      if (assignments.error) throw assignments.error
      if (!active) return
      setItems(tasks.data)
      setCheckedAt(Date.now())
      setCustomers(assignments.data.flatMap((entry) => {
        const item = Array.isArray(entry.customers) ? entry.customers[0] : entry.customers
        return item ? [{ id: item.id, name: item.full_name }] : []
      }))
      setError('')
    }).catch((error: unknown) => { if (active) setError(formatUserError(error)) }).finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [user, revision])
  const mutate = async (operation: () => PromiseLike<unknown>) => {
    if (lock.current) return
    lock.current = true; setBusy(true)
    try { await operation(); setRevision((v) => v + 1); setNote('') }
    catch (error) { setError(formatUserError(error)) }
    finally { lock.current = false; setBusy(false) }
  }
  const submit = (event: FormEvent) => { event.preventDefault(); void mutate(() => supabase.from('customer_followups').insert({ customer_id: customer, note: note.trim(), due_at: new Date(due).toISOString() }).throwOnError()) }
  return <section className="workbench rounded-xl border bg-white p-5 space-y-4"><h2 className="text-xl font-bold">Tindak lanjut nasabah dampingan</h2><p className="text-sm text-slate-600">Maksimal 100 penugasan dan tindak lanjut terdekat. Pengingat ditampilkan di aplikasi; tidak mengirim pesan kepada nasabah.</p>
    {loading && <p role="status">Memuat penugasan…</p>}{error && <p role="alert">{error}</p>}<button onClick={() => setRevision((v) => v + 1)} className="rounded-lg border px-3">Muat ulang tindak lanjut</button>
    {!loading && !customers.length && <p>Belum ada penugasan aktif. Hubungi manager untuk penugasan nasabah.</p>}
    {!!customers.length && <form onSubmit={submit} className="grid gap-4 sm:grid-cols-2"><label>Nasabah<select required value={customer} onChange={(e) => setCustomer(e.target.value)}><option value="">Pilih nasabah</option>{customers.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label><label>Waktu tindak lanjut<input required type="datetime-local" value={due} onChange={(e) => setDue(e.target.value)} /></label><label className="sm:col-span-2">Catatan tindak lanjut<textarea required maxLength={2000} value={note} onChange={(e) => setNote(e.target.value)} /></label><button disabled={busy} className="rounded-lg bg-green-800 px-4 text-white">{busy ? 'Menyimpan…' : 'Tambah tindak lanjut'}</button></form>}
    {!loading && !items.length && <p>Belum ada tindak lanjut.</p>}
    <ul className="space-y-3">{items.map((item) => <li key={item.id} className="rounded-lg border p-4"><p className="font-semibold">{customers.find((c) => c.id === item.customer_id)?.name ?? 'Nasabah penugasan sebelumnya'}</p><p className="whitespace-pre-wrap break-words">{item.note}</p><p className="text-sm">{new Date(item.due_at).toLocaleString('id-ID')} · {item.completed ? 'Selesai' : new Date(item.due_at).getTime() < checkedAt ? 'Perlu ditindaklanjuti' : 'Terjadwal'}</p>{!item.completed && <button disabled={busy} onClick={() => void mutate(() => supabase.from('customer_followups').update({ completed: true }).eq('id', item.id).throwOnError())} className="mt-2 rounded-lg border px-3">Tandai selesai</button>}</li>)}</ul>
  </section>
}
