# prome DB設計書

Supabase（PostgreSQL、Auth、Storage、Realtime）を使う。画面の仕様は [screens.md](screens.md) を参照。

## 1. 基本方針

- プロフィールは、QRコードの読み取りと承認を経て交換した相手にだけ公開する。例外は交換前の確認に使う項目で、詳しくは「5. 交換の流れ」に示す。
- DBで必須のプロフィール項目は `nickname` のみ。姓、名、せい、めいはアプリで必須にし、DBではNULL可とする。未入力の項目は、空文字や空配列ではなく `NULL` で保存する。
- 相手には常に最新のプロフィールを見せる。交換時点のコピーは持たない。
- 星座とお気に入り件数は保存せず、誕生日や一覧から算出する。
- 退会時はデータを物理削除する。

## 2. テーブル構成

```text
auth.users ─1:1─ profiles ─1:1─ exchange_codes
                    │
                    ├─ exchange_requests（申請者・相手）
                    └─ friendships（持ち主・友だち）
```

`auth.users` はSupabase Authが管理する。ユーザーIDとメールアドレスはここで管理し、Flutterからは `supabase.auth.currentUser?.id` でIDを取得する。

| テーブル | 目的 | 1レコードが指すもの |
|---|---|---|
| `profiles` | プロフィール帳の内容を保存する | ユーザー1人分のプロフィール帳 |
| `exchange_codes` | QRコードのトークンを保存する | ユーザー1人が現在使っている交換コード |
| `exchange_requests` | 交換の申請と結果を保存する | 「誰が誰に申請したか」という1回の申請 |
| `friendships` | ともだちの帳と、相手に対する自分だけの情報を保存する | 「ある人の帳に、ある友だちが1人載っている」という関係。交換成立で1組につき2行 |

## 3. テーブル定義

### `profiles`

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| `id` | uuid | 不可 | 主キー。`auth.users.id` と同じ値 |
| `public_id` | text | 不可 | 画面に表示するID。本人の確認と同名の区別に使う。自動発行、ユニーク、変更不可 |
| `nickname` | text | 不可 | 呼んでほしい名前。空白のみは不可 |
| `family_name` | text | 可 | 姓。アプリで必須 |
| `given_name` | text | 可 | 名。アプリで必須 |
| `family_name_kana` | text | 可 | 姓のふりがな。アプリで必須。ともだち一覧の名前順に使う |
| `given_name_kana` | text | 可 | 名のふりがな。アプリで必須 |
| `family_name_romaji` | text | 可 | 姓のローマ字表記 |
| `given_name_romaji` | text | 可 | 名のローマ字表記 |
| `birth_year` | smallint | 可 | 誕生年。任意。入力するときは月日も必要 |
| `birth_month` | smallint | 可 | 誕生月。誕生日は月と日の両方を入力するか、両方を未入力にする |
| `birth_day` | smallint | 可 | 誕生日の日 |
| `likes` | text[] | 可 | 好きなもの。最大5件。自由入力 |
| `hobby` | text | 可 | 趣味 |
| `message` | text | 可 | ひとこと。最大100文字 |
| `avatar_path` | text | 可 | Storage上のパス |
| `created_at` | timestamptz | 不可 | 作成日時 |
| `updated_at` | timestamptz | 不可 | 更新日時。トリガーで更新 |

IDは次の3種類を使い分ける。

| 種類 | 用途 | 画面表示 | 変更 |
|---|---|---|---|
| `profiles.id` | FK、RLS | しない | 不可 |
| `profiles.public_id` | 本人の確認、同名の区別 | `#7F3A92C1` の形式で表示 | 不可 |
| `exchange_codes.token` | QRコード | しない | 再発行で変わる |

`public_id` では検索も交換もできない。交換にはQRコードのトークンが必要である。登録時にまれに重複した場合はUNIQUE制約でサインアップが失敗し、再度登録すれば別の値になる。

### `exchange_codes`

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| `user_id` | uuid | 不可 | 主キー。`profiles.id` を参照 |
| `token` | text | 不可 | 推測できないランダム値。ユニーク |
| `rotated_at` | timestamptz | 不可 | 最後に発行した日時 |

有効期限は設けない。画面の写真などでコードが漏れた場合は、再発行で古いコードを無効にする。

### `exchange_requests`

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| `id` | uuid | 不可 | 主キー |
| `requester_id` | uuid | 不可 | コードを読み取り、申請した人 |
| `addressee_id` | uuid | 不可 | コードの持ち主で、申請を受けた人 |
| `status` | enum | 不可 | `pending` / `accepted` / `declined` / `cancelled` |
| `created_at` | timestamptz | 不可 | 申請日時 |
| `responded_at` | timestamptz | 可 | 承認、拒否、取り消しの日時 |

辞退後の再申請は別の行として記録する。同じ2人の間の `pending` は、向きに関係なく1件までとする。

### `friendships`

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| `owner_id` | uuid | 不可 | 帳の持ち主。複合主キー |
| `friend_id` | uuid | 不可 | 帳に載っている友だち。複合主キー |
| `is_favorite` | boolean | 不可 | お気に入り |
| `memo` | text | 可 | 自分だけのメモ。相手には見えない |
| `exchanged_at` | timestamptz | 不可 | 交換日。一覧の並び順にも使う |
| `first_viewed_at` | timestamptz | 可 | 初めて詳細を開いた日時。`NULL` なら「new!」を表示 |

### DDL

```sql
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  public_id   text not null unique default upper(left(gen_random_uuid()::text, 8)),
  nickname    text not null check (char_length(btrim(nickname)) > 0),
  family_name        text,
  given_name         text,
  family_name_kana   text,
  given_name_kana    text,
  family_name_romaji text,
  given_name_romaji  text,
  birth_year  smallint check (birth_year between 1900 and 2100),
  birth_month smallint check (birth_month between 1 and 12),
  birth_day   smallint check (birth_day between 1 and 31),
  likes       text[] check (cardinality(likes) <= 5),
  hobby       text,
  message     text check (char_length(message) <= 100),
  avatar_path text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check ((birth_month is null) = (birth_day is null)),
  check (birth_year is null or birth_month is not null)
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
```

## 4. インデックス

主キーとUNIQUE制約のインデックスは自動で作られる。追加するのは次の4つだけ。

```sql
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
```

次のインデックスは、書き込みの負担を増やさないために作らない。

| 対象 | 作らない理由 |
|---|---|
| `friendships.exchanged_at` | 主キーで自分の行に絞れる。1人の友だちは多くても数百人程度で、並び替えの負担が小さい |
| `friendships.is_favorite` | 取得済みの一覧をFlutter側で絞り込む |
| `profiles` の名前、`likes` | 検索対象は自分の友だちのみ。取得済みの一覧をFlutter側で絞り込む |

## 5. 交換の流れ

はなさんが、みおさんのQRコードを読み取る場合。

| 順番 | 出来事 | 処理 | データの変化 |
|---|---|---|---|
| 1 | はなさんがコードを読み取る | `preview_exchange_code` | なし。確認画面にみおさんの呼び名と表示用IDを表示 |
| 2 | はなさんが「交換を申請する」を押す | `request_exchange` | `exchange_requests` に `pending` の行を追加 |
| 3 | みおさんに通知が届く | Realtime | なし |
| 4 | みおさんが承認する | `respond_exchange` | 申請を `accepted` にし、`friendships` を2行追加 |
| 5 | お互いのプロフィールを見る | `profiles` の読み取り | なし |

- みおさんが拒否した場合は `declined` にし、`friendships` は作らない。
- 2人が同時に相手のコードを読み取り、逆向きの `pending` がある場合は、自動で成立させる。
- 確認画面でキャンセルした場合、DBには何も記録しない。
- 友だち解除では2行とも削除する。再交換すると新しい友だちとして扱い、メモは残らない。

### 交換前に公開される項目

有効なコードを読み取ったログイン済みユーザーは、確認画面で持ち主の次の項目だけを見られる。申請を受けた人も、承認前に申請者の同じ項目だけを見られる。

`public_id`、`nickname`

アバターを含むそれ以外の項目は、交換が成立するまで公開しない。共有リンクと画像の保存は作らないので、コードは対面で見せたときにだけ伝わる。画面の写真などでコードが第三者に渡ると、ログイン済みの誰でも確認画面を開けるので、この場合はコードの再発行で止める。

## 6. RPCとEdge Function

テーブルへの直接の書き込みでは実現できない処理は、次の入口に限定する。RPCは `SECURITY DEFINER` と `set search_path = ''` で作成し、`anon` から実行権限を外して `authenticated` にのみ許可する。

| 名前 | 種類 | 処理 |
|---|---|---|
| `preview_exchange_code(p_token text)` | RPC | トークンから、持ち主の `owner_id`、`public_id`、`nickname`、現在の関係（`none` / `self` / `friend` / `pending_outgoing` / `pending_incoming`）、申請中なら `request_id` を返す。無効なトークンなら0行を返す。`owner_id` と `request_id` は画面に表示せず、友だちの帳を開く、申請を取り消す、届いた申請を開くために使う |
| `request_exchange(p_token text)` | RPC | 自分のコード、既存の友だち、重複申請を確認して申請を作る。逆向きの `pending` があれば成立させる |
| `respond_exchange(p_request_id uuid, p_accept boolean)` | RPC | 相手本人の `pending` のみ処理する。承認時は同じトランザクションで `friendships` を2行作る |
| `cancel_exchange(p_request_id uuid)` | RPC | 申請者本人の `pending` を `cancelled` にする |
| `list_incoming_exchange_requests()` | RPC | 自分宛ての `pending` と、申請者の `public_id`、`nickname` を返す |
| `rotate_exchange_code()` | RPC | トークンを作り直し、新しい値を返す |
| `remove_friend(p_friend_id uuid)` | RPC | 自分と相手の `friendships` を2行とも削除する |
| `delete-account` | Edge Function | 本人のアバターと `auth.users` の行を削除する |

交換前はアバターを見せないので、確認画面は署名付きURLを発行するEdge Functionを使わず、RPCで作る。

## 7. トリガー

```sql
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

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

サインアップ時は、メタデータに `nickname` と姓、名、せい、めいを渡す。`nickname` がない場合はサインアップ自体が失敗する。

```dart
await supabase.auth.signUp(
  email: email,
  password: password,
  data: {
    'family_name': familyName,
    'given_name': givenName,
    'family_name_kana': familyNameKana,
    'given_name_kana': givenNameKana,
    'nickname': nickname,
  },
);
```

アプリから `signUp` の後に `profiles` を更新しないのは、メールアドレスの確認が終わるまでセッションがなく、RLSで更新できないためである。

**匿名ログインは使わない。** `nickname` なしで `auth.users` に行が作られると、このトリガーで失敗する。現在の `lib/main.dart` の `signInAnonymously()` は、DB適用前に取り除き、Supabaseの匿名サインインも無効にする。

## 8. アクセス制御（RLS）

全テーブルでRLSを有効にする。

| 対象 | 読み取り | 書き込み |
|---|---|---|
| `profiles` | 本人と友だち | 本人のみ更新可。作成はトリガー、削除は連鎖 |
| `exchange_codes` | 本人のみ | RPC経由のみ |
| `exchange_requests` | 当事者のみ | RPC経由のみ |
| `friendships` | `owner_id` が本人の行 | `is_favorite`、`memo`、`first_viewed_at` のみ本人が更新可 |

RLSは列を制限できないので、更新できる列は `GRANT` で限定する。

```sql
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
  nickname, family_name, given_name, family_name_kana, given_name_kana,
  family_name_romaji, given_name_romaji, birth_year, birth_month, birth_day,
  likes, hobby, message, avatar_path
) on public.profiles to authenticated;

revoke update on public.friendships from anon, authenticated;
grant update (is_favorite, memo, first_viewed_at)
  on public.friendships to authenticated;
```

## 9. Storage

アバターは非公開バケット `avatars` に `{ユーザーID}/avatar.jpg` として保存し、署名付きURLで配信する。署名付きURLの有効期限は1時間程度とする。

閲覧できるのは、本人と友だちである。交換前の相手には見せない。

```sql
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
```

## 10. Realtime

申請の通知と、承認結果の反映に使う。RLSが適用されるので、当事者にだけ届く。

```sql
alter publication supabase_realtime add table public.exchange_requests;
```

## 11. 退会

`delete-account` で次の順に処理する。アバターを先に消すので、途中で失敗してもユーザーが残り、やり直せる。

1. JWTを検証し、削除対象を本人に限定する。
2. Storageのアバターを削除する。Storageのファイルは連鎖削除されない。
3. `auth.admin.deleteUser()` でユーザーを削除する。
4. アプリ側でサインアウトし、ログイン画面に戻す。

`auth.users` を消すと、`profiles`、`exchange_codes`、`exchange_requests`、`friendships` の関連行が連鎖して削除される。

- 相手の帳からも通知なしで消え、相手が書いたメモも消える。
- 取り消しはできず、猶予期間も設けない。
- 同じメールアドレスで再登録すると新しいIDになり、以前の友だち関係は戻らない。
- 発行済みの署名付きURLは期限まで有効で、Supabaseのバックアップにも保持期間内は残る。公開するなら、プライバシーポリシーに記載する。

## 12. Flutterからの取得例

`friendships` から `profiles` への外部キーが2本あるので、使う方を指定する。

```dart
final rows = await supabase
    .from('friendships')
    .select('*, friend:profiles!friendships_friend_id_fkey(*)')
    .order('exchanged_at', ascending: false);
```

## 13. カラムの追加

NULL可のカラムを足すだけなら、既存の行に影響しない。`profiles` は更新できる列を `GRANT` で限定しているので、更新対象のカラムを増やすときは `GRANT` も追加する。

```sql
alter table public.profiles add column instagram_id text;
grant update (instagram_id) on public.profiles to authenticated;
```
