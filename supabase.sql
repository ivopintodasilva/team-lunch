-- Run in Supabase → SQL Editor. Safe to re-run.
-- No login: people identify by typing their work email. Anyone with the page's publishable key
-- can read; writes only need an @algoriddim.com address (not verified).

create table if not exists public.votes (
  email      text not null,
  week       date not null,                       -- the Wednesday this vote is for
  name       text not null check (char_length(name) between 1 and 30),
  picks      text[] not null default '{}' check (cardinality(picks) <= 300),
  updated_at timestamptz not null default now(),
  primary key (email, week)
);

-- One-off migration from the magic-link version (votes keyed by auth user id → keyed by email).
do $$ begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'votes' and column_name = 'user_id') then
    drop policy if exists "team reads votes" on public.votes;
    drop policy if exists "own vote insert" on public.votes;
    drop policy if exists "own vote update" on public.votes;
    drop policy if exists "own vote delete" on public.votes;
    alter table public.votes add column if not exists email text;
    update public.votes v set email = lower(u.email) from auth.users u where u.id = v.user_id;
    delete from public.votes where email is null;
    alter table public.votes drop constraint votes_pkey;
    alter table public.votes drop column user_id;
    alter table public.votes alter column email set not null;
    alter table public.votes add primary key (email, week);
  end if;
end $$;

alter table public.votes drop constraint if exists votes_team_email;
alter table public.votes add constraint votes_team_email check (email = lower(email) and email like '%_@algoriddim.com');

create table if not exists public.favorites (
  restaurant_id text primary key check (char_length(restaurant_id) <= 40),
  from_vote     boolean not null default false,
  created_at    timestamptz not null default now()
);
alter table public.favorites drop column if exists created_by;

create table if not exists public.restaurants (
  id   text primary key,
  data jsonb not null
);

alter table public.votes enable row level security;
alter table public.favorites enable row level security;
alter table public.restaurants enable row level security;

-- Old login-based policies.
drop policy if exists "team reads favorites" on public.favorites;
drop policy if exists "team adds favorites" on public.favorites;
drop policy if exists "team removes favorites" on public.favorites;
drop policy if exists "team reads restaurants" on public.restaurants;
drop policy if exists "team reads restaurant images" on storage.objects;
drop function if exists public.is_team();

-- Open policies (anon = the page's publishable key). Restaurants are read-only; seed.py writes them.
drop policy if exists "read votes" on public.votes;
drop policy if exists "add vote" on public.votes;
drop policy if exists "change vote" on public.votes;
create policy "read votes"  on public.votes for select to anon, authenticated using (true);
create policy "add vote"    on public.votes for insert to anon, authenticated with check (true);
create policy "change vote" on public.votes for update to anon, authenticated using (true) with check (true);

drop policy if exists "read favorites" on public.favorites;
drop policy if exists "add favorites" on public.favorites;
drop policy if exists "remove favorites" on public.favorites;
create policy "read favorites"   on public.favorites for select to anon, authenticated using (true);
create policy "add favorites"    on public.favorites for insert to anon, authenticated with check (true);
create policy "remove favorites" on public.favorites for delete to anon, authenticated using (true);

drop policy if exists "read restaurants" on public.restaurants;
create policy "read restaurants" on public.restaurants for select to anon, authenticated using (true);

-- Photos: public bucket, served by plain URL.
insert into storage.buckets (id, name, public) values ('restaurant-images', 'restaurant-images', true)
on conflict (id) do update set public = true;

-- Live updates in the page.
do $$ begin
  alter publication supabase_realtime add table public.votes, public.favorites;
exception when duplicate_object then null; end $$;
