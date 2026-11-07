import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get _client => Supabase.instance.client;

String exchangeQrData(String token) => 'prome://exchange?token=$token';

/// QRコードの内容からトークンを取り出す。形式が違えば null。
String? parseExchangeToken(String? raw) {
  final uri = raw == null ? null : Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'prome' || uri.host != 'exchange') {
    return null;
  }
  return uri.queryParameters['token'];
}

/// 交換前の相手について見せてよい項目。`id` は画面に表示しない。
class ExchangeParty {
  const ExchangeParty({
    required this.id,
    required this.publicId,
    required this.nickname,
  });

  final String id;
  final String publicId;
  final String nickname;

  String get publicIdLabel => '#$publicId';
}

/// `preview_exchange_code` が返す、読み取った人とコードの持ち主の関係。
enum ExchangeRelation {
  none('none'),
  self('self'),
  friend('friend'),
  pendingOutgoing('pending_outgoing'),
  pendingIncoming('pending_incoming');

  const ExchangeRelation(this.value);

  final String value;

  static ExchangeRelation parse(String value) =>
      values.firstWhere((relation) => relation.value == value);
}

class ExchangePreview {
  const ExchangePreview({
    required this.party,
    required this.relation,
    this.requestId,
  });

  final ExchangeParty party;
  final ExchangeRelation relation;

  /// 申請中（`pendingOutgoing` / `pendingIncoming`）のときだけ入る。
  final String? requestId;
}

/// `exchange_requests` の `pending` の1行と、申請者の公開項目。
class ExchangeRequest {
  const ExchangeRequest({
    required this.id,
    required this.requester,
    required this.createdAt,
  });

  final String id;
  final ExchangeParty requester;
  final DateTime createdAt;
}

/// RPCが返すエラーを、画面に表示する文言にする。
String exchangeErrorMessage(Object error) => switch (error) {
  PostgrestException(message: 'invalid_token') =>
    'このコードは使えません。\n相手に新しいコードを見せてもらってください。',
  PostgrestException(message: 'own_code') => 'これはあなたのQRコードです。',
  PostgrestException(message: 'already_friends') => 'この相手とは、もう交換しています。',
  PostgrestException(message: 'request_not_found') => 'このリクエストは、もう処理されています。',
  _ => '通信に失敗しました。もう一度お試しください。',
};

/// ログイン中のユーザーのID。ログアウトすると null。
final currentUserIdProvider = StreamProvider<String?>(
  (ref) => _client.auth.onAuthStateChange
      .map((state) => state.session?.user.id)
      .distinct(),
);

/// ログイン中のユーザーのIDを待つ。ログインし直したら、呼び出し元も作り直される。
Future<String> _watchUserId(Ref ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) throw StateError('ログインしていません');
  return userId;
}

/// 自分の交換コードのトークン。
class MyExchangeTokenNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final userId = await _watchUserId(ref);
    final row = await _client
        .from('exchange_codes')
        .select('token')
        .eq('user_id', userId)
        .single();
    return row['token'] as String;
  }

  /// `rotate_exchange_code` を呼び、古いコードを使えなくする。
  Future<void> rotate() async {
    final token = await _client.rpc('rotate_exchange_code') as String;
    state = AsyncData(token);
  }
}

final myExchangeTokenProvider =
    AsyncNotifierProvider<MyExchangeTokenNotifier, String>(
      MyExchangeTokenNotifier.new,
    );

/// `preview_exchange_code` の結果。無効なトークンなら null。
final exchangePreviewProvider = FutureProvider.autoDispose
    .family<ExchangePreview?, String?>((ref, token) async {
      await _watchUserId(ref);
      if (token == null || token.isEmpty) return null;
      final rows = await _client.rpc(
        'preview_exchange_code',
        params: {'p_token': token},
      ) as List;
      if (rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      return ExchangePreview(
        party: ExchangeParty(
          id: row['owner_id'] as String,
          publicId: row['public_id'] as String,
          nickname: row['nickname'] as String,
        ),
        relation: ExchangeRelation.parse(row['relation'] as String),
        requestId: row['request_id'] as String?,
      );
    });

/// `request_exchange` を呼ぶ。相手からの申請が先にあり、その場で交換が
/// 成立したら true を返す。
Future<bool> requestExchange(String token) async {
  final rows =
      await _client.rpc('request_exchange', params: {'p_token': token}) as List;
  return (rows.first as Map<String, dynamic>)['status'] == 'accepted';
}

/// `cancel_exchange` を呼び、自分が送った申請を取り消す。
Future<void> cancelExchange(String requestId) =>
    _client.rpc('cancel_exchange', params: {'p_request_id': requestId});

/// 自分宛ての `pending` の申請。古い順に並べる。
/// 申請が届いたり取り消されたりしたときと、アプリが前面に戻ったときに取り直す。
class IncomingRequestsNotifier extends AsyncNotifier<List<ExchangeRequest>> {
  @override
  Future<List<ExchangeRequest>> build() async {
    final userId = await _watchUserId(ref);
    final channel = _client
        .channel('incoming-requests:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'exchange_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'addressee_id',
            value: userId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
    // バックグラウンド中に届いたRealtimeのイベントは受け取れない。
    final lifecycle = AppLifecycleListener(onResume: _refresh);
    ref.onDispose(() {
      lifecycle.dispose();
      _client.removeChannel(channel);
    });
    return _fetch();
  }

  Future<List<ExchangeRequest>> _fetch() async {
    final rows = await _client.rpc('list_incoming_exchange_requests') as List;
    return [
      // RPCは新しい順に返すので、古い順に並べ直す。
      for (final row in rows.reversed.cast<Map<String, dynamic>>())
        ExchangeRequest(
          id: row['id'] as String,
          requester: ExchangeParty(
            id: row['requester_id'] as String,
            publicId: row['public_id'] as String,
            nickname: row['nickname'] as String,
          ),
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        ),
    ];
  }

  Future<void> _refresh() async {
    try {
      final requests = await _fetch();
      if (ref.mounted) state = AsyncData(requests);
    } catch (_) {
      // 取り直しに失敗しても、表示中の一覧はそのまま残す。
    }
  }

  /// `respond_exchange` を呼び、承認するか断る。
  Future<void> respond(String requestId, {required bool accept}) async {
    try {
      await _client.rpc(
        'respond_exchange',
        params: {'p_request_id': requestId, 'p_accept': accept},
      );
    } on PostgrestException {
      // 相手が取り消した後などは、一覧を最新にしてから失敗を伝える。
      await _refresh();
      rethrow;
    }
    state = AsyncData([
      ...?state.value?.where((request) => request.id != requestId),
    ]);
  }
}

final incomingRequestsProvider =
    AsyncNotifierProvider<IncomingRequestsNotifier, List<ExchangeRequest>>(
      IncomingRequestsNotifier.new,
    );

/// 自分が送った申請で交換が成立したときに、相手の呼び名を流す。
/// 相手が承認したときと、相手が申請し返してその場で成立したときに届く。
final acceptedExchangesProvider = StreamProvider<String>((ref) {
  final controller = StreamController<String>();
  final userId = ref.watch(currentUserIdProvider).value;
  if (userId != null) {
    final channel = _client
        .channel('outgoing-requests:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'exchange_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'requester_id',
            value: userId,
          ),
          callback: (payload) async {
            if (payload.newRecord['status'] != 'accepted') return;
            try {
              // 交換が成立したので、相手のプロフィールを読める。
              final row = await _client
                  .from('profiles')
                  .select('nickname')
                  .eq('id', payload.newRecord['addressee_id'] as String)
                  .single();
              if (!controller.isClosed) {
                controller.add(row['nickname'] as String);
              }
            } catch (_) {
              // 呼び名を取れなければ、知らせずに終える。
            }
          },
        )
        .subscribe();
    ref.onDispose(() => _client.removeChannel(channel));
  }
  ref.onDispose(controller.close);
  return controller.stream;
});
