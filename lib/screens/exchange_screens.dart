import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/theme.dart';
import '../data/exchange.dart';
import '../data/friends.dart';
import '../data/my_profile.dart';
import '../widgets/common.dart';

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 確認画面や交換リクエストを閉じる。直接開いた場合は交換画面に戻る。
void _closePage(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/exchange');
  }
}

class ExchangeScreen extends ConsumerStatefulWidget {
  const ExchangeScreen({super.key});

  @override
  ConsumerState<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends ConsumerState<ExchangeScreen> {
  bool _reading = false;

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('交換のしかた', style: TextStyle(fontSize: 16)),
        content: const Text(
          '相手のコードを読み取って申請し、相手が承認すると交換が成立します。\n'
          '交換するまでは、呼び名と表示用IDしか相手に見えません。',
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
    // コードを見せている間に申請が届いたら、その場で交換リクエストを開く。
    final active = TickerMode.valuesOf(context).enabled;
    ref.listen(incomingRequestsProvider, (previous, next) {
      // 最初の読み込みで取れた申請は、届いたばかりとは扱わない。
      final before = previous?.value;
      final after = next.value;
      if (_reading || !active || before == null || after == null) return;
      final known = {for (final r in before) r.id};
      final arrived = after.where((r) => !known.contains(r.id)).firstOrNull;
      if (arrived != null) context.push('/exchange/requests/${arrived.id}');
    });

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

  Future<void> _rotate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QRを再発行する？', style: TextStyle(fontSize: 16)),
        content: const Text(
          '今のQRコードは使えなくなります。\n'
          '写真などでコードが広まってしまったときに使ってね。',
          style: TextStyle(fontSize: 13, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('再発行する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(myExchangeTokenProvider.notifier).rotate();
      if (context.mounted) _showMessage(context, 'QRを再発行しました');
    } catch (error) {
      if (context.mounted) _showMessage(context, exchangeErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final token = ref.watch(myExchangeTokenProvider);
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
                    if (profile != null)
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
                              Text(
                                profile.publicIdLabel,
                                style: serif(size: 9, color: AppColors.subText),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    SizedBox.square(
                      dimension: 180,
                      child: switch (token) {
                        AsyncData(:final value) => QrImageView(
                          data: exchangeQrData(value),
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
                        AsyncError() => Center(
                          child: TextButton(
                            onPressed: () =>
                                ref.invalidate(myExchangeTokenProvider),
                            child: const Text(
                              'QRを表示できませんでした\n再読み込み',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        _ => const Center(child: CircularProgressIndicator()),
                      },
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
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () => _rotate(context, ref),
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('QRを再発行'),
          ),
        ),
        const SizedBox(height: 6),
        PrimaryButton(
          label: '友だちのQRコードを読み取る',
          icon: Icons.qr_code_scanner,
          onPressed: onRead,
        ),
        const SizedBox(height: 12),
        const Text(
          'コードは交換したい相手にだけ見せてね。\n'
          'お互いに確認してから、プロフィール帳が届きます。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, height: 1.8, color: AppColors.subText),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          TextButton(
            // シミュレーターはカメラを使えないので、コードを文字で渡して試す。
            onPressed: token.value == null
                ? null
                : () {
                    Clipboard.setData(
                      ClipboardData(text: exchangeQrData(token.value!)),
                    );
                    _showMessage(context, 'コードをコピーしました（開発用）');
                  },
            child: const Text('コードをコピーする（開発用）'),
          ),
        ],
      ],
    );
  }
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
          style: TextStyle(fontSize: 10, height: 1.8, color: AppColors.subText),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          TextButton(
            // シミュレーターはカメラを使えないので、コピーしたコードで試す。
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              _openConfirm(parseExchangeToken(data?.text) ?? '');
            },
            child: const Text('コピーしたコードで試す（開発用）'),
          ),
        ],
      ],
    );
  }
}

/// RPCを呼ぶ間はボタンを押せなくし、失敗したら理由を表示する。
mixin _RpcRunner<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      _showMessage(context, exchangeErrorMessage(error));
      onRpcError();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// 失敗したときに、画面のデータを最新にする。
  void onRpcError() {}
}

class ExchangeConfirmScreen extends ConsumerStatefulWidget {
  const ExchangeConfirmScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ExchangeConfirmScreen> createState() =>
      _ExchangeConfirmScreenState();
}

class _ExchangeConfirmScreenState extends ConsumerState<ExchangeConfirmScreen>
    with _RpcRunner {
  @override
  void onRpcError() => ref.invalidate(exchangePreviewProvider(widget.token));

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(exchangePreviewProvider(widget.token));
    return _ExchangePage(
      title: 'プロフィール帳の追加',
      children: switch (preview) {
        AsyncData(value: null) => const [
          _Notice('このコードは使えません。\n相手に新しいコードを見せてもらってください。'),
        ],
        AsyncData(:final value?) when value.relation == ExchangeRelation.none =>
          _content(value.party),
        AsyncData(:final value?) => _status(value),
        AsyncError() => _loadError(
          () => ref.invalidate(exchangePreviewProvider(widget.token)),
        ),
        _ => const [_Loading()],
      },
    );
  }

  /// 申請できない相手のときに、理由と次の操作を表示する。
  List<Widget> _status(ExchangePreview preview) {
    final party = preview.party;
    return switch (preview.relation) {
      ExchangeRelation.self => const [
        _Notice('これはあなたのQRコードです。\n交換したい相手に読み取ってもらってね。'),
      ],
      ExchangeRelation.friend => [
        _Notice('${party.nickname}さんとは、もう交換しています。'),
        PrimaryButton(
          label: 'プロフィール帳を見る',
          icon: Icons.menu_book_outlined,
          onPressed: () {
            _closePage(context);
            context.go('/friends/${party.id}');
          },
        ),
      ],
      ExchangeRelation.pendingOutgoing => [
        _Notice('${party.nickname}さんの承認を待っています。'),
        SecondaryButton(
          label: '申請を取り消す',
          onPressed: busy
              ? null
              : () => run(() async {
                  await cancelExchange(preview.requestId!);
                  if (!mounted) return;
                  _showMessage(context, '申請を取り消しました');
                  _closePage(context);
                }),
        ),
      ],
      ExchangeRelation.pendingIncoming => [
        _Notice('${party.nickname}さんから、交換リクエストが届いています。'),
        PrimaryButton(
          label: 'リクエストを確認する',
          icon: Icons.mail_outline,
          onPressed: () => context.pushReplacement(
            '/exchange/requests/${preview.requestId}',
          ),
        ),
      ],
      ExchangeRelation.none => const [],
    };
  }

  List<Widget> _content(ExchangeParty party) => [
    const _StatusLine(icon: Icons.check_circle_outline, label: 'QRコードを読み取りました'),
    const SizedBox(height: 4),
    _Title('${party.nickname}さんと交換する？'),
    const SizedBox(height: 4),
    const _Lead('相手を確認してから、申請してね。'),
    const SizedBox(height: 14),
    _LockedProfileCard(party: party),
    const SizedBox(height: 14),
    _ConsentNote(
      'お互いに承認すると、プロフィール帳を交換します。\n'
      'あなたのプロフィール帳も、${party.nickname}さんに届きます。',
    ),
    const SizedBox(height: 12),
    PrimaryButton(
      label: '交換を申請する',
      icon: Icons.note_add_outlined,
      onPressed: busy
          ? null
          : () => run(() async {
              final accepted = await requestExchange(widget.token!);
              if (!mounted) return;
              if (accepted) ref.invalidate(friendsProvider);
              _showMessage(
                context,
                accepted
                    ? '${party.nickname}さんとプロフィール帳を交換しました'
                    : '申請を送りました。${party.nickname}さんの承認を待っています。',
              );
              // 交換タブに戻ったときに確認画面が残らないよう、閉じてから移動する。
              _closePage(context);
              context.go('/friends');
            }),
    ),
    const SizedBox(height: 8),
    SecondaryButton(label: 'キャンセル', onPressed: () => _closePage(context)),
    const SizedBox(height: 10),
    const _Footnote('まだ申請・交換はされていません'),
  ];
}

/// 届いた交換リクエストの一覧。ホームのベルから開く。
class ExchangeRequestListScreen extends ConsumerWidget {
  const ExchangeRequestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider);
    return _ExchangePage(
      title: '交換リクエスト',
      children: switch (requests) {
        AsyncData(value: []) => const [_NoRequests()],
        AsyncData(:final value) => [
          const SizedBox(height: 4),
          Text("You've got requests!", style: serifItalic(size: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                '届いたリクエスト',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                '${value.length}',
                style: serif(size: 16, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '相手を確認して、交換するか決めてね。',
            style: TextStyle(fontSize: 11, color: AppColors.subText),
          ),
          const SizedBox(height: 14),
          for (final request in value) ...[
            _RequestTile(
              request: request,
              onTap: () => context.push('/friends/requests/${request.id}'),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          const _Footnote('承認するまで、あなたのプロフィール帳は相手に見えません'),
        ],
        AsyncError() => _loadError(
          () => ref.invalidate(incomingRequestsProvider),
        ),
        _ => const [_Loading()],
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.onTap});

  final ExchangeRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: PaperCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      radius: 16,
      child: Row(
        children: [
          const _LockedAvatar(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.requester.nickname}さん',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  request.requester.publicIdLabel,
                  style: serif(size: 10, color: AppColors.subText),
                ),
              ],
            ),
          ),
          Text(
            _timeAgo(request.createdAt),
            style: const TextStyle(fontSize: 10, color: AppColors.hint),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.subText),
        ],
      ),
    ),
  );
}

String _timeAgo(DateTime time) {
  final elapsed = DateTime.now().difference(time);
  if (elapsed.inMinutes < 1) return 'たった今';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}分前';
  if (elapsed.inDays < 1) return '${elapsed.inHours}時間前';
  if (elapsed.inDays < 7) return '${elapsed.inDays}日前';
  return '${time.month}月${time.day}日';
}

class _NoRequests extends StatelessWidget {
  const _NoRequests();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: Flower(size: 48)),
        const SizedBox(height: 16),
        const Text(
          'まだ交換リクエストは届いていません',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'QRコードを見せて、友だちに読み取ってもらおう。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.subText),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'QRコードを見せる',
          icon: Icons.qr_code_2,
          onPressed: () => context.go('/exchange'),
        ),
      ],
    ),
  );
}

/// 自分宛ての申請を確認し、承認するか断る画面。
class ExchangeRequestScreen extends ConsumerStatefulWidget {
  const ExchangeRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ExchangeRequestScreen> createState() =>
      _ExchangeRequestScreenState();
}

class _ExchangeRequestScreenState extends ConsumerState<ExchangeRequestScreen>
    with _RpcRunner {
  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(incomingRequestsProvider);
    final request = requests.value
        ?.where((r) => r.id == widget.requestId)
        .firstOrNull;
    return _ExchangePage(
      title: '交換リクエスト',
      children: switch (requests) {
        _ when request != null => _content(request.requester),
        AsyncData() => const [_Notice('このリクエストは、もう届いていません。')],
        AsyncError() => _loadError(
          () => ref.invalidate(incomingRequestsProvider),
        ),
        _ => const [_Loading()],
      },
    );
  }

  /// 承認しても断っても元の画面に戻る。一覧から開いた場合は、残りの申請を続けて見られる。
  Future<void> _respond(ExchangeParty party, {required bool accept}) =>
      run(() async {
        await ref
            .read(incomingRequestsProvider.notifier)
            .respond(widget.requestId, accept: accept);
        if (!mounted) return;
        // 承認したら、ともだちの帳に新しい友だちを取り込む。
        if (accept) ref.invalidate(friendsProvider);
        _showMessage(
          context,
          accept ? '${party.nickname}さんとプロフィール帳を交換しました' : 'リクエストを断りました',
        );
        _closePage(context);
      });

  List<Widget> _content(ExchangeParty party) => [
    const _StatusLine(icon: Icons.mail_outline, label: '交換リクエストが届きました'),
    const SizedBox(height: 4),
    _Title('${party.nickname}さんと交換する？'),
    const SizedBox(height: 4),
    const _Lead('あなたのQRコードを読み取った相手です。'),
    const SizedBox(height: 14),
    _LockedProfileCard(party: party, caption: '交換リクエストの送り主'),
    const SizedBox(height: 14),
    _ConsentNote(
      '承認すると、お互いのプロフィール帳を交換します。\n'
      'あなたのプロフィール帳も、${party.nickname}さんに共有されます。',
    ),
    const SizedBox(height: 12),
    PrimaryButton(
      label: '承認してプロフィール帳を交換',
      icon: Icons.note_add_outlined,
      onPressed: busy ? null : () => _respond(party, accept: true),
    ),
    const SizedBox(height: 8),
    SecondaryButton(
      label: '今回は断る',
      onPressed: busy ? null : () => _respond(party, accept: false),
    ),
    const SizedBox(height: 10),
    const _Footnote('承認するまで、プロフィール帳は共有されません'),
  ];
}

List<Widget> _loadError(VoidCallback onRetry) => [
  const _Notice('読み込めませんでした。\n通信状況を確認してください。'),
  SecondaryButton(label: 'もう一度読み込む', onPressed: onRetry),
];

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 80),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// 確認画面と交換リクエストで共通の、ヘッダー付きの縦スクロール画面。
class _ExchangePage extends StatelessWidget {
  const _ExchangePage({
    required this.title,
    required this.children,
    this.onBack,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          PageHeader(title: title, onBack: onBack ?? () => _closePage(context)),
          ...children,
        ],
      ),
    ),
  );
}

/// 交換前の相手のアバターの代わり。顔は交換するまで見せない。
class _LockedAvatar extends StatelessWidget {
  const _LockedAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.ring,
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.lock_outline, size: size * 0.3, color: AppColors.subText),
  );
}

/// 交換前の相手のカード。呼び名と表示用IDだけを見せる。
class _LockedProfileCard extends StatelessWidget {
  const _LockedProfileCard({required this.party, this.caption});

  final ExchangeParty party;
  final String? caption;

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                    children: [
                      Expanded(
                        child: Text(
                          '${party.nickname}のプロフィール帳',
                          overflow: TextOverflow.ellipsis,
                          style: serifItalic(size: 15, color: AppColors.ink),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '交換前',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.subText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const _LockedAvatar(size: 72),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              party.nickname,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              party.publicIdLabel,
                              style: serif(size: 11, color: AppColors.subText),
                            ),
                            if (caption != null)
                              Text(
                                caption!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.subText,
                                ),
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
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(Icons.lock_outline, size: 15, color: AppColors.subText),
                SizedBox(height: 6),
                Text(
                  '交換するまで、相手のプロフィールは見えません',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.subText),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 15, color: AppColors.accent),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.accent),
      ),
    ],
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
  );
}

class _Lead extends StatelessWidget {
  const _Lead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 11, color: AppColors.subText),
  );
}

class _ConsentNote extends StatelessWidget {
  const _ConsentNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
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
            text,
            style: const TextStyle(
              fontSize: 11,
              height: 1.8,
              color: AppColors.subText,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 10, color: AppColors.subText),
  );
}

/// 申請できないときや、リクエストがないときの案内。
class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 13,
        height: 1.8,
        color: AppColors.subText,
      ),
    ),
  );
}
