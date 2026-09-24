import { supabase } from './supabase'
import { formatUserError } from './errors'

type SubmitOnboardingInput = {
  userId: string
  applicationId?: string
  onSaved?: (id: string) => void
  form: Record<string, string>
  ktpFile: File
  signatureDataUrl: string
  onUploadStatus: (status: 'uploading' | 'success' | 'error', message: string) => void
}

const INCOME_BY_BRACKET: Record<string, string> = {
  LT_1M: '500000',
  '1_2M': '1500000',
  '2_5M': '3500000',
  GT_5M: '7500000',
}

export async function submitOnboarding({
  userId,
  applicationId,
  onSaved,
  form,
  ktpFile,
  signatureDataUrl,
  onUploadStatus,
}: SubmitOnboardingInput) {
  if (applicationId) {
    const current = await supabase.from('onboarding_applications').select('status').eq('id', applicationId).single()
    if (current.error) throw current.error
    if (['TELLER_REVIEW', 'MANAGER_REVIEW', 'APPROVED', 'COMPLETED'].includes(current.data.status)) return
    if (!['DRAFT', 'RETURNED'].includes(current.data.status)) throw new Error('Status pendaftaran telah berubah. Muat ulang sebelum melanjutkan.')
  }
  const saved = await supabase.rpc('save_onboarding_draft', {
    p_data: { ...form, monthlyIncome: INCOME_BY_BRACKET[form.incomeBracket] },
    ...(applicationId ? { p_id: applicationId } : {}),
  })
  if (saved.error) throw new Error(`Penyimpanan data gagal: ${formatUserError(saved.error)}`)

  const id = String(saved.data)
  onSaved?.(id)
  const ktpHash = await hashBlob(ktpFile)
  const ktpPath = `${userId}/${id}/ktp-${ktpHash}-${sanitizeFileName(ktpFile.name)}`
  onUploadStatus('uploading', 'Sedang mengunggah KTP...')
  const upload = await uploadOnce('onboarding-documents', ktpPath, ktpFile)
  if (upload.error) { onUploadStatus('error', 'Upload gagal. Data draf sudah tersimpan; coba lagi.'); throw new Error(`Upload KTP gagal: ${upload.error.message}`) }
  onUploadStatus('success', 'Upload KTP berhasil.')

  const existingDocument = await supabase.from('onboarding_documents').select('id').eq('application_id', id).eq('storage_path', ktpPath).limit(1)
  if (existingDocument.error) throw existingDocument.error
  const document = existingDocument.data.length ? { error: null } : await supabase.from('onboarding_documents').insert({ application_id: id, document_type: 'KTP', storage_bucket: 'onboarding-documents', storage_path: ktpPath, mime_type: ktpFile.type, file_size_bytes: ktpFile.size }).select('id').single()
  if (document.error) throw new Error(`Pencatatan KTP gagal: ${formatUserError(document.error)}`)

  const product = await supabase.from('products').select('id').eq('code', form.productCode).eq('is_active', true).single()
  if (product.error || !product.data) throw new Error('Produk rekening belum tersedia. Pilih produk lain atau minta administrator mengaktifkannya.')
  const request = await supabase.from('onboarding_product_requests').upsert({ application_id: id, product_id: product.data.id, purpose: form.purpose }, { onConflict: 'application_id,product_id' })
  if (request.error) throw new Error(`Pilihan produk gagal disimpan: ${formatUserError(request.error)}`)

  const signatureBlob = await (await fetch(signatureDataUrl)).blob()
  const hash = await hashBlob(signatureBlob)
  const signaturePath = `${userId}/${id}/customer-signature-${hash}.png`
  const signatureUpload = await uploadOnce('demo-signatures', signaturePath, signatureBlob)
  if (signatureUpload.error) throw new Error(`Upload tanda tangan gagal: ${signatureUpload.error.message}`)
  const signed = await supabase.rpc('sign_onboarding_application', { p_application_id: id, p_signer_role: 'CUSTOMER', p_storage_bucket: 'demo-signatures', p_storage_path: signaturePath, p_signature_sha256: hash })
  if (signed.error) throw new Error(`Tanda tangan gagal disimpan: ${formatUserError(signed.error)}`)

  const submitted = await supabase.rpc('submit_onboarding_application', { p_application_id: id })
  if (submitted.error) throw new Error(`Pengajuan gagal: ${formatUserError(submitted.error)}`)
}

function sanitizeFileName(name: string) {
  return name.replace(/[^a-zA-Z0-9._-]/g, '_')
}

async function hashBlob(file: Blob) {
  const hash = await crypto.subtle.digest('SHA-256', await file.arrayBuffer())
  return Array.from(new Uint8Array(hash), (byte) => byte.toString(16).padStart(2, '0')).join('')
}

async function uploadOnce(bucket: string, path: string, file: Blob) {
  const result = await supabase.storage.from(bucket).upload(path, file, { upsert: false, contentType: file.type })
  if (!result.error) return result
  const existing = await supabase.storage.from(bucket).download(path)
  if (!existing.error && await hashBlob(existing.data) === await hashBlob(file)) return { error: null }
  return result
}

export async function saveOnboardingDraft(form: Record<string, string>, applicationId?: string) {
  const saved = await supabase.rpc('save_onboarding_draft', {
    p_data: { ...form, monthlyIncome: INCOME_BY_BRACKET[form.incomeBracket] ?? '' },
    ...(applicationId ? { p_id: applicationId } : {}),
  })
  if (saved.error) throw saved.error
  if (form.productCode) {
    const product = await supabase.from('products').select('id').eq('code', form.productCode).eq('is_active', true).single()
    if (product.error) throw product.error
    await supabase.from('onboarding_product_requests').upsert({ application_id: String(saved.data), product_id: product.data.id, purpose: form.purpose }, { onConflict: 'application_id,product_id' }).throwOnError()
  }
  return String(saved.data)
}
