import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'exchange.dart';
import 'mock_data.dart';

SupabaseClient get _client => Supabase.instance.client;

/// ログイン中のユーザーの `profiles` の1行。
class MyProfileNotifier extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() async {
    final userId = await ref.watch(currentUserIdProvider.future);
    if (userId == null) throw StateError('ログインしていません');
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(row);
  }

  /// マイページで編集できる項目だけを保存する。保存に失敗したら例外を投げる。
  Future<void> save(Profile profile) async {
    final row = await _client
        .from('profiles')
        .update({
          'nickname': profile.nickname,
          'family_name': profile.familyName,
          'given_name': profile.givenName,
          'family_name_kana': profile.familyNameKana,
          'given_name_kana': profile.givenNameKana,
          'family_name_romaji': profile.familyNameRomaji,
          'given_name_romaji': profile.givenNameRomaji,
          'birth_year': profile.birthYear,
          'birth_month': profile.birthMonth,
          'birth_day': profile.birthDay,
          'hometown': profile.hometown,
          'blood_type': profile.bloodType,
          'likes': profile.likes,
          'hobby': profile.hobby,
          'message': profile.message,
          'goal_this_year': profile.goalThisYear,
          'want_to_go': profile.wantToGo,
          'want_to_try': profile.wantToTry,
          'which_one': profile.whichOne,
        })
        .eq('id', profile.id)
        .select()
        .single();
    state = AsyncData(Profile.fromJson(row));
  }
}

final myProfileProvider = AsyncNotifierProvider<MyProfileNotifier, Profile>(
  MyProfileNotifier.new,
);
