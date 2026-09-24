import { supabase } from './supabase'

export async function loadOnboardingForm() {
  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) throw new Error('Sesi berakhir. Silakan masuk kembali.')
  const [applications, products] = await Promise.all([
    supabase.from('onboarding_applications').select('*').eq('applicant_user_id', user.id).order('created_at', { ascending: false }).limit(1).maybeSingle(),
    supabase.from('products').select('id,code,name').eq('is_active', true).order('code'),
  ])
  if (applications.error) throw applications.error
  if (products.error) throw products.error
  const application = applications.data
  if (!application) return { application, products: products.data, address: null, employment: null, product: null }
  const [address, employment, product] = await Promise.all([
    supabase.from('onboarding_addresses').select('*').eq('application_id', application.id).eq('address_type', 'ID_CARD').maybeSingle(),
    supabase.from('onboarding_employment').select('employment_type').eq('application_id', application.id).maybeSingle(),
    supabase.from('onboarding_product_requests').select('product_id,purpose').eq('application_id', application.id).order('created_at').limit(1).maybeSingle(),
  ])
  if (address.error || employment.error || product.error) throw address.error || employment.error || product.error
  return { application, products: products.data, address: address.data, employment: employment.data, product: product.data }
}
