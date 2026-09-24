"""Read-only browser regression for the Agil customer loan form on local Supabase.

Uses a short-lived locally signed test session; never use against production.
"""

import base64
import hashlib
import hmac
import json
import os
import re
import subprocess
import time

from playwright.sync_api import expect, sync_playwright


USER_ID = '28d4b478-18a6-4dd6-929c-e7a7233c5269'
BASE = 'http://127.0.0.1:5173'


def encoded(value):
    return base64.urlsafe_b64encode(json.dumps(value, separators=(',', ':')).encode()).rstrip(b'=').decode()


def local_session():
    result = subprocess.run(['npx.cmd' if os.name == 'nt' else 'npx', 'supabase', 'status', '-o', 'env'],
                            capture_output=True, text=True, check=True)
    match = re.search(r'^JWT_SECRET="?([^"\r\n]+)', result.stdout, re.MULTILINE)
    if not match:
        raise RuntimeError('Local JWT secret unavailable')
    now = int(time.time())
    payload = {'aud': 'authenticated', 'exp': now + 1800, 'iat': now, 'iss': 'supabase',
               'sub': USER_ID, 'email': 'agil@naracode.id', 'role': 'authenticated'}
    signing_input = encoded({'alg': 'HS256', 'typ': 'JWT'}) + '.' + encoded(payload)
    signature = base64.urlsafe_b64encode(hmac.new(match.group(1).encode(), signing_input.encode(), hashlib.sha256).digest()).rstrip(b'=').decode()
    user = {'id': USER_ID, 'aud': 'authenticated', 'role': 'authenticated', 'email': payload['email'],
            'app_metadata': {}, 'user_metadata': {}, 'created_at': '2026-09-24T00:00:00Z'}
    return {'access_token': signing_input + '.' + signature, 'refresh_token': 'local-read-only-test',
            'expires_at': now + 1800, 'expires_in': 1800, 'token_type': 'bearer', 'user': user}


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)
    context = browser.new_context()
    session = local_session()
    context.add_init_script(f'localStorage.setItem("sb-127-auth-token", {json.dumps(json.dumps(session))})')
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto(BASE + '/nasabah?view=portal_get_loan_applications')
    page.wait_for_load_state('networkidle')
    expect(page.get_by_role('heading', name='Selamat datang, Agil Muhammad')).to_be_visible(timeout=15000)
    expect(page.get_by_label('Rekening sumber').locator('option')).to_have_count(2, timeout=15000)
    expect(page.get_by_label('Rekening sumber').locator('option').nth(1)).to_have_text('001.00000013')
    expect(page.get_by_label('Produk pembiayaan').locator('option')).to_have_count(4, timeout=15000)
    expect(page.get_by_label('Produk pembiayaan').locator('option').nth(1)).not_to_have_text('')
    assert not errors, errors
    print('PASS Agil: rekening sumber aktif dan 3 produk pembiayaan tampil; pengajuan tidak dikirim')
    context.close()
    browser.close()
