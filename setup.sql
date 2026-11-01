-- ============================================================
-- Sociocracy: database setup for Supabase
-- ============================================================
-- What this does:
--   * creates the tables Sociocracy needs
--   * turns on rules so only invited people can see anything
--   * makes you the first admin
--
-- BEFORE YOU CLICK RUN:
--   Scroll to the very bottom and replace you@example.org
--   with the email address you will sign in with.
--
-- It is safe to run this file again later.
-- ============================================================

-- People who may sign in, and what they may do
create table if not exists public.members (
  email       text primary key check (email = lower(email)),
  role        text not null check (role in ('admin', 'member', 'viewer')),
  person_name text,
  created_at  timestamptz not null default now()
);

-- Everything the app stores (circles, meetings, wiki pages, ...)
create table if not exists public.docs (
  col        text not null,
  id         text not null,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by text default lower(auth.jwt() ->> 'email'),
  primary key (col, id)
);

-- Workspace settings (who can see it: private or public)
create table if not exists public.settings (
  key   text primary key,
  value text not null
);
insert into public.settings (key, value) values ('visibility', 'private')
on conflict (key) do nothing;

create or replace function public.is_public() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select value = 'public' from public.settings where key = 'visibility'), false)
$$;

-- The role of whoever is signed in (null when not invited)
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.members
  where email = lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

-- Who may change a given kind of record
create or replace function public.can_edit(target_col text) returns boolean
language sql stable security definer set search_path = public as $$
  select case public.my_role()
    when 'admin'  then true
    when 'member' then target_col <> 'org'
    else false
  end
$$;

-- The email of whoever is signed in
create or replace function public.my_email() returns text
language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

-- The name an admin gave this account in People (when invited)
create or replace function public.my_person_name() returns text
language sql stable security definer set search_path = public as $$
  select lower(trim(coalesce(person_name, ''))) from public.members
  where email = public.my_email()
$$;

-- Is this People profile linked to an account? Is it mine?
create or replace function public.person_owner(pid text) returns text
language sql stable security definer set search_path = public as $$
  select lower(coalesce(data ->> 'ownerEmail', '')) from public.docs
  where col = 'people' and id = pid
$$;

create or replace function public.owns_person(pid text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.my_email() <> '' and coalesce(public.person_owner(pid), '') = public.my_email()
$$;

-- Who may add or change a record.
--   Admins: everything.  Members: everything except settings (org)
--   and other people's linked profiles.  Everyone invited: their own
--   profile and their own contact details.
create or replace function public.can_write(target_col text, target_id text, target_data jsonb) returns boolean
language sql stable security definer set search_path = public as $$
  select case
    when public.my_role() = 'admin' then true
    when public.my_role() is null then false
    when target_col = 'org' then false
    when target_col = 'people' then
      lower(coalesce(target_data ->> 'ownerEmail', '')) = public.my_email()
      or (public.my_role() = 'member' and coalesce(target_data ->> 'ownerEmail', '') = '')
      or (coalesce(target_data ->> 'ownerEmail', '') = ''
          and lower(trim(coalesce(target_data ->> 'name', ''))) = public.my_person_name()
          and public.my_person_name() <> '')
    when target_col = 'contacts' then
      public.owns_person(target_id)
      or (public.my_role() = 'member' and coalesce(public.person_owner(target_id), '') = '')
    else public.my_role() = 'member'
  end
$$;

-- Who may delete a record. Linked profiles: admins only.
create or replace function public.can_delete(target_col text, target_id text, target_data jsonb) returns boolean
language sql stable security definer set search_path = public as $$
  select case
    when public.my_role() = 'admin' then true
    when public.my_role() <> 'member' or public.my_role() is null then false
    when target_col = 'org' then false
    when target_col = 'people' then coalesce(target_data ->> 'ownerEmail', '') = ''
    when target_col = 'contacts' then coalesce(public.person_owner(target_id), '') = ''
    else true
  end
$$;

alter table public.members enable row level security;
alter table public.docs    enable row level security;
alter table public.settings enable row level security;

drop policy if exists "Invited people can see the member list" on public.members;
create policy "Invited people can see the member list" on public.members
  for select to authenticated using (public.my_role() is not null);

drop policy if exists "Admins manage members" on public.members;
create policy "Admins manage members" on public.members
  for all to authenticated
  using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

drop policy if exists "Invited people read data" on public.docs;
create policy "Invited people read data" on public.docs
  for select to authenticated
  using (public.my_role() in ('admin', 'member')
         or (public.my_role() = 'viewer' and (col <> 'contacts' or public.owns_person(id))));

drop policy if exists "Anyone reads data when the workspace is public" on public.docs;
create policy "Anyone reads data when the workspace is public" on public.docs
  for select to anon, authenticated
  using (public.is_public() and col <> 'contacts');

drop policy if exists "Anyone can read the settings" on public.settings;
create policy "Anyone can read the settings" on public.settings
  for select to anon, authenticated using (true);

drop policy if exists "Admins change the settings" on public.settings;
create policy "Admins change the settings" on public.settings
  for all to authenticated
  using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

drop policy if exists "Editors add data" on public.docs;
create policy "Editors add data" on public.docs
  for insert to authenticated with check (public.can_write(col, id, data));

drop policy if exists "Editors change data" on public.docs;
create policy "Editors change data" on public.docs
  for update to authenticated
  using (public.can_write(col, id, data)) with check (public.can_write(col, id, data));

drop policy if exists "Editors delete data" on public.docs;
create policy "Editors delete data" on public.docs
  for delete to authenticated using (public.can_delete(col, id, data));

-- A workspace always keeps at least one admin
create or replace function public.keep_an_admin() returns trigger
language plpgsql as $$
begin
  if not exists (select 1 from public.members where role = 'admin') then
    raise exception 'A workspace needs at least one admin.';
  end if;
  return null;
end $$;
drop trigger if exists keep_an_admin on public.members;
create trigger keep_an_admin after update or delete on public.members
  for each statement execute function public.keep_an_admin();

-- Only admins link a profile to an account. Anyone may claim the one
-- unlinked profile whose name an admin gave them when inviting them.
create or replace function public.guard_people() returns trigger
language plpgsql set search_path = public as $$
declare
  old_owner text := '';
  new_owner text := lower(coalesce(new.data ->> 'ownerEmail', ''));
begin
  if new.col <> 'people' or current_user not in ('authenticated', 'anon')
     or public.my_role() = 'admin' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    -- An upsert of an existing row is checked again as an update
    if exists (select 1 from public.docs where col = new.col and id = new.id) then
      return new;
    end if;
  else
    old_owner := lower(coalesce(old.data ->> 'ownerEmail', ''));
  end if;
  if new_owner = old_owner then
    return new;
  end if;
  if old_owner = '' and new_owner = public.my_email()
     and (tg_op = 'INSERT' or lower(trim(coalesce(old.data ->> 'name', ''))) = public.my_person_name())
     and not exists (select 1 from public.docs
                     where col = 'people' and id <> new.id
                       and lower(coalesce(data ->> 'ownerEmail', '')) = new_owner) then
    return new;
  end if;
  raise exception 'Only an admin can link a profile to an account.' using errcode = '42501';
end $$;
drop trigger if exists guard_people on public.docs;
create trigger guard_people before insert or update on public.docs
  for each row execute function public.guard_people();

-- Record when and by whom a record last changed
create or replace function public.touch_doc() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := lower(auth.jwt() ->> 'email');
  return new;
end $$;
drop trigger if exists touch_doc on public.docs;
create trigger touch_doc before update on public.docs
  for each row execute function public.touch_doc();

-- Signed-out visitors can only read, and only when the workspace is public
revoke all on public.docs     from anon;
revoke all on public.members  from anon;
revoke all on public.settings from anon;
grant select on public.docs     to anon;
grant select on public.settings to anon;
grant select, insert, update, delete on public.docs     to authenticated;
grant select, insert, update, delete on public.members  to authenticated;
grant select, insert, update, delete on public.settings to authenticated;
grant execute on function public.is_public() to anon, authenticated;

-- Live updates: changes appear for everyone without refreshing
do $$
begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null;
end $$;

-- ============================================================
-- YOUR EMAIL: replace you@example.org below, then click Run.
-- ============================================================
insert into public.members (email, role)
values (lower('you@example.org'), 'admin')
on conflict (email) do update set role = 'admin';
