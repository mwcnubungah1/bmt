import { AlertCircle, Inbox, RefreshCw } from 'lucide-react'

export function LoadingState() {
  return <div className="space-y-3 px-5 py-10" role="status" aria-label="Memuat data">{[1, 2, 3].map((item) => <div key={item} className="h-14 animate-pulse rounded-xl bg-[#e9f0e6]" />)}</div>
}

export function EmptyState({ message }: { message: string }) {
  return <div className="px-5 py-14 text-center"><Inbox className="mx-auto text-[#9bb79a]" size={32} /><p className="mt-3 font-semibold">{message}</p><p className="mt-1 text-sm text-[#475569]">Data akan muncul setelah aktivitas tercatat.</p></div>
}

export function ErrorState({ onRetry, message }: { onRetry: () => void; message?: string }) {
  return <div className="px-5 py-12 text-center" role="alert"><AlertCircle className="mx-auto text-[#b84e35]" size={30} /><p className="mt-3 font-semibold">Data belum dapat dimuat</p><p className="mt-1 text-sm text-[#475569]">{message || 'Periksa koneksi Anda, lalu coba lagi.'}</p><button type="button" onClick={onRetry} className="mt-5 inline-flex min-h-11 items-center gap-2 rounded-xl bg-[#1d7042] px-4 py-2 text-sm font-semibold text-white"><RefreshCw size={15} /> Coba lagi</button></div>
}
