BEGIN;

-- Synthetic local workflow data only. Never apply this seed to production.
CREATE TEMP TABLE seed_demo_customers (
    cif TEXT PRIMARY KEY,
    full_name TEXT NOT NULL,
    nik TEXT NOT NULL,
    birth_place TEXT,
    birth_date DATE,
    gender bmt_db.gender_type,
    occupation TEXT,
    income NUMERIC,
    phone TEXT,
    email TEXT,
    status bmt_db.customer_status NOT NULL,
    onboarding_status bmt_db.onboarding_status NOT NULL,
    purpose TEXT NOT NULL,
    product_code TEXT NOT NULL,
    loan_status bmt_db.loan_application_status
);

INSERT INTO seed_demo_customers VALUES
('900000000001','Ahmad Fauzi','352500000001','Gresik','1988-02-14','MALE','Pedagang sembako',8500000,'0800000001','demo.ahmad@example.test','ACTIVE','COMPLETED','Menabung','SAV40',NULL),
('900000000002','Siti Aminah','352500000002','Bungah','1991-06-21','FEMALE','Guru madrasah',5200000,'0800000002','demo.siti@example.test','ACTIVE','APPROVED','Menabung','SAV41',NULL),
('900000000003','M. Rizal Hidayat','352500000003','Lamongan','1985-11-03','MALE','Petani',6500000,'0800000003','demo.rizal@example.test','ACTIVE','COMPLETED','Deposito','DEP50-3M',NULL),
('900000000004','Nur Aisyah','352500000004','Surabaya','1994-04-17','FEMALE','Karyawan swasta',9000000,'0800000004','demo.aisyah@example.test','ACTIVE','MANAGER_REVIEW','Pembiayaan usaha','LOAN409','REVIEW'),
('900000000005','H. Abdul Karim','352500000005','Gresik','1978-09-09','MALE','Pemilik toko',15000000,'0800000005','demo.karim@example.test','ACTIVE','COMPLETED','Pembiayaan usaha','LOAN410','APPROVED'),
('CIF-DEMO-0006','Laila Khairunnisa','352500000006','Bungah','1997-01-28','FEMALE','Perawat',7200000,'0800000006','demo.laila@example.test','ACTIVE','COMPLETED','Tabungan pendidikan','SAV41',NULL),
('CIF-DEMO-0007','Fajar Maulana','352500000007','Sidayu','1989-12-12','MALE','Nelayan',7800000,'0800000007','demo.fajar@example.test','ACTIVE','COMPLETED','Pembiayaan modal kerja','LOAN409','APPROVED'),
('CIF-DEMO-0008','Dewi Kartika','352500000008','Gresik','1993-03-30','FEMALE','Wiraswasta',11000000,'0800000008','demo.dewi@example.test','ACTIVE','TELLER_REVIEW','Menabung','SAV40',NULL),
('CIF-DEMO-0009','Budi Santoso','352500000009','Bungah','1982-07-07','MALE','Bengkel motor',6800000,'0800000009','demo.budi@example.test','ACTIVE','COMPLETED','Pembiayaan konsumtif','LOAN413','REJECTED'),
('CIF-DEMO-0010','Maya Lestari','352500000010','Manyar','1996-10-19','FEMALE','Karyawan swasta',5800000,'0800000010','demo.maya@example.test','PROSPECT','DRAFT','Deposito','DEP50-6M',NULL),
('CIF-DEMO-0011','Yusuf Hadi','352500000011','Gresik','1975-05-25','MALE','Peternak',12500000,'0800000011','demo.yusuf@example.test','ACTIVE','COMPLETED','Pembiayaan usaha','LOAN410','APPROVED'),
('CIF-DEMO-0012','Rina Wulandari','352500000012','Bungah','1990-08-16','FEMALE','Ibu rumah tangga',4500000,'0800000012','demo.rina@example.test','ACTIVE','RETURNED','Menabung','SAV42',NULL);

INSERT INTO bmt_db.customers (cif_number,nik,full_name,birth_place,birth_date,gender,occupation,monthly_income,phone,email,branch_id,status,registered_at)
SELECT regexp_replace(s.cif,'[^0-9]','','g'),lpad(s.nik,16,'0'),s.full_name,s.birth_place,s.birth_date,s.gender,s.occupation,s.income,s.phone,s.email,b.id,s.status,now()
FROM seed_demo_customers s CROSS JOIN LATERAL (SELECT id FROM bmt_db.branches ORDER BY code LIMIT 1) b
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.customers c WHERE c.cif_number=regexp_replace(s.cif,'[^0-9]','','g'));

INSERT INTO bmt_db.onboarding_applications (branch_id,applicant_user_id,status,form_version,nik,full_name,birth_place,birth_date,gender,marital_status,mother_name,identity_type,nationality,religion,education,phone,email,occupation,employer_name,position_name,monthly_income,monthly_expense,source_of_funds,purpose_of_account,emergency_contact_name,emergency_contact_phone,emergency_relationship,submitted_at,approved_at,customer_id)
SELECT b.id,NULL,'DRAFT'::bmt_db.onboarding_status,1,lpad(s.nik,16,'0'),s.full_name,s.birth_place,s.birth_date,s.gender,'KAWIN','Ibu Demo','KTP','INDONESIA','ISLAM','SMA',s.phone,s.email,s.occupation,'Usaha Demo','Pemilik',s.income,s.income*0.55,'HASIL_USAHA',s.purpose,'Kontak Keluarga Demo','0899999999','Keluarga',NULL,NULL,c.id
FROM seed_demo_customers s CROSS JOIN LATERAL (SELECT id FROM bmt_db.branches ORDER BY code LIMIT 1) b JOIN bmt_db.customers c ON c.cif_number=regexp_replace(s.cif,'[^0-9]','','g')
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_applications o WHERE o.nik=s.nik);

INSERT INTO bmt_db.onboarding_addresses (application_id,address_type,address,province,city,district,village,postal_code,rt,rw,is_primary)
SELECT o.id,'ID_CARD','Jl. Contoh Demo No. '||right(s.cif,2),'Jawa Timur','Gresik','Bungah','Desa Demo','61152','001','002',true
FROM bmt_db.onboarding_applications o JOIN seed_demo_customers s ON s.nik=o.nik
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_addresses a WHERE a.application_id=o.id);

INSERT INTO bmt_db.onboarding_employment (application_id,employment_type,occupation,employer_name,position_name,business_name,business_type,years_employed,years_in_business,office_address,monthly_income,other_monthly_income,income_source_detail)
SELECT o.id,'WIRASWASTA',s.occupation,'Usaha Demo','Pemilik','Usaha Demo','PERDAGANGAN',4,4,'Jl. Usaha Demo, Gresik',s.income,0,'Pendapatan usaha sintetis'
FROM bmt_db.onboarding_applications o JOIN seed_demo_customers s ON s.nik=o.nik
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_employment e WHERE e.application_id=o.id);

INSERT INTO bmt_db.onboarding_financial_profiles (application_id,monthly_income,monthly_expense,total_assets,total_liabilities,source_of_funds,source_of_wealth,transaction_purpose,expected_monthly_tx_count,expected_monthly_tx_amount)
SELECT o.id,s.income,s.income*0.55,s.income*18,s.income*3,'HASIL_USAHA','TABUNGAN','Transaksi dan simpanan',20,s.income*2
FROM bmt_db.onboarding_applications o JOIN seed_demo_customers s ON s.nik=o.nik
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_financial_profiles f WHERE f.application_id=o.id);

INSERT INTO bmt_db.onboarding_bank_accounts (application_id,bank_name,account_type,account_number,account_name,is_primary)
SELECT o.id,'Bank Demo','TABUNGAN','900000'||right(s.cif,4),s.full_name,true
FROM bmt_db.onboarding_applications o JOIN seed_demo_customers s ON s.nik=o.nik
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_bank_accounts a WHERE a.application_id=o.id);

INSERT INTO bmt_db.onboarding_documents (application_id,document_type,document_number,storage_bucket,storage_path,mime_type,file_size_bytes,status,verification_notes)
SELECT o.id,'KTP',s.nik,'demo-documents','local-demo/'||s.cif||'/ktp.txt','text/plain',128,'VERIFIED','Dokumen sintetis untuk pengujian lokal'
FROM bmt_db.onboarding_applications o JOIN seed_demo_customers s ON s.nik=o.nik
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_documents d WHERE d.application_id=o.id);

INSERT INTO bmt_db.onboarding_product_requests (application_id,product_id,status,requested_amount,requested_tenor_months,purpose,rollover_type,profit_payment_method)
SELECT o.id,p.id,CASE WHEN s.onboarding_status IN ('APPROVED','COMPLETED') THEN 'APPROVED'::bmt_db.onboarding_product_status ELSE 'REQUESTED'::bmt_db.onboarding_product_status END,CASE WHEN p.category='LOAN' THEN s.income*2 ELSE 1000000 END,CASE WHEN p.category='LOAN' THEN 12 ELSE NULL END,s.purpose,CASE WHEN p.category='DEPOSIT' THEN 'NONE' ELSE NULL END,CASE WHEN p.category='DEPOSIT' THEN 'ADD_ON' ELSE NULL END
FROM bmt_db.onboarding_applications o JOIN seed_demo_customers s ON s.nik=o.nik JOIN bmt_db.products p ON p.code=s.product_code
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_product_requests r WHERE r.application_id=o.id);

INSERT INTO bmt_db.financial_accounts (account_number,account_type,customer_id,branch_id,product_id,status,opened_at,sequence_no)
SELECT '80000000.'||right(s.cif,4),'SAVINGS',c.id,b.id,p.id,'ACTIVE',now(),row_number() OVER (ORDER BY s.cif)
FROM seed_demo_customers s JOIN bmt_db.customers c ON c.cif_number=regexp_replace(s.cif,'[^0-9]','','g') CROSS JOIN LATERAL (SELECT id FROM bmt_db.branches ORDER BY code LIMIT 1) b JOIN bmt_db.products p ON p.code='SAV40'
WHERE s.status='ACTIVE' AND NOT EXISTS (SELECT 1 FROM bmt_db.financial_accounts fa WHERE fa.account_number='80000000.'||right(s.cif,4));

INSERT INTO bmt_db.savings_accounts (financial_account_id,current_balance,available_balance)
SELECT fa.id,CASE WHEN right(fa.account_number,2) IN ('01','03','05','07','11') THEN 2500000 ELSE 750000 END,CASE WHEN right(fa.account_number,2) IN ('01','03','05','07','11') THEN 2500000 ELSE 750000 END
FROM bmt_db.financial_accounts fa
WHERE fa.account_number LIKE '80000000.%'
  AND NOT EXISTS (SELECT 1 FROM bmt_db.savings_accounts sa WHERE sa.financial_account_id=fa.id);

INSERT INTO bmt_db.loan_applications (application_number,customer_id,savings_account_id,loan_product_id,branch_id,requested_amount,requested_tenor_months,purpose,status,submitted_at,decided_at,created_at)
SELECT 'APP-DEMO-'||right(s.cif,4),c.id,sa.financial_account_id,p.id,b.id,s.income*2,12,s.purpose,s.loan_status,now(),CASE WHEN s.loan_status IN ('APPROVED','REJECTED') THEN now() END,now()
FROM seed_demo_customers s JOIN bmt_db.customers c ON c.cif_number=regexp_replace(s.cif,'[^0-9]','','g') JOIN LATERAL (SELECT id FROM bmt_db.branches ORDER BY code LIMIT 1) b ON true JOIN bmt_db.products p ON p.code=s.product_code LEFT JOIN LATERAL (SELECT fa.id AS financial_account_id FROM bmt_db.financial_accounts fa WHERE fa.customer_id=c.id LIMIT 1) sa ON true
WHERE s.loan_status IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bmt_db.loan_applications l WHERE l.application_number='APP-DEMO-'||right(s.cif,4));

COMMIT;
