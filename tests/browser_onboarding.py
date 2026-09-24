import os
import time
from playwright.sync_api import sync_playwright, expect
BASE = os.environ.get('BMT_TEST_URL', 'http://127.0.0.1:4288')
uid='11111111-1111-4111-8111-111111111111'
user={'id':uid,'aud':'authenticated','role':'authenticated','email':'test@example.test','app_metadata':{},'user_metadata':{},'created_at':'2026-01-01T00:00:00Z'}
session={'access_token':'test-token','refresh_token':'test-refresh','expires_at':int(time.time())+3600,'expires_in':3600,'token_type':'bearer','user':user}
with sync_playwright() as p:
 browser=p.chromium.launch(headless=True)
 for width in [360,768,1440]:
  page=browser.new_page(viewport={'width':width,'height':900})
  def api(route):
   path=route.request.url.split('/rest/v1/')[-1].split('?')[0]
   if '/auth/v1/token' in route.request.url: data=session
   elif '/auth/v1/user' in route.request.url: data=user
   elif path=='user_profiles': data={'id':uid,'full_name':'Penguji BMT','email':user['email'],'is_active':True,'employee_no':None}
   elif path in ['user_roles','user_branches','rpc/portal_get_onboarding_applications']: data=[]
   elif path=='onboarding_applications': data={'id':uid,'status':'RETURNED','full_name':'Nama tersimpan','nik':'1234567890123456','return_reason':'Perbaiki alamat','monthly_income':1500000}
   elif path=='rpc/save_onboarding_draft': data=uid
   elif path=='products': data=[{'id':uid,'code':'TEST','name':'Produk dari database'}]
   elif path=='onboarding_addresses': data={'address':'Alamat tersimpan'}
   elif path=='onboarding_employment': data={'employment_type':'PNS'}
   elif path=='onboarding_product_requests': data={'product_id':uid,'purpose':'Menabung'}
   else: data=[]
   route.fulfill(json=data)
  page.route('**/auth/v1/**',api);page.route('**/rest/v1/**',api)
  page.goto(BASE+'/login');page.wait_for_load_state('networkidle')
  page.get_by_label('Email',exact=True).fill(user['email']);page.get_by_label('Password',exact=True).fill('test-password')
  page.get_by_role('button',name='Masuk ke aplikasi').click()
  expect(page.get_by_role('heading',name='Formulir aplikasi pembukaan rekening')).to_be_visible()
  expect(page.get_by_label('Nama lengkap sesuai identitas',exact=False)).to_have_value('Nama tersimpan')
  expect(page.get_by_label('Alamat lengkap / nama jalan',exact=False)).to_have_value('Alamat tersimpan')
  expect(page.get_by_text('Catatan petugas: Perbaiki alamat')).to_be_visible()
  expect(page.get_by_label('Produk yang dipilih',exact=False)).to_have_value('TEST')
  assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
  page.get_by_role('button',name='Simpan draf').click()
  expect(page.get_by_text('Draf tersimpan di server',exact=False)).to_be_visible()
  page.get_by_role('button',name='4. Dokumen').click()
  page.get_by_role('button',name='Kirim formulir untuk diperiksa').click()
  expect(page.get_by_text('Tahap 1 dari 4')).to_be_visible()
  assert page.locator('input:invalid,select:invalid').count()>0
  page.screenshot(path=f'test-results/onboarding-{width}.png',full_page=True)
  print(f'PASS mocked onboarding saved draft, actual product contract, return reason, required validation, overflow: {width}px')
  page.close()
 browser.close()
