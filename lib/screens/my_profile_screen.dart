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
  late final _fullName = TextEditingController(text: _initial.fullName);
  late final _romaji = TextEditingController(text: _initial.nameRomaji);
  late final _nickname = TextEditingController(text: _initial.nickname);
  late final _hobby = TextEditingController(text: _initial.hobby);
  late final _message = TextEditingController(text: _initial.message);
  late List<String> _likes = [...?_initial.likes];
  late int? _birthYear = _initial.birthYear;
  late int? _birthMonth = _initial.birthMonth;
  late int? _birthDay = _initial.birthDay;

  @override
  void dispose() {
    for (final controller in [_fullName, _romaji, _nickname, _hobby, _message]) {
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
    fullName: _orNull(_fullName),
    nameRomaji: _orNull(_romaji),
    birthYear: _birthYear,
    birthMonth: _birthMonth,
    birthDay: _birthDay,
    likes: _likes.isEmpty ? null : _likes,
    hobby: _orNull(_hobby),
    message: _orNull(_message),
    avatarAsset: _initial.avatarAsset,
  );

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (_nickname.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('呼んでほしい名前を入力してください')),
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

  Widget _field(TextEditingController controller, {String? hint}) => TextField(
    controller: controller,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(hintText: hint),
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
                  const FieldLabel('名前'),
                  _field(_fullName),
                  const SizedBox(height: 12),
                  const FieldLabel('ローマ字の名前'),
                  _field(_romaji, hint: '例：MIO KOBAYASHI'),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('呼んでほしい名前'),
                            _field(_nickname),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _birthdayField()),
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
                    buildCounter: (
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

class _BirthdayResult {
  const _BirthdayResult(this.year, this.month, this.day);

  final int? year;
  final int? month;
  final int? day;
}
