-- Waitlist table — run ONCE in the Supabase SQL editor (Dashboard → SQL).
-- Lives in the Supabase project (next to auth), never in the health database.
-- RLS is enabled with NO policies: anon/authenticated clients can't touch it;
-- only the service-role key (held as a Cloudflare Worker secret) can write.
create table if not exists public.waitlist (
  id bigint generated always as identity primary key,
  email text not null unique,
  created_at timestamptz not null default now(),
  source text not null default 'landing'
);

alter table public.waitlist enable row level security;
