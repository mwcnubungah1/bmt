import { Component, type ErrorInfo, type ReactNode } from 'react'

type Props = { children: ReactNode }
type State = { error: Error | null }

export class AppErrorBoundary extends Component<Props, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Unhandled application error', error, info)
  }

  render() {
    if (!this.state.error) return this.props.children
    return <main className="flex min-h-screen items-center justify-center bg-[#f4f7f1] p-5 text-[#183b2a]"><section className="w-full max-w-lg rounded-3xl border border-[#d9e5d5] bg-white p-6 shadow-sm"><p className="text-sm font-semibold text-red-700">Halaman tidak dapat ditampilkan</p><h1 className="mt-2 text-2xl font-bold">Terjadi gangguan saat memproses data</h1><p className="mt-3 text-sm leading-6 text-slate-600">Data yang sudah tersimpan tetap aman. Muat ulang halaman lalu lanjutkan dari draf terakhir. Jika masalah berulang, hubungi petugas BMT.</p><details className="mt-4 rounded-xl bg-slate-50 p-3 text-xs text-slate-600"><summary className="cursor-pointer font-semibold">Lihat detail teknis</summary><pre className="mt-2 whitespace-pre-wrap break-words">{this.state.error.message || 'Kesalahan tanpa pesan'}</pre></details><div className="mt-5 flex flex-wrap gap-3"><button type="button" onClick={() => window.location.reload()} className="min-h-11 rounded-xl bg-green-800 px-4 font-semibold text-white">Muat ulang halaman</button><button type="button" onClick={() => this.setState({ error: null })} className="min-h-11 rounded-xl border border-[#d4e2d0] px-4 font-semibold">Coba tampilkan lagi</button></div></section></main>
  }
}
