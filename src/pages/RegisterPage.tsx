import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { ArrowLeft, ArrowRight, CheckCircle2, LockKeyhole, Mail, Phone, UserRound } from 'lucide-react'
import logo from '../assets/bmt-nu-bungah.webp'
import { useAuth } from '../contexts/auth-context'

export function RegisterPage() {
  const navigate = useNavigate()
  const { signUp, loading, error } = useAuth()
  const [fullName, setFullName] = useState('')
  const [phone, setPhone] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [submitted, setSubmitted] = useState(false)

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    try {
      await signUp({ fullName: fullName.trim(), phone: phone.trim(), email: email.trim(), password })
      setSubmitted(true)
    } catch { /* AuthContext menyediakan error yang aman. */ }
  }

  if (submitted) return <main className="flex min-h-screen items-center justify-center bg-[#f7faf7] px-5"><section className="w-full max-w-md rounded-[2rem] bg-white p-8 text-center shadow-xl shadow-[#8eb696]/15"><div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-[#eaf5eb] text-[#16843a]"><CheckCircle2 size={32} /></div><h1 className="mt-5 text-2xl font-bold text-[#204e31]">Akun berhasil dibuat</h1><p className="mt-3 text-sm leading-6 text-[#65816d]">Silakan login kembali, lalu lengkapi formulir identitas dan tanda tangan. Setelah formulir diajukan, pendaftaran akan muncul di antrean teller.</p><button onClick={() => navigate('/login')} className="mt-7 w-full rounded-2xl bg-[#16843a] px-4 py-3.5 font-semibold text-white">Lanjut ke login</button></section></main>

  return <main className="min-h-screen bg-[#f7faf7] px-5 py-6 text-[#173b2a] sm:px-8 sm:py-10"><div className="mx-auto max-w-lg"><Link to="/login" className="inline-flex items-center gap-2 text-sm font-semibold text-[#4e8b5e]"><ArrowLeft size={17} /> Kembali ke login</Link><div className="mt-8 flex items-center gap-3"><img src={logo} alt="BMT NU Bungah" className="h-12 w-24 object-contain object-left" /><span className="border-l border-[#d5e6d7] pl-3 text-xs font-semibold uppercase tracking-[0.15em] text-[#4b7557]">Pendaftaran nasabah</span></div><div className="mt-8 rounded-[2rem] border border-[#deebdf] bg-white p-6 shadow-sm sm:p-8"><h1 className="text-2xl font-bold">Mulai menjadi anggota</h1><p className="mt-2 text-sm leading-6 text-[#65816d]">Isi data singkat ini. Setelah diterima, Anda dapat melanjutkan formulir onboarding dan tanda tangan digital.</p><form onSubmit={submit} className="mt-7 space-y-4"><label className="block"><span className="mb-2 block text-sm font-semibold">Nama lengkap</span><div className="flex items-center rounded-2xl border border-[#d7e5d9] px-4 focus-within:border-[#399454] focus-within:ring-4 focus-within:ring-[#399454]/10"><UserRound size={18} className="text-[#7da086]" /><input required value={fullName} onChange={(event) => setFullName(event.target.value)} className="w-full bg-transparent px-3 py-3.5 outline-none" placeholder="Sesuai identitas resmi" /></div></label><label className="block"><span className="mb-2 block text-sm font-semibold">Nomor WhatsApp</span><div className="flex items-center rounded-2xl border border-[#d7e5d9] px-4 focus-within:border-[#399454] focus-within:ring-4 focus-within:ring-[#399454]/10"><Phone size={18} className="text-[#7da086]" /><input required type="tel" value={phone} onChange={(event) => setPhone(event.target.value)} className="w-full bg-transparent px-3 py-3.5 outline-none" placeholder="08xxxxxxxxxx" /></div></label><label className="block"><span className="mb-2 block text-sm font-semibold">Email</span><div className="flex items-center rounded-2xl border border-[#d7e5d9] px-4 focus-within:border-[#399454] focus-within:ring-4 focus-within:ring-[#399454]/10"><Mail size={18} className="text-[#7da086]" /><input required type="email" value={email} onChange={(event) => setEmail(event.target.value)} className="w-full bg-transparent px-3 py-3.5 outline-none" placeholder="nama@email.com" /></div></label><label className="block"><span className="mb-2 block text-sm font-semibold">Buat password</span><div className="flex items-center rounded-2xl border border-[#d7e5d9] px-4 focus-within:border-[#399454] focus-within:ring-4 focus-within:ring-[#399454]/10"><LockKeyhole size={18} className="text-[#7da086]" /><input required minLength={8} type="password" value={password} onChange={(event) => setPassword(event.target.value)} className="w-full bg-transparent px-3 py-3.5 outline-none" placeholder="Minimal 8 karakter" /></div></label>{error && <div className="rounded-2xl border border-red-200 bg-red-50 p-3 text-sm text-red-700">{error}</div>}<button disabled={loading} className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#16843a] px-4 py-3.5 font-semibold text-white shadow-lg shadow-[#16843a]/20 disabled:opacity-60">{loading ? 'Mendaftarkan...' : 'Kirim pendaftaran'}{!loading && <ArrowRight size={18} />}</button></form><p className="mt-5 text-xs leading-5 text-[#78917e]">Dengan mendaftar, Anda menyetujui proses verifikasi identitas oleh petugas BMT.</p></div></div></main>
}
