import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'data/exchange.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('① Flutter起動開始');

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  debugPrint('② Supabase初期化完了');

  runApp(const ProviderScope(child: App()));

  debugPrint('③ runApp実行完了');
}

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // どの画面にいても、自分が送った申請で交換が成立したら知らせる。
    ref.listen(acceptedExchangesProvider, (_, next) {
      final nickname = next.value;
      if (nickname == null) return;
      _messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$nicknameさんとプロフィール帳を交換しました')),
        );
    });

    return MaterialApp.router(
      scaffoldMessengerKey: _messengerKey,
      title: 'prome',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // スクロールのオーバースクロールの挙動を無効化する。
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
          child: child!,
        );
      },
      // 端末の言語によらず、日本語の字形で表示する。
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: appRouter,
    );
  }
}
