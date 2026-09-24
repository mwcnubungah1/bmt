import os, time
from playwright.sync_api import sync_playwright, expect

BASE = os.environ.get('BMT_TEST_URL', 'http://127.0.0.1:4288')
uid = '11111111-1111-4111-8111-111111111111'
user = {'id': uid, 'aud': 'authenticated', 'role': 'authenticated', 'email': 'test@example.test', 'app_metadata': {}, 'user_metadata': {}}
session = {'access_token': 'test-token', 'refresh_token': 'test-refresh', 'expires_at': int(time.time())+3600, 'expires_in': 3600, 'token_type': 'bearer', 'user': user}

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    for role in ['TELLER', 'MANAGER', 'MARKETING', 'CUSTOMER']:
        for width in [360, 768, 1440]:
            context = browser.new_context(viewport={'width': width, 'height': 900})
            page = context.new_page()
            errors, mutations = [], []
            page.on('pageerror', lambda e: errors.append(str(e)))
            def api(route):
                path = route.request.url.split('/rest/v1/')[-1].split('?')[0]
                if '/auth/v1/token' in route.request.url: data = session
                elif '/auth/v1/user' in route.request.url: data = user
                elif path == 'user_profiles': data = {'id': uid, 'full_name': 'Penguji BMT', 'email': user['email'], 'is_active': True, 'employee_no': None}
                elif path == 'user_roles': data = [] if role == 'CUSTOMER' else [{'branch_id': None, 'roles': {'code': role, 'name': role}}]
                elif path == 'rpc/workbench_summary': data = {'customers': 50, 'onboarding_pending': 2, 'loans_pending': 1, 'followups_due': 0}
                elif path == 'loan_applications': data = [{'id': uid, 'application_number': 'APP-1', 'requested_amount': 1000000, 'status': 'REVIEW'}]
                elif path == 'rpc/portal_get_onboarding_applications': data = [{'id': uid, 'status': 'COMPLETED'}]
                elif path == 'rpc/portal_get_loan_schedules': data = [{'id': uid, 'installment_no': 1, 'total_due': 100000, 'principal_paid': 0}]
                elif path == 'rpc/customer_request_installment_payment': mutations.append(path); data = uid
                elif path == 'rpc/staff_review_loan_application': mutations.append(route.request.post_data_json); data = uid
                elif path == 'onboarding_applications': data = []
                elif path == 'customers': data = [{'id': uid, 'full_name': 'Nasabah uji', 'status': 'ACTIVE'}]
                else: data = []
                route.fulfill(json=data)
            page.route('**/auth/v1/**', api)
            page.route('**/rest/v1/**', api)
            page.goto(BASE+'/login')
            page.wait_for_load_state('networkidle')
            page.get_by_label('Email', exact=True).fill(user['email'])
            page.get_by_label('Password', exact=True).fill('test-password')
            page.get_by_role('button', name='Masuk ke aplikasi').click()
            expect(page.get_by_role('heading', name='Selamat datang, Penguji BMT')).to_be_visible()
            dashboard_role = {'TELLER': 'Teller', 'MANAGER': 'Manager', 'MARKETING': 'Marketing', 'CUSTOMER': 'Nasabah'}[role]
            expect(page.get_by_role('heading', name=f'Dashboard {dashboard_role}', exact=True)).to_be_visible()
            page.wait_for_load_state('networkidle')
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), (role, width)
            page.screenshot(path=f'test-results/home-{role.lower()}-{width}.png', full_page=True)
            action = {'TELLER': 'Cari nasabah', 'MANAGER': 'Tinjau pembiayaan', 'MARKETING': 'Nasabah dampingan', 'CUSTOMER': 'Lihat mutasi'}[role]
            page.get_by_role('button', name=action, exact=False).click()
            expect(page.get_by_role('heading', name=f'Dashboard {dashboard_role}', exact=True)).to_have_count(0)
            page.get_by_role('button', name='Beranda', exact=True).filter(visible=True).click()
            expect(page.get_by_role('heading', name=f'Dashboard {dashboard_role}', exact=True)).to_be_visible()
            if role in ['TELLER', 'MARKETING']:
                expect(page.get_by_role('button', name='Tambah produk')).to_have_count(0)
            if role == 'MANAGER':
                page.goto(BASE+'/manager?view=loan_applications')
                page.get_by_role('button', name='Lihat detail' if width >= 768 else 'Buka detail', exact=False).first.click()
                page.get_by_role('button', name='Tolak', exact=True).click()
                expect(page.get_by_text('Isi alasan penolakan.', exact=True)).to_be_visible()
                page.get_by_label('Alasan keputusan (wajib untuk penolakan)').fill('Dokumen perlu diperbaiki')
                page.get_by_role('button', name='Tolak', exact=True).click()
                expect(page.get_by_role('dialog')).to_be_visible()
                assert not mutations
                page.get_by_role('button', name='Batal', exact=True).click()
                assert not mutations
            if role == 'CUSTOMER':
                page.goto(BASE+'/nasabah?view=portal_get_loan_schedules')
                page.get_by_role('button', name='Bayar sekarang', exact=False).click()
                expect(page.get_by_role('dialog')).to_be_visible()
                assert not mutations
                page.get_by_role('button', name='Batal', exact=True).click()
                assert not mutations
                page.get_by_role('button', name='Bayar sekarang', exact=False).click()
                page.get_by_role('button', name='Konfirmasi', exact=True).click()
                expect(page.get_by_text('Pembayaran Rp 100.000 berhasil dibukukan.')).to_be_visible()
                assert len(mutations) == 1
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), (role, width)
            assert not errors, errors
            page.screenshot(path=f'test-results/workbench-{role.lower()}-{width}.png', full_page=True)
            print('PASS', role, width)
            context.close()
    browser.close()
