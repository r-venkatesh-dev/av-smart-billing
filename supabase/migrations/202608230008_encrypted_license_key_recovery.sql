alter table public.licenses
  add column if not exists license_key_ciphertext text;

comment on column public.licenses.license_key_ciphertext is
  'AES-256-GCM encrypted full license key for password-gated administrative recovery. Legacy hash-only keys remain null.';
