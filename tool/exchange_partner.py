"""交換の相手役を、2人目のアカウントで演じるスクリプト。

使い方（リポジトリのルートで実行し、env.json から接続先を読む）:
  ※ 開発用。ログイン情報は tool/.partner_session.json に保存する（git には入らない）
  python3 tool/exchange_partner.py signup <email> <password> <nickname>  アカウントを作る（確認メールが届く）
  python3 tool/exchange_partner.py login <email> <password>              ログインして、セッションを保存する
  python3 tool/exchange_partner.py code                                   相手役のQRの中身を表示する
  python3 tool/exchange_partner.py request <prome://... またはトークン>     相手役から申請する
  python3 tool/exchange_partner.py incoming                               相手役に届いた申請を表示する
  python3 tool/exchange_partner.py accept | decline                       相手役に届いた最も古い申請に答える
  python3 tool/exchange_partner.py cancel                                 相手役が送った申請を取り消す
  python3 tool/exchange_partner.py rotate                                 相手役のQRを再発行する
  python3 tool/exchange_partner.py friends                                相手役の友だちを表示する
"""

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ENV = json.loads(Path('env.json').read_text())
URL = ENV['SUPABASE_URL'].rstrip('/')
KEY = ENV['SUPABASE_PUBLISHABLE_KEY']
SESSION = Path(__file__).with_name('.partner_session.json')


def call(method, path, body=None, token=None):
    headers = {'apikey': KEY, 'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(URL + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            text = response.read().decode()
            return json.loads(text) if text else None
    except urllib.error.HTTPError as error:
        sys.exit(f'エラー {error.code}: {error.read().decode()}')


def session():
    if not SESSION.exists():
        sys.exit('先に login してください')
    return json.loads(SESSION.read_text())


def rpc(name, params=None):
    return call('POST', f'/rest/v1/rpc/{name}', params or {}, session()['access_token'])


def select(path):
    return call('GET', f'/rest/v1/{path}', token=session()['access_token'])


def first_incoming():
    requests = rpc('list_incoming_exchange_requests')
    if not requests:
        sys.exit('相手役に届いている申請はありません')
    return requests[-1]  # RPCは新しい順に返す


def main(command, *args):
    if command == 'signup':
        email, password, nickname = args
        call('POST', '/auth/v1/signup', {'email': email, 'password': password, 'data': {'nickname': nickname}})
        print('アカウントを作りました。確認メールのリンクを開いてから login してください')
    elif command == 'login':
        email, password = args
        result = call('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password})
        SESSION.write_text(json.dumps({'access_token': result['access_token'], 'user_id': result['user']['id']}))
        profile = select(f"profiles?id=eq.{result['user']['id']}&select=nickname,public_id")[0]
        print(f"{profile['nickname']}（#{profile['public_id']}）としてログインしました")
    elif command == 'code':
        token = select(f"exchange_codes?user_id=eq.{session()['user_id']}&select=token")[0]['token']
        print(f'prome://exchange?token={token}')
    elif command == 'request':
        raw = args[0]
        token = urllib.parse.parse_qs(urllib.parse.urlparse(raw).query).get('token', [raw])[0]
        result = rpc('request_exchange', {'p_token': token})[0]
        print('その場で交換が成立しました' if result['status'] == 'accepted' else '申請しました（承認待ち）')
    elif command == 'incoming':
        for r in reversed(rpc('list_incoming_exchange_requests')):
            print(f"{r['nickname']}（#{r['public_id']}） {r['created_at']}")
    elif command in ('accept', 'decline'):
        request = first_incoming()
        rpc('respond_exchange', {'p_request_id': request['id'], 'p_accept': command == 'accept'})
        print(f"{request['nickname']}さんの申請を{'承認' if command == 'accept' else '拒否'}しました")
    elif command == 'cancel':
        mine = select(f"exchange_requests?requester_id=eq.{session()['user_id']}&status=eq.pending&select=id")
        if not mine:
            sys.exit('相手役が送った申請はありません')
        for r in mine:
            rpc('cancel_exchange', {'p_request_id': r['id']})
        print('申請を取り消しました')
    elif command == 'rotate':
        print(f"prome://exchange?token={rpc('rotate_exchange_code')}")
    elif command == 'friends':
        for f in select('friendships?select=exchanged_at,friend:profiles!friendships_friend_id_fkey(nickname,public_id)'):
            print(f"{f['friend']['nickname']}（#{f['friend']['public_id']}） {f['exchanged_at']}")
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(*sys.argv[1:])
