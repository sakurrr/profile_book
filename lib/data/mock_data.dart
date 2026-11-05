import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `profiles` の1行に対応する。`nickname` 以外は未入力なら null。
class Profile {
  const Profile({
    required this.id,
    required this.publicId,
    required this.nickname,
    this.fullName,
    this.nameRomaji,
    this.birthMonth,
    this.birthDay,
    this.likes,
    this.hobby,
    this.message,
    this.avatarAsset,
  });

  final String id;
  final String publicId;
  final String nickname;
  final String? fullName;
  final String? nameRomaji;
  final int? birthMonth;
  final int? birthDay;
  final List<String>? likes;
  final String? hobby;
  final String? message;
  final String? avatarAsset;

  String get displayName => fullName ?? nickname;

  String get publicIdLabel => '#$publicId';

  String? get birthdayLabel =>
      birthMonth == null ? null : '$birthMonth月$birthDay日';

  String? get zodiac => birthMonth == null
      ? null
      : zodiacOf(birthMonth!, birthDay!);

  /// ホームのカードで使う、ひとことの1行目。
  String? get messageHeadline => message?.split('\n').first;

  /// 「Hana's profile book」の表示に使う、ローマ字の名前の先頭。
  String get bookTitle {
    final given = nameRomaji?.split(' ').first;
    if (given == null || given.isEmpty) return 'Profile book';
    final name = given[0].toUpperCase() + given.substring(1).toLowerCase();
    return "$name's profile book";
  }
}

String zodiacOf(int month, int day) {
  const names = [
    'やぎ座', 'みずがめ座', 'うお座', 'おひつじ座', 'おうし座', 'ふたご座',
    'かに座', 'しし座', 'おとめ座', 'てんびん座', 'さそり座', 'いて座', 'やぎ座',
  ];
  const startDays = [20, 19, 21, 20, 21, 22, 23, 23, 23, 24, 23, 22];
  return names[day < startDays[month - 1] ? month - 1 : month];
}

/// `friendships` の1行と、相手の `profiles` を合わせたもの。
class Friend {
  const Friend({
    required this.profile,
    required this.exchangedAt,
    this.isFavorite = false,
    this.isNew = false,
    this.memo,
  });

  final Profile profile;
  final DateTime exchangedAt;
  final bool isFavorite;
  final bool isNew;
  final String? memo;

  Friend copyWith({bool? isFavorite, bool? isNew, String? memo}) => Friend(
    profile: profile,
    exchangedAt: exchangedAt,
    isFavorite: isFavorite ?? this.isFavorite,
    isNew: isNew ?? this.isNew,
    memo: memo ?? this.memo,
  );
}

const _hana = Profile(
  id: 'hana',
  publicId: '7F3A92C1',
  nickname: 'はな',
  fullName: '佐藤 はな',
  nameRomaji: 'HANA SATO',
  birthMonth: 7,
  birthDay: 7,
  likes: ['喫茶店', 'クリームソーダ', '本屋'],
  hobby: '喫茶店巡り、読書、散歩',
  message: '小さな喫茶店がすき。\nいつか一緒に、おいしいクリームソーダを飲みに行こう！',
  avatarAsset: 'assets/avatars/hana.png',
);

/// ダミーの友だちに、毎回同じ表示用IDを割り当てる。
String _dummyPublicId(String id) {
  final hash = id.codeUnits.fold(17, (value, unit) => value * 131 + unit);
  return (hash & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase();
}

Friend _friend(
  String id,
  String fullName,
  String like,
  String message,
  int daysAgo, {
  String? avatar,
  bool favorite = false,
  bool isNew = false,
}) => Friend(
  profile: Profile(
    id: id,
    publicId: _dummyPublicId(id),
    nickname: fullName.split(' ').last,
    fullName: fullName,
    likes: [like],
    message: message,
    avatarAsset: avatar,
  ),
  exchangedAt: DateTime(2026, 10, 25).subtract(Duration(days: daysAgo)),
  isFavorite: favorite,
  isNew: isNew,
);

final _initialFriends = [
  Friend(
    profile: _hana,
    exchangedAt: DateTime(2026, 10, 25),
    isNew: true,
    memo: '次は駅前の喫茶店に誘ってみよう。',
  ),
  _friend('sota', '高橋 そうた', 'フィルム写真', '休日はカメラと散歩。', 1,
      avatar: 'assets/avatars/sota.png', isNew: true),
  _friend('yui', '田中 ゆい', 'お菓子づくり', 'おいしいものは正義！', 2,
      avatar: 'assets/avatars/yui.png'),
  _friend('ren', '伊藤 れん', '読書', 'おすすめの本、教えて。', 3,
      avatar: 'assets/avatars/ren.png'),
  _friend('aoi', '山本 あおい', '映画', '週末は映画館にいます。', 4, favorite: true),
  _friend('kaito', '中村 かいと', 'サッカー', '朝ランはじめました。', 5, favorite: true),
  _friend('mei', '小川 めい', 'ねこ', 'うちのねこ、見てほしい。', 6, favorite: true),
  _friend('riku', '加藤 りく', 'ギター', 'いつかライブがしたい。', 7, favorite: true),
  _friend('saki', '吉田 さき', '旅行', '次は京都に行きたい。', 8),
  _friend('yuto', '松本 ゆうと', 'ラーメン', 'おすすめのお店、募集中。', 9),
  _friend('nana', '井上 なな', 'お花', 'ベランダで育てています。', 10),
  _friend('haru', '木村 はる', 'ゲーム', '一緒にあそぼう！', 11),
];

class FriendsNotifier extends Notifier<List<Friend>> {
  @override
  List<Friend> build() => _initialFriends;

  void _update(String id, Friend Function(Friend) change) {
    state = [
      for (final friend in state)
        friend.profile.id == id ? change(friend) : friend,
    ];
  }

  void toggleFavorite(String id) =>
      _update(id, (f) => f.copyWith(isFavorite: !f.isFavorite));

  void markViewed(String id) => _update(id, (f) => f.copyWith(isNew: false));

  void updateMemo(String id, String memo) =>
      _update(id, (f) => f.copyWith(memo: memo));

  void add(Friend friend) => state = [friend, ...state];

  void remove(String id) {
    state = state.where((f) => f.profile.id != id).toList();
  }
}

final friendsProvider = NotifierProvider<FriendsNotifier, List<Friend>>(
  FriendsNotifier.new,
);

class MyProfileNotifier extends Notifier<Profile> {
  @override
  Profile build() => const Profile(
    id: 'mio',
    publicId: 'A4E1C07B',
    nickname: 'みお',
    fullName: '小林 みお',
    nameRomaji: 'MIO KOBAYASHI',
    birthMonth: 5,
    birthDay: 18,
    likes: ['プリン', '喫茶店', 'ねこ'],
    hobby: '喫茶店巡り、フィルム写真',
    message: 'おいしいプリンと、のんびりした時間がすき。おすすめの喫茶店、教えてね！',
    avatarAsset: 'assets/avatars/mio.png',
  );

  void save(Profile profile) => state = profile;
}

final myProfileProvider = NotifierProvider<MyProfileNotifier, Profile>(
  MyProfileNotifier.new,
);

class ExchangeTokenNotifier extends Notifier<String> {
  int _generation = 1;

  @override
  String build() => 'demo-mio-$_generation';

  void rotate() {
    _generation++;
    state = 'demo-mio-$_generation';
  }
}

final exchangeTokenProvider = NotifierProvider<ExchangeTokenNotifier, String>(
  ExchangeTokenNotifier.new,
);

/// 動作確認用のトークン。読み取ると、交換済みの佐藤はなさんを指す。
const demoFriendToken = 'demo-hana';

/// 動作確認用のトークン。読み取ると、まだ交換していない森そらさんを指す。
const demoStrangerToken = 'demo-sora';

const _sora = Profile(
  id: 'sora',
  publicId: '3B9D0E52',
  nickname: 'そら',
  fullName: '森 そら',
  likes: ['星空', 'プラネタリウム'],
  message: '夜の散歩がすき。',
);

const _rina = Profile(
  id: 'rina',
  publicId: 'C2F81A6D',
  nickname: 'りな',
  fullName: '石井 りな',
  likes: ['パン屋'],
  message: '焼きたてのパンの匂いがすき。',
);

const _yuzu = Profile(
  id: 'yuzu',
  publicId: '5E07B3F9',
  nickname: 'ゆず',
  fullName: '岡田 ゆず',
  likes: ['水族館'],
  message: 'くらげをずっと見ていられる。',
);

const _profilesByToken = {demoFriendToken: _hana, demoStrangerToken: _sora};

/// 交換が成立したときに友だちの帳へ加える、モックのプロフィール。
const _profilesById = {
  'hana': _hana,
  'sora': _sora,
  'rina': _rina,
  'yuzu': _yuzu,
};

String exchangeQrData(String token) => 'prome://exchange?token=$token';

/// QRコードの内容からトークンを取り出す。形式が違えば null。
String? parseExchangeToken(String? raw) {
  final uri = raw == null ? null : Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'prome' || uri.host != 'exchange') {
    return null;
  }
  return uri.queryParameters['token'];
}

/// 交換前の相手について見せてよい項目。`public_id` と `nickname` だけを持つ。
class ExchangeParty {
  const ExchangeParty({
    required this.id,
    required this.publicId,
    required this.nickname,
  });

  ExchangeParty.of(Profile profile)
    : id = profile.id,
      publicId = profile.publicId,
      nickname = profile.nickname;

  final String id;
  final String publicId;
  final String nickname;

  String get publicIdLabel => '#$publicId';
}

/// `preview_exchange_code` が返す、読み取った人とコードの持ち主の関係。
enum ExchangeRelation { none, self, friend, pendingOutgoing, pendingIncoming }

class ExchangePreview {
  const ExchangePreview({required this.party, required this.relation});

  final ExchangeParty party;
  final ExchangeRelation relation;
}

/// `exchange_requests` の `pending` の1行と、申請者の公開項目。
class ExchangeRequest {
  const ExchangeRequest({required this.id, required this.requester});

  final String id;
  final ExchangeParty requester;
}

/// 自分が送った `pending` の申請の相手。
class OutgoingRequestsNotifier extends Notifier<List<ExchangeParty>> {
  @override
  List<ExchangeParty> build() => const [];

  void request(ExchangeParty party) => state = [...state, party];

  void cancel(String partyId) =>
      state = state.where((p) => p.id != partyId).toList();
}

final outgoingRequestsProvider =
    NotifierProvider<OutgoingRequestsNotifier, List<ExchangeParty>>(
      OutgoingRequestsNotifier.new,
    );

/// 自分宛ての `pending` の申請。`list_incoming_exchange_requests` の代わり。
class IncomingRequestsNotifier extends Notifier<List<ExchangeRequest>> {
  @override
  List<ExchangeRequest> build() => [
    ExchangeRequest(id: 'req-rina', requester: ExchangeParty.of(_rina)),
  ];

  /// `respond_exchange` の代わり。承認すると友だちの帳に加える。
  void respond(String requestId, {required bool accept}) {
    final request = state.firstWhere((r) => r.id == requestId);
    state = state.where((r) => r.id != requestId).toList();
    if (accept) {
      ref
          .read(friendsProvider.notifier)
          .add(
            Friend(
              profile: _profilesById[request.requester.id]!,
              exchangedAt: DateTime.now(),
              isNew: true,
            ),
          );
    }
  }

  /// Realtimeで申請が届いたときの動きを、開発中に試すためのもの。
  void simulateArrival() {
    if (state.any((r) => r.id == 'req-yuzu')) return;
    state = [
      ...state,
      ExchangeRequest(id: 'req-yuzu', requester: ExchangeParty.of(_yuzu)),
    ];
  }
}

final incomingRequestsProvider =
    NotifierProvider<IncomingRequestsNotifier, List<ExchangeRequest>>(
      IncomingRequestsNotifier.new,
    );

/// `preview_exchange_code` の代わり。無効なトークンなら null。
final exchangePreviewProvider = Provider.family<ExchangePreview?, String?>((
  ref,
  token,
) {
  final me = ref.watch(myProfileProvider);
  if (token != null && token == ref.watch(exchangeTokenProvider)) {
    return ExchangePreview(
      party: ExchangeParty.of(me),
      relation: ExchangeRelation.self,
    );
  }
  final owner = _profilesByToken[token];
  if (owner == null) return null;
  final relation = switch (owner.id) {
    final id when ref.watch(friendsProvider).any((f) => f.profile.id == id) =>
      ExchangeRelation.friend,
    final id when ref.watch(outgoingRequestsProvider).any((p) => p.id == id) =>
      ExchangeRelation.pendingOutgoing,
    final id
        when ref
            .watch(incomingRequestsProvider)
            .any((r) => r.requester.id == id) =>
      ExchangeRelation.pendingIncoming,
    _ => ExchangeRelation.none,
  };
  return ExchangePreview(party: ExchangeParty.of(owner), relation: relation);
});
