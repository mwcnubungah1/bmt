import { supabase } from './supabase'

export type WorkflowAction = 'teller' | 'manager' | 'finalize' | 'return'
export type ReviewInput = { signature: File | null; reason: string }

async function uploadSignature(applicationId: string, action: 'teller' | 'manager', file: File) {
  if (!['image/png', 'image/jpeg'].includes(file.type) || file.size > 2 * 1024 * 1024) {
    throw new Error('Tanda tangan harus PNG atau JPG, maksimal 2 MB.')
  }
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) throw new Error('Sesi berakhir. Silakan masuk kembali.')
  const path = `${data.user.id}/${applicationId}/${action}-${crypto.randomUUID()}`
  const uploaded = await supabase.storage.from('demo-signatures').upload(path, file, { contentType: file.type })
  if (uploaded.error) throw uploaded.error
  const digest = await crypto.subtle.digest('SHA-256', await file.arrayBuffer())
  const hash = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('')
  const signed = await supabase.rpc('sign_onboarding_application', { p_application_id: applicationId, p_signer_role: action === 'teller' ? 'TELLER' : 'MANAGER', p_storage_bucket: 'demo-signatures', p_storage_path: path, p_signature_sha256: hash })
  if (signed.error) throw signed.error
}

export async function reviewOnboarding(applicationId: string, action: WorkflowAction, input: ReviewInput) {
  if (action === 'teller' || action === 'manager') {
    if (!input.signature) throw new Error('Unggah tanda tangan Anda sebelum menyetujui.')
    await uploadSignature(applicationId, action, input.signature)
  }
  if (action === 'return' && !input.reason.trim()) throw new Error('Isi alasan pengembalian untuk nasabah.')
  const result = action === 'finalize'
    ? await supabase.rpc('finalize_onboarding_application', { p_application_id: applicationId })
    : await supabase.rpc(action === 'manager' ? 'complete_manager_onboarding_review' : 'complete_teller_onboarding_review', {
      p_application_id: applicationId, p_approve: action !== 'return', p_reason: input.reason.trim(),
    })
  if (result.error) throw result.error
  if (action === 'manager') {
    const finalized = await supabase.rpc('finalize_onboarding_application', { p_application_id: applicationId })
    if (finalized.error) throw finalized.error
  }
}
