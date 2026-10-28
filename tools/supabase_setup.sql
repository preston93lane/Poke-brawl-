-- Poké Brawl cloud saves. Paste this whole file into Supabase → SQL Editor → Run.
-- One row per account: the game's profile as JSON, plus a dev flag the game
-- can read but never change (only this script / the dashboard can).

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  is_dev boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
drop policy if exists "insert own profile" on public.profiles;
drop policy if exists "update own profile" on public.profiles;
create policy "read own profile" on public.profiles for select to authenticated using (auth.uid() = id);
create policy "insert own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Players may write their own save, but not the dev flag.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant insert (id, data), update (id, data) on public.profiles to authenticated;

-- New rows: the dev account gets is_dev; every save stamps updated_at.
-- (Players can't change is_dev afterwards: they have no permission on that column.)
create or replace function public.profiles_before_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.is_dev := coalesce((select lower(email) from auth.users where id = new.id) = 'preston93lane@gmail.com', false);
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists profiles_before_write on public.profiles;
create trigger profiles_before_write before insert or update on public.profiles
for each row execute function public.profiles_before_write();

-- If the dev account already has a row, make sure it's flagged.
update public.profiles set is_dev = true
where id in (select id from auth.users where lower(email) = 'preston93lane@gmail.com');
