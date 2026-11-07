/// `profiles` の1行に対応する。`nickname` 以外は未入力なら null。
class Profile {
  const Profile({
    required this.id,
    required this.publicId,
    required this.nickname,
    this.fullName,
    this.nameRomaji,
    this.nameKana,
    this.birthYear,
    this.birthMonth,
    this.birthDay,
    this.likes,
    this.hobby,
    this.message,
    this.avatarAsset,
  });

  /// `profiles` の1行から作る。アバターはまだDBから表示しない。
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    publicId: json['public_id'] as String,
    nickname: json['nickname'] as String,
    fullName: json['full_name'] as String?,
    nameRomaji: json['name_romaji'] as String?,
    nameKana: json['name_kana'] as String?,
    birthYear: json['birth_year'] as int?,
    birthMonth: json['birth_month'] as int?,
    birthDay: json['birth_day'] as int?,
    likes: (json['likes'] as List?)?.cast<String>(),
    hobby: json['hobby'] as String?,
    message: json['message'] as String?,
  );

  final String id;
  final String publicId;
  final String nickname;
  final String? fullName;
  final String? nameRomaji;
  final String? nameKana;
  final int? birthYear;
  final int? birthMonth;
  final int? birthDay;
  final List<String>? likes;
  final String? hobby;
  final String? message;
  final String? avatarAsset;

  String get displayName => fullName ?? nickname;

  String get publicIdLabel => '#$publicId';

  /// 誕生年は任意なので、なければ月日だけを表示する。
  String? get birthdayLabel => birthMonth == null
      ? null
      : '${birthYear == null ? '' : '$birthYear年'}$birthMonth月$birthDay日';

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

  /// `friendships` の1行から作る。相手の `profiles` は `friend` に入れて取得する。
  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    profile: Profile.fromJson(json['friend'] as Map<String, dynamic>),
    exchangedAt: DateTime.parse(json['exchanged_at'] as String).toLocal(),
    isFavorite: json['is_favorite'] as bool,
    // 一度も詳細を開いていなければ「new!」を表示する。
    isNew: json['first_viewed_at'] == null,
    memo: json['memo'] as String?,
  );

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
