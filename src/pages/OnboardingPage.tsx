import { useEffect, useRef, useState, type FormEvent, type PointerEvent } from 'react'
import { AlertCircle, ArrowLeft, CheckCircle2, FileText, Upload, UserRound } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useAuth } from '../contexts/auth-context'
import { formatUserError } from '../lib/errors'
import { loadOnboardingForm } from '../lib/onboarding-data'
import { ErrorState, LoadingState } from '../components/DashboardStates'
import { saveOnboardingDraft, submitOnboarding } from '../lib/onboarding-service'

type Status = { type: 'error' | 'success'; message: string }
type UploadStatus = 'idle' | 'ready' | 'uploading' | 'success' | 'error'
const inputClass = 'w-full rounded-2xl border border-[#d7e5d9] px-4 py-3 outline-none focus:border-[#399454] focus:ring-4 focus:ring-[#399454]/10'

export function OnboardingPage() {
  const [data, setData] = useState<Awaited<ReturnType<typeof loadOnboardingForm>> | null>(null)
  const [error, setError] = useState('')
  const [revision, setRevision] = useState(0)
  useEffect(() => {
    let active = true
    void loadOnboardingForm().then((result) => { if (active) { setData(result); setError('') } })
      .catch((reason: unknown) => { if (active) setError(formatUserError(reason)) })
    return () => { active = false }
  }, [revision])
  if (error) return <ErrorState message={error} onRetry={() => { setError(''); setRevision((value) => value + 1) }} />
  if (!data) return <LoadingState />
  if (data.application && !['DRAFT', 'RETURNED'].includes(data.application.status)) {
    return <main className="mx-auto max-w-xl space-y-5 p-6"><h1 className="text-2xl font-bold">Pendaftaran Anda</h1><p role="status">Status: {data.application.status}. Formulir sudah diterima.</p><Link className="inline-flex items-center rounded-xl bg-green-700 px-4 text-white" to="/nasabah">Lihat dashboard</Link></main>
  }
  return <OnboardingForm initial={data} />
}

function OnboardingForm({ initial }: { initial: Awaited<ReturnType<typeof loadOnboardingForm>> }) {
  const { user } = useAuth()
  const app = initial.application
  const [applicationId, setApplicationId] = useState(app?.id)
  const [step, setStep] = useState(0)
  const [savedAt, setSavedAt] = useState('')
  const saving = useRef(false)
  const hasStroke = useRef(false)
  const formElement = useRef<HTMLFormElement>(null)
  const steps = ['Identitas', 'Alamat', 'Pekerjaan', 'Dokumen']
  const moveStep = (next: number) => { setStep(next); requestAnimationFrame(() => formElement.current?.querySelector<HTMLElement>('fieldset:not([hidden]) input, fieldset:not([hidden]) select')?.focus()) }
  const address = initial.address
  const [form, setForm] = useState({
    fullName: app?.full_name ?? '', nik: app?.nik ?? '', birthPlace: app?.birth_place ?? '', birthDate: app?.birth_date ?? '', gender: app?.gender ?? '', motherName: app?.mother_name ?? '', nationality: 'INDONESIA', identityType: 'KTP',
    religion: app?.religion ?? '', education: app?.education ?? '', maritalStatus: app?.marital_status ?? '', phone: app?.phone ?? '', occupation: app?.occupation ?? '', employmentType: initial.employment?.employment_type ?? '', monthlyIncome: String(app?.monthly_income ?? ''), incomeBracket: app?.monthly_income ? (app.monthly_income < 1000000 ? 'LT_1M' : app.monthly_income <= 2000000 ? '1_2M' : app.monthly_income <= 5000000 ? '2_5M' : 'GT_5M') : '', sourceOfFunds: app?.source_of_funds ?? '',
    address: address?.address ?? '', province: address?.province ?? '', city: address?.city ?? '', district: address?.district ?? '', village: address?.village ?? '', postalCode: address?.postal_code ?? '', rt: address?.rt ?? '', rw: address?.rw ?? '', purpose: initial.product?.purpose ?? 'Menabung', productCode: initial.products.find((product) => product.id === initial.product?.product_id)?.code ?? '',
  })
  const [ktpFile, setKtpFile] = useState<File | null>(null)
  const [uploadStatus, setUploadStatus] = useState<UploadStatus>('idle')
  const [uploadMessage, setUploadMessage] = useState('')
  const [signatureDataUrl, setSignatureDataUrl] = useState('')
  const signatureCanvas = useRef<HTMLCanvasElement>(null)
  const drawing = useRef(false)
  const [status, setStatus] = useState<Status | null>(null)
  const [submitted, setSubmitted] = useState(false)
  const [loading, setLoading] = useState(false)
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})
  const [agree, setAgree] = useState(false)
  const saveDraft = async () => {
    if (saving.current) return
    saving.current = true; setLoading(true)
    try { const id = await saveOnboardingDraft(form, applicationId); setApplicationId(id); setSavedAt(new Date().toLocaleTimeString('id-ID')); setStatus(null) }
    catch (error) { setStatus({ type: 'error', message: formatUserError(error) }) }
    finally { saving.current = false; setLoading(false) }
  }
  const advanceStep = async () => {
    if (loading || step >= 3) return
    const currentStep = formElement.current?.querySelector<HTMLElement>(`fieldset[data-step="${step}"]`)
    const invalid = currentStep?.querySelector<HTMLInputElement | HTMLSelectElement>('input:invalid, select:invalid')
    if (invalid) {
      setFieldErrors((errors) => ({ ...errors, [invalid.id]: invalid.validationMessage }))
      invalid.reportValidity()
      return
    }
    if (step === 0 && !/^\d{16}$/.test(form.nik)) { setStatus({ type: 'error', message: 'NIK harus terdiri dari tepat 16 digit angka.' }); return }
    if (step === 1) {
      if (!/^\d{5}$/.test(form.postalCode)) { setStatus({ type: 'error', message: 'Kode pos harus terdiri dari tepat 5 digit angka.' }); return }
      if (!/^\d{1,5}$/.test(form.rt) || !/^\d{1,5}$/.test(form.rw)) { setStatus({ type: 'error', message: 'RT dan RW hanya boleh berisi 1–5 digit angka.' }); return }
    }
    if (step === 2 && (!form.employmentType || !form.occupation.trim() || !form.incomeBracket || !form.sourceOfFunds)) { setStatus({ type: 'error', message: 'Lengkapi data pekerjaan dan keuangan terlebih dahulu.' }); return }
    saving.current = true; setLoading(true); setStatus(null)
    try {
      const id = await saveOnboardingDraft(form, applicationId)
      setApplicationId(id); setSavedAt(new Date().toLocaleTimeString('id-ID')); moveStep(step + 1)
    } catch (error) { setStatus({ type: 'error', message: `Tahap ${step + 1} belum tersimpan: ${formatUserError(error)}` }) }
    finally { saving.current = false; setLoading(false) }
  }
  const update = (key: keyof typeof form, value: string) => { setSavedAt(''); setFieldErrors((errors) => ({ ...errors, [key]: '' })); setForm((current) => ({ ...current, [key]: value })); setStatus(null) }
  const field = (key: keyof typeof form, label: string, type = 'text', required = false) => { const pattern = key === 'nik' ? '[0-9]{16}' : key === 'postalCode' ? '[0-9]{5}' : ['rt', 'rw'].includes(key) ? '[0-9]{1,5}' : undefined; const title = key === 'nik' ? 'NIK harus 16 digit angka' : key === 'postalCode' ? 'Kode pos harus 5 digit angka' : ['rt', 'rw'].includes(key) ? 'RT/RW harus 1–5 digit angka' : undefined; return <label className="block"><span className="mb-2 block text-sm font-semibold">{label}{required && <span className="text-red-600"> *</span>}</span><input id={key} aria-invalid={Boolean(fieldErrors[key])} aria-describedby={fieldErrors[key] ? `${key}-error` : undefined} onInvalid={(event) => { const message = event.currentTarget.validationMessage; setFieldErrors((errors) => ({ ...errors, [key]: message })) }} pattern={pattern} title={title} inputMode={pattern ? 'numeric' : undefined} required={required} type={type} value={form[key]} onChange={(event) => update(key, event.target.value)} className={inputClass} />{fieldErrors[key] && <span id={`${key}-error`} className="text-sm text-red-800">{fieldErrors[key]}</span>}</label> }
  const select = (key: keyof typeof form, label: string, options: Array<[string, string]>, required = false) => <label className="block"><span className="mb-2 block text-sm font-semibold">{label}{required && <span className="text-red-600"> *</span>}</span><select id={key} aria-invalid={Boolean(fieldErrors[key])} aria-describedby={fieldErrors[key] ? `${key}-error` : undefined} onInvalid={(event) => { const message = event.currentTarget.validationMessage; setFieldErrors((errors) => ({ ...errors, [key]: message })) }} required={required} value={form[key]} onChange={(event) => update(key, event.target.value)} className={`${inputClass} bg-white`}><option value="">Pilih {label.toLowerCase()}</option>{options.map(([value, text]) => <option key={value} value={value}>{text}</option>)}</select>{fieldErrors[key] && <span id={`${key}-error`} className="text-sm text-red-800">{fieldErrors[key]}</span>}</label>
  const startSignature = (event: PointerEvent<HTMLCanvasElement>) => { const canvas = signatureCanvas.current; if (!canvas) return; drawing.current = true; canvas.setPointerCapture(event.pointerId); const rect = canvas.getBoundingClientRect(); const context = canvas.getContext('2d'); if (!context) return; context.beginPath(); context.moveTo((event.clientX - rect.left) * (canvas.width / rect.width), (event.clientY - rect.top) * (canvas.height / rect.height)) }
  const drawSignature = (event: PointerEvent<HTMLCanvasElement>) => { if (!drawing.current) return; const canvas = signatureCanvas.current; if (!canvas) return; const rect = canvas.getBoundingClientRect(); const context = canvas.getContext('2d'); if (!context) return; context.lineWidth = 3; context.lineCap = 'round'; context.strokeStyle = '#173b2a'; context.lineTo((event.clientX - rect.left) * (canvas.width / rect.width), (event.clientY - rect.top) * (canvas.height / rect.height)); context.stroke(); hasStroke.current = true;  }
  const clearSignature = () => { const canvas = signatureCanvas.current; const context = canvas?.getContext('2d'); if (canvas && context) context.clearRect(0, 0, canvas.width, canvas.height); setSignatureDataUrl(''); hasStroke.current = false }

  const uploadSignatureFile = async (file?: File) => {
    if (!file) return
    if (!['image/png', 'image/jpeg'].includes(file.type) || file.size > 2 * 1024 * 1024) {
      setStatus({ type: 'error', message: 'Tanda tangan harus PNG/JPG maksimal 2 MB.' }); return
    }
    try {
      const bitmap = await createImageBitmap(file)
      const canvas = signatureCanvas.current
      const context = canvas?.getContext('2d')
      if (!canvas || !context) { bitmap.close(); return }
      context.clearRect(0, 0, canvas.width, canvas.height)
      const scale = Math.min(canvas.width / bitmap.width, canvas.height / bitmap.height)
      context.drawImage(bitmap, 0, 0, bitmap.width * scale, bitmap.height * scale)
      bitmap.close()
      hasStroke.current = true; setSignatureDataUrl(canvas.toDataURL('image/png'))
    } catch { setStatus({ type: 'error', message: 'Gambar tanda tangan tidak dapat dibaca.' }) }
  }
  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); if (!user || saving.current) return
    const invalid = formElement.current?.querySelector<HTMLInputElement | HTMLSelectElement>('input:invalid, select:invalid')
    if (invalid) { setFieldErrors((errors) => ({ ...errors, [invalid.id]: invalid.validationMessage })); const fieldset = invalid.closest('fieldset'); moveStep(Number(fieldset?.dataset.step ?? 0)); requestAnimationFrame(() => invalid.reportValidity()); return }
    if (!/^\d{16}$/.test(form.nik)) { moveStep(0); setStatus({ type: 'error', message: 'NIK harus terdiri dari tepat 16 digit angka.' }); return }
    if (!/^\d{5}$/.test(form.postalCode)) { moveStep(1); setStatus({ type: 'error', message: 'Kode pos harus terdiri dari tepat 5 digit angka.' }); return }
    if (!/^\d{1,5}$/.test(form.rt) || !/^\d{1,5}$/.test(form.rw)) { moveStep(1); setStatus({ type: 'error', message: 'RT dan RW hanya boleh berisi 1–5 digit angka.' }); return }
    if (form.birthDate > new Date().toISOString().slice(0, 10)) { moveStep(0); setStatus({ type: 'error', message: 'Tanggal lahir tidak boleh di masa depan.' }); return }
    const required = [form.fullName, form.birthDate, form.gender, form.motherName, form.religion, form.maritalStatus, form.phone, form.occupation, form.incomeBracket, form.sourceOfFunds, form.address, form.province, form.city, form.district, form.village, form.postalCode, form.rt, form.rw]
    if (required.some((value) => !value.trim())) { setStatus({ type: 'error', message: 'Lengkapi seluruh data identitas, alamat KTP, pekerjaan, dan keuangan bertanda wajib.' }); return }
    if (!ktpFile) { setStatus({ type: 'error', message: 'Upload foto atau scan KTP terlebih dahulu.' }); return }
    if (!['image/jpeg', 'image/png', 'application/pdf'].includes(ktpFile.type)) { setStatus({ type: 'error', message: 'Format KTP harus JPG, PNG, atau PDF.' }); return }
    if (ktpFile.size > 5 * 1024 * 1024) { setStatus({ type: 'error', message: 'Ukuran file KTP maksimal 5 MB.' }); return }
    if (!signatureDataUrl) { setStatus({ type: 'error', message: 'Tanda tangan elektronik nasabah wajib dibuat di area tanda tangan.' }); return }
    if (!agree) { setStatus({ type: 'error', message: 'Centang persetujuan data dan tanda tangan elektronik terlebih dahulu.' }); return }
    saving.current = true; setLoading(true); setStatus(null)
    try {
      await submitOnboarding({ userId: user.id, applicationId, onSaved: setApplicationId, form, ktpFile, signatureDataUrl, onUploadStatus: (nextStatus, message) => { setUploadStatus(nextStatus); setUploadMessage(message) } })
      setSubmitted(true)
    } catch (error) { setStatus({ type: 'error', message: formatUserError(error) }) } finally { saving.current = false; setLoading(false) }
  }

  if (submitted) return <main className="flex min-h-screen items-center justify-center bg-[#f7faf7] px-4 py-8 text-[#173b2a]"><section className="w-full max-w-xl rounded-[2rem] border border-[#deebdf] bg-white p-6 text-center shadow-sm sm:p-10"><div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-[#eaf5eb] text-[#16843a]"><CheckCircle2 size={34} /></div><h1 className="mt-6 text-2xl font-bold">Terima kasih</h1><p className="mt-4 text-base leading-7 text-[#475569]">Data akan diproses pihak BMT MWCNU Bungah. Kami akan segera menghubungi Anda.</p><Link className="mt-7 inline-flex min-h-11 items-center rounded-xl bg-green-700 px-5 font-semibold text-white" to="/nasabah">Kembali ke dashboard</Link></section></main>

  return <main className="min-h-screen bg-[#f7faf7] px-4 py-6 text-[#173b2a] sm:px-8"><div className="mx-auto max-w-4xl"><Link to="/nasabah" className="inline-flex items-center gap-2 text-sm font-semibold text-[#4e8b5e]"><ArrowLeft size={17} /> Kembali</Link><div className="mt-6 rounded-[2rem] border border-[#deebdf] bg-white p-5 shadow-sm sm:p-8"><div className="flex items-start gap-4"><div className="rounded-2xl bg-[#eaf5eb] p-3 text-[#16843a]"><FileText size={22} /></div><div><p className="text-sm font-semibold text-[#4e8b5e]">Tahap {step + 1} dari 4</p><h1 className="mt-1 text-2xl font-bold">Formulir aplikasi pembukaan rekening</h1><p className="mt-2 text-sm leading-6 text-[#475569]">Isi sesuai KTP. Data akan diperiksa teller, lalu disahkan manager.</p></div></div>{app?.return_reason && <p role="status" className="mt-4 rounded-xl bg-amber-50 p-4">Catatan petugas: {app.return_reason}</p>}{!initial.products.length && <p role="status" className="mt-4">Belum ada produk aktif. Hubungi petugas BMT.</p>}<nav aria-label="Tahapan formulir" className="my-6 flex flex-wrap gap-2">{steps.map((name, index) => <button type="button" key={name} disabled={loading} aria-current={index === step ? 'step' : undefined} onClick={() => moveStep(index)} className={`rounded-lg border px-3 ${step === index ? 'bg-green-800 text-white' : 'bg-white'}`}>{index + 1}. {name}</button>)}</nav><p role="status">{savedAt ? `Draf tersimpan di server pukul ${savedAt}` : 'Simpan draf sebelum meninggalkan halaman. Berkas dan tanda tangan diunggah saat dikirim.'}</p><form ref={formElement} noValidate onSubmit={submit} className="mt-8 space-y-8">
    <fieldset data-step="0" hidden={step !== 0} disabled={loading}><h2 className="mb-4 flex items-center gap-2 font-bold"><UserRound size={18} className="text-[#16843a]" /> Data pribadi</h2><div className="grid gap-4 sm:grid-cols-2">{field('fullName', 'Nama lengkap sesuai identitas', 'text', true)}{field('nik', 'Nomor identitas / NIK', 'text', true)}{field('birthPlace', 'Tempat lahir', 'text', true)}{field('birthDate', 'Tanggal lahir', 'date', true)}{select('gender', 'Jenis kelamin', [['MALE', 'Pria'], ['FEMALE', 'Wanita']], true)}{field('motherName', 'Nama gadis ibu kandung', 'text', true)}{select('religion', 'Agama', [['ISLAM', 'Islam'], ['KATOLIK', 'Katolik'], ['PROTESTAN', 'Protestan'], ['BUDDHA', 'Budha'], ['HINDU', 'Hindu'], ['LAINNYA', 'Lainnya']], true)}{select('maritalStatus', 'Status perkawinan', [['LAJANG', 'Lajang'], ['KAWIN', 'Kawin'], ['CERAI', 'Janda/Duda']], true)}{field('phone', 'Nomor WhatsApp', 'tel', true)}</div></fieldset>
    <fieldset data-step="1" hidden={step !== 1} disabled={loading}><h2 className="mb-4 font-bold">Alamat sesuai KTP</h2><div className="grid gap-4 sm:grid-cols-2">{field('address', 'Alamat lengkap / nama jalan', 'text', true)}{field('province', 'Provinsi', 'text', true)}{field('city', 'Kabupaten / kota', 'text', true)}{field('district', 'Kecamatan', 'text', true)}{field('village', 'Kelurahan / desa', 'text', true)}{field('postalCode', 'Kode pos', 'text', true)}{field('rt', 'RT', 'text', true)}{field('rw', 'RW', 'text', true)}</div></fieldset>
    <fieldset data-step="2" hidden={step !== 2} disabled={loading}><h2 className="mb-4 font-bold">Data pekerjaan dan keuangan</h2><div className="grid gap-4 sm:grid-cols-2">{select('employmentType', 'Jenis pekerjaan', [['PNS', 'PNS'], ['SWASTA', 'Pegawai swasta'], ['BUMN', 'Pegawai BUMN'], ['PROFESIONAL', 'Profesional'], ['WIRASWASTA', 'Wiraswasta'], ['LAINNYA', 'Lainnya']], true)}{field('occupation', 'Jabatan / pekerjaan', 'text', true)}{select('incomeBracket', 'Penghasilan per bulan', [['LT_1M', '< Rp1 juta'], ['1_2M', 'Rp1 juta – Rp2 juta'], ['2_5M', 'Rp2 juta – Rp5 juta'], ['GT_5M', '> Rp5 juta']], true)}{select('sourceOfFunds', 'Sumber dana', [['GAJI', 'Gaji'], ['USAHA', 'Hasil usaha'], ['LAINNYA', 'Lainnya']], true)}</div></fieldset>
    <fieldset data-step="3" hidden={step !== 3} disabled={loading}><h2 className="mb-4 font-bold">Pembukaan rekening dan dokumen</h2><div className="grid gap-4 sm:grid-cols-2">{select('productCode', 'Produk yang dipilih', initial.products.map((product) => [product.code, product.name]), true)}{select('purpose', 'Tujuan pembukaan rekening', [['Menabung', 'Menabung'], ['Transaksi', 'Transaksi'], ['Pembiayaan', 'Pinjaman / kredit'], ['Deposito', 'Deposito']], true)}</div><label className="mt-4 flex flex-wrap cursor-pointer items-center gap-3 rounded-2xl border border-dashed border-[#9cc8a4] bg-[#f7fcf7] p-4"><Upload size={20} className="text-[#16843a]" /><span className="flex-1 text-sm"><strong className="block">Upload KTP *</strong><span className="text-[#475569]">JPG, PNG, atau PDF maksimal 5 MB</span></span><input required type="file" accept="image/jpeg,image/png,application/pdf" onChange={(event) => { const file = event.target.files?.[0] ?? null; setKtpFile(file); setUploadStatus(file ? 'ready' : 'idle'); setUploadMessage(file ? 'Dokumen siap diunggah saat formulir dikirim.' : '') }} className="max-w-[150px] text-xs" /></label>{ktpFile && <p className={`text-sm ${uploadStatus === 'error' ? 'text-red-700' : uploadStatus === 'success' ? 'text-[#16843a]' : 'text-[#467153]'}`}>{ktpFile.name} — {uploadMessage || 'Dokumen siap diunggah.'}</p>}<div className="mt-4 rounded-2xl border border-[#d7e5d9] p-4"><div className="flex items-center justify-between"><div><h3 className="font-semibold">Tanda tangan elektronik nasabah *</h3><p className="text-xs text-[#475569]">Tanda tangan langsung di layar gawai atau mouse.</p></div><button type="button" onClick={clearSignature} className="min-w-11 text-xs font-semibold text-[#16843a]">Hapus</button></div><label className="mt-3 block text-sm">Alternatif: unggah gambar tanda tangan Anda (PNG/JPG, maksimal 2 MB)<input type="file" accept="image/png,image/jpeg" onChange={(event) => void uploadSignatureFile(event.target.files?.[0])} className="mt-2 block max-w-full" /></label><canvas aria-label="Area menggambar tanda tangan" ref={signatureCanvas} width={900} height={240} onPointerDown={startSignature} onPointerMove={drawSignature} onPointerUp={() => { drawing.current = false; if (hasStroke.current) setSignatureDataUrl(signatureCanvas.current?.toDataURL('image/png') ?? '') }} onPointerLeave={() => { drawing.current = false }} className="mt-3 h-32 w-full touch-none rounded-xl border border-dashed border-[#9cc8a4] bg-white" /></div><label className="mt-4 flex items-start gap-3 text-sm"><input type="checkbox" checked={agree} onChange={(event) => setAgree(event.target.checked)} className="mt-1 h-4 w-4" /><span>Saya menyatakan data benar dan menyetujui penggunaan tanda tangan elektronik.</span></label></fieldset>
    {status && <div role="alert" className={`flex items-start gap-3 rounded-2xl p-4 text-sm ${status.type === 'error' ? 'bg-red-50 text-red-700' : 'bg-[#eaf5eb] text-[#467153]'}`}>{status.type === 'error' ? <AlertCircle size={18} className="mt-0.5 shrink-0" /> : <CheckCircle2 size={18} className="mt-0.5 shrink-0 text-[#16843a]" />}<span>{status.message}</span></div>}<div className="flex flex-wrap gap-3"><button type="button" disabled={loading || status?.type === 'success'} onClick={() => void saveDraft()} className="rounded-lg border px-4">Simpan draf</button>{step > 0 && <button type="button" disabled={loading} onClick={() => moveStep(step - 1)} className="rounded-lg border px-4">Sebelumnya</button>}{step < 3 && <button type="button" disabled={loading} onClick={() => void advanceStep()} className="rounded-lg bg-green-800 px-4 text-white">{loading ? 'Menyimpan tahap...' : 'Lanjut'}</button>}</div><button type="submit" hidden={step !== 3} disabled={loading || status?.type === 'success' || !initial.products.length} className="w-full rounded-2xl bg-[#16843a] px-4 py-3.5 font-semibold text-white disabled:opacity-60">{loading ? 'Menyimpan dan mengunggah...' : 'Kirim formulir untuk diperiksa'}</button></form></div></div></main>
}
