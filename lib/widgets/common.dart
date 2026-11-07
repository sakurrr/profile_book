import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';

void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$featureは準備中です')));
}

class Flower extends StatelessWidget {
  const Flower({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _FlowerPainter());
}

class _FlowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final unit = size.width / 2;
    final petal = Paint()..color = AppColors.yellow;
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * unit * 0.58,
        unit * 0.42,
        petal,
      );
    }
    canvas.drawCircle(center, unit * 0.6, petal);
    canvas.drawCircle(center, unit * 0.36, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// バナーの右側に置く、傾いた紙と花の飾り。
class FlowerPaper extends StatelessWidget {
  const FlowerPaper({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 62,
    height: 74,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: 0.09,
          child: Container(width: 50, height: 64, color: Colors.white),
        ),
        const Positioned(right: 0, child: Flower(size: 50)),
      ],
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.profile,
    this.size = 52,
    this.ringWidth = 5,
  });

  final Profile profile;
  final double size;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final asset = profile.avatarAsset;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ringWidth),
      decoration: const BoxDecoration(
        color: AppColors.ring,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: asset != null
            ? Image.asset(asset, fit: BoxFit.cover)
            : ColoredBox(
                color: AppColors.lavender,
                child: Center(
                  child: Text(
                    profile.nickname.characters.first,
                    style: TextStyle(
                      fontSize: size * 0.34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

const tagColors = [AppColors.pink, AppColors.lavender, AppColors.mint];

class LikeTag extends StatelessWidget {
  const LikeTag({
    super.key,
    required this.label,
    required this.color,
    this.onDeleted,
  });

  final String label;
  final Color color;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        if (onDeleted != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDeleted,
            child: const Icon(Icons.close, size: 13, color: AppColors.accent),
          ),
        ],
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Text(label),
        ],
      ),
    ),
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.subText,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 44,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D343850),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

/// カードの上に貼るマスキングテープの飾り。Stackの中で使う。
class Tape extends StatelessWidget {
  const Tape({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.05,
    child: Container(width: 66, height: 16, color: color),
  );
}

/// 「01 ログイン ───」形式の見出し。
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(number, style: serif(size: 14, color: AppColors.accent)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: AppColors.border, height: 1)),
    ],
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontSize: 11)),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(fontSize: 10, color: AppColors.subText),
          ),
      ],
    ),
  );
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: SizedBox.square(dimension: 36, child: Icon(icon, size: 20)),
    ),
  );
}

/// 戻るボタンとタイトルが並ぶ画面上部のヘッダー。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(0, 8, 14, 8),
            child: Icon(Icons.arrow_back, size: 22),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text.rich(
          TextSpan(
            text: 'prome',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            children: [
              TextSpan(
                text: ' プロミー',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// ホーム、ログイン、アカウント作成の上部にあるバナー。
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.caption,
    required this.color,
    this.eyebrowIsSerif = true,
  });

  final String eyebrow;
  final String title;
  final String caption;
  final Color color;
  final bool eyebrowIsSerif;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: eyebrowIsSerif
                    ? serifItalic(size: 12)
                    : const TextStyle(fontSize: 10, color: AppColors.accent),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                caption,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.7,
                  color: AppColors.subText,
                ),
              ),
            ],
          ),
        ),
        const FlowerPaper(),
      ],
    ),
  );
}

/// ともだちの詳細と自分の見え方で共通のプロフィール帳カード。
class ProfileBookCard extends StatelessWidget {
  const ProfileBookCard({
    super.key,
    required this.profile,
    this.trailing,
    this.footer,
  });

  final Profile profile;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final likes = profile.likes ?? const <String>[];
    final message = profile.message;
    return PaperCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 未入力の項目も同じ位置に「未記入」と出し、人によって形を変えない。
                _pairRow(
                  ('誕生日', profile.birthdayLabel),
                  ('星座', profile.zodiac),
                ),
                const SizedBox(height: 14),
                _pairRow(
                  ('出身地', profile.hometown),
                  ('血液型', profile.bloodTypeLabel),
                ),
                const Divider(color: AppColors.border, height: 24),
                const _CaptionLabel('好きなもの'),
                const SizedBox(height: 6),
                if (likes.isEmpty)
                  const _ValueText(null)
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (i, like) in likes.indexed)
                        LikeTag(
                          label: like,
                          color: tagColors[i % tagColors.length],
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                const _CaptionLabel('趣味'),
                const SizedBox(height: 6),
                _ValueText(profile.hobby),
                const Divider(color: AppColors.border, height: 32),
                const _BookSubheading(english: 'Future', title: 'これからのこと'),
                const SizedBox(height: 12),
                _labeled('今年の目標', profile.goalThisYear),
                const SizedBox(height: 14),
                _labeled('行ってみたいところ', profile.wantToGo),
                const SizedBox(height: 14),
                _labeled('やってみたいこと', profile.wantToTry),
                const Divider(color: AppColors.border, height: 32),
                const _BookSubheading(english: 'Which one?', title: 'どっち派？'),
                const SizedBox(height: 10),
                for (final question in whichOneQuestions)
                  _WhichOneAnswer(
                    question: question,
                    selected: profile.whichOne[question.id],
                  ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CaptionLabel('みんなにひとこと'),
                      const SizedBox(height: 6),
                      _ValueText(message, height: 1.85),
                    ],
                  ),
                ),
                if (footer != null) ...[const SizedBox(height: 12), footer!],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
    color: AppColors.lavender,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(right: 10, bottom: -18, child: Flower(size: 40)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  profile.bookTitle,
                  style: serifItalic(size: 15, color: AppColors.ink),
                ),
                if (trailing != null) trailing! else const SizedBox(height: 30),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Avatar(profile: profile, size: 72, ringWidth: 8),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile.nameRomaji != null)
                        Text(
                          profile.nameRomaji!,
                          style: serif(size: 10, color: AppColors.subText),
                        ),
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '「${profile.nickname}」って呼んでね',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.subText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.publicIdLabel,
                        style: serif(size: 10, color: AppColors.subText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  /// 2つの項目を縦線で区切って横に並べる。
  Widget _pairRow((String, String?) left, (String, String?) right) =>
      IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _labeled(left.$1, left.$2)),
            const VerticalDivider(color: AppColors.border, width: 1),
            const SizedBox(width: 16),
            Expanded(child: _labeled(right.$1, right.$2)),
          ],
        ),
      );

  Widget _labeled(String label, String? value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _CaptionLabel(label),
      const SizedBox(height: 6),
      _ValueText(value),
    ],
  );
}

/// プロフィール帳のカード内の小見出し。「Future これからのこと」の形式。
class _BookSubheading extends StatelessWidget {
  const _BookSubheading({required this.english, required this.title});

  final String english;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(english, style: serifItalic(size: 13)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

/// 紙のプロフィール帳の「【 犬 ・ 猫 】派」のように、選んだほうに色を付けて並べる。
/// 未回答なら、どちらにも色を付けない。
class _WhichOneAnswer extends StatelessWidget {
  const _WhichOneAnswer({required this.question, required this.selected});

  final WhichOneQuestion question;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    const bracket = TextStyle(fontSize: 13, color: AppColors.hint);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('【 ', style: bracket),
          for (final (i, option) in question.options.indexed) ...[
            if (i > 0) const Text(' ・ ', style: bracket),
            _option(option.label, selected == option.id),
          ],
          const Text(' 】', style: bracket),
          const Text('派', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _option(String label, bool chosen) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: chosen ? AppColors.pink : null,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: chosen ? AppColors.accent : Colors.transparent),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: chosen ? FontWeight.w700 : FontWeight.w400,
        color: chosen ? AppColors.accent : AppColors.hint,
      ),
    ),
  );
}

/// プロフィール帳の項目の値。未入力なら薄いグレーで「未記入」と出す。
class _ValueText extends StatelessWidget {
  const _ValueText(this.value, {this.height});

  final String? value;
  final double? height;

  @override
  Widget build(BuildContext context) => Text(
    value ?? '未記入',
    style: TextStyle(
      fontSize: 13,
      height: height,
      color: value == null ? AppColors.hint : null,
    ),
  );
}

class _CaptionLabel extends StatelessWidget {
  const _CaptionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 10, color: AppColors.hint));
}
