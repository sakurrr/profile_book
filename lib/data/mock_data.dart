import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `profiles` の1行に対応する。`nickname` 以外は未入力なら null。
class Profile {
  const Profile({
    required this.id,
    required this.publicId,
    required this.nickname,
    this.fullName,
    this.nameRomaji,
    this.nameKana,
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
  final String? nameKana;
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

  String? get zodiac =>
      birthMonth == null ? null : zodiacOf(birthMonth!, birthDay!);

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
    'やぎ座',
    'みずがめ座',
    'うお座',
    'おひつじ座',
    'おうし座',
    'ふたご座',
    'かに座',
    'しし座',
    'おとめ座',
    'てんびん座',
    'さそり座',
    'いて座',
    'やぎ座',
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
  nameKana: 'さとう はな',
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
  int? birthMonth,
  int? birthDay,
  required String nameKana,
}) => Friend(
  profile: Profile(
    id: id,
    publicId: _dummyPublicId(id),
    nickname: fullName.split(' ').last,
    fullName: fullName,
    nameKana: nameKana,
    birthMonth: birthMonth,
    birthDay: birthDay,
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
  _friend(
    'sota',
    '高橋 そうた',
    'フィルム写真',
    '休日はカメラと散歩。',
    1,
    avatar: 'assets/avatars/sota.png',
    isNew: true,
    birthMonth: 3,
    birthDay: 15,
    nameKana: 'たかはし そうた',
  ),
  _friend(
    'yui',
    '田中 ゆい',
    'お菓子づくり',
    'おいしいものは正義！',
    2,
    avatar: 'assets/avatars/yui.png',
    birthMonth: 7,
    birthDay: 20,
    nameKana: 'たなか ゆい',
  ),
  _friend(
    'ren',
    '伊藤 れん',
    '読書',
    'おすすめの本、教えて。',
    3,
    avatar: 'assets/avatars/ren.png',
    birthMonth: 12,
    birthDay: 25,
    nameKana: 'いとう れん',
  ),
  _friend(
    'aoi',
    '山本 あおい',
    '映画',
    '週末は映画館にいます。',
    4,
    favorite: true,
    nameKana: 'やまもと あおい',
  ),
  _friend(
    'kaito',
    '中村 かいと',
    'サッカー',
    '朝ランはじめました。',
    5,
    favorite: true,
    nameKana: 'なかむら かいと',
  ),
  _friend(
    'mei',
    '小川 めい',
    'ねこ',
    'うちのねこ、見てほしい。',
    6,
    favorite: true,
    nameKana: 'おがわ めい',
  ),
  _friend(
    'riku',
    '加藤 りく',
    'ギター',
    'いつかライブがしたい。',
    7,
    favorite: true,
    nameKana: 'かとう りく',
  ),
  _friend('saki', '吉田 さき', '旅行', '次は京都に行きたい。', 8, nameKana: 'よしだ さき'),
  _friend('yuto', '松本 ゆうと', 'ラーメン', 'おすすめのお店、募集中。', 9, nameKana: 'まつもと ゆうと'),
  _friend('nana', '井上 なな', 'お花', 'ベランダで育てています。', 10, nameKana: 'いのうえ なな'),
  _friend('haru', '木村 はる', 'ゲーム', '一緒にあそぼう！', 11, nameKana: 'きむら はる'),
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
