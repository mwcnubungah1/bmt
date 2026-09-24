BEGIN;

-- Repair only the local demo applications created by migration 023.
-- The original seed joined on the unpadded NIK while applications store
-- the normalized 16-character value, so child records were left empty.

WITH demo AS (
    SELECT o.id, c.full_name, c.nik, c.email, c.occupation,
           COALESCE(c.monthly_income, 5000000::numeric) AS income,
           CASE right(split_part(c.email, '@', 1), 2)
             WHEN '01' THEN 'SAV40' WHEN '02' THEN 'SAV41'
             WHEN '03' THEN 'DEP50' WHEN '04' THEN 'LOAN409'
             WHEN '05' THEN 'LOAN410' WHEN '06' THEN 'SAV41'
             WHEN '07' THEN 'LOAN409' WHEN '08' THEN 'SAV40'
             WHEN '09' THEN 'LOAN413' WHEN '10' THEN 'DEP50'
             WHEN '11' THEN 'LOAN410' ELSE 'SAV42'
           END AS product_code
    FROM bmt_db.onboarding_applications o
    JOIN bmt_db.customers c ON c.email = o.email
    WHERE o.email LIKE 'demo.%@example.test'
)
INSERT INTO bmt_db.onboarding_addresses
    (application_id,address_type,address,province,city,district,village,postal_code,rt,rw,is_primary)
SELECT id,'ID_CARD','Jl. Contoh Demo No. '||right(split_part(email,'@',1),2),
       'Jawa Timur','Gresik','Bungah','Desa Demo','61152','001','002',true
FROM demo d
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_addresses x WHERE x.application_id=d.id);

WITH demo AS (
    SELECT o.id, c.occupation, c.full_name, COALESCE(c.monthly_income,5000000::numeric) income
    FROM bmt_db.onboarding_applications o JOIN bmt_db.customers c ON c.email=o.email
    WHERE o.email LIKE 'demo.%@example.test'
)
INSERT INTO bmt_db.onboarding_employment
    (application_id,employment_type,occupation,employer_name,position_name,business_name,business_type,years_employed,years_in_business,office_address,monthly_income,other_monthly_income,income_source_detail)
SELECT id,'WIRASWASTA',occupation,'Usaha Demo','Pemilik','Usaha Demo','PERDAGANGAN',4,4,
       'Jl. Usaha Demo, Gresik',income,0,'Pendapatan usaha sintetis'
FROM demo d
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_employment x WHERE x.application_id=d.id);

WITH demo AS (
    SELECT o.id, COALESCE(c.monthly_income,5000000::numeric) income
    FROM bmt_db.onboarding_applications o JOIN bmt_db.customers c ON c.email=o.email
    WHERE o.email LIKE 'demo.%@example.test'
)
INSERT INTO bmt_db.onboarding_financial_profiles
    (application_id,monthly_income,monthly_expense,total_assets,total_liabilities,source_of_funds,source_of_wealth,transaction_purpose,expected_monthly_tx_count,expected_monthly_tx_amount)
SELECT id,income,income*0.55,income*18,income*3,'HASIL_USAHA','TABUNGAN','Transaksi dan simpanan',20,income*2
FROM demo d
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_financial_profiles x WHERE x.application_id=d.id);

WITH demo AS (
    SELECT o.id,c.full_name,c.email
    FROM bmt_db.onboarding_applications o JOIN bmt_db.customers c ON c.email=o.email
    WHERE o.email LIKE 'demo.%@example.test'
)
INSERT INTO bmt_db.onboarding_bank_accounts
    (application_id,bank_name,account_type,account_number,account_name,is_primary)
SELECT id,'Bank Demo','TABUNGAN','900000'||right(split_part(email,'@',1),2),full_name,true
FROM demo d
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_bank_accounts x WHERE x.application_id=d.id);

WITH demo AS (
    SELECT o.id,c.nik,c.email
    FROM bmt_db.onboarding_applications o JOIN bmt_db.customers c ON c.email=o.email
    WHERE o.email LIKE 'demo.%@example.test'
)
INSERT INTO bmt_db.onboarding_documents
    (application_id,document_type,document_number,storage_bucket,storage_path,mime_type,file_size_bytes,status,verification_notes)
SELECT id,'KTP',nik,'demo-documents','local-demo/'||split_part(email,'@',1)||'/ktp.txt',
       'text/plain',128,'UPLOADED',NULL
FROM demo d
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_documents x WHERE x.application_id=d.id);

WITH demo AS (
    SELECT o.id,o.purpose_of_account,c.email,c.monthly_income income,
           CASE right(split_part(c.email,'@',1),2)
             WHEN '01' THEN 'SAV40' WHEN '02' THEN 'SAV41' WHEN '03' THEN 'DEP50'
             WHEN '04' THEN 'LOAN409' WHEN '05' THEN 'LOAN410' WHEN '06' THEN 'SAV41'
             WHEN '07' THEN 'LOAN409' WHEN '08' THEN 'SAV40' WHEN '09' THEN 'LOAN413'
             WHEN '10' THEN 'DEP50' WHEN '11' THEN 'LOAN410' ELSE 'SAV42' END product_code
    FROM bmt_db.onboarding_applications o JOIN bmt_db.customers c ON c.email=o.email
    WHERE o.email LIKE 'demo.%@example.test'
)
INSERT INTO bmt_db.onboarding_product_requests
    (application_id,product_id,status,requested_amount,requested_tenor_months,purpose,rollover_type,profit_payment_method)
SELECT d.id,p.id,'REQUESTED',CASE WHEN p.category='LOAN' THEN COALESCE(d.income,5000000)*2 ELSE 1000000 END,
       CASE WHEN p.category='LOAN' THEN 12 ELSE NULL END,d.purpose_of_account,
       CASE WHEN p.category='DEPOSIT' THEN 'NONE' ELSE NULL END,
       CASE WHEN p.category='DEPOSIT' THEN 'ADD_ON' ELSE NULL END
FROM demo d JOIN bmt_db.products p ON p.code=d.product_code
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_product_requests x WHERE x.application_id=d.id);

DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM bmt_db.onboarding_applications o
  WHERE o.email LIKE 'demo.%@example.test'
    AND NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_addresses a WHERE a.application_id=o.id)
    AND NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_employment e WHERE e.application_id=o.id)
    AND NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_financial_profiles f WHERE f.application_id=o.id)
    AND NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_documents d WHERE d.application_id=o.id)
    AND NOT EXISTS (SELECT 1 FROM bmt_db.onboarding_product_requests p WHERE p.application_id=o.id);
  IF n <> 0 THEN RAISE EXCEPTION '027 assertion failed: % demo applications remain incomplete', n; END IF;
END $$;

COMMIT;




