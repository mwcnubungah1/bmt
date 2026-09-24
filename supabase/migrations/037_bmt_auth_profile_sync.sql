BEGIN;

CREATE OR REPLACE FUNCTION bmt_db.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO bmt_db.user_profiles (id, full_name, phone, email)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(btrim(NEW.raw_user_meta_data->>'full_name'), ''), split_part(COALESCE(NEW.email, 'Nasabah'), '@', 1)),
    NULLIF(NEW.raw_user_meta_data->>'phone', ''),
    NEW.email
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone = COALESCE(EXCLUDED.phone, bmt_db.user_profiles.phone),
    full_name = CASE
      WHEN bmt_db.user_profiles.full_name = '' THEN EXCLUDED.full_name
      ELSE bmt_db.user_profiles.full_name
    END,
    updated_at = now();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION bmt_db.handle_new_auth_user() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created_bmt_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_bmt_profile
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION bmt_db.handle_new_auth_user();

INSERT INTO bmt_db.user_profiles (id, full_name, phone, email)
SELECT u.id,
       COALESCE(NULLIF(btrim(u.raw_user_meta_data->>'full_name'), ''), split_part(COALESCE(u.email, 'Nasabah'), '@', 1)),
       NULLIF(u.raw_user_meta_data->>'phone', ''),
       u.email
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM bmt_db.user_profiles p WHERE p.id = u.id);

COMMENT ON FUNCTION bmt_db.handle_new_auth_user() IS
'Creates the BMT profile row required by onboarding for every new Supabase Auth user.';

COMMIT;
