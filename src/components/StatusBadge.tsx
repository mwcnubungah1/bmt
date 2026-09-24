const names: Record<string, string> = {
  DRAFT: 'Draf', RETURNED: 'Perlu perbaikan', TELLER_REVIEW: 'Diperiksa teller',
  MANAGER_REVIEW: 'Menunggu manager', APPROVED: 'Disetujui', COMPLETED: 'Selesai',
  ACTIVE: 'Aktif', REJECTED: 'Ditolak', SUBMITTED: 'Diajukan', REVIEW: 'Diperiksa',
  PAID: 'Lunas', PENDING: 'Menunggu', POSTED: 'Dibukukan', CANCELLED: 'Dibatalkan',
}
export function StatusBadge({ value }: { value: unknown }) {
  const status = String(value ?? '')
  const tone = ['REJECTED', 'CANCELLED'].includes(status) ? 'bg-red-50 text-red-800' : ['RETURNED', 'PENDING'].includes(status) ? 'bg-amber-50 text-amber-800' : ['ACTIVE', 'APPROVED', 'COMPLETED', 'PAID', 'POSTED'].includes(status) ? 'bg-green-50 text-green-800' : 'bg-blue-50 text-blue-800'
  return <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${tone}`}>{names[status] ?? status.replaceAll('_', ' ')}</span>
}
