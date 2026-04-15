create extension if not exists pgcrypto;

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null check (char_length(display_name) between 1 and 48),
    role_title text not null default 'Online user' check (char_length(role_title) <= 72),
    handle text not null unique check (handle ~ '^[a-z0-9][a-z0-9_-]{2,31}$'),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.conversations (
    id uuid primary key default gen_random_uuid(),
    kind text not null default 'direct' check (kind = 'direct'),
    created_by uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    last_message_preview text not null default ''
);

create table if not exists public.conversation_members (
    conversation_id uuid not null references public.conversations(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    joined_at timestamptz not null default timezone('utc', now()),
    primary key (conversation_id, user_id)
);

create table if not exists public.messages (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid not null references public.conversations(id) on delete cascade,
    sender_id uuid not null references auth.users(id) on delete cascade,
    body text not null check (char_length(body) between 1 and 1200),
    created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_profiles_handle on public.profiles(handle);
create index if not exists idx_conversation_members_user on public.conversation_members(user_id);
create index if not exists idx_messages_conversation_created_at on public.messages(conversation_id, created_at);

create or replace function public.set_row_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_row_updated_at();

drop trigger if exists trg_conversations_updated_at on public.conversations;
create trigger trg_conversations_updated_at
before update on public.conversations
for each row
execute function public.set_row_updated_at();

create or replace function public.bump_conversation_on_message()
returns trigger
language plpgsql
as $$
begin
    update public.conversations
    set
        updated_at = timezone('utc', now()),
        last_message_preview = left(new.body, 140)
    where id = new.conversation_id;
    return new;
end;
$$;

drop trigger if exists trg_messages_bump_conversation on public.messages;
create trigger trg_messages_bump_conversation
after insert on public.messages
for each row
execute function public.bump_conversation_on_message();

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

drop policy if exists "profiles_read_authenticated" on public.profiles;
create policy "profiles_read_authenticated"
on public.profiles
for select
to authenticated
using (true);

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "conversations_select_members" on public.conversations;
create policy "conversations_select_members"
on public.conversations
for select
to authenticated
using (
    exists (
        select 1
        from public.conversation_members cm
        where cm.conversation_id = id
          and cm.user_id = auth.uid()
    )
);

drop policy if exists "conversations_insert_owner" on public.conversations;
create policy "conversations_insert_owner"
on public.conversations
for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists "conversations_update_members" on public.conversations;
create policy "conversations_update_members"
on public.conversations
for update
to authenticated
using (
    exists (
        select 1
        from public.conversation_members cm
        where cm.conversation_id = id
          and cm.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.conversation_members cm
        where cm.conversation_id = id
          and cm.user_id = auth.uid()
    )
);

drop policy if exists "conversation_members_select_related" on public.conversation_members;
create policy "conversation_members_select_related"
on public.conversation_members
for select
to authenticated
using (
    exists (
        select 1
        from public.conversation_members self
        where self.conversation_id = conversation_id
          and self.user_id = auth.uid()
    )
);

drop policy if exists "messages_select_members" on public.messages;
create policy "messages_select_members"
on public.messages
for select
to authenticated
using (
    exists (
        select 1
        from public.conversation_members cm
        where cm.conversation_id = messages.conversation_id
          and cm.user_id = auth.uid()
    )
);

drop policy if exists "messages_insert_sender" on public.messages;
create policy "messages_insert_sender"
on public.messages
for insert
to authenticated
with check (
    sender_id = auth.uid()
    and exists (
        select 1
        from public.conversation_members cm
        where cm.conversation_id = messages.conversation_id
          and cm.user_id = auth.uid()
    )
);

create or replace function public.start_direct_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
    existing_conversation_id uuid;
begin
    if current_user_id is null then
        raise exception 'auth_required';
    end if;

    if target_user_id is null or target_user_id = current_user_id then
        raise exception 'invalid_target';
    end if;

    if not exists (select 1 from public.profiles where id = target_user_id) then
        raise exception 'target_not_found';
    end if;

    select c.id
    into existing_conversation_id
    from public.conversations c
    join public.conversation_members self_member
      on self_member.conversation_id = c.id
     and self_member.user_id = current_user_id
    join public.conversation_members target_member
      on target_member.conversation_id = c.id
     and target_member.user_id = target_user_id
    where c.kind = 'direct'
      and (
          select count(*)
          from public.conversation_members cm
          where cm.conversation_id = c.id
      ) = 2
    limit 1;

    if existing_conversation_id is null then
        insert into public.conversations (kind, created_by)
        values ('direct', current_user_id)
        returning id into existing_conversation_id;

        insert into public.conversation_members (conversation_id, user_id)
        values
            (existing_conversation_id, current_user_id),
            (existing_conversation_id, target_user_id);
    end if;

    return existing_conversation_id;
end;
$$;

grant execute on function public.start_direct_conversation(uuid) to authenticated;

create or replace function public.list_my_direct_conversations()
returns table (
    conversation_id uuid,
    updated_at timestamptz,
    last_message_preview text,
    partner_id uuid,
    partner_display_name text,
    partner_handle text,
    partner_role_title text,
    last_message_at timestamptz
)
language sql
security definer
set search_path = public
as $$
    select
        c.id as conversation_id,
        c.updated_at,
        c.last_message_preview,
        partner.user_id as partner_id,
        p.display_name as partner_display_name,
        p.handle as partner_handle,
        p.role_title as partner_role_title,
        coalesce(max(m.created_at), c.updated_at) as last_message_at
    from public.conversations c
    join public.conversation_members self_member
      on self_member.conversation_id = c.id
     and self_member.user_id = auth.uid()
    join public.conversation_members partner
      on partner.conversation_id = c.id
     and partner.user_id <> auth.uid()
    join public.profiles p
      on p.id = partner.user_id
    left join public.messages m
      on m.conversation_id = c.id
    where c.kind = 'direct'
    group by
        c.id,
        c.updated_at,
        c.last_message_preview,
        partner.user_id,
        p.display_name,
        p.handle,
        p.role_title
    order by coalesce(max(m.created_at), c.updated_at) desc;
$$;

grant execute on function public.list_my_direct_conversations() to authenticated;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    current_user_id uuid := auth.uid();
begin
    if current_user_id is null then
        raise exception 'auth_required';
    end if;

    delete from auth.users
    where id = current_user_id;
end;
$$;

grant execute on function public.delete_my_account() to authenticated;
