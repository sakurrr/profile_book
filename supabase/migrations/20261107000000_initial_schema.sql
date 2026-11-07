-- prome 初期スキーマ。設計は doc/db_design/database.md を参照。

-- ============================================================
-- テーブル
-- ============================================================

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  public_id   text not null unique default upper(left(gen_random_uuid()::text, 8)),
  nickname    text not null check (char_length(btrim(nickname)) > 0),
  full_name   text,
  name_romaji text,
  name_kana   text,
  birth_month smallint check (birth_month between 1 and 12),
  birth_day   smallint check (birth_day between 1 and 31),
  likes       text[] check (cardinality(likes) <= 5),
  hobby       text,
  message     text check (char_length(message) <= 100),
  avatar_path text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check ((birth_month is null) = (birth_day is null))
);

create table public.exchange_codes (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  token      text not null unique default gen_random_uuid()::text,
  rotated_at timestamptz not null default now()
);

create type public.exchange_status as enum
  ('pending', 'accepted', 'declined', 'cancelled');

create table public.exchange_requests (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status       public.exchange_status not null default 'pending',
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id)
);

create table public.friendships (
  owner_id        uuid not null references public.profiles (id) on delete cascade,
  friend_id       uuid not null references public.profiles (id) on delete cascade,
  is_favorite     boolean not null default false,
  memo            text,
  exchanged_at    timestamptz not null default now(),
  first_viewed_at timestamptz,
  primary key (owner_id, friend_id),
  check (owner_id <> friend_id)
);

-- ============================================================
-- インデックス
-- ============================================================

-- 自分宛ての申請の取得 + 退会時の削除
create index exchange_requests_addressee
  on public.exchange_requests (addressee_id, created_at desc);

-- 自分が送った申請の取得 + 退会時の削除
create index exchange_requests_requester
  on public.exchange_requests (requester_id, created_at desc);

-- 同じ2人のpendingの重複防止
create unique index exchange_requests_pending_pair
  on public.exchange_requests (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  )
  where status = 'pending';

-- 退会時の削除
create index friendships_friend
  on public.friendships (friend_id);

-- ============================================================
-- トリガー
-- ============================================================

-- 更新日時の自動更新
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- サインアップ時にプロフィールと交換コードを作成
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, nickname)
  values (new.id, new.raw_user_meta_data ->> 'nickname');

  insert into public.exchange_codes (user_id)
  values (new.id);

  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- アクセス制御（RLS）
-- ============================================================

alter table public.profiles          enable row level security;
alter table public.exchange_codes    enable row level security;
alter table public.exchange_requests enable row level security;
alter table public.friendships       enable row level security;

create policy "本人と友だちが読める"
on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or exists (
    select 1 from public.friendships f
    where f.owner_id = (select auth.uid())
      and f.friend_id = profiles.id
  )
);

create policy "本人が更新できる"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy "本人が読める"
on public.exchange_codes for select to authenticated
using (user_id = (select auth.uid()));

create policy "当事者が読める"
on public.exchange_requests for select to authenticated
using (
  requester_id = (select auth.uid())
  or addressee_id = (select auth.uid())
);

create policy "持ち主が読める"
on public.friendships for select to authenticated
using (owner_id = (select auth.uid()));

create policy "持ち主が更新できる"
on public.friendships for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

revoke update on public.profiles from anon, authenticated;
grant update (
  nickname, full_name, name_romaji, name_kana, birth_month, birth_day,
  likes, hobby, message, avatar_path
) on public.profiles to authenticated;

revoke update on public.friendships from anon, authenticated;
grant update (is_favorite, memo, first_viewed_at)
  on public.friendships to authenticated;

-- ============================================================
-- RPC
-- ============================================================

-- トークンから持ち主の表示用情報と、現在の関係を返す。無効なトークンなら0行
create function public.preview_exchange_code(p_token text)
returns table (public_id text, nickname text, relation text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := auth.uid();
  v_owner uuid;
begin
  select c.user_id into v_owner
  from public.exchange_codes c
  where c.token = p_token;

  if v_owner is null then
    return;
  end if;

  return query
  select
    p.public_id,
    p.nickname,
    case
      when v_owner = v_me then 'self'
      when exists (
        select 1 from public.friendships f
        where f.owner_id = v_me and f.friend_id = v_owner
      ) then 'friend'
      when exists (
        select 1 from public.exchange_requests r
        where r.requester_id = v_me and r.addressee_id = v_owner
          and r.status = 'pending'
      ) then 'pending_outgoing'
      when exists (
        select 1 from public.exchange_requests r
        where r.requester_id = v_owner and r.addressee_id = v_me
          and r.status = 'pending'
      ) then 'pending_incoming'
      else 'none'
    end
  from public.profiles p
  where p.id = v_owner;
end;
$$;

-- 交換を申請する。逆向きのpendingがあればその場で成立させる
create function public.request_exchange(p_token text)
returns table (request_id uuid, status public.exchange_status)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := auth.uid();
  v_owner   uuid;
  v_request uuid;
begin
  select c.user_id into v_owner
  from public.exchange_codes c
  where c.token = p_token;

  if v_owner is null then
    raise exception 'invalid_token';
  end if;
  if v_owner = v_me then
    raise exception 'own_code';
  end if;
  if exists (
    select 1 from public.friendships f
    where f.owner_id = v_me and f.friend_id = v_owner
  ) then
    raise exception 'already_friends';
  end if;

  -- 相手からの申請が先にあれば成立
  update public.exchange_requests r
  set status = 'accepted', responded_at = now()
  where r.requester_id = v_owner and r.addressee_id = v_me
    and r.status = 'pending'
  returning r.id into v_request;

  if v_request is not null then
    insert into public.friendships (owner_id, friend_id)
    values (v_me, v_owner), (v_owner, v_me)
    on conflict do nothing;

    return query select v_request, 'accepted'::public.exchange_status;
    return;
  end if;

  -- 同じ向きの申請が既にあればそれを返す
  select r.id into v_request
  from public.exchange_requests r
  where r.requester_id = v_me and r.addressee_id = v_owner
    and r.status = 'pending';

  if v_request is null then
    insert into public.exchange_requests (requester_id, addressee_id)
    values (v_me, v_owner)
    returning id into v_request;
  end if;

  return query select v_request, 'pending'::public.exchange_status;
end;
$$;

-- 自分宛てのpendingを承認または拒否する
create function public.respond_exchange(p_request_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me        uuid := auth.uid();
  v_requester uuid;
begin
  update public.exchange_requests r
  set status = case when p_accept then 'accepted'::public.exchange_status
                    else 'declined'::public.exchange_status end,
      responded_at = now()
  where r.id = p_request_id
    and r.addressee_id = v_me
    and r.status = 'pending'
  returning r.requester_id into v_requester;

  if v_requester is null then
    raise exception 'request_not_found';
  end if;

  if p_accept then
    insert into public.friendships (owner_id, friend_id)
    values (v_me, v_requester), (v_requester, v_me)
    on conflict do nothing;
  end if;
end;
$$;

-- 自分が送ったpendingを取り消す
create function public.cancel_exchange(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.exchange_requests r
  set status = 'cancelled', responded_at = now()
  where r.id = p_request_id
    and r.requester_id = auth.uid()
    and r.status = 'pending';

  if not found then
    raise exception 'request_not_found';
  end if;
end;
$$;

-- 自分宛てのpendingと、申請者の表示用情報を返す
create function public.list_incoming_exchange_requests()
returns table (
  id           uuid,
  requester_id uuid,
  public_id    text,
  nickname     text,
  created_at   timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.requester_id, p.public_id, p.nickname, r.created_at
  from public.exchange_requests r
  join public.profiles p on p.id = r.requester_id
  where r.addressee_id = auth.uid()
    and r.status = 'pending'
  order by r.created_at desc;
$$;

-- 交換コードを作り直し、新しい値を返す
create function public.rotate_exchange_code()
returns text
language sql
security definer
set search_path = ''
as $$
  update public.exchange_codes
  set token = gen_random_uuid()::text, rotated_at = now()
  where user_id = auth.uid()
  returning token;
$$;

-- 自分と相手のfriendshipsを2行とも削除する
create function public.remove_friend(p_friend_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.friendships
  where (owner_id = auth.uid() and friend_id = p_friend_id)
     or (owner_id = p_friend_id and friend_id = auth.uid());
$$;

revoke execute on function
  public.preview_exchange_code(text),
  public.request_exchange(text),
  public.respond_exchange(uuid, boolean),
  public.cancel_exchange(uuid),
  public.list_incoming_exchange_requests(),
  public.rotate_exchange_code(),
  public.remove_friend(uuid)
from public, anon;

grant execute on function
  public.preview_exchange_code(text),
  public.request_exchange(text),
  public.respond_exchange(uuid, boolean),
  public.cancel_exchange(uuid),
  public.list_incoming_exchange_requests(),
  public.rotate_exchange_code(),
  public.remove_friend(uuid)
to authenticated;

-- ============================================================
-- Storage
-- ============================================================

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false);

create policy "アバターを読める"
on storage.objects for select to authenticated
using (
  bucket_id = 'avatars'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists (
      select 1 from public.friendships f
      where f.owner_id = (select auth.uid())
        and f.friend_id::text = (storage.foldername(name))[1]
    )
  )
);

create policy "本人がアップロードできる"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "本人が更新できる"
on storage.objects for update to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "本人が削除できる"
on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- ============================================================
-- Realtime
-- ============================================================

alter publication supabase_realtime add table public.exchange_requests;
