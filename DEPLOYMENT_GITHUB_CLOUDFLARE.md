# Tutorial Deployment BMT NU Bungah

## 1. Salinan proyek

Salinan kerja aplikasi ada di D:\\BMT. Jangan commit file .env, .env.local, node_modules, atau dist.

## 2. GitHub

Buat repository kosong, misalnya bmt-nu-bungah. Jalankan:

    cd D:\\BMT
    git init
    git add .
    git commit -m "BMT v1.1.0"
    git branch -M main
    git remote add origin https://github.com/USERNAME/bmt-nu-bungah.git
    git push -u origin main

Ganti USERNAME dan URL repository sesuai akun Anda.

## 3. Environment

Buat .env.local untuk komputer sendiri:

    VITE_SUPABASE_URL=https://PROJECT_REF.supabase.co
    VITE_SUPABASE_ANON_KEY=SUPABASE_ANON_KEY
    VITE_CLOUDINARY_CLOUD_NAME=CLOUDINARY_CLOUD_NAME
    VITE_CLOUDINARY_UPLOAD_PRESET=CLOUDINARY_UNSIGNED_UPLOAD_PRESET

Nilai VITE_ masuk ke bundle browser. Jangan masukkan Supabase service-role key, Cloudinary API secret, atau password database ke frontend.

## 4. Supabase production

1. Buat project Supabase production.
2. Jalankan migration pada folder supabase/migrations sesuai urutan.
3. Pastikan schema bmt_db tersedia dan API expose schema tersebut.
4. Isi URL dan anon key dari Project Settings > API.
5. Uji login, pendaftaran, teller, manager, setoran, pengajuan, dan upload dokumen.

Dokumen pengajuan menggunakan bucket private loan-documents. Migration 071_bmt_loan_application_documents.sql membuat bucket dan policy-nya. Jangan ubah menjadi public tanpa keputusan keamanan.

## 5. Cloudinary

Gunakan Cloudinary untuk gambar publik atau aset visual. Buat unsigned upload preset dengan folder, format, dan ukuran yang dibatasi. Simpan hanya cloud name dan upload preset di environment frontend. Untuk KTP, KK, PDF, dan dokumen sensitif gunakan Supabase Storage private.

## 6. Cloudflare Pages

1. Cloudflare Dashboard > Workers & Pages > Create application > Pages > Connect to Git.
2. Pilih repository GitHub.
3. Framework preset: Vite.
4. Build command: npm run build.
5. Build output directory: dist.
6. Production branch: main.
7. Tambahkan VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY, VITE_CLOUDINARY_CLOUD_NAME, dan VITE_CLOUDINARY_UPLOAD_PRESET di Settings > Environment variables.
8. Deploy.

## 7. SPA routing

Jika refresh halaman seperti /login menghasilkan 404, tambahkan public/_redirects:

    /* /index.html 200

## 8. Checklist go-live

- npm ci
- npm run typecheck
- npm run lint
- npm run build
- Uji role customer, teller, marketing, manager.
- Uji buka sesi kas, setoran, tutup sesi kas.
- Uji pengajuan murabahah, upload dokumen, persetujuan manager.
- Uji pencairan dan pembayaran angsuran.
- Pastikan RLS, redirect URL Supabase Auth, domain Cloudflare, backup database, dan retensi dokumen sudah disiapkan.

## 9. Versi

Versi ini dikunci sebagai v1.1.0. Perbaikan berikutnya gunakan v1.1.1, v1.1.2, dan seterusnya. Setiap rilis harus melewati typecheck, lint, build, dan uji alur yang terdampak.
