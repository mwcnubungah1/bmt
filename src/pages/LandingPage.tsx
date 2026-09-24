import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import {
  ArrowRight,
  CheckCircle2,
  Clock3,
  HandHeart,
  Landmark,
  Mail,
  MapPin,
  Menu,
  PackageOpen,
  Phone,
  ShieldCheck,
  Sparkles,
  Users,
  WalletCards,
  X,
  type LucideIcon,
} from 'lucide-react'
import logo from '../assets/bmt-nu-bungah.webp'
import { calculateMurabahah } from '../utils/murabahahCalculator'

const tenorOptions = [6, 12, 18, 24, 36]
const formatCurrency = (value: number) => new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(value)
const formatInput = (value: number) => new Intl.NumberFormat('id-ID').format(value)

const navItems = [
  ['Tentang Kami', '#tentang'],
  ['Simpanan', '#simpanan'],
  ['Pembiayaan Syariah', '#pembiayaan'],
  ['Berita/ZISWAF', '#ziswaf'],
  ['Kontak', '#kontak'],
] as const
const valueProps: Array<{ title: string; description: string; Icon: LucideIcon }> = [
  { title: 'Syariah', description: '100% prinsip syariah dan bebas riba.', Icon: ShieldCheck },
  { title: 'Transparan', description: 'Dikelola secara terbuka dan terpercaya.', Icon: Landmark },
  { title: 'Mudah', description: 'Layanan jemput bola teller keliling/mobile.', Icon: MapPin },
  { title: 'Berdaya', description: 'Sinergi pemberdayaan ekonomi Nahdliyin.', Icon: Users },
]

export function LandingPage() {
  const navigate = useNavigate()
  const [menuOpen, setMenuOpen] = useState(false)
  const [principal, setPrincipal] = useState(50_000_000)
  const [tenor, setTenor] = useState(12)
  const simulation = useMemo(() => calculateMurabahah({ principal, tenorMonths: tenor, marginRate: 12 }), [principal, tenor])

  const updatePrincipal = (raw: string) => {
    const parsed = Number(raw.replace(/\D/g, ''))
    if (Number.isFinite(parsed)) setPrincipal(Math.min(100_000_000, Math.max(5_000_000, parsed)))
  }

  const startApplication = () => {
    const payload = JSON.stringify({ principal, tenor, marginRate: 12, source: 'public-landing' })
    sessionStorage.setItem('bmt:public-murabahah-simulation', payload)
    localStorage.setItem('bmt:public-murabahah-simulation', payload)
    navigate('/login?next=%2Fnasabah%3Fview%3Dportal_get_loan_applications')
  }

  const scrollToSimulation = () => document.getElementById('simulasi')?.scrollIntoView({ behavior: 'smooth' })

  return (
    <div className="min-h-screen bg-[#fbfdf9] text-[#173b2a]">
      <header className="sticky top-0 z-50 border-b border-[#dcebdd] bg-white/90 shadow-sm backdrop-blur">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-3 sm:px-8 lg:px-10">
          <Link to="/" className="flex items-center gap-3" aria-label="BMT NU Bungah beranda">
            <img src={logo} alt="BMT NU Bungah" className="h-11 w-28 object-contain object-left" />
            <span className="hidden border-l border-[#d8e8da] pl-3 text-[10px] font-bold uppercase tracking-[0.18em] text-[#568061] sm:block">Berkah bersama</span>
          </Link>
          <nav className="hidden items-center gap-6 lg:flex" aria-label="Navigasi utama">
            {navItems.map(([label, href]) => <a key={href} href={href} className="text-sm font-semibold text-[#46674e] transition hover:text-[#16843a]">{label}</a>)}
          </nav>
          <div className="hidden items-center gap-2 sm:flex">
            <Link to="/login" className="rounded-xl px-4 py-2.5 text-sm font-bold text-[#16843a] hover:bg-[#edf7ee]">Masuk / Login</Link>
            <Link to="/daftar" className="rounded-xl bg-[#16843a] px-4 py-2.5 text-sm font-bold text-white shadow-lg shadow-[#16843a]/20 hover:bg-[#116e30]">Daftar Anggota</Link>
          </div>
          <button type="button" aria-label={menuOpen ? 'Tutup menu' : 'Buka menu'} onClick={() => setMenuOpen((value) => !value)} className="rounded-xl p-2 text-[#16843a] sm:hidden">{menuOpen ? <X /> : <Menu />}</button>
        </div>
        {menuOpen && <nav className="border-t border-[#dcebdd] bg-white px-5 py-4 sm:hidden" aria-label="Navigasi mobile">{navItems.map(([label, href]) => <a key={href} href={href} onClick={() => setMenuOpen(false)} className="block border-b border-[#edf4ed] py-3 text-sm font-semibold text-[#46674e]">{label}</a>)}<div className="mt-4 grid grid-cols-2 gap-2"><Link to="/login" className="rounded-xl border border-[#b9d8bd] py-3 text-center text-sm font-bold text-[#16843a]">Masuk</Link><Link to="/daftar" className="rounded-xl bg-[#16843a] py-3 text-center text-sm font-bold text-white">Daftar</Link></div></nav>}
      </header>

      <main>
        <section className="relative overflow-hidden bg-[radial-gradient(circle_at_80%_15%,#c9e8ca_0,transparent_35%),linear-gradient(135deg,#f4fbf3_0%,#ffffff_55%,#edf7ed_100%)]">
          <div className="mx-auto grid max-w-7xl gap-12 px-5 py-16 sm:px-8 sm:py-20 lg:grid-cols-[1.1fr_.9fr] lg:items-center lg:px-10 lg:py-28">
            <div>
              <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-[#c7e1ca] bg-white/75 px-4 py-2 text-xs font-bold uppercase tracking-[0.12em] text-[#318449]"><Sparkles size={15} /> Mitra tumbuh bersama umat</div>
              <h1 className="max-w-3xl text-4xl font-extrabold leading-[1.1] tracking-tight text-[#173b2a] sm:text-5xl lg:text-6xl">Solusi Keuangan Syariah yang <span className="text-[#16843a]">Amanah, Berkah, dan Berdaya.</span></h1>
              <p className="mt-6 max-w-2xl text-base leading-8 text-[#5b7862] sm:text-lg">Memberdayakan ekonomi umat dengan layanan keuangan berlandaskan prinsip syariah, transparansi, dan kebersamaan dari Bungah untuk keluarga dan usaha Anda.</p>
              <div className="mt-8 flex flex-col gap-3 sm:flex-row"><button type="button" onClick={scrollToSimulation} className="inline-flex items-center justify-center gap-2 rounded-2xl bg-[#16843a] px-5 py-3.5 font-bold text-white shadow-xl shadow-[#16843a]/20 hover:bg-[#116e30]">Simulasi Pembiayaan <ArrowRight size={18} /></button><Link to="/daftar" className="inline-flex items-center justify-center gap-2 rounded-2xl border border-[#b9d8bd] bg-white px-5 py-3.5 font-bold text-[#16843a] hover:bg-[#f1faf2]">Ajukan Menjadi Anggota</Link></div>
              <div className="mt-10 flex flex-wrap gap-4 text-xs font-semibold text-[#568061]"><span className="inline-flex items-center gap-2"><ShieldCheck size={17} className="text-[#16843a]" /> Amanah & transparan</span><span className="inline-flex items-center gap-2"><Users size={17} className="text-[#16843a]" /> Dekat dengan anggota</span></div>
            </div>
            <div className="relative mx-auto w-full max-w-md"><div className="absolute -inset-4 rounded-[2.5rem] bg-[#b9dfbd]/40 blur-2xl" /><div className="relative rounded-[2rem] border border-white/80 bg-white/80 p-5 shadow-2xl shadow-[#6da877]/20 backdrop-blur"><div className="flex items-center justify-between rounded-2xl bg-[#eff8ef] p-4"><div><p className="text-xs font-bold uppercase tracking-widest text-[#6b9472]">Dampak BMT NU Bungah</p><p className="mt-1 text-lg font-extrabold text-[#204e31]">Tumbuh dengan berkah</p></div><div className="rounded-2xl bg-[#16843a] p-3 text-white"><Landmark size={25} /></div></div><div className="mt-4 grid grid-cols-2 gap-4"><div className="rounded-3xl bg-gradient-to-br from-[#147b38] to-[#58ad64] p-5 text-white"><Users size={25} /><p className="mt-6 text-3xl font-extrabold">1.250+</p><p className="mt-1 text-sm text-white/75">Nasabah aktif</p></div><div className="rounded-3xl bg-[#fff8e8] p-5 text-[#765f27]"><PackageOpen size={25} /><p className="mt-6 text-3xl font-extrabold">12</p><p className="mt-1 text-sm text-[#8b784c]">Produk layanan</p></div></div><div className="mt-4 rounded-2xl bg-[#f3f9f3] p-4 text-sm leading-6 text-[#52715a]"><span className="font-bold text-[#204e31]">Melayani dengan amanah.</span> Simpanan, pembiayaan, dan layanan sosial untuk kebutuhan umat.</div></div></div>
          </div>
        </section>

        <section id="simulasi" className="scroll-mt-24 bg-[#173b2a] px-5 py-16 text-white sm:px-8 lg:py-24"><div className="mx-auto max-w-7xl"><div className="grid gap-10 lg:grid-cols-[.8fr_1.2fr] lg:items-start"><div><span className="text-sm font-bold uppercase tracking-[0.15em] text-[#b7dc9f]">Kalkulator publik</span><h2 className="mt-3 text-3xl font-extrabold sm:text-4xl">Rencanakan pembiayaan dengan lebih tenang.</h2><p className="mt-5 max-w-lg leading-7 text-[#c8ddcb]">Sesuaikan nominal dan tenor, lalu lihat estimasi cicilan murabahah secara transparan sebelum berkonsultasi dengan petugas kami.</p><div className="mt-7 flex items-center gap-3 text-sm text-[#d7e9d8]"><CheckCircle2 size={19} className="text-[#cce978]" /> Margin simulasi publik 12% flat per tahun</div></div><div className="rounded-[2rem] bg-white p-5 text-[#173b2a] shadow-2xl sm:p-7"><div className="grid gap-7 md:grid-cols-[1fr_.85fr]"><div><label htmlFor="public-principal" className="text-sm font-bold">Nominal Pengajuan</label><div className="mt-3 flex items-center rounded-2xl border border-[#cfe1d2] bg-[#fbfdf9] px-4"><span className="text-sm font-bold text-[#6b8b71]">Rp</span><input id="public-principal" aria-label="Nominal pengajuan" inputMode="numeric" value={formatInput(principal)} onChange={(event) => updatePrincipal(event.target.value)} className="w-full bg-transparent px-3 py-3.5 text-lg font-extrabold outline-none" /></div><input type="range" min="5000000" max="100000000" step="5000000" value={principal} onChange={(event) => setPrincipal(Number(event.target.value))} className="mt-5 w-full accent-[#16843a]" aria-label="Geser nominal pengajuan" /><div className="mt-2 flex justify-between text-xs text-[#79937d]"><span>Rp5 juta</span><span>Rp100 juta</span></div><p className="mt-7 text-sm font-bold">Tenor Pembiayaan</p><div className="mt-3 grid grid-cols-5 gap-2">{tenorOptions.map((option) => <button key={option} type="button" onClick={() => setTenor(option)} className={`rounded-xl border py-2.5 text-sm font-bold ${tenor === option ? 'border-[#16843a] bg-[#16843a] text-white' : 'border-[#d6e6d8] text-[#54745b] hover:border-[#16843a]'}`}>{option}</button>)}</div><p className="mt-2 text-right text-xs text-[#79937d]">Bulan</p></div><div className="rounded-3xl bg-[#eff8ef] p-5"><p className="text-xs font-bold uppercase tracking-[0.13em] text-[#6b9472]">Estimasi Cicilan / Bulan</p><p className="mt-3 text-3xl font-extrabold text-[#16843a]">{formatCurrency(simulation.monthlyInstallment)}</p><div className="my-5 h-px bg-[#d5e8d7]" /><dl className="space-y-3 text-sm"><div className="flex justify-between gap-3"><dt className="text-[#66836c]">Pokok pembiayaan</dt><dd className="font-bold">{formatCurrency(simulation.principal)}</dd></div><div className="flex justify-between gap-3"><dt className="text-[#66836c]">Margin BMT</dt><dd className="font-bold">{formatCurrency(simulation.marginAmount)}</dd></div><div className="flex justify-between gap-3"><dt className="text-[#66836c]">Total harga jual</dt><dd className="font-bold">{formatCurrency(simulation.sellingPrice)}</dd></div></dl></div></div><p className="mt-6 text-xs leading-5 text-[#6a856e]">Hasil simulasi ini merupakan estimasi awal. Perhitungan definitif ditetapkan pada saat penandatanganan akad di kantor BMT.</p><button type="button" onClick={startApplication} className="mt-5 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-[#16843a] px-5 py-3.5 font-bold text-white hover:bg-[#116e30]">Ajukan Pembiayaan Berdasarkan Simulasi Ini <ArrowRight size={18} /></button></div></div></div></section>

        <section id="tentang" className="scroll-mt-24 px-5 py-16 sm:px-8 lg:px-10 lg:py-24"><div className="mx-auto max-w-7xl"><div className="max-w-2xl"><span className="text-sm font-bold uppercase tracking-[0.15em] text-[#318449]">Layanan untuk keluarga dan usaha</span><h2 className="mt-3 text-3xl font-extrabold text-[#173b2a] sm:text-4xl">Pilihan produk yang tumbuh bersama kebutuhan Anda.</h2></div><div className="mt-10 grid gap-5 md:grid-cols-2"><article id="simpanan" className="rounded-[2rem] border border-[#dcebdd] bg-[#f4fbf4] p-7"><div className="flex items-center gap-3"><div className="rounded-2xl bg-[#d8efd9] p-3 text-[#16843a]"><WalletCards /></div><h3 className="text-xl font-extrabold">Simpanan Syariah</h3></div><p className="mt-4 leading-7 text-[#607d66]">Bangun kebiasaan baik dengan produk simpanan yang aman, sederhana, dan sesuai prinsip syariah.</p><div className="mt-6 space-y-3 text-sm font-semibold text-[#376744]"><p>• Tabungan Wadiah Sakinah</p><p>• Deposito Mudharabah Berjangka</p></div></article><article id="pembiayaan" className="rounded-[2rem] border border-[#e9dfc6] bg-[#fffaf0] p-7"><div className="flex items-center gap-3"><div className="rounded-2xl bg-[#f5e8be] p-3 text-[#a57616]"><HandHeart /></div><h3 className="text-xl font-extrabold">Pembiayaan Syariah</h3></div><p className="mt-4 leading-7 text-[#786c50]">Dukung rencana produktif Anda dengan akad yang jelas dan pendampingan yang dekat.</p><div className="mt-6 space-y-3 text-sm font-semibold text-[#765f27]"><p>• Murabahah pengadaan barang</p><p>• Modal kerja dan multijasa</p></div></article></div></div></section>

        <section className="bg-[#f1f8f1] px-5 py-16 sm:px-8 lg:px-10"><div className="mx-auto max-w-7xl"><div className="text-center"><span className="text-sm font-bold uppercase tracking-[0.15em] text-[#318449]">Nilai yang kami jaga</span><h2 className="mt-3 text-3xl font-extrabold text-[#173b2a]">Dekat, jelas, dan memberi manfaat.</h2></div><div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{valueProps.map(({ title, description, Icon }) => <div key={title} className="rounded-3xl bg-white p-6 shadow-sm"><div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[#e2f2e3] text-[#16843a]"><Icon size={21} /></div><h3 className="mt-5 font-extrabold">{title}</h3><p className="mt-2 text-sm leading-6 text-[#66836c]">{description}</p></div>)}</div></div></section>

        <section id="ziswaf" className="scroll-mt-24 px-5 py-16 sm:px-8 lg:px-10"><div className="mx-auto flex max-w-7xl flex-col justify-between gap-8 rounded-[2rem] bg-[#e4f3e5] p-8 sm:p-10 lg:flex-row lg:items-center"><div><span className="text-sm font-bold uppercase tracking-[0.15em] text-[#318449]">Berita & ZISWAF</span><h2 className="mt-3 text-3xl font-extrabold text-[#173b2a]">Kebaikan yang bergerak bersama.</h2><p className="mt-3 max-w-2xl leading-7 text-[#5f7d65]">Ikuti kabar program sosial, edukasi keuangan, dan aktivitas pemberdayaan BMT NU Bungah.</p></div><a href="mailto:info@bmtnubungah.id" className="inline-flex items-center justify-center gap-2 rounded-2xl bg-white px-5 py-3.5 font-bold text-[#16843a] shadow-sm">Hubungi kami <ArrowRight size={18} /></a></div></section>
      </main>

      <footer id="kontak" className="scroll-mt-24 bg-[#102d20] px-5 pb-8 pt-14 text-[#d8e9d9] sm:px-8 lg:px-10"><div className="mx-auto grid max-w-7xl gap-10 md:grid-cols-[1.2fr_.8fr_.8fr]"><div><img src={logo} alt="BMT NU Bungah" className="h-14 w-36 object-contain object-left brightness-0 invert" /><p className="mt-5 max-w-sm text-sm leading-6 text-[#a9c3ac]">BMT NU Bungah hadir sebagai mitra keuangan syariah yang amanah untuk menguatkan ekonomi umat.</p><p className="mt-4 text-xs leading-5 text-[#91b197]">Koperasi/KSPPS · Informasi legalitas dan akad tersedia di kantor BMT.</p></div><div><h3 className="font-extrabold text-white">Jam Layanan</h3><p className="mt-4 flex items-start gap-2 text-sm leading-6 text-[#a9c3ac]"><Clock3 size={17} className="mt-0.5 shrink-0 text-[#b7dc9f]" /> Senin–Jumat<br />08.00–15.00 WIB</p><p className="mt-3 flex items-start gap-2 text-sm leading-6 text-[#a9c3ac]"><MapPin size={17} className="mt-0.5 shrink-0 text-[#b7dc9f]" /> Bungah, Gresik, Jawa Timur</p></div><div><h3 className="font-extrabold text-white">Customer Care</h3><div className="mt-4 space-y-3 text-sm text-[#a9c3ac]"><a className="flex items-center gap-2 hover:text-white" href="https://wa.me/6281234567890"><Phone size={17} className="text-[#b7dc9f]" /> WhatsApp Customer Care</a><a className="flex items-center gap-2 hover:text-white" href="tel:+6281234567890"><Phone size={17} className="text-[#b7dc9f]" /> +62 812-3456-7890</a><a className="flex items-center gap-2 hover:text-white" href="mailto:info@bmtnubungah.id"><Mail size={17} className="text-[#b7dc9f]" /> info@bmtnubungah.id</a></div></div></div><div className="mx-auto mt-12 flex max-w-7xl flex-col justify-between gap-3 border-t border-white/10 pt-6 text-xs text-[#91b197] sm:flex-row"><span>© 2026 BMT NU Bungah. Semua hak dilindungi.</span><span>Layanan keuangan syariah untuk kemaslahatan umat.</span></div></footer>
    </div>
  )
}
