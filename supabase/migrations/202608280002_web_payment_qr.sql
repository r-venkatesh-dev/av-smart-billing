alter table public.billing_businesses
  add column if not exists payment_qr_path text not null default '';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'billing-payment-qrs',
  'billing-payment-qrs',
  true,
  1048576,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "billing payment qr public read"
on storage.objects for select
to public
using (bucket_id = 'billing-payment-qrs');

create policy "billing payment qr owner insert"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'billing-payment-qrs'
  and exists (
    select 1 from public.billing_businesses business
    where business.id::text = (storage.foldername(name))[1]
      and business.created_by = auth.uid()
  )
);

create policy "billing payment qr owner update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'billing-payment-qrs'
  and exists (
    select 1 from public.billing_businesses business
    where business.id::text = (storage.foldername(name))[1]
      and business.created_by = auth.uid()
  )
)
with check (
  bucket_id = 'billing-payment-qrs'
  and exists (
    select 1 from public.billing_businesses business
    where business.id::text = (storage.foldername(name))[1]
      and business.created_by = auth.uid()
  )
);

create policy "billing payment qr owner delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'billing-payment-qrs'
  and exists (
    select 1 from public.billing_businesses business
    where business.id::text = (storage.foldername(name))[1]
      and business.created_by = auth.uid()
  )
);
