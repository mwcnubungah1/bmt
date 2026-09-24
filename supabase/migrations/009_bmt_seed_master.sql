-- ============================================================
-- BMT CORE BANKING SYSTEM
-- Migration : 009_bmt_seed_master.sql
-- Purpose   : Master data seed
-- Version   : 1.0.0
-- Requires  : 001 - 008
-- ============================================================

BEGIN;


-- ============================================================
-- 1. HEAD OFFICE
-- ============================================================

INSERT INTO bmt_db.branches (
    code,
    name,
    branch_type,
    is_active
)
VALUES (
    '001',
    'Kantor Pusat',
    'HQ',
    TRUE
)
ON CONFLICT (code) DO NOTHING;


-- ============================================================
-- 2. SYSTEM ROLES
-- ============================================================

INSERT INTO bmt_db.roles (
    code,
    name,
    description,
    is_system,
    is_active
)
VALUES
(
    'SUPERADMIN',
    'Super Administrator',
    'Technical and system administrator.',
    TRUE,
    TRUE
),
(
    'MANAGER',
    'Manager',
    'Managerial approval, analysis and reporting.',
    TRUE,
    TRUE
),
(
    'MARKETING',
    'Marketing',
    'Prospect, customer acquisition and loan application.',
    TRUE,
    TRUE
),
(
    'TELLER',
    'Teller',
    'Customer servicing and teller transactions.',
    TRUE,
    TRUE
),
(
    'CUSTOMER',
    'Customer',
    'Customer portal role.',
    TRUE,
    TRUE
)
ON CONFLICT (code) DO NOTHING;


-- ============================================================
-- 3. PERMISSIONS
-- ============================================================

INSERT INTO bmt_db.permissions (
    code,
    module,
    description
)
VALUES

-- Customer
('customer.view', 'customer', 'View customer information'),
('customer.create', 'customer', 'Create customer'),
('customer.update', 'customer', 'Update customer'),

-- Savings
('savings.open', 'savings', 'Open savings account'),
('savings.deposit', 'savings', 'Post savings deposit'),
('savings.withdraw', 'savings', 'Post savings withdrawal'),

-- Deposit
('deposit.open', 'deposit', 'Open deposit account'),
('deposit.close', 'deposit', 'Close or terminate deposit account'),

-- Loan
('loan.create', 'loan', 'Create loan application'),
('loan.analyze', 'loan', 'Perform credit analysis'),
('loan.approve', 'loan', 'Approve or reject loan application'),
('loan.disburse', 'loan', 'Disburse approved loan'),
('loan.payment', 'loan', 'Post installment payment'),

-- Transactions
('transaction.approve', 'transaction', 'Approve transaction'),
('transaction.reverse', 'transaction', 'Reverse posted transaction'),

-- Teller
('teller.cash.open', 'teller', 'Open teller cash session'),
('teller.cash.close', 'teller', 'Close teller cash session'),
('teller.cash.view', 'teller', 'View teller cash session'),

-- Reports
('report.financial.view', 'report', 'View accounting and financial reports'),
('report.loan.view', 'report', 'View loan portfolio reports'),

-- System
('system.user.manage', 'system', 'Manage users and authorization'),
('system.product.manage', 'system', 'Manage financial products'),
('system.coa.manage', 'system', 'Manage chart of accounts'),
('system.branch.manage', 'system', 'Manage branches'),
('system.period.manage', 'system', 'Manage fiscal periods')

ON CONFLICT (code) DO NOTHING;


-- ============================================================
-- 4. SUPERADMIN PERMISSIONS
-- ============================================================

INSERT INTO bmt_db.role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM bmt_db.roles r
CROSS JOIN bmt_db.permissions p
WHERE r.code = 'SUPERADMIN'
ON CONFLICT DO NOTHING;


-- ============================================================
-- 5. MANAGER PERMISSIONS
-- ============================================================

INSERT INTO bmt_db.role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM bmt_db.roles r
JOIN bmt_db.permissions p
  ON p.code IN (
      'customer.view',

      'loan.create',
      'loan.analyze',
      'loan.approve',
      'loan.disburse',
      'loan.payment',

      'transaction.approve',
      'transaction.reverse',

      'teller.cash.view',

      'report.financial.view',
      'report.loan.view'
  )
WHERE r.code = 'MANAGER'
ON CONFLICT DO NOTHING;


-- ============================================================
-- 6. MARKETING PERMISSIONS
-- ============================================================

INSERT INTO bmt_db.role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM bmt_db.roles r
JOIN bmt_db.permissions p
  ON p.code IN (
      'customer.view',
      'customer.create',
      'customer.update',
      'loan.create',
      'report.loan.view'
  )
WHERE r.code = 'MARKETING'
ON CONFLICT DO NOTHING;


-- ============================================================
-- 7. TELLER PERMISSIONS
-- ============================================================

INSERT INTO bmt_db.role_permissions (
    role_id,
    permission_id
)
SELECT
    r.id,
    p.id
FROM bmt_db.roles r
JOIN bmt_db.permissions p
  ON p.code IN (
      'customer.view',
      'customer.create',
      'customer.update',

      'savings.open',
      'savings.deposit',
      'savings.withdraw',

      'deposit.open',
      'deposit.close',

      'loan.payment',
      'loan.disburse',

      'teller.cash.open',
      'teller.cash.close',
      'teller.cash.view'
  )
WHERE r.code = 'TELLER'
ON CONFLICT DO NOTHING;


-- ============================================================
-- 8. CHART OF ACCOUNTS
-- ============================================================
-- Insert parents before children.


-- ASSET
INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
VALUES (
    '1', 'ASET', 'ASSET', 'DEBIT',
    NULL, 1, FALSE
)
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.01', 'Kas dan Setara Kas', 'ASSET', 'DEBIT',
    id, 2, FALSE
FROM bmt_db.chart_of_accounts
WHERE code = '1'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.01.001', 'Kas Teller', 'ASSET', 'DEBIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '1.01'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.01.002', 'Kas Utama', 'ASSET', 'DEBIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '1.01'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.02', 'Bank', 'ASSET', 'DEBIT',
    id, 2, FALSE
FROM bmt_db.chart_of_accounts
WHERE code = '1'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.02.001', 'Bank Operasional', 'ASSET', 'DEBIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '1.02'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.03', 'Piutang dan Pembiayaan', 'ASSET', 'DEBIT',
    id, 2, FALSE
FROM bmt_db.chart_of_accounts
WHERE code = '1'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.03.001', 'Piutang Kredit Umum', 'ASSET', 'DEBIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '1.03'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.03.002', 'Piutang Murabahah', 'ASSET', 'DEBIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '1.03'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.03.003', 'Piutang Qardh', 'ASSET', 'DEBIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '1.03'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.04', 'Cadangan Penurunan Nilai', 'ASSET', 'CREDIT',
    id, 2, FALSE
FROM bmt_db.chart_of_accounts
WHERE code = '1'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '1.04.001', 'Cadangan Kerugian Piutang', 'ASSET', 'CREDIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '1.04'
ON CONFLICT (code) DO NOTHING;


-- LIABILITY

INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
VALUES (
    '2', 'LIABILITAS', 'LIABILITY', 'CREDIT',
    NULL, 1, FALSE
)
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '2.01', 'Simpanan Anggota', 'LIABILITY', 'CREDIT',
    id, 2, FALSE
FROM bmt_db.chart_of_accounts
WHERE code = '2'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '2.01.001', 'Tabungan Umum', 'LIABILITY', 'CREDIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '2.01'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '2.01.002', 'Tabungan Pendidikan', 'LIABILITY', 'CREDIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '2.01'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '2.01.003', 'Tabungan Qurban', 'LIABILITY', 'CREDIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '2.01'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '2.02', 'Deposito', 'LIABILITY', 'CREDIT',
    id, 2, FALSE
FROM bmt_db.chart_of_accounts
WHERE code = '2'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '2.02.001', 'Deposito 3 Bulan', 'LIABILITY', 'CREDIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '2.02'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '2.02.002', 'Deposito 6 Bulan', 'LIABILITY', 'CREDIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '2.02'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '2.02.003', 'Deposito 12 Bulan', 'LIABILITY', 'CREDIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '2.02'
ON CONFLICT (code) DO NOTHING;


-- EQUITY

INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
VALUES (
    '3', 'EKUITAS', 'EQUITY', 'CREDIT',
    NULL, 1, FALSE
)
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '3.01', 'Modal', 'EQUITY', 'CREDIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '3'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '3.02', 'Cadangan', 'EQUITY', 'CREDIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '3'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '3.03', 'Sisa Hasil Usaha', 'EQUITY', 'CREDIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '3'
ON CONFLICT (code) DO NOTHING;


-- INCOME

INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
VALUES (
    '4', 'PENDAPATAN', 'INCOME', 'CREDIT',
    NULL, 1, FALSE
)
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '4.01', 'Pendapatan Margin', 'INCOME', 'CREDIT',
    id, 2, FALSE
FROM bmt_db.chart_of_accounts
WHERE code = '4'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '4.01.001', 'Pendapatan Kredit Umum', 'INCOME', 'CREDIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '4.01'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '4.01.002', 'Pendapatan Margin Murabahah', 'INCOME', 'CREDIT',
    id, 3, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '4.01'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '4.02', 'Pendapatan Administrasi', 'INCOME', 'CREDIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '4'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '4.03', 'Pendapatan Denda', 'INCOME', 'CREDIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '4'
ON CONFLICT (code) DO NOTHING;


-- EXPENSE

INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
VALUES (
    '5', 'BEBAN', 'EXPENSE', 'DEBIT',
    NULL, 1, FALSE
)
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '5.01', 'Beban Operasional', 'EXPENSE', 'DEBIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '5'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '5.02', 'Beban Gaji', 'EXPENSE', 'DEBIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '5'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '5.03', 'Beban Penyusutan', 'EXPENSE', 'DEBIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '5'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '5.04', 'Beban Bagi Hasil', 'EXPENSE', 'DEBIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '5'
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.chart_of_accounts (
    code, name, account_type, normal_balance,
    parent_id, level, allow_posting
)
SELECT
    '5.05', 'Beban Penurunan Nilai', 'EXPENSE', 'DEBIT',
    id, 2, TRUE
FROM bmt_db.chart_of_accounts
WHERE code = '5'
ON CONFLICT (code) DO NOTHING;


-- ============================================================
-- 9. FISCAL PERIODS 2026
-- ============================================================

INSERT INTO bmt_db.fiscal_periods (
    fiscal_year,
    period_no,
    start_date,
    end_date,
    status
)
SELECT
    2026,
    m,
    make_date(2026, m, 1),
    (
        make_date(2026, m, 1)
        + INTERVAL '1 month'
        - INTERVAL '1 day'
    )::date,
    'OPEN'::bmt_db.fiscal_period_status
FROM generate_series(1, 12) AS m
ON CONFLICT (fiscal_year, period_no) DO NOTHING;


-- ============================================================
-- 10. SAVINGS PRODUCTS
-- ============================================================

INSERT INTO bmt_db.products (
    code,
    name,
    category,
    description,
    currency,
    is_active
)
VALUES
('SAV40', 'Tabungan Umum', 'SAVINGS',
 'Produk tabungan umum anggota.', 'IDR', TRUE),

('SAV41', 'Tabungan Pendidikan', 'SAVINGS',
 'Produk tabungan pendidikan.', 'IDR', TRUE),

('SAV42', 'Tabungan Qurban', 'SAVINGS',
 'Produk tabungan perencanaan qurban.', 'IDR', TRUE)

ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.savings_products (
    product_id,
    account_code,
    minimum_opening_balance,
    minimum_balance,
    minimum_deposit,
    minimum_withdrawal,
    admin_fee,
    profit_sharing_rate,
    dormant_after_days,
    dormant_fee,
    allow_negative_balance,

    liability_coa_id,
    admin_income_coa_id,
    profit_expense_coa_id
)
SELECT
    p.id,
    x.account_code,

    x.opening_balance,
    x.minimum_balance,
    x.minimum_deposit,
    x.minimum_withdrawal,

    x.admin_fee,
    x.profit_rate,

    365,
    0,
    FALSE,

    liability.id,
    admin_income.id,
    profit_expense.id

FROM (
    VALUES
        (
            'SAV40',
            '40',
            50000::numeric,
            25000::numeric,
            10000::numeric,
            10000::numeric,
            5000::numeric,
            0::numeric,
            '2.01.001'
        ),
        (
            'SAV41',
            '41',
            50000::numeric,
            25000::numeric,
            10000::numeric,
            10000::numeric,
            3000::numeric,
            0::numeric,
            '2.01.002'
        ),
        (
            'SAV42',
            '42',
            50000::numeric,
            25000::numeric,
            10000::numeric,
            10000::numeric,
            3000::numeric,
            0::numeric,
            '2.01.003'
        )
) AS x(
    product_code,
    account_code,
    opening_balance,
    minimum_balance,
    minimum_deposit,
    minimum_withdrawal,
    admin_fee,
    profit_rate,
    liability_code
)

JOIN bmt_db.products p
  ON p.code = x.product_code

JOIN bmt_db.chart_of_accounts liability
  ON liability.code = x.liability_code

JOIN bmt_db.chart_of_accounts admin_income
  ON admin_income.code = '4.02'

JOIN bmt_db.chart_of_accounts profit_expense
  ON profit_expense.code = '5.04'

ON CONFLICT (product_id) DO NOTHING;


-- ============================================================
-- 11. DEPOSIT PRODUCTS
-- ============================================================

INSERT INTO bmt_db.products (
    code,
    name,
    category,
    description,
    currency,
    is_active
)
VALUES
(
    'DEP50-3M',
    'Deposito 3 Bulan',
    'DEPOSIT',
    'Simpanan berjangka tenor 3 bulan.',
    'IDR',
    TRUE
),
(
    'DEP50-6M',
    'Deposito 6 Bulan',
    'DEPOSIT',
    'Simpanan berjangka tenor 6 bulan.',
    'IDR',
    TRUE
),
(
    'DEP50-12M',
    'Deposito 12 Bulan',
    'DEPOSIT',
    'Simpanan berjangka tenor 12 bulan.',
    'IDR',
    TRUE
)
ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.deposit_products (
    product_id,
    account_code,
    minimum_amount,
    tenor_months,
    profit_rate,
    profit_method,
    early_withdrawal_allowed,
    early_withdrawal_penalty,
    allow_aro,
    default_aro_type,

    liability_coa_id,
    profit_expense_coa_id,
    penalty_income_coa_id
)
SELECT
    p.id,
    x.account_code,

    x.minimum_amount,
    x.tenor,
    x.profit_rate,

    'MONTHLY',

    TRUE,
    50000,

    TRUE,
    'PRINCIPAL',

    liability.id,
    profit_expense.id,
    penalty_income.id

FROM (
    VALUES
        (
            'DEP50-3M',
            '50',
            3,
            1000000::numeric,
            3.00000000::numeric,
            '2.02.001'
        ),
        (
            'DEP50-6M',
            '51',
            6,
            1000000::numeric,
            4.00000000::numeric,
            '2.02.002'
        ),
        (
            'DEP50-12M',
            '52',
            12,
            1000000::numeric,
            5.00000000::numeric,
            '2.02.003'
        )
) AS x(
    product_code,
    account_code,
    tenor,
    minimum_amount,
    profit_rate,
    liability_code
)

JOIN bmt_db.products p
    ON p.code = x.product_code

JOIN bmt_db.chart_of_accounts liability
    ON liability.code = x.liability_code

JOIN bmt_db.chart_of_accounts profit_expense
    ON profit_expense.code = '5.04'

JOIN bmt_db.chart_of_accounts penalty_income
    ON penalty_income.code = '4.03'

ON CONFLICT (product_id) DO NOTHING;

-- ============================================================
-- 12. LOAN PRODUCTS
-- ============================================================

INSERT INTO bmt_db.products (
    code,
    name,
    category,
    description,
    currency,
    is_active
)
VALUES
('LOAN409', 'Kredit Umum', 'LOAN',
 'Produk kredit umum.', 'IDR', TRUE),

('LOAN410', 'Pembiayaan Murabahah', 'LOAN',
 'Produk pembiayaan akad murabahah.', 'IDR', TRUE),

('LOAN413', 'Pembiayaan Qardh', 'LOAN',
 'Produk pembiayaan akad qardh.', 'IDR', TRUE)

ON CONFLICT (code) DO NOTHING;


INSERT INTO bmt_db.loan_products (
    product_id,
    loan_code,
    contract_type,

    minimum_principal,
    maximum_principal,

    minimum_tenor_months,
    maximum_tenor_months,

    rate_type,
    rate,

    installment_method,

    admin_fee,
    provision_rate,
    penalty_rate,

    grace_period_days,

    require_collateral,
    require_manager_approval,

    receivable_coa_id,
    margin_income_coa_id,
    admin_income_coa_id,
    penalty_income_coa_id,
    impairment_coa_id
)
SELECT
    p.id,
    x.loan_code,
    x.contract_type::bmt_db.contract_type,

    x.minimum_principal,
    x.maximum_principal,

    x.minimum_tenor,
    x.maximum_tenor,

    x.rate_type,
    x.rate,

    'MONTHLY',

    x.admin_fee,
    x.provision_rate,
    x.penalty_rate,

    0,

    x.require_collateral,
    TRUE,

    receivable.id,
    margin_income.id,
    admin_income.id,
    penalty_income.id,
    impairment.id

FROM (
    VALUES
        (
            'LOAN409',
            '409',
            'CONVENTIONAL',
            1000000::numeric,
            100000000::numeric,
            3,
            36,
            'FLAT',
            12.00000000::numeric,
            100000::numeric,
            1.00000000::numeric,
            0.10000000::numeric,
            TRUE,
            '1.03.001',
            '4.01.001'
        ),
        (
            'LOAN410',
            '410',
            'MURABAHAH',
            1000000::numeric,
            100000000::numeric,
            3,
            36,
            'FIXED_MARGIN',
            12.00000000::numeric,
            100000::numeric,
            1.00000000::numeric,
            0.10000000::numeric,
            TRUE,
            '1.03.002',
            '4.01.002'
        ),
        (
            'LOAN413',
            '413',
            'QARDH',
            500000::numeric,
            20000000::numeric,
            1,
            12,
            'FLAT',
            0::numeric,
            25000::numeric,
            0::numeric,
            0::numeric,
            FALSE,
            '1.03.003',
            '4.01.001'
        )
) AS x(
    product_code,
    loan_code,
    contract_type,
    minimum_principal,
    maximum_principal,
    minimum_tenor,
    maximum_tenor,
    rate_type,
    rate,
    admin_fee,
    provision_rate,
    penalty_rate,
    require_collateral,
    receivable_code,
    income_code
)

JOIN bmt_db.products p
  ON p.code = x.product_code

JOIN bmt_db.chart_of_accounts receivable
  ON receivable.code = x.receivable_code

JOIN bmt_db.chart_of_accounts margin_income
  ON margin_income.code = x.income_code

JOIN bmt_db.chart_of_accounts admin_income
  ON admin_income.code = '4.02'

JOIN bmt_db.chart_of_accounts penalty_income
  ON penalty_income.code = '4.03'

JOIN bmt_db.chart_of_accounts impairment
  ON impairment.code = '1.04.001'

ON CONFLICT (product_id) DO NOTHING;


-- ============================================================
-- 13. APPROVAL RULES
-- ============================================================
-- Initial business policy only. Thresholds can later be
-- maintained through authorized configuration UI.

INSERT INTO bmt_db.approval_rules (
    transaction_type,
    branch_id,
    minimum_amount,
    maximum_amount,
    required_role,
    approval_level,
    maker_checker_required,
    is_active
)
VALUES

(
    'SAVINGS_WITHDRAWAL',
    NULL,
    10000000,
    NULL,
    'MANAGER',
    1,
    TRUE,
    TRUE
),

(
    'LOAN_DISBURSEMENT',
    NULL,
    1,
    NULL,
    'MANAGER',
    1,
    TRUE,
    TRUE
),

(
    'REVERSAL',
    NULL,
    1,
    NULL,
    'MANAGER',
    1,
    TRUE,
    TRUE
);


COMMIT;
