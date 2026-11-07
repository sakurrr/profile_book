import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';
import '../data/my_profile.dart';
import '../widgets/common.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return switch (profile) {
      // 保存して読み直しても入力欄が作り直されないよう、ユーザーごとにフォームを作る。
      AsyncValue(:final value?) => _MyProfileForm(
        key: ValueKey(value.id),
        initial: value,
      ),
      AsyncError() => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'プロフィールを読み込めませんでした',
                style: TextStyle(fontSize: 12, color: AppColors.subText),
              ),
              TextButton(
                onPressed: () => ref.invalidate(myProfileProvider),
                child: const Text('もう一度読み込む'),
              ),
            ],
          ),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _MyProfileForm extends ConsumerStatefulWidget {
  const _MyProfileForm({super.key, required this.initial});

  final Profile initial;

  @override
  ConsumerState<_MyProfileForm> createState() => _MyProfileFormState();
}

class _MyProfileFormState extends ConsumerState<_MyProfileForm> {
  static const _maxLikes = 5;
  static const _maxMessage = 100;

  late final Profile _initial = widget.initial;
  bool _saving = false;
  late final _familyName = TextEditingController(text: _initial.familyName);
  late final _givenName = TextEditingController(text: _initial.givenName);
  late final _familyNameKana = TextEditingController(
    text: _initial.familyNameKana,
  );
  late final _givenNameKana = TextEditingController(
    text: _initial.givenNameKana,
  );
  late final _familyNameRomaji = TextEditingController(
    text: _initial.familyNameRomaji,
  );
  late final _givenNameRomaji = TextEditingController(
    text: _initial.givenNameRomaji,
  );
  late final _nickname = TextEditingController(text: _initial.nickname);
  late final _hobby = TextEditingController(text: _initial.hobby);
  late final _message = TextEditingController(text: _initial.message);
  late final _hometown = TextEditingController(text: _initial.hometown);
  late final _goalThisYear = TextEditingController(text: _initial.goalThisYear);
  late final _wantToGo = TextEditingController(text: _initial.wantToGo);
  late final _wantToTry = TextEditingController(text: _initial.wantToTry);
  late String? _bloodType = _initial.bloodType;
  late Map<String, String> _whichOne = {..._initial.whichOne};
  late List<String> _likes = [...?_initial.likes];
  late int? _birthYear = _initial.birthYear;
  late int? _birthMonth = _initial.birthMonth;
  late int? _birthDay = _initial.birthDay;

  @override
  void dispose() {
    for (final controller in [
      _familyName,
      _givenName,
      _familyNameKana,
      _givenNameKana,
      _familyNameRomaji,
      _givenNameRomaji,
      _nickname,
      _hobby,
      _message,
      _hometown,
      _goalThisYear,
      _wantToGo,
      _wantToTry,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 未入力は空文字ではなく null として扱う。
  String? _orNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Profile _draft() => Profile(
    id: _initial.id,
    publicId: _initial.publicId,
    nickname: _nickname.text.trim(),
    familyName: _orNull(_familyName),
    givenName: _orNull(_givenName),
    familyNameKana: _orNull(_familyNameKana),
    givenNameKana: _orNull(_givenNameKana),
    familyNameRomaji: _orNull(_familyNameRomaji),
    givenNameRomaji: _orNull(_givenNameRomaji),
    birthYear: _birthYear,
    birthMonth: _birthMonth,
    birthDay: _birthDay,
    hometown: _orNull(_hometown),
    bloodType: _bloodType,
    likes: _likes.isEmpty ? null : _likes,
    hobby: _orNull(_hobby),
    message: _orNull(_message),
    goalThisYear: _orNull(_goalThisYear),
    wantToGo: _orNull(_wantToGo),
    wantToTry: _orNull(_wantToTry),
    whichOne: _whichOne,
    avatarAsset: _initial.avatarAsset,
  );

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final missing = {
      '姓': _familyName,
      '名': _givenName,
      'せい': _familyNameKana,
      'めい': _givenNameKana,
      'ニックネーム': _nickname,
    }.entries.where((entry) => _orNull(entry.value) == null).firstOrNull;
    if (missing != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('${missing.key}を入力してください')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(myProfileProvider.notifier).save(_draft());
      messenger.showSnackBar(const SnackBar(content: Text('変更を保存しました')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('保存に失敗しました。もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _preview() {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '友だちからの見え方',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              ProfileBookCard(profile: _draft()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addLike() async {
    final controller = TextEditingController();
    final like = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('好きなものを追加', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例：プリン'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (like != null && like.isNotEmpty && !_likes.contains(like)) {
      setState(() => _likes = [..._likes, like]);
    }
  }

  Future<void> _pickBirthday() async {
    var year = _birthYear;
    var month = _birthMonth ?? 1;
    var day = _birthDay ?? 1;
    final thisYear = DateTime.now().year;
    final result = await showDialog<_BirthdayResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 年が未選択なら、2月29日も選べるよう、うるう年で日数を数える。
          final maxDay = DateUtils.getDaysInMonth(year ?? 2024, month);
          if (day > maxDay) day = maxDay;
          return AlertDialog(
            title: const Text('誕生日', style: TextStyle(fontSize: 16)),
            // 狭い画面で3つ並ばないときは折り返す。
            content: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: [
                // 年は任意なので、未選択（null）も選べる。
                DropdownButton<int?>(
                  value: year,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('年なし')),
                    for (var y = thisYear; y >= 1900; y--)
                      DropdownMenuItem(value: y, child: Text('$y年')),
                  ],
                  onChanged: (y) => setDialogState(() => year = y),
                ),
                DropdownButton<int>(
                  value: month,
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text('$m月')),
                  ],
                  onChanged: (m) => setDialogState(() => month = m!),
                ),
                DropdownButton<int>(
                  value: day,
                  items: [
                    for (var d = 1; d <= maxDay; d++)
                      DropdownMenuItem(value: d, child: Text('$d日')),
                  ],
                  onChanged: (d) => setDialogState(() => day = d!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  const _BirthdayResult(null, null, null),
                ),
                child: const Text('未設定にする'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _BirthdayResult(year, month, day)),
                child: const Text('決定'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) {
      setState(() {
        _birthYear = result.year;
        _birthMonth = result.month;
        _birthDay = result.day;
      });
    }
  }

  Widget _field(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
  }) => TextField(
    controller: controller,
    minLines: 1,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(hintText: hint),
  );

  /// 姓と名の入力欄を横に並べる。
  Widget _namePair(
    (String, TextEditingController, String) family,
    (String, TextEditingController, String) given,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, (label, controller, hint)) in [
        family,
        given,
      ].indexed) ...[
        if (index > 0) const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(label),
              _field(controller, hint: hint),
            ],
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            PageHeader(
              title: '自分のプロフィール帳',
              onBack: () => context.go('/friends'),
              trailing: CircleIconButton(
                icon: Icons.visibility_outlined,
                onPressed: _preview,
              ),
            ),
            const SizedBox(height: 4),
            _intro(context),
            const SizedBox(height: 14),
            PaperCard(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(number: '01', title: 'わたしのこと'),
                  const SizedBox(height: 14),
                  _namePair(
                    ('姓', _familyName, '例：小林'),
                    ('名', _givenName, '例：みお'),
                  ),
                  const SizedBox(height: 12),
                  _namePair(
                    ('せい', _familyNameKana, '例：こばやし'),
                    ('めい', _givenNameKana, '例：みお'),
                  ),
                  const SizedBox(height: 12),
                  _namePair(
                    ('姓（ローマ字）', _familyNameRomaji, '例：KOBAYASHI'),
                    ('名（ローマ字）', _givenNameRomaji, '例：MIO'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('ニックネーム'),
                            _field(_nickname),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _birthdayField()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('出身地'),
                            _field(_hometown, hint: '例：福岡県'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _bloodTypeField()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FieldLabel(
                    '好きなもの',
                    trailing: '${_likes.length} / $_maxLikes',
                  ),
                  _likesEditor(),
                  const SizedBox(height: 12),
                  const FieldLabel('趣味'),
                  _field(_hobby),
                  const SizedBox(height: 12),
                  const FieldLabel('ひとこと'),
                  TextField(
                    controller: _message,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: _maxMessage,
                    style: const TextStyle(fontSize: 13, height: 1.7),
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => Text(
                          '$currentLength / $maxLength文字',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.subText,
                          ),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PaperCard(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(number: '02', title: 'これからのこと'),
                  const SizedBox(height: 14),
                  const FieldLabel('今年の目標'),
                  _field(_goalThisYear, hint: '例：毎朝ランニングする', maxLines: 3),
                  const SizedBox(height: 12),
                  const FieldLabel('行ってみたいところ'),
                  _field(_wantToGo, hint: '例：北海道の旭山動物園', maxLines: 3),
                  const SizedBox(height: 12),
                  const FieldLabel('やってみたいこと'),
                  _field(_wantToTry, hint: '例：スキューバダイビング', maxLines: 3),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PaperCard(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(number: '03', title: 'どっち派？'),
                  const SizedBox(height: 4),
                  const Text(
                    'もう一度タップすると選択を外せます',
                    style: TextStyle(fontSize: 9, color: AppColors.subText),
                  ),
                  const SizedBox(height: 12),
                  for (final (i, question) in whichOneQuestions.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _whichOneRow(question),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 13, color: AppColors.subText),
                SizedBox(width: 6),
                Text(
                  '交換した友だちにだけ公開されます',
                  style: TextStyle(fontSize: 10, color: AppColors.subText),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: '変更を保存する',
              icon: Icons.check,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) => Row(
    children: [
      GestureDetector(
        onTap: () => showComingSoon(context, '写真の変更'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Avatar(profile: _initial, size: 54, ringWidth: 3),
            Positioned(
              right: -4,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_camera, size: 13),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My profile book', style: serifItalic(size: 11)),
            const Text(
              'わたしらしさを、一冊に。',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const Text(
              '内容はあとからいつでも変更できます',
              style: TextStyle(fontSize: 9, color: AppColors.subText),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _birthdayField() {
    final year = _birthYear == null ? '' : '$_birthYear年';
    final label = _birthMonth == null ? '未設定' : '$year$_birthMonth月$_birthDay日';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('誕生日'),
        GestureDetector(
          onTap: _pickBirthday,
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: AppColors.subText,
              ),
            ),
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _bloodTypeField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const FieldLabel('血液型'),
      DropdownButtonFormField<String?>(
        initialValue: _bloodType,
        style: const TextStyle(fontSize: 13, color: AppColors.ink),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('未設定')),
          for (final type in bloodTypes)
            DropdownMenuItem(value: type, child: Text('$type型')),
        ],
        onChanged: (type) => setState(() => _bloodType = type),
      ),
    ],
  );

  /// 「犬 派 vs 猫 派」の2択。選択中の選択肢をもう一度押すと未回答に戻す。
  Widget _whichOneRow(WhichOneQuestion question) {
    final selected = _whichOne[question.id];
    void select(String option) => setState(() {
      _whichOne = {..._whichOne};
      if (selected == option) {
        _whichOne.remove(question.id);
      } else {
        _whichOne[question.id] = option;
      }
    });

    return Row(
      children: [
        for (final (i, option) in question.options.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'vs',
                style: serifItalic(size: 11, color: AppColors.subText),
              ),
            ),
          Expanded(
            child: _WhichOneChoice(
              label: option.label,
              selected: selected == option.id,
              onTap: () => select(option.id),
            ),
          ),
        ],
      ],
    );
  }

  Widget _likesEditor() => Wrap(
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final like in _likes)
        LikeTag(
          label: like,
          color: AppColors.pink,
          onDeleted: () => setState(() {
            _likes = _likes.where((item) => item != like).toList();
          }),
        ),
      if (_likes.length < _maxLikes)
        GestureDetector(
          onTap: _addLike,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.add, size: 16),
          ),
        ),
    ],
  );
}

class _WhichOneChoice extends StatelessWidget {
  const _WhichOneChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.pink : AppColors.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Text.rich(
        TextSpan(
          text: label,
          children: const [
            TextSpan(text: ' 派', style: TextStyle(fontSize: 10)),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? AppColors.accent : AppColors.subText,
        ),
      ),
    ),
  );
}

class _BirthdayResult {
  const _BirthdayResult(this.year, this.month, this.day);

  final int? year;
  final int? month;
  final int? day;
}
