"""Real-browser teller flow against the local Supabase instance.

Creates uniquely named synthetic teller and savings accounts. Posted test records
remain in the local audit trail intentionally; never point this at production.
"""

import json
import os
import re
import secrets
import subprocess
import sys
import time
import unittest
import urllib.request
import uuid

from playwright.sync_api import expect, sync_playwright


BASE = os.environ.get('BMT_TEST_URL', 'http://127.0.0.1:5173')
API = 'http://127.0.0.1:54321'


def local_sql(statement):
    result = subprocess.run(
        ['docker', 'exec', '-i', 'supabase_db_bmt', 'psql', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres', '-At'],
        input=statement, text=True, capture_output=True,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def service_key():
    result = subprocess.run(['npx.cmd' if os.name == 'nt' else 'npx', 'supabase', 'status', '-o', 'env'], text=True, capture_output=True, check=True)
    match = re.search(r'^SERVICE_ROLE_KEY="?([^"\r\n]+)', result.stdout, re.MULTILINE)
    if not match:
        raise RuntimeError('Local Supabase service key unavailable')
    return match.group(1)


def create_fixture():
    stamp = str(int(time.time())) + secrets.token_hex(3)
    email = f'e2e-teller-{stamp}@example.test'
    password = secrets.token_urlsafe(20)
    key = service_key()
    body = json.dumps({'email': email, 'password': password, 'email_confirm': True}).encode()
    request = urllib.request.Request(
        API + '/auth/v1/admin/users', data=body, method='POST',
        headers={'apikey': key, 'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'},
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        user_id = json.load(response)['id']
    customer_id, active_id, pending_id = (str(uuid.uuid4()) for _ in range(3))
    suffix = str(int(time.time()))[-8:] + str(secrets.randbelow(1000)).zfill(3)
    cif = '9' + suffix
    active_no, pending_no = f'8999.{suffix}1', f'8999.{suffix}2'
    seq = int(suffix) * 10
    local_sql(f"""
    BEGIN;
    INSERT INTO bmt_db.user_profiles(id, employee_no, full_name, email, is_active)
      VALUES ('{user_id}', 'E2E-{suffix}', 'Teller E2E', '{email}', TRUE)
      ON CONFLICT (id) DO UPDATE SET employee_no=EXCLUDED.employee_no, full_name=EXCLUDED.full_name, is_active=TRUE;
    INSERT INTO bmt_db.user_branches(user_id, branch_id, is_primary)
      SELECT '{user_id}', id, TRUE FROM bmt_db.branches WHERE code='001';
    INSERT INTO bmt_db.user_roles(user_id, role_id, branch_id, is_active)
      SELECT '{user_id}', r.id, b.id, TRUE FROM bmt_db.roles r CROSS JOIN bmt_db.branches b
      WHERE r.code='TELLER' AND b.code='001';
    INSERT INTO bmt_db.customers(id, cif_number, full_name, branch_id, status)
      SELECT '{customer_id}', '{cif}', 'Nasabah Uji E2E {suffix}', id, 'ACTIVE'
      FROM bmt_db.branches WHERE code='001';
    INSERT INTO bmt_db.financial_accounts(id, account_number, account_type, customer_id, branch_id, product_id, status, opened_at, sequence_no)
      SELECT '{active_id}', '{active_no}', 'SAVINGS', '{customer_id}', fa.branch_id, fa.product_id, 'ACTIVE', now(), {seq + 1}
      FROM bmt_db.financial_accounts fa WHERE fa.account_type='SAVINGS' AND fa.status='ACTIVE' AND fa.branch_id=(SELECT id FROM bmt_db.branches WHERE code='001') LIMIT 1;
    INSERT INTO bmt_db.financial_accounts(id, account_number, account_type, customer_id, branch_id, product_id, status, sequence_no)
      SELECT '{pending_id}', '{pending_no}', 'SAVINGS', '{customer_id}', fa.branch_id, fa.product_id, 'PENDING', {seq + 2}
      FROM bmt_db.financial_accounts fa WHERE fa.account_type='SAVINGS' AND fa.status='ACTIVE' AND fa.branch_id=(SELECT id FROM bmt_db.branches WHERE code='001') LIMIT 1;
    INSERT INTO bmt_db.savings_accounts(financial_account_id) VALUES ('{active_id}'), ('{pending_id}');
    COMMIT;
    """)
    return {'email': email, 'password': password, 'user_id': user_id, 'active_id': active_id,
            'active_no': active_no, 'pending_no': pending_no}


class TellerE2E(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = create_fixture()
        cls.playwright = sync_playwright().start()
        cls.browser = cls.playwright.chromium.launch(headless=True)
        cls.context = cls.browser.new_context(locale='id-ID')
        cls.page = cls.context.new_page()
        cls.errors = []
        cls.page.on('pageerror', lambda error: cls.errors.append(str(error)))
        cls.page.goto(BASE + '/login')
        cls.page.wait_for_load_state('networkidle')

    @classmethod
    def tearDownClass(cls):
        cls.context.close()
        cls.browser.close()
        cls.playwright.stop()

    def test_01_login_closed_session(self):
        self.page.get_by_label('Email', exact=True).fill(self.fixture['email'])
        self.page.get_by_label('Password', exact=True).fill(self.fixture['password'])
        self.page.get_by_role('button', name='Masuk ke aplikasi').click()
        expect(self.page.get_by_role('heading', name='Dashboard Teller')).to_be_visible(timeout=15000)
        self.page.wait_for_load_state('networkidle')
        form = self.page.get_by_role('region', name='Form setoran teller')
        expect(form.get_by_text('Sesi kas belum dibuka', exact=False)).to_be_visible()
        expect(form.get_by_role('button', name='Konfirmasi setoran tunai')).to_be_disabled()
        self.assertFalse(self.errors, self.errors)

    def test_02_open_session(self):
        session = self.page.get_by_role('region', name='Sesi kas teller')
        session.get_by_role('spinbutton').first.fill('500000')
        session.get_by_role('button', name='Buka sesi kas').click()
        expect(session.get_by_text('Sesi kas aktif')).to_be_visible(timeout=15000)
        expect(session.get_by_text('OPEN', exact=True)).to_be_visible()
        expect(session.get_by_text('Saldo awal: Rp 500.000')).to_be_visible()
        self.assertEqual(local_sql(f"SELECT opening_balance::int FROM bmt_db.teller_cash_sessions WHERE teller_user_id='{self.fixture['user_id']}' AND status='OPEN' ORDER BY opened_at DESC LIMIT 1;"), '500000')

    def test_03_cash_deposit_and_receipt(self):
        form = self.page.get_by_role('region', name='Form setoran teller')
        search = form.get_by_label('Cari nama atau nomor rekening')
        search.fill(self.fixture['active_no'])
        expect(form.get_by_role('button', name=re.compile(self.fixture['active_no']))).to_be_visible(timeout=15000)
        form.get_by_role('button', name=re.compile(self.fixture['active_no'])).click()
        expect(form.get_by_text('Status: ACTIVE')).to_be_visible()
        expect(form.get_by_text('Saldo terkini: Rp 0')).to_be_visible()
        form.get_by_label('Nominal').fill('100000')
        button = form.get_by_role('button', name='Konfirmasi setoran tunai')
        button.click()
        expect(form.get_by_role('button', name='Menyimpan…')).to_be_disabled(timeout=5000)
        expect(self.page.get_by_role('heading', name='Setoran berhasil dicatat')).to_be_visible(timeout=20000)
        receipt = self.page.locator('#teller-receipt')
        expect(receipt).to_contain_text('BMT NU MWCNU Bungah')
        expect(receipt).to_contain_text(self.fixture['active_no'])
        expect(receipt).to_contain_text('Rp 100.000')
        transaction_id = re.search(r'No. transaksi: ([0-9a-f-]{36})', receipt.inner_text()).group(1)
        self.fixture['transaction_id'] = transaction_id
        self.assertEqual(local_sql(f"SELECT status::text || '|' || amount::int FROM bmt_db.transactions WHERE id='{transaction_id}';"), 'POSTED|100000')
        self.assertEqual(local_sql(f"SELECT current_balance::int FROM bmt_db.savings_accounts WHERE financial_account_id='{self.fixture['active_id']}';"), '100000')
        self.assertEqual(local_sql(f"SELECT count(*) FROM bmt_db.savings_ledger WHERE transaction_id='{transaction_id}' AND amount=100000;"), '1')
        self.assertEqual(local_sql(f"SELECT count(*) FROM bmt_db.teller_cash_movements WHERE transaction_id='{transaction_id}';"), '1')
        self.assertEqual(local_sql(f"SELECT sum(debit)::int || '|' || sum(credit)::int FROM bmt_db.journal_lines jl JOIN bmt_db.journal_entries je ON je.id=jl.journal_entry_id WHERE je.transaction_id='{transaction_id}';"), '100000|100000')
        self.page.evaluate('window.__printed = false; window.print = () => { window.__printed = true }')
        self.page.get_by_role('button', name='Cetak struk').click()
        self.assertTrue(self.page.evaluate('window.__printed'))
        self.page.emulate_media(media='print')
        self.assertEqual(receipt.evaluate('(node) => getComputedStyle(node).visibility'), 'visible')
        self.page.emulate_media(media='screen')

    def test_04_pending_account_rejected(self):
        self.page.get_by_role('button', name='Setoran baru').click()
        form = self.page.get_by_role('region', name='Form setoran teller')
        form.get_by_label('Cari nama atau nomor rekening').fill(self.fixture['pending_no'])
        expect(form.get_by_role('button', name=re.compile(self.fixture['pending_no']))).to_be_visible(timeout=15000)
        form.get_by_role('button', name=re.compile(self.fixture['pending_no'])).click()
        expect(form.get_by_text('Status: PENDING')).to_be_visible()
        form.get_by_label('Nominal').fill('100000')
        expect(form.get_by_role('button', name='Konfirmasi setoran tunai')).to_be_disabled()
        self.assertEqual(local_sql(f"SELECT current_balance::int FROM bmt_db.savings_accounts sa JOIN bmt_db.financial_accounts fa ON fa.id=sa.financial_account_id WHERE fa.account_number='{self.fixture['pending_no']}';"), '0')

    def test_05_cash_reconciliation(self):
        session = self.page.get_by_role('region', name='Sesi kas teller')
        session.get_by_role('button', name='Perbarui kas').click()
        expect(session.get_by_text('Saldo kas sistem: Rp 600.000')).to_be_visible(timeout=15000)
        self.assertEqual(local_sql(f"SELECT (s.opening_balance+sum(m.amount))::int FROM bmt_db.teller_cash_sessions s JOIN bmt_db.teller_cash_movements m ON m.cash_session_id=s.id WHERE s.teller_user_id='{self.fixture['user_id']}' GROUP BY s.id;"), '600000')
        self.assertFalse(self.errors, self.errors)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TellerE2E)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
