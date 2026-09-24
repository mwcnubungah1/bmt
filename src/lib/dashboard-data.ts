import type { PostgrestError } from '@supabase/supabase-js'
import { supabase } from './supabase'
import type { Database } from '../types/database'

export type DashboardRow = Record<string, unknown>
export type DashboardSource = {
  label: string
  name: keyof Database['bmt_db']['Tables'] | keyof Database['bmt_db']['Functions']
  columns?: string
  paginated?: boolean
}

export const STAFF_SOURCES: DashboardSource[] = [
  { label: 'Nasabah', name: 'customers', columns: 'id,cif_number,full_name,status' },
  { label: 'Pendaftaran', name: 'onboarding_applications', columns: 'id,full_name,status,created_at' },
  { label: 'Rekening', name: 'financial_accounts', columns: 'id,account_number,account_type,status' },
  { label: 'Pengajuan kredit', name: 'loan_applications', columns: 'id,application_number,requested_amount,status' },
  { label: 'Transaksi', name: 'transactions', columns: 'id,transaction_number,amount,status' },
]

export const CUSTOMER_SOURCES: DashboardSource[] = [
  { label: 'Profil', name: 'portal_get_profile' },
  { label: 'Pendaftaran', name: 'portal_get_onboarding_applications' },
  { label: 'Tabungan', name: 'portal_get_savings_accounts' },
  { label: 'Deposito', name: 'portal_get_deposit_accounts' },
  { label: 'Pembiayaan', name: 'portal_get_loan_accounts' },
  { label: 'Ajukan kredit', name: 'portal_get_loan_applications' },
  { label: 'Angsuran', name: 'portal_get_loan_schedules', paginated: true },
  { label: 'Transaksi', name: 'portal_get_transactions', paginated: true },
]

export const PAGE_SIZE = 25

type DashboardResult = {
  data: DashboardRow[]
  error: PostgrestError | null
  hasNextPage: boolean
}

export async function fetchDashboardRows(
  staff: boolean,
  source: DashboardSource,
  page: number,
  search = '',
  status = '',
): Promise<DashboardResult> {
  if (staff) {
    let query = supabase
      .from(source.name as keyof Database['bmt_db']['Tables'])
      .select(source.columns ?? '*')
    const searchColumn = ({ customers: 'full_name', onboarding_applications: 'full_name', financial_accounts: 'account_number', loan_applications: 'application_number', transactions: 'transaction_number' } as Record<string, string>)[source.name]
    if (search.trim() && searchColumn) query = query.ilike(searchColumn, `%${search.trim().replace(/[%_]/g, '')}%`)
    if (status) query = query.filter('status', 'eq', status)
    const result = await query.order('id', { ascending: true }).range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE)

    return {
      data: (result.data ?? []) as unknown as DashboardRow[],
      error: result.error,
      hasNextPage: (result.data?.length ?? 0) > PAGE_SIZE,
    }
  }

  const result = await supabase.rpc(
    source.name as keyof Database['bmt_db']['Functions'],
    source.paginated
      ? { p_limit: PAGE_SIZE + 1, p_offset: page * PAGE_SIZE }
      : {},
  )

  return {
    data: (result.data ?? []) as unknown as DashboardRow[],
    error: result.error,
    hasNextPage: Boolean(source.paginated && (result.data?.length ?? 0) > PAGE_SIZE),
  }
}

export type DocumentRow = {
  id: string
  application_id: string
  document_type: string
  storage_bucket: string
  storage_path: string
  mime_type: string | null
  file_size_bytes: number | null
  status: string
  created_at: string
}

export async function fetchOnboardingDocuments(applicationId: string, staff: boolean) {
  if (!staff) {
    const result = await supabase.rpc('portal_get_onboarding_documents', { p_application_id: applicationId })
    if (result.error) throw result.error
    return (result.data ?? []) as unknown as DocumentRow[]
  }

  const result = await supabase
    .from('onboarding_documents')
    .select('id,application_id,document_type,storage_bucket,storage_path,mime_type,file_size_bytes,status,created_at')
    .eq('application_id', applicationId)
    .order('created_at', { ascending: false })
  if (result.error) throw result.error
  return (result.data ?? []) as unknown as DocumentRow[]
}

export async function createDocumentDownload(document: DocumentRow) {
  const result = await supabase.storage
    .from(document.storage_bucket)
    .createSignedUrl(document.storage_path, 300)
  if (result.error) throw result.error
  return result.data.signedUrl
}
