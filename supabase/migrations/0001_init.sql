-- Enable extensions used by the schema
create extension if not exists pgcrypto;

-- === Core tables ===
create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  billing_plan text default 'free',
  created_at timestamptz not null default now()
);

create table if not exists public.users (
  id uuid primary key,
  email text not null,
  name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  role text not null check (role in ('owner','admin','coach','assistant','player')),
  created_at timestamptz not null default now(),
  unique(user_id, tenant_id)
);

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  season text,
  level text,
  color text,
  created_at timestamptz not null default now()
);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  name text not null,
  dob date,
  height_cm int,
  weight_kg int,
  number int,
  positions text[] default '{}',
  contact jsonb,
  tags text[] default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.plays (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  title text not null,
  category text check (category in ('ATO','BLOB','SLOB','Halfcourt','Zone O','Defense')),
  diagram_json jsonb not null default '{"frames":[]}',
  video_url text,
  notes text,
  version int not null default 1,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workouts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  title text not null,
  date date,
  duration_min int,
  blocks_json jsonb not null default '[]',
  assigned_to uuid[] default '{}',
  attachments jsonb default '[]',
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  player_id uuid references public.players(id) on delete set null,
  title text not null,
  body text not null,
  labels text[] default '{}',
  pinned boolean default false,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  type text check (type in ('practice','game','meeting')),
  start timestamptz not null,
  "end" timestamptz not null,
  location text,
  agenda_json jsonb default '[]',
  created_at timestamptz not null default now()
);

create table if not exists public.attachments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  owner_table text not null,
  owner_id uuid not null,
  file_url text not null,
  file_type text,
  meta jsonb default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.activity_log (
  id bigint generated always as identity primary key,
  tenant_id uuid not null,
  actor_id uuid,
  action text not null,
  entity text not null,
  entity_id uuid,
  details jsonb default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null,
  payload_json jsonb not null,
  read_at timestamptz
);

-- === Auth linkage ===
create or replace function public.handle_new_user()
returns trigger language plpgsql as $$
begin
  insert into public.users (id, email, name, avatar_url)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;
  return new;
end; $$;

create or replace function public.uid() returns uuid language sql stable as $$
  select auth.uid();
$$;

-- attach trigger if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created'
  ) THEN
    CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
  END IF;
END$$;

-- === RLS enablement ===
alter table public.tenants enable row level security;
alter table public.memberships enable row level security;
alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.plays enable row level security;
alter table public.workouts enable row level security;
alter table public.notes enable row level security;
alter table public.events enable row level security;
alter table public.attachments enable row level security;
alter table public.activity_log enable row level security;

-- helper
create or replace function public.is_tenant_member(tid uuid)
returns boolean language sql stable as $$
  select exists (select 1 from public.memberships m where m.tenant_id = tid and m.user_id = auth.uid());
$$;

create or replace function public.can_write(tid uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.memberships m
    where m.tenant_id = tid and m.user_id = auth.uid() and m.role in ('owner','admin','coach','assistant')
  );
$$;

-- policies (read)
create policy if not exists "tenant members can select" on public.tenants
for select using (exists (
  select 1 from public.memberships m where m.tenant_id = tenants.id and m.user_id = auth.uid()
));

create policy if not exists "self memberships" on public.memberships
for select using (user_id = auth.uid());

create policy if not exists "read team by tenant" on public.teams for select using (public.is_tenant_member(tenant_id));
create policy if not exists "read players by tenant" on public.players for select using (public.is_tenant_member(tenant_id));
create policy if not exists "read plays by tenant" on public.plays for select using (public.is_tenant_member(tenant_id));
create policy if not exists "read workouts by tenant" on public.workouts for select using (public.is_tenant_member(tenant_id));
create policy if not exists "read notes by tenant" on public.notes for select using (public.is_tenant_member(tenant_id));
create policy if not exists "read events by tenant" on public.events for select using (public.is_tenant_member(tenant_id));
create policy if not exists "read attachments by tenant" on public.attachments for select using (public.is_tenant_member(tenant_id));
create policy if not exists "read activity log by tenant" on public.activity_log for select using (public.is_tenant_member(tenant_id));

-- policies (write)
create policy if not exists "write teams" on public.teams for insert with check (public.can_write(tenant_id));
create policy if not exists "update teams" on public.teams for update using (public.can_write(tenant_id));

create policy if not exists "write players" on public.players for insert with check (public.can_write(tenant_id));
create policy if not exists "update players" on public.players for update using (public.can_write(tenant_id));

create policy if not exists "write plays" on public.plays for insert with check (public.can_write(tenant_id));
create policy if not exists "update plays" on public.plays for update using (public.can_write(tenant_id));

create policy if not exists "write workouts" on public.workouts for insert with check (public.can_write(tenant_id));
create policy if not exists "update workouts" on public.workouts for update using (public.can_write(tenant_id));

create policy if not exists "write notes" on public.notes for insert with check (public.can_write(tenant_id));
create policy if not exists "update notes" on public.notes for update using (public.can_write(tenant_id));

create policy if not exists "write events" on public.events for insert with check (public.can_write(tenant_id));
create policy if not exists "update events" on public.events for update using (public.can_write(tenant_id));

create policy if not exists "write attachments" on public.attachments for insert with check (public.can_write(tenant_id));