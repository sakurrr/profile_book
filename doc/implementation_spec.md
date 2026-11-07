# prome 実装仕様（現状）

[screens.md](db_design/screens.md) と [database.md](db_design/database.md) に書かれていない、現在のコードの挙動をまとめる。対象はログイン、プロフィール、QR交換。

## 1. 画面

### ルーティング（`lib/app/router.dart`）

| パス | 画面 | タブ |
|---|---|---|
| `/login` | ログイン（初期表示） | なし |
| `/signup` | アカウント作成 | なし |
| `/friends/requests` | 届いた申請の一覧 | ともだち |
| `/friends/requests/:id` | 交換リクエスト | ともだち |
| `/exchange` | プロフィール帳を交換 | 交換する |
| `/exchange/confirm?token=` | プロフィール帳の追加 | 交換する |
| `/exchange/requests/:id` | 交換リクエスト | 交換する |
| `/mypage` | 自分のプロフィール帳 | マイページ |

- 選択中のタブを押すと、そのタブの最初の画面に戻る。
- ログイン状態で振り分ける。未ログインで `/login`、`/signup` 以外を開くと `/login` へ、ログイン済みで `/login`、`/signup` を開くと `/friends` へ移動する。
- 起動時は `/friends` を開く。端末に保存されたセッションがあればそのままホーム、なければ `/login` になる。
- ログイン、ログアウト、セッション切れなどでログイン状態が変わるたびに、振り分けをやり直す。

### ログイン

- `signInWithPassword` に成功すると `/friends` へ遷移する。
- 失敗（`AuthException`）時は「メールアドレスまたはパスワードが間違っています」を表示する。その他のエラーはログ出力のみ。
- 「パスワードを忘れた方」は準備中の表示のみ。

### アカウント作成

- **入力欄:** 姓、名、せい、めい、ニックネーム、メールアドレス、パスワード。すべて必須
- **検証:** 送信時に、空白のみの欄には「必須項目です」を、パスワードが半角英字と数字を含む8文字以上でなければその旨を、欄の下に表示する。
- **送信:** `signUp` の `data` に `family_name`、`given_name`、`family_name_kana`、`given_name_kana`、`nickname` を前後の空白を除いて渡す。成功すると `/login` へ遷移する。メールアドレスの確認が不要な環境では登録と同時にログイン済みになるので、振り分けによって `/friends` へ移動する。
- **失敗時:** ボタンの下に表示する。

| Auth のエラー | 表示 |
|---|---|
| `weak_password` | パスワードは半角英字と数字を含む8文字以上にしてください |
| `user_already_exists`、`email_exists` | このメールアドレスはすでに登録されています |
| `email_address_invalid`、`validation_failed` | メールアドレスの形式が正しくありません |
| `over_request_rate_limit`、`over_email_send_rate_limit` | 時間をおいて、もう一度お試しください |
| その他 | 登録に失敗しました。もう一度お試しください。 |

### ログアウト

- ホーム画面から確認ダイアログを経て `signOut` し、`/login` へ戻る。失敗時はスナックバーを表示する。

### 自分のプロフィール帳

- **編集できる項目:** 姓・名、せい・めい、ローマ字の姓・名、ニックネーム、誕生日、好きなもの、趣味、ひとこと
- **誕生日:** 年・月・日のダイアログで選ぶ。年は「年なし」を選べる（1900年〜今年）。年なしのときは2月29日も選べる。「未設定にする」で3つとも `NULL`。
- **好きなもの:** ダイアログで1件ずつ追加、タグの×で削除。最大5件、重複は追加しない。
- **ひとこと:** 100文字まで、カウンター表示あり。
- **保存:** 姓、名、せい、めい、ニックネームのどれかが空なら「○○を入力してください」を表示して保存しない。空欄は前後の空白を除いて `NULL` にする。結果はスナックバーで表示する。
- **名前の表示:** 名前は「姓 名」、ふりがなは「せい めい」（名前順の並び替えに使う）、ローマ字は「名 姓」の順で空白区切りにする。姓と名がどちらもなければ、名前の代わりにニックネームを表示する。
- **目のアイコン:** 保存前の入力内容で、友だちからの見え方をボトムシートに表示する。
- **アバター:** 写真の変更は準備中。画像がなければ `nickname` の1文字目を表示する。
- 読み込み失敗時は「もう一度読み込む」を表示する。

### プロフィール帳を交換

- 「コードを見せる」「読み取る」をタブで切り替える。
- **コードを見せる:** QRコード（180px角）を表示する。「QRを再発行」は確認ダイアログの後に `rotate_exchange_code` を呼ぶ。
- **申請の自動表示:** コードを見せている間に新しい申請が届くと `/exchange/requests/:id` を開く。画面を開いた時点ですでにある申請は対象外。
- **読み取る:** タブが前面にあるときだけカメラを動かす。読み取り結果が `prome://exchange?token=` 形式でなければ、空のトークンとして確認画面を開く（無効なコードの表示になる）。確認画面を開いている間は次の読み取りを無視する。
- **開発用（デバッグビルドのみ）:** 自分のコードをクリップボードにコピーするボタンと、クリップボードのコードで確認画面を開くボタンを表示する。

### プロフィール帳の追加（確認画面）

`preview_exchange_code` の結果で表示を分ける。

| 結果 | 表示 | 操作 |
|---|---|---|
| 0行 | このコードは使えません | なし |
| `none` | 交換の確認 | 交換を申請する、キャンセル |
| `self` | これはあなたのQRコードです | なし |
| `friend` | ○○さんとは、もう交換しています | プロフィール帳を見る（`/friends/:id`） |
| `pending_outgoing` | ○○さんの承認を待っています | 申請を取り消す（`cancel_exchange`） |
| `pending_incoming` | ○○さんから、交換リクエストが届いています | リクエストを確認する（交換リクエストに置き換え） |

- 申請後は確認画面を閉じて `/friends` へ移動する。その場で成立したら「交換しました」、そうでなければ「申請を送りました」と表示する。
- RPCが失敗したら、エラーの文言を表示してプレビューを取り直す。

### 交換リクエスト・届いた申請の一覧

- 申請は古い順に並べ、届いてからの時間を「たった今」「○分前」「○時間前」「○日前」、7日以上は「○月○日」で表示する。
- 交換リクエストは、手元の申請一覧に該当IDがなければ「このリクエストは、もう届いていません」を表示する。
- 承認・拒否の後は、開いた元の画面に戻る。直接開いた場合は `/exchange` に戻る。

### 交換成立の通知

- 自分が送った申請が `accepted` になると、どの画面にいても「○○さんとプロフィール帳を交換しました」を表示し、ともだちの帳を取り直す。

## 2. API

Flutter から呼ぶ Supabase の処理（`lib/data/`）。

| 用途 | 呼び出し | 備考 |
|---|---|---|
| ログイン | `auth.signInWithPassword` | |
| アカウント作成 | `auth.signUp` | `data`: `family_name`、`given_name`、`family_name_kana`、`given_name_kana`、`nickname` |
| ログアウト | `auth.signOut` | |
| ログイン中のユーザー | `auth.onAuthStateChange` | ユーザーが変わると、自分のデータを取り直す |
| 自分のプロフィール取得 | `profiles` select（`id` = 自分） | |
| 自分のプロフィール保存 | `profiles` update → select | `avatar_path` は送らない |
| 自分の交換コード | `exchange_codes` select `token` | |
| QR再発行 | `rotate_exchange_code()` | 新しいトークンを返す |
| 確認画面 | `preview_exchange_code(p_token)` | |
| 申請 | `request_exchange(p_token)` | 戻り値の `status` が `accepted` ならその場で成立 |
| 取り消し | `cancel_exchange(p_request_id)` | |
| 届いた申請 | `list_incoming_exchange_requests()` | 新しい順で返り、アプリで古い順に並べ直す |
| 承認・拒否 | `respond_exchange(p_request_id, p_accept)` | 失敗時は申請一覧を取り直す |

### QRコードの形式

`prome://exchange?token=<token>`。スキームが `prome`、ホストが `exchange` のときだけ `token` を取り出す。

### RPCのエラー

`raise exception` のメッセージを画面の文言に変換する。

| メッセージ | 発生元 | 画面の文言 |
|---|---|---|
| `invalid_token` | `request_exchange` | このコードは使えません。相手に新しいコードを見せてもらってください。 |
| `own_code` | `request_exchange` | これはあなたのQRコードです。 |
| `already_friends` | `request_exchange` | この相手とは、もう交換しています。 |
| `request_not_found` | `respond_exchange`、`cancel_exchange` | このリクエストは、もう処理されています。 |
| その他 | | 通信に失敗しました。もう一度お試しください。 |

### `request_exchange` の判定順

1. トークンが無効 → `invalid_token`
2. 自分のコード → `own_code`
3. すでに友だち → `already_friends`
4. 相手からの `pending` がある → それを `accepted` にし、`friendships` を2行作って `accepted` を返す
5. 自分からの `pending` がある → その申請を `pending` で返す（新しく作らない）
6. どれでもない → 申請を作り `pending` を返す

### Realtime

| チャンネル | 対象 | 用途 |
|---|---|---|
| `incoming-requests:<自分のID>` | `exchange_requests` の全イベント、`addressee_id` = 自分 | 届いた申請の一覧を取り直す |
| `outgoing-requests:<自分のID>` | `exchange_requests` の UPDATE、`requester_id` = 自分 | `accepted` になったら相手の `nickname` を取得して通知する |

- バックグラウンド中のイベントは受け取れないので、アプリが前面に戻ったときに届いた申請を取り直す。
- 取り直しに失敗しても、表示中の一覧はそのまま残す。

## 3. DB

### マイグレーション

| ファイル | 内容 |
|---|---|
| `20261107000000_initial_schema.sql` | 初期スキーマ（database.md のDDL、RPC、RLS、Storage、Realtime） |
| `20261108000000_preview_exchange_code_ids.sql` | `preview_exchange_code` の戻り値に `owner_id`、`request_id` を追加 |
| `20261108010000_add_birth_year.sql` | `profiles.birth_year` を追加 |
| `20261108020000_split_names.sql` | `full_name`、`name_kana`、`name_romaji` を姓と名の6列に置き換え、`handle_new_user` で姓、名、せい、めいも保存する。既存の値は移さない |

### サインアップ時のデータ

- トリガー `handle_new_user` は `raw_user_meta_data` の `nickname`、`family_name`、`given_name`、`family_name_kana`、`given_name_kana` を `profiles` に入れる。空白のみの値は `NULL` にする。
- 姓、名、せい、めいはアプリで必須だが、DBではNULL可。既存のユーザーと、`nickname` だけで登録する `tool/exchange_partner.py` のため。

### Auth の設定（`supabase/config.toml`、ローカル）

| 項目 | 値 |
|---|---|
| `enable_anonymous_sign_ins` | `false` |
| `minimum_password_length` | `8` |
| `password_requirements` | `letters_digits` |
| `auth.email.enable_confirmations` | `false`（ローカルでは確認メールなしで登録できる） |

`config.toml` はローカル用。本番のプロジェクトは、ダッシュボードの Auth 設定で同じ値にする。

### 開発用ツール

`tool/exchange_partner.py` で、2人目のアカウントとして申請、承認、拒否、取り消し、再発行を行える。接続先はリポジトリ直下の `env.json` から読み、セッションは `tool/.partner_session.json` に保存する。

## 4. ドキュメントとの差異・未実装

| 項目 | ドキュメント | 現状 |
|---|---|---|
| 登録後 | メールアドレスの確認待ち画面 | `/login` に戻る |
| ログアウトの場所 | マイページ | ホーム |
| パスワード再設定、写真の変更 | あり | 準備中の表示のみ |
| アバター | Storage の署名付きURL | DBから表示しない（頭文字を表示） |
| 退会（`delete-account`） | あり | 未実装 |
