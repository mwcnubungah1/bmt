# Audit Keseluruhan Aplikasi BMT

Tanggal: 24 September 2026  
Ruang lingkup: React/Vite frontend, Supabase/PostgreSQL migrations/RLS/RPC, test suite, alur onboarding, tabungan, pembiayaan, teller, dan akuntansi.

## Ringkasan eksekutif

Aplikasi memiliki fondasi yang cukup baik: TypeScript dan lint lolos, penggunaan RPC untuk mutasi finansial sudah mengarah ke transaksi atomik, terdapat idempotency, audit/reconciliation, RLS, versioning produk, dan snapshot simulasi pembiayaan.

Namun aplikasi **belum layak produksi untuk transaksi BMT riil** sebelum isu P0/P1 ditutup. Risiko terbesar adalah:

1. RPC pemeliharaan status dapat dipanggil user authenticated biasa tetapi mengubah seluruh rekening/pembiayaan.
2. Denda keterlambatan tidak pernah dihitung walaupun saldo/COA penalty disediakan.
3. Tabel dokumen pembiayaan mengaktifkan RLS tanpa policy tabel, sehingga akses yang diberikan melalui GRANT tidak cukup dan alurnya berpotensi gagal/inkonsisten.
4. Rekonsiliasi harian menghitung ketidakseimbangan jurnal, tetapi belum menjamin kelengkapan transaksi, kas teller, outstanding ledger, dan duplicate run.
5. Implementasi “murabahah” belum menunjukkan kontrol fiqh-operasional yang memadai atas kepemilikan/risiko aset, wakalah, disclosure harga pokok dan margin, serta perlakuan ta’zir.

## Temuan prioritas

### P0 — RPC refresh dapat mengubah data global oleh user authenticated

`supabase/migrations/069_bmt_loan_disbursement_and_teller_payment.sql:199-210` mendefinisikan `refresh_loan_quality()` sebagai `SECURITY DEFINER` dan `supabase/migrations/069_bmt_loan_disbursement_and_teller_payment.sql:218-219` memberikan EXECUTE ke seluruh role `authenticated`. Fungsi melakukan UPDATE seluruh `loan_schedules` dan `loan_accounts`, tetapi tidak memeriksa role manager/superadmin maupun konteks job internal.

Masalah sejenis ada pada `supabase/migrations/070_bmt_savings_monthly_rules_dormant.sql:41-89` dan `:125-126`: `refresh_savings_account_status()` juga mengubah seluruh rekening dan dapat dipanggil user authenticated biasa.

Dampak: nasabah dapat memicu perubahan status pembiayaan/rekening nasabah lain; hal ini melanggar least privilege, segregasi tugas, dan integritas operasional.

Perbaikan: cabut EXECUTE dari `authenticated`, jadikan fungsi hanya dapat dipanggil oleh scheduler/service role yang terisolasi, atau tambahkan guard role + branch/job authorization. Tambahkan test negatif untuk customer, teller, marketing, dan manager lintas cabang.

### P0 — Denda keterlambatan selalu nol

Pada `supabase/migrations/069_bmt_loan_disbursement_and_teller_payment.sql:138-142` variabel penalty disiapkan, tetapi `:165` menetapkan `v_penalty := 0` tanpa menghitung overdue/policy produk. Nilai tersebut kemudian dipakai untuk installment payment, pengurangan outstanding, ledger, dan jurnal pada `:172-187`.

Dampak: saldo penalty tidak pernah tertagih/tercatat; atau sistem dapat menampilkan outstanding penalty yang tidak konsisten dengan penerimaan kas. Dari perspektif syariah, ini juga belum membuktikan perlakuan ta’zir yang benar. Denda keterlambatan bukan pendapatan BMT; bila diterapkan atas nasabah mampu yang sengaja menunda, penyalurannya harus dipisahkan sesuai kebijakan DPS/ketentuan yang berlaku, bukan otomatis menjadi `Pendapatan Denda`.

Perbaikan: tetapkan policy yang eksplisit: kapan denda boleh muncul, pengecualian force majeure/mu’sir, dasar perhitungan, pembulatan, approval, dan COA dana sosial/ta’zir terpisah. Uji allocation order dan jurnalnya secara end-to-end.

### P1 — RLS dokumen pembiayaan tidak lengkap

`supabase/migrations/071_bmt_loan_application_documents.sql:19-20` mengaktifkan RLS dan memberi SELECT/INSERT/UPDATE kepada `authenticated`, tetapi tidak membuat policy untuk `bmt_db.loan_application_documents`. Policy yang ada pada `:26-32` hanya untuk `storage.objects`.

Dampak: akses langsung tabel akan default-deny dan alur upload/validasi dokumen dapat gagal atau mendorong bypass lewat SECURITY DEFINER. Selain itu tidak ada policy staff untuk review dokumen, sementara storage policy hanya mengizinkan folder milik `auth.uid()`.

Perbaikan: buat policy customer-own untuk SELECT/INSERT/UPDATE terbatas pada application miliknya; policy staff berdasarkan role dan branch; cegah perubahan `customer_id`, application ID, status VERIFIED, dan storage bucket/path oleh client. Buat RPC review yang memeriksa role, cabang, dan state transition.

### P1 — Rekonsiliasi belum merupakan kontrol kas/ledger lengkap

`supabase/migrations/051_bmt_daily_reconciliation.sql:7-20` hanya membandingkan total debit-credit journal lines untuk transaksi POSTED. Belum terlihat constraint/guard untuk satu run per tanggal, actor/approval, cash session teller, movement kas, saldo sub-ledger, transaksi tanpa journal, journal tanpa transaksi, atau status exception yang wajib ditindaklanjuti.

Dampak: laporan dapat berstatus BALANCED walaupun ada transaksi POSTED tanpa jurnal yang ikut agregasi secara salah, kas teller berbeda dari jurnal, atau subledger tabungan/pembiayaan tidak sama dengan GL.

Perbaikan: tambahkan rekonsiliasi multi-perspektif: transaction↔journal, journal↔cash movement, subledger↔GL, teller opening/closing, dan duplicate prevention per branch/date. Exception harus immutable, memiliki owner, resolution, approval, dan evidence.

### P1 — Validasi numerik dan kontrak produk belum cukup ketat

`src/utils/murabahahCalculator.ts:32-60` memvalidasi principal/tenor/margin, tetapi tidak menolak `adminFeeValue` negatif untuk tipe percentage, tidak memvalidasi margin maksimum/policy DPS, dan menggunakan JavaScript number/floor untuk uang. RPC `customer_simulate_murabahah` pada `supabase/migrations/067_bmt_murabahah_product_simulation.sql:114-122` juga menerima `p_requested_amount` tanpa guard eksplisit `> 0`, memakai `v_lp.admin_fee_value` untuk fee fixed tanpa normalisasi negatif, dan belum memastikan tenor berada pada batas produk jika `tenor_options` kosong.

Dampak: simulasi frontend dan database dapat berbeda; fee/margin dapat memiliki nilai invalid; pembulatan dapat menimbulkan selisih material pada tenor panjang.

Perbaikan: gunakan NUMERIC end-to-end dan satu canonical calculator di database; validasi amount > 0, fee >= 0, rate range, tenor min/max, currency, scale, dan total schedule = selling price secara constraint/test.

### P1 — Model murabahah belum membuktikan substansi akad

Database menyimpan `akad_code`, `margin_rate`, `selling_price_snapshot`, dan terms (`067:7-21,75-83`), tetapi audit kode belum menemukan kontrol wajib berikut:

- bukti BMT memiliki/menguasai aset sebelum menjual kepada nasabah;
- wakalah terpisah dan batas penggunaannya bila nasabah menjadi agen pembelian;
- harga pokok, margin, harga jual, supplier/invoice, tanggal akuisisi, dan risiko aset;
- persetujuan akad final setelah analisis, bukan hanya simulasi;
- perubahan harga/versi produk setelah pengajuan yang tetap menjaga snapshot akad;
- perlakuan restrukturisasi, ibra’, pelunasan dipercepat, force majeure, dan nasabah mu’sir.

Label “murabahah” dan perhitungan flat saja belum cukup menjadi kontrol kepatuhan syariah. Ini memerlukan review DPS dan SOP BMT, bukan hanya perubahan kode.

### P1 — Kelemahan audit trail dan maker-checker

Walaupun tersedia status history/idempotency, mutasi penting masih perlu diverifikasi untuk memastikan setiap perubahan produk, approval, disbursement, payment, reversal, dan dokumen memiliki actor, timestamp, alasan, branch, before/after, dan approval chain yang immutable. `manager_create_murabahah_product` (`067:134-148`) membuat produk dan langsung membuat versi `ACTIVE` dengan `approved_by = v_user`, sehingga maker dan checker dapat menjadi orang yang sama.

Dampak: konflik kepentingan dan sulit membuktikan kontrol dua pihak saat audit internal/eksternal.

Perbaikan: pisahkan DRAFT → REVIEWED → APPROVED → ACTIVE, larang approver sama dengan creator, dan simpan audit event sebelum/after dalam append-only table.

### P2 — Upload dokumen belum atomic dan validasi konten masih lemah

`src/lib/onboarding-service.ts:36-70` melakukan save, upload KTP, insert metadata, upload signature, sign, lalu submit sebagai beberapa request. Retry dapat meninggalkan object yatim atau metadata tanpa object. Validasi upload mengandalkan MIME dan ukuran; belum ada pemeriksaan magic bytes, antivirus/antimalware, EXIF/privacy stripping, atau lifecycle cleanup.

Perbaikan: gunakan upload session/state machine, idempotency per document, cleanup job untuk orphan, content inspection server-side, dan signed URL minimum lifetime.

### P2 — Pagination frontend memiliki off-by-one

`src/lib/dashboard-data.ts:54` mengambil range `page * PAGE_SIZE` sampai `page * PAGE_SIZE + PAGE_SIZE`, yang pada Supabase bersifat inclusive. Ini mengambil 26 baris, sedangkan `:59` hanya memeriksa `> PAGE_SIZE`; data tampilan berpotensi menampilkan 26 baris dan navigasi berikutnya tidak konsisten.

Perbaikan: gunakan akhir range `page * PAGE_SIZE + PAGE_SIZE - 1`, atau sengaja ambil lookahead ke array terpisah lalu potong data tampilan menjadi 25.

### P2 — Dokumen readiness/audit sudah stale

`IMPLEMENTATION_AUDIT.md:6-7` masih menyebut migration 001–037, sedangkan repository memiliki migration sampai 071. `PRODUCTION_READINESS.md:35` juga masih menetapkan apply 001–036. `IMPLEMENTATION_AUDIT.md:46-49` menyatakan build/test PASS, tetapi kondisi saat audit ini build dan unit test gagal sebelum start karena native Tailwind/rolldown binding.

Dampak: operator dapat mengikuti prosedur deployment yang tidak mencakup schema terbaru dan mempercayai evidence yang tidak lagi valid.

Perbaikan: generate readiness evidence per commit, pin Node/package manager/platform, dan update runbook setiap migration release.

## Yang sudah baik

- TypeScript typecheck dan ESLint berhasil.
- Frontend menolak secret key dan memerlukan anon/publishable key (`src/lib/supabase.ts:11-17`).
- Banyak RPC sensitif memakai `SECURITY DEFINER` dengan `search_path` dipin.
- Terdapat idempotency key/unique constraint dan beberapa guard retry.
- Ada product version/snapshot untuk menjaga histori simulasi.
- Terdapat RLS test, branch matrix, teller cash session, dan reconciliation test assets.
- Mutasi disbursement/payment diarahkan melalui RPC transaksi database, bukan rangkaian update client.

## Validasi yang dijalankan

- `npm run typecheck`: PASS.
- `npm run lint`: PASS.
- `npm run build`: FAIL sebelum bundling karena native `@tailwindcss/oxide-win32-x64-msvc` tidak dapat dimuat (`spawn EPERM`, binding bukan UTF-8/valid).
- `npm run test:unit`: FAIL pada startup yang sama, sehingga test unit belum benar-benar dieksekusi.
- Audit statis repository, migration, RPC, RLS, dan dokumen readiness: selesai.

## Urutan remediasi yang disarankan

1. Tutup P0: batasi refresh RPC dan perbaiki penalty/ta’zir policy.
2. Tutup P1 RLS dokumen serta semua maker-checker dan audit trail.
3. Satukan kalkulator ke canonical NUMERIC database function dan tambahkan invariant tests.
4. Perluas reconciliation dan reversal controls.
5. Perbaiki upload state machine, pagination, dependency reproducibility, dan runbook.
6. Minta review DPS/penasihat syariah untuk akad, denda, restrukturisasi, ibra’, wakalah, dan pengelolaan dana sosial.

## Kesimpulan

Secara engineering aplikasi menunjukkan kemajuan dan struktur kontrol yang serius, tetapi kontrol otorisasi global, penalty accounting, RLS dokumen, dan substansi akad masih merupakan blocker. Status yang tepat saat ini adalah **staging/internal pilot dengan data sintetis**, bukan produksi dengan dana dan data nasabah nyata.
