-- 名前、ふりがな、ローマ字を姓と名に分ける。既存の値は移さない。
-- 姓、名、せい、めいはアプリで必須にする。既存のユーザーと、nickname だけで
-- 登録する開発用ツールのために、DBではNULL可のままにする。

alter table public.profiles
  drop column full_name,
  drop column name_kana,
  drop column name_romaji,
  add column family_name        text,
  add column given_name         text,
  add column family_name_kana   text,
  add column given_name_kana    text,
  add column family_name_romaji text,
  add column given_name_romaji  text;

grant update (
  family_name, given_name, family_name_kana, given_name_kana,
  family_name_romaji, given_name_romaji
) on public.profiles to authenticated;

-- サインアップ時に、メタデータの姓、名、せい、めいも保存する
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id, nickname, family_name, given_name, family_name_kana, given_name_kana
  )
  values (
    new.id,
    new.raw_user_meta_data ->> 'nickname',
    nullif(btrim(new.raw_user_meta_data ->> 'family_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'given_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'family_name_kana'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'given_name_kana'), '')
  );

  insert into public.exchange_codes (user_id)
  values (new.id);

  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
