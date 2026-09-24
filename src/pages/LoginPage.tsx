import { useMemo, useState, type FormEvent } from 'react'
import { Link, Navigate, useSearchParams } from 'react-router-dom'
import { ArrowRight, Calculator, Eye, EyeOff, LockKeyhole, ShieldCheck } from 'lucide-react'
import logo from '../assets/bmt-nu-bungah.webp'
import { useAuth } from '../contexts/auth-context'
import { calculateMurabahah } from '../utils/murabahahCalculator'

export function LoginPage() {
  const { user, signIn, loading, error } = useAuth()
  const [searchParams] = useSearchParams()
  const [identifier, setIdentifier] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loanAmount, setLoanAmount] = useState(50_000_000)
  const [loanTenor, setLoanTenor] = useState(12)
  const estimate = useMemo(() => calculateMurabahah({ principal: loanAmount, tenorMonths: loanTenor, marginRate: 12 }), [loanAmount, loanTenor])
  if (user) return <Navigate to={searchParams.get('next') || '/nasabah'} replace />

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    try { await signIn(identifier.trim(), password) } catch { /* AuthContext displays the error. */ }
  }

  return (
    <main className="min-h-screen bg-[#f7faf7] text-[#173b2a]">
      <div className="mx-auto flex min-h-screen max-w-6xl flex-col lg:flex-row">
        <section className="flex flex-1 flex-col justify-between px-6 pb-8 pt-8 sm:px-10 lg:px-16 lg:py-12">
          <div className="flex items-center gap-3"><img src={logo} alt="BMT NU Bungah" className="h-12 w-24 object-contain object-left" /><div className="border-l border-[#cfe1d2] pl-3 text-xs font-semibold uppercase tracking-[0.18em] text-[#4b7557]">Layanan keuangan umat</div></div>
          <div className="mx-auto w-full max-w-md py-12 lg:py-0">
            <div className="mb-8"><p className="mb-3 text-sm font-semibold text-[#318449]">Selamat datang kembali</p><h1 className="text-3xl font-bold tracking-tight sm:text-4xl">Masuk ke BMT NU Bungah</h1><p className="mt-3 text-sm leading-6 text-[#65816d]">Kelola simpanan, pembiayaan, dan layanan BMT dalam satu tempat.</p></div>
            <form onSubmit={handleSubmit} className="space-y-5">
              <label className="block"><span className="mb-2 block text-sm font-semibold">Email</span><input required type="email" autoComplete="username" value={identifier} onChange={(event) => setIdentifier(event.target.value)} className="w-full rounded-2xl border border-[#d7e5d9] bg-white px-4 py-3.5 text-[#173b2a] outline-none transition focus:border-[#399454] focus:ring-4 focus:ring-[#399454]/10" placeholder="nama@contoh.com" /></label>
              <label className="block"><span className="mb-2 block text-sm font-semibold">Password</span><div className="flex items-center rounded-2xl border border-[#d7e5d9] bg-white px-4 focus-within:border-[#399454] focus-within:ring-4 focus-within:ring-[#399454]/10"><LockKeyhole size={18} className="min-w-11 text-[#7da086]" /><input required autoComplete="current-password" type={showPassword ? 'text' : 'password'} value={password} onChange={(event) => setPassword(event.target.value)} className="w-full bg-transparent px-3 py-3.5 outline-none" placeholder="Masukkan password" /><button type="button" aria-label={showPassword ? 'Sembunyikan password' : 'Tampilkan password'} aria-pressed={showPassword} onClick={() => setShowPassword((value) => !value)} className="min-w-11 text-[#7da086]">{showPassword ? <EyeOff size={18} /> : <Eye size={18} />}</button></div></label>
              {error && <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-3 text-sm text-red-700">{error}</div>}
              <button disabled={loading} className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#16843a] px-4 py-3.5 font-semibold text-white shadow-lg shadow-[#16843a]/20 transition hover:bg-[#116e30] disabled:opacity-60">{loading ? 'Memproses...' : 'Masuk ke aplikasi'}{!loading && <ArrowRight size={18} />}</button>
            </form>
            <div className="mt-6 flex items-start gap-3 rounded-2xl bg-[#eaf5eb] p-4 text-xs leading-5 text-[#467153]"><ShieldCheck size={17} className="mt-0.5 shrink-0 text-[#16843a]" /><span>Data Anda dilindungi dengan autentikasi aman dan akses sesuai peran.</span></div>
            <p className="mt-6 text-center text-sm text-[#65816d]">Belum menjadi anggota? <Link to="/daftar" className="font-bold text-[#16843a] hover:underline">Daftar sebagai nasabah</Link></p>
          </div>
          <p className="text-center text-xs text-[#78917e] lg:text-left">BMT NU Bungah · Menuju Ekonomi Umat yang Barokah</p>
        </section>
        <aside className="hidden flex-1 items-center justify-center bg-[#e7f3e8] p-12 lg:flex"><div className="w-full max-w-md"><div className="mb-8 flex items-center gap-3"><div className="rounded-2xl bg-[#16843a] p-3 text-white"><Calculator size={23} /></div><div><p className="text-xs font-bold uppercase tracking-[0.15em] text-[#568061]">Kalkulator pembiayaan</p><h2 className="text-2xl font-extrabold text-[#204e31]">Hitung sebelum mengajukan</h2></div></div><div className="rounded-[2rem] bg-white p-7 shadow-xl shadow-[#8eb696]/20"><label htmlFor="login-loan-amount" className="text-sm font-bold text-[#204e31]">Nominal pembiayaan</label><div className="mt-3 flex items-center rounded-2xl border border-[#d7e5d9] px-4"><span className="text-sm font-bold text-[#7da086]">Rp</span><input id="login-loan-amount" inputMode="numeric" value={new Intl.NumberFormat('id-ID').format(loanAmount)} onChange={(event) => { const value = Number(event.target.value.replace(/\D/g, '')); if (value) setLoanAmount(Math.min(100_000_000, Math.max(5_000_000, value))) }} className="w-full bg-transparent px-3 py-3.5 text-lg font-extrabold outline-none" /></div><input type="range" min="5000000" max="100000000" step="5000000" value={loanAmount} onChange={(event) => setLoanAmount(Number(event.target.value))} className="mt-5 w-full accent-[#16843a]" aria-label="Geser nominal pembiayaan" /><p className="mt-6 text-sm font-bold text-[#204e31]">Tenor</p><div className="mt-3 grid grid-cols-5 gap-2">{[6, 12, 18, 24, 36].map((month) => <button key={month} type="button" onClick={() => setLoanTenor(month)} className={`rounded-xl border py-2 text-xs font-bold ${loanTenor === month ? 'border-[#16843a] bg-[#16843a] text-white' : 'border-[#d7e5d9] text-[#52715a]'}`}>{month} bln</button>)}</div><div className="mt-6 rounded-2xl bg-[#eff8ef] p-4"><p className="text-xs font-bold uppercase tracking-wider text-[#6b9472]">Estimasi cicilan / bulan</p><p className="mt-2 text-3xl font-extrabold text-[#16843a]">{new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(estimate.monthlyInstallment)}</p><p className="mt-2 text-xs text-[#66836c]">Margin simulasi 12% flat. Hasil akhir mengikuti akad dan persetujuan BMT.</p></div></div></div></aside>
      </div>
    </main>
  )
}
