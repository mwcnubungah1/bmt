import os
import json, time
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
BASE = os.environ.get('BMT_TEST_URL', 'http://127.0.0.1:4288')
uid='11111111-1111-4111-8111-111111111111'
user={'id':uid,'aud':'authenticated','role':'authenticated','email':'test@example.test','app_metadata':{},'user_metadata':{},'created_at':'2026-01-01T00:00:00Z'}
session={'access_token':'test-token','refresh_token':'test-refresh','expires_at':int(time.time())+3600,'expires_in':3600,'token_type':'bearer','user':user}
with sync_playwright() as p:
 browser=p.chromium.launch(headless=True)
 for width in [360,768,1440]:
  page=browser.new_page(viewport={'width':width,'height':900})
  failures=[]
  page.on('pageerror',lambda error:failures.append(str(error)))
  state={'fail':False}
  def api(route):
   path=route.request.url.split('/rest/v1/')[-1].split('?')[0]
   if '/auth/v1/token' in route.request.url: data=session
   elif '/auth/v1/user' in route.request.url: data=user
   elif path=='user_profiles': data={'id':uid,'full_name':'Penguji BMT','email':user['email'],'is_active':True,'employee_no':None}
   elif path=='user_roles': data=[{'branch_id':None,'roles':{'code':'TELLER','name':'Teller'}}]
   elif path=='user_branches': data=[]
   elif path=='customers':
    if state['fail']:
     route.fulfill(status=503,json={'message':'Jaringan pengujian tidak tersedia'});return
    data=[{'id':str(i),'cif_number':str(1000+i),'full_name':f'Nasabah uji {i}','status':'ACTIVE'} for i in range(26)]
   elif path=='onboarding_applications': data=[{'id':uid,'full_name':'Nasabah Uji','status':'TELLER_REVIEW','created_at':'2026-09-22'}]
   else: data=[]
   route.fulfill(json=data)
  page.route('**/auth/v1/**',api)
  page.route('**/rest/v1/**',api)
  page.goto(BASE+'/login');page.wait_for_load_state('networkidle')
  page.get_by_label('Email',exact=True).fill(user['email'])
  page.get_by_label('Password',exact=True).fill('test-password')
  page.get_by_role('button',name='Masuk ke aplikasi').click()
  page.get_by_role('button',name='Nasabah',exact=True).filter(visible=True).click()
  expect(page.get_by_role('heading',name='Nasabah',exact=True)).to_be_visible()
  expect(page.get_by_text('25 data ditampilkan',exact=False)).to_be_visible()
  assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
  page.get_by_role('button',name='Berikutnya').click()
  expect(page.get_by_text('Halaman 2',exact=True)).to_be_visible()
  page.get_by_role('button',name='Pendaftaran',exact=True).filter(visible=True).click()
  page.get_by_role('button',name='Lihat detail' if width>=768 else 'Buka detail',exact=False).first.click()
  page.get_by_label('Saya telah mencocokkan identitas, alamat, pekerjaan, dan dokumen.').check()
  page.get_by_role('button',name='Tanda tangan & teruskan').click()
  expect(page.get_by_text('Unggah tanda tangan Anda sebelum menyetujui.',exact=True).first).to_be_visible()
  if width < 1024: page.get_by_role('button',name='Lainnya',exact=True).click()
  page.get_by_role('button',name='Rekening',exact=True).filter(visible=True).click()
  expect(page.get_by_text('Belum ada informasi di sini')).to_be_visible()
  state['fail']=True
  page.get_by_role('button',name='Nasabah',exact=True).filter(visible=True).click()
  expect(page.get_by_role('button',name='Coba lagi')).to_be_visible(timeout=30000)
  state['fail']=False
  page.get_by_role('button',name='Coba lagi').click()
  expect(page.get_by_text('25 data ditampilkan',exact=False)).to_be_visible()
  page.screenshot(path=f'test-results/dashboard-{width}.png',full_page=True)
  assert not failures,failures
  print(f'PASS mocked API dashboard pagination, empty, error/retry, signature validation: {width}px')
  page.close()
 browser.close()

