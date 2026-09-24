import os
import json
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

BASE = os.environ.get('BMT_TEST_URL', 'http://127.0.0.1:4288')
OUT = Path('test-results')
OUT.mkdir(exist_ok=True)

def no_overflow(page):
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), 'Horizontal overflow'

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    for width in [360, 768, 1440]:
        page = browser.new_page(viewport={'width': width, 'height': 900})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(BASE + '/login')
        page.wait_for_load_state('networkidle')
        expect(page.get_by_role('heading', name='Masuk ke BMT NU Bungah')).to_be_visible()
        page.get_by_label('Email', exact=True).fill('invalid@example.test')
        page.get_by_label('Password', exact=True).fill('wrong-password')
        page.get_by_role('button', name='Tampilkan password').click()
        expect(page.get_by_label('Password', exact=True)).to_have_attribute('type', 'text')
        page.get_by_role('button', name='Masuk ke aplikasi').click()
        expect(page.get_by_role('alert')).to_be_visible(timeout=20000)
        no_overflow(page)
        page.screenshot(path=str(OUT / f'login-{width}.png'), full_page=True)
        page.get_by_role('link', name='Daftar sebagai nasabah').click()
        expect(page.get_by_role('heading', name='Mulai menjadi anggota')).to_be_visible()
        no_overflow(page)
        page.screenshot(path=str(OUT / f'register-{width}.png'), full_page=True)
        page.goto(BASE + '/nasabah')
        expect(page).to_have_url(BASE + '/login')
        assert not errors, errors
        print(f'PASS public pages, validation, real auth rejection, protected route, overflow: {width}px')
        page.close()
    browser.close()
