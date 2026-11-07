import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'exchange.dart';
import 'mock_data.dart';

SupabaseClient get _client => Supabase.instance.client;

/// メモは入力が止まってから保存する。
const _memoSaveDelay = Duration(milliseconds: 800);

/// ともだちの帳。`friendships` の自分の行と、相手の `profiles` を合わせて取得する。
/// お気に入りなどは先に画面に反映し、保存に失敗したら元に戻す。
class FriendsNotifier extends AsyncNotifier<List<Friend>> {
  late String _userId;
  final _memoTimers = <String, Timer>{};

  @override
  Future<List<Friend>> build() async {
    final userId = await ref.watch(currentUserIdProvider.future);
    if (userId == null) throw StateError('ログインしていません');
    _userId = userId;
    // 自分が送った申請で交換が成立したら、新しい友だちを取り込む。
    ref.listen(acceptedExchangesProvider, (_, _) => ref.invalidateSelf());

    // `friendships` から `profiles` への外部キーが2本あるので、相手の方を指定する。
    final rows = await _client
        .from('friendships')
        .select('*, friend:profiles!friendships_friend_id_fkey(*)')
        .eq('owner_id', userId)
        .order('exchanged_at', ascending: false);
    return [for (final row in rows) Friend.fromJson(row)];
  }

  Friend? _find(String friendId) =>
      state.value?.where((friend) => friend.profile.id == friendId).firstOrNull;

  void _replace(String friendId, Friend Function(Friend) change) {
    final friends = state.value;
    if (friends == null) return;
    state = AsyncData([
      for (final friend in friends)
        friend.profile.id == friendId ? change(friend) : friend,
    ]);
  }

  Future<void> _save(String friendId, Map<String, dynamic> values) => _client
      .from('friendships')
      .update(values)
      .eq('owner_id', _userId)
      .eq('friend_id', friendId);

  Future<void> toggleFavorite(String friendId) async {
    final friend = _find(friendId);
    if (friend == null) return;
    final favorite = !friend.isFavorite;
    _replace(friendId, (f) => f.copyWith(isFavorite: favorite));
    try {
      await _save(friendId, {'is_favorite': favorite});
    } catch (_) {
      if (ref.mounted) {
        _replace(friendId, (f) => f.copyWith(isFavorite: !favorite));
      }
      rethrow;
    }
  }

  /// 詳細を初めて開いたことを記録し、「new!」を消す。
  Future<void> markViewed(String friendId) async {
    if (_find(friendId)?.isNew != true) return;
    _replace(friendId, (f) => f.copyWith(isNew: false));
    try {
      await _save(friendId, {
        'first_viewed_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // 記録できなければ、次に取得したときにまた「new!」が付くだけなので知らせない。
    }
  }

  /// 画面にはすぐ反映し、DBには入力が止まってから保存する。空欄は null で保存する。
  void updateMemo(String friendId, String memo) {
    _replace(friendId, (f) => f.copyWith(memo: memo));
    _memoTimers[friendId]?.cancel();
    _memoTimers[friendId] = Timer(_memoSaveDelay, () async {
      _memoTimers.remove(friendId);
      try {
        await _save(friendId, {'memo': memo.trim().isEmpty ? null : memo});
      } catch (_) {
        // 保存に失敗しても入力中の内容は画面に残り、次の入力でまた保存する。
      }
    });
  }

  /// `remove_friend` を呼び、相手の帳からも自分を消す。
  Future<void> remove(String friendId) async {
    final friends = state.value;
    if (friends == null) return;
    _memoTimers.remove(friendId)?.cancel();
    state = AsyncData(
      friends.where((friend) => friend.profile.id != friendId).toList(),
    );
    try {
      await _client.rpc('remove_friend', params: {'p_friend_id': friendId});
    } catch (_) {
      // 解除できたかわからないので、DBから取り直す。
      if (ref.mounted) ref.invalidateSelf();
      rethrow;
    }
  }
}

final friendsProvider = AsyncNotifierProvider<FriendsNotifier, List<Friend>>(
  FriendsNotifier.new,
);
