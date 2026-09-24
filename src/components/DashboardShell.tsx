import { BriefcaseBusiness, ClipboardCheck, LayoutDashboard, LogOut, RefreshCw, ShieldCheck, Users, WalletCards } from 'lucide-react'
import type { ReactNode } from 'react'
import type { AuthProfile } from '../types/auth'
import logo from '../assets/bmt-nu-bungah.webp'

type Props = {
  profile: AuthProfile | null
  sources: Array<{ label: string }>
  selected: number
  onHome?: () => void
  onSelect: (index: number) => void
  onSignOut: () => void
  role?: string
  children: ReactNode
}

const roleLabels: Record<string, string> = { teller: 'Ruang kerja teller', marketing: 'Ruang kerja marketing', manager: 'Ruang kerja manager', superadmin: 'Administrasi sistem', nasabah: 'Layanan nasabah' }

export function DashboardShell({ profile, sources, selected, onSelect, onSignOut, onHome, role, children }: Props) {
  const activeRole = role ?? profile?.roles[0]?.code?.toLowerCase() ?? 'nasabah'
  const icons = activeRole === 'nasabah' ? [LayoutDashboard, ClipboardCheck, WalletCards, BriefcaseBusiness, Users] : [Users, ClipboardCheck, WalletCards, BriefcaseBusiness, LayoutDashboard]
  return (
    <main className="min-h-screen text-[#183b2a]">
      <div className="flex min-h-screen">
        <aside className="hidden w-60 shrink-0 flex-col border-r border-[#d9e5d5] bg-[#fbfcf8] px-5 py-6 lg:flex">
          <div className="border-b border-[#e3ebdf] pb-6">
            <img src={logo} alt="BMT MWCNU Bungah" className="h-14 w-44 object-contain object-left" />
            <div className="mt-5 rounded-xl bg-[#f0f5ed] px-3 py-2"><p className="text-[11px] font-bold uppercase tracking-[0.14em] text-[#475569]">Akses aktif</p><p className="mt-1 text-sm font-semibold text-[#1d5133]">{roleLabels[activeRole] ?? 'Layanan BMT'}</p></div>
          </div>
          <nav className="mt-7 space-y-1" aria-label="Navigasi layanan">
            <p className="mb-2 px-3 text-[11px] font-bold uppercase tracking-[0.16em] text-[#475569]">Menu utama</p>
            {onHome && <button type="button" onClick={onHome} aria-current={selected === -1 ? 'page' : undefined} className={`flex min-h-11 w-full items-center gap-3 rounded-xl px-3 text-sm font-semibold ${selected === -1 ? 'bg-[#e3f0df] text-[#185e37]' : 'text-[#557360]'}`}><LayoutDashboard size={17} />Beranda</button>}
            {sources.map((source, index) => (
              <button
                key={source.label}
                type="button"
                onClick={() => onSelect(index)}
                aria-current={index === selected ? 'page' : undefined}
                className={`flex min-h-11 w-full items-center rounded-xl px-3 py-2.5 text-left text-sm font-semibold transition-colors duration-200 ${index === selected ? 'bg-[#e3f0df] text-[#185e37] shadow-sm' : 'text-[#557360] hover:bg-[#f0f5ed] hover:text-[#1d5133]'}`}
              >
                {(() => { const Icon = icons[index] ?? LayoutDashboard; return <Icon size={17} className="mr-3 shrink-0 opacity-75" /> })()}
                {source.label}
              </button>
            ))}
          </nav>
          <button type="button" onClick={onSignOut} className="mt-auto flex min-h-11 items-center gap-3 rounded-xl px-3 py-3 text-sm font-semibold text-[#557360] hover:bg-[#f0f5ed]">
            <LogOut size={17} /> Keluar
          </button>
        </aside>
        <div className="min-w-0 flex-1">
          <header className="flex items-center justify-between border-b border-[#d9e5d5] bg-[#fbfcf8] px-5 py-3 lg:hidden">
            <img src={logo} alt="BMT MWCNU Bungah" className="h-10 w-32 object-contain object-left" />
            <button type="button" onClick={onSignOut} className="min-h-11 rounded-xl border border-[#d4e2d0] px-4 py-2 text-sm">Keluar</button>
          </header>
          <div className="mx-auto max-w-7xl space-y-6 p-5 sm:p-8">
            <section className="rounded-2xl border border-[#d9e5d5] bg-white px-6 py-6 shadow-[0_8px_28px_rgba(32,75,43,0.05)] sm:px-8">
              <div className="flex flex-wrap items-start justify-between gap-5"><div><p className="text-xs font-bold uppercase tracking-[0.16em] text-[#475569]">{roleLabels[activeRole] ?? 'Layanan BMT'}</p><h1 className="mt-2 text-3xl font-bold tracking-tight text-[#183b2a]">Selamat datang, {profile?.fullName ?? 'Pengguna BMT'}</h1><p className="mt-2 max-w-2xl text-sm leading-6 text-[#557360]">Pantau layanan, pengajuan, dan aktivitas BMT Anda dalam satu tempat.</p></div><div className="hidden items-center gap-2 rounded-full bg-[#eaf5eb] px-3 py-2 text-xs font-semibold text-[#1d7042] lg:flex"><ShieldCheck size={15} /> Akses aman sesuai peran</div></div>
            </section>
            {children}
          </div>
        </div>
      </div>
    </main>
  )
}

export function RefreshButton({ onClick }: { onClick: () => void }) {
  return <button type="button" onClick={onClick} className="inline-flex min-h-11 items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold text-[#1d7042] hover:bg-[#edf5e9]"><RefreshCw size={15} /> Muat ulang</button>
}
