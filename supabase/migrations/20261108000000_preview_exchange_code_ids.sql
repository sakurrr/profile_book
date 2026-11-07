-- preview_exchange_code の戻り値に、持ち主のIDと申請中の申請のIDを足す。
-- 確認画面から、友だちの帳を開く、申請を取り消す、届いた申請を開くために使う。
-- 戻り値の列を変えるので、create or replace ではなく作り直す。

drop function public.preview_exchange_code(text);

-- トークンから持ち主の表示用情報と、現在の関係を返す。無効なトークンなら0行
create function public.preview_exchange_code(p_token text)
returns table (
  owner_id   uuid,
  public_id  text,
  nickname   text,
  relation   text,
  request_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me        uuid := auth.uid();
  v_owner     uuid;
  v_request   uuid;
  v_requester uuid;
begin
  select c.user_id into v_owner
  from public.exchange_codes c
  where c.token = p_token;

  if v_owner is null then
    return;
  end if;

  -- 同じ2人の間のpendingは、向きに関係なく1件まで
  select r.id, r.requester_id into v_request, v_requester
  from public.exchange_requests r
  where r.status = 'pending'
    and (
      (r.requester_id = v_me and r.addressee_id = v_owner)
      or (r.requester_id = v_owner and r.addressee_id = v_me)
    );

  return query
  select
    p.id,
    p.public_id,
    p.nickname,
    case
      when v_owner = v_me then 'self'
      when exists (
        select 1 from public.friendships f
        where f.owner_id = v_me and f.friend_id = v_owner
      ) then 'friend'
      when v_requester = v_me then 'pending_outgoing'
      when v_requester = v_owner then 'pending_incoming'
      else 'none'
    end,
    v_request
  from public.profiles p
  where p.id = v_owner;
end;
$$;

revoke execute on function public.preview_exchange_code(text) from public, anon;
grant execute on function public.preview_exchange_code(text) to authenticated;
