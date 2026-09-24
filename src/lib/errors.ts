import type { PostgrestError } from '@supabase/supabase-js'

export function formatUserError(error: unknown): string {
  if (typeof error === 'object' && error !== null && 'message' in error) {
    const pgError = error as Partial<PostgrestError>
    if (pgError.message?.includes('Failed to fetch')) return 'Koneksi gagal. Periksa jaringan Anda lalu coba lagi.'
    if (pgError.code === '42501') return 'Anda tidak memiliki izin untuk melakukan tindakan ini.'
    if (pgError.code === '23505') return 'Data tersebut sudah terdaftar.'
    if (pgError.code === '23514') {
      if (pgError.message?.includes('postal')) return 'Kode pos harus terdiri dari 5 digit angka.'
      if (pgError.message?.includes('_rt') || pgError.message?.includes('_rw')) return 'RT dan RW hanya boleh berisi 1–5 digit angka.'
      if (pgError.message?.includes('birth_date')) return 'Tanggal lahir tidak boleh di masa depan.'
      return 'Ada format data yang belum sesuai. Periksa kembali isian formulir.'
    }
    if (pgError.code === '22007') return 'Format tanggal tidak valid. Periksa kembali tanggal lahir.'
    if (pgError.code === '22P02') return 'Ada pilihan atau angka yang belum sesuai format. Periksa kembali formulir Anda.'
    if (pgError.message?.toLowerCase().includes('invalid login')) return 'Email atau password tidak valid.'
    return pgError.message || 'Permintaan tidak dapat diproses. Silakan coba lagi.'
  }
  if (error instanceof Error) return error.message === 'Failed to fetch' ? 'Koneksi gagal. Periksa jaringan Anda lalu coba lagi.' : error.message
  return 'Terjadi kesalahan yang tidak diketahui. Silakan coba lagi.'
}
