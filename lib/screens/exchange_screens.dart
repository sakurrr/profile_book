import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';
import '../widgets/common.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  bool _reading = false;

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('交換のしかた', style: TextStyle(fontSize: 16)),
        content: const Text(
          '相手のコードを読み取って申請し、相手が承認すると交換が成立します。\n'
          '交換すると、お互いのプロフィール帳を見られるようになります。',
          style: TextStyle(fontSize: 13, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            PageHeader(
              title: 'プロフィール帳を交換',
              onBack: () => context.go('/friends'),
              trailing: CircleIconButton(
                icon: Icons.help_outline,
                onPressed: _showHelp,
              ),
            ),
            const SizedBox(height: 4),
            _ModeSwitch(
              reading: _reading,
              onChanged: (reading) => setState(() => _reading = reading),
            ),
            const SizedBox(height: 18),
            if (_reading)
              const _ReadCodeView()
            else
              _ShowCodeView(onRead: () => setState(() => _reading = true)),
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.reading, required this.onChanged});

  final bool reading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final selected = reading == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppColors.accent : AppColors.subText,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E2DA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [tab('コードを見せる', false), tab('読み取る', true)]),
    );
  }
}

class _ShowCodeView extends ConsumerWidget {
  const _ShowCodeView({required this.onRead});

  final VoidCallback onRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final token = ref.watch(exchangeTokenProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Let's exchange!",
          textAlign: TextAlign.center,
          style: serifItalic(size: 12),
        ),
        const SizedBox(height: 4),
        const Text(
          'はじめましてを、一冊に。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          '友だちにこのコードを読み取ってもらおう。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.subText),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PaperCard(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Avatar(profile: profile, size: 36, ringWidth: 3),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'わたしのプロフィール帳',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.subText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    QrImageView(
                      data: exchangeLink(token),
                      size: 180,
                      padding: EdgeInsets.zero,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.ink,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: AppColors.subText,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'あなた専用の交換コード',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.subText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(child: Tape(color: AppColors.lavender)),
              ),
              const Positioned(right: -8, bottom: 8, child: Flower(size: 40)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: '友だちのQRコードを読み取る',
          icon: Icons.qr_code_scanner,
          onPressed: onRead,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LinkAction(
              icon: Icons.link,
              label: 'リンクで送る',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(
                  ClipboardData(text: exchangeLink(token)),
                );
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('リンクをコピーしました')),
                  );
              },
            ),
            _LinkAction(
              icon: Icons.download_outlined,
              label: '画像を保存',
              onTap: () => showComingSoon(context, '画像の保存'),
            ),
            _LinkAction(
              icon: Icons.refresh,
              label: '再発行',
              onTap: () {
                ref.read(exchangeTokenProvider.notifier).rotate();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('コードを再発行しました')),
                  );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'コードは交換したい相手にだけ見せてね。\n'
          '相手が承認すると、お互いのプロフィール帳を見られるようになります。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            height: 1.8,
            color: AppColors.subText,
          ),
        ),
      ],
    );
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.accent,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 15),
    label: Text(label),
  );
}

class _ReadCodeView extends StatefulWidget {
  const _ReadCodeView();

  @override
  State<_ReadCodeView> createState() => _ReadCodeViewState();
}

class _ReadCodeViewState extends State<_ReadCodeView> {
  bool _handling = false;

  Future<void> _openConfirm(String? token) async {
    if (_handling) return;
    _handling = true;
    await context.push(
      Uri(
        path: '/exchange/confirm',
        queryParameters: {'token': ?token},
      ).toString(),
    );
    _handling = false;
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw != null) _openConfirm(parseExchangeToken(raw) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    // 別のタブや確認画面の裏にいるときはカメラを止める。
    final active = TickerMode.valuesOf(context).enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Let's exchange!",
          textAlign: TextAlign.center,
          style: serifItalic(size: 12),
        ),
        const SizedBox(height: 4),
        const Text(
          '友だちのコードを読み取ろう。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: AppColors.ink,
              child: active
                  ? MobileScanner(onDetect: _onDetect)
                  : const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '読み取っただけでは、まだ交換されません。\n次の画面で相手を確認できます。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            height: 1.8,
            color: AppColors.subText,
          ),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _openConfirm(demoFriendToken),
            child: const Text('サンプルのコードで試す（開発用）'),
          ),
        ],
      ],
    );
  }
}

class ExchangeConfirmScreen extends ConsumerWidget {
  const ExchangeConfirmScreen({super.key, required this.token});

  final String? token;

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/exchange');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = previewByToken(token);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            PageHeader(
              title: 'プロフィール帳の追加',
              onBack: () => _close(context),
            ),
            if (profile == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Text(
                  'このコードは使えません。\n相手に新しいコードを見せてもらってください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.8,
                    color: AppColors.subText,
                  ),
                ),
              )
            else
              ..._content(context, profile),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, Profile profile) => [
    const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, size: 15, color: AppColors.accent),
        SizedBox(width: 5),
        Text(
          'QRコードを読み取りました',
          style: TextStyle(fontSize: 11, color: AppColors.accent),
        ),
      ],
    ),
    const SizedBox(height: 4),
    const Text(
      'このプロフィール帳を追加する？',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 4),
    const Text(
      '相手を確認してから、追加してね。',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: AppColors.subText),
    ),
    const SizedBox(height: 14),
    ProfileBookCard(
      profile: profile,
      showHobby: false,
      headlineOnly: true,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '追加前',
          style: TextStyle(fontSize: 9, color: AppColors.subText),
        ),
      ),
    ),
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 15, color: AppColors.subText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'お互いに承認すると、プロフィール帳を交換します。\n'
              'あなたのプロフィール帳も、${profile.nickname}さんに届きます。',
              style: const TextStyle(
                fontSize: 10,
                height: 1.8,
                color: AppColors.subText,
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    PrimaryButton(
      label: '承認してプロフィール帳を追加',
      icon: Icons.note_add_outlined,
      onPressed: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('申請を送りました。相手の承認を待っています。')),
          );
        // 交換タブに戻ったときに確認画面が残らないよう、閉じてから移動する。
        _close(context);
        context.go('/friends');
      },
    ),
    const SizedBox(height: 8),
    SecondaryButton(label: 'キャンセル', onPressed: () => _close(context)),
    const SizedBox(height: 10),
    const Text(
      'まだ追加・交換はされていません',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10, color: AppColors.subText),
    ),
  ];
}
