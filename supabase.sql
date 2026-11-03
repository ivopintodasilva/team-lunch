-- Run once in Supabase → SQL Editor. Safe to re-run.

create table if not exists public.votes (
  user_id    uuid not null default auth.uid() references auth.users on delete cascade,
  week       date not null,                       -- the Wednesday this vote is for
  name       text not null check (char_length(name) between 1 and 30),
  picks      text[] not null default '{}' check (cardinality(picks) <= 300),
  updated_at timestamptz not null default now(),
  primary key (user_id, week)
);

create table if not exists public.favorites (
  restaurant_id text primary key check (char_length(restaurant_id) <= 40),
  created_by    uuid default auth.uid(),
  from_vote     boolean not null default false,
  created_at    timestamptz not null default now()
);

-- Only signed-in @algoriddim.com accounts can read or write. Magic-link sign-in proves the address.
create or replace function public.is_team() returns boolean
language sql stable as $$ select coalesce(auth.jwt() ->> 'email', '') ilike '%@algoriddim.com' $$;

alter table public.votes enable row level security;
alter table public.favorites enable row level security;

drop policy if exists "team reads votes" on public.votes;
drop policy if exists "own vote insert" on public.votes;
drop policy if exists "own vote update" on public.votes;
drop policy if exists "own vote delete" on public.votes;
create policy "team reads votes" on public.votes for select to authenticated using (public.is_team());
create policy "own vote insert"  on public.votes for insert to authenticated with check (public.is_team() and user_id = auth.uid());
create policy "own vote update"  on public.votes for update to authenticated using (user_id = auth.uid()) with check (public.is_team() and user_id = auth.uid());
create policy "own vote delete"  on public.votes for delete to authenticated using (user_id = auth.uid());

drop policy if exists "team reads favorites" on public.favorites;
drop policy if exists "team adds favorites" on public.favorites;
drop policy if exists "team removes favorites" on public.favorites;
create policy "team reads favorites"   on public.favorites for select to authenticated using (public.is_team());
create policy "team adds favorites"    on public.favorites for insert to authenticated with check (public.is_team());
create policy "team removes favorites" on public.favorites for delete to authenticated using (public.is_team());

-- Live updates in the page.
do $$ begin
  alter publication supabase_realtime add table public.votes, public.favorites;
exception when duplicate_object then null; end $$;

-- Initial favourites (OpenStreetMap ids).
insert into public.favorites (restaurant_id) values
  ('n10763204005'), -- The Klub Kitchen
  ('n12737395361'), -- Japan Plaza
  ('n12747998498'), -- Dump Ling
  ('n567837367'),   -- Monsieur Vuong
  ('n5140813622'),  -- Banh Mi Stable
  ('n2831137575'),  -- Mädchenitaliener
  ('n6058583255'),  -- Iimori Ramen
  ('n9907785210'),  -- Standard Pizza Mitte (filtered out as closed Wed 13:00)
  ('n13529669101')  -- Taquería El Oso
on conflict do nothing;
