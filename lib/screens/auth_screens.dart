import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/theme.dart';
import '../widgets/common.dart';

final supabase = Supabase.instance.client;

//ログイン画面
//stateで情報を保持
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreen();
}

class _LoginScreen extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String email = '';
  String password = '';
  bool sucsess = true; //ログイン認証成功(true)or失敗(false)
  bool push1 = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      banner: const HeroBanner(
        eyebrow: 'Welcome back!',
        title: 'おかえりなさい。',
        caption: 'ともだちとのつづき、\n今日もここから。',
        color: AppColors.pink,
      ),
      tapeColor: AppColors.lavender,
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(number: '01', title: 'ログイン'),
          const SizedBox(height: 16),
          const FieldLabel('メールアドレス'),
          _EmailField(hint: '登録したメールアドレス', controller: emailController),
          const SizedBox(height: 14),
          const FieldLabel('パスワード'),
          _PasswordField(hint: 'パスワードを入力', controller: passwordController),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                textStyle: const TextStyle(fontSize: 11),
              ),
              onPressed: () => showComingSoon(context, 'パスワードの再設定'),
              child: const Text('パスワードを忘れた方'),
            ),
          ),
          PrimaryButton(
            label: 'ログインする',
            //ここで，入力情報をバックエンドの「ログイン処理を行うAPI」をたたくと同時に渡したい

            onPressed: () async {
              //1.入力されたメールアドレスとパスワードを取得

              email = emailController.text;
              password = passwordController.text;
              push1 = true;

              //2.バックエンドの認証APIをたたく
              try {
                // ② Supabaseでログイン認証
                final res = await Supabase.instance.client.auth
                    .signInWithPassword(email: email, password: password);
                // 非同期処理中に画面が破棄された場合の対策
                if (!mounted) return;
                //認証成功
                if (res.user != null) {
                  setState(() {
                    sucsess = true;
                  });
                  if (!context.mounted) return;
                  context.go('/friends');
                }
              } on AuthException catch (e) {
                //Supabaseで認証失敗
                if (!mounted) return;
                setState(() {
                  sucsess = false;
                });
                debugPrint('ログインエラー: ${e.message}');
              } catch (e) {
                // その他の予期しないエラー
                if (!mounted) return;
                debugPrint('予期しないエラー: $e');
              }
            },
          ),
          if (!sucsess && push1)
            Text(
              'メールアドレスまたはパスワードが間違っています',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: const Color.fromARGB(255, 236, 14, 14),
              ),
            ),
          //Text('email: $email , password: $password'),//デバック用
        ],
      ),
      below: [
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'はじめての方はこちら',
                style: TextStyle(fontSize: 10, color: AppColors.subText),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: '新しくアカウントを作成',
          color: AppColors.accent,
          onPressed: () =>
              context.push('/signup'), //画面遷移（現在のページにあたら行くページを積み重ねる，戻れる）
        ),
        const SizedBox(height: 16),
        const Text(
          'あなただけのプロフィール帳を、無料ではじめよう。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppColors.subText),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 13, color: AppColors.subText),
            SizedBox(width: 6),
            Text(
              'メールアドレスは友だちに公開されません',
              style: TextStyle(fontSize: 10, color: AppColors.subText),
            ),
          ],
        ),
      ],
    );
  }
}

//バリデーション
abstract class Validator<T> {
  bool validate(T value);

  String getMessage();
}

class RequiredValidator implements Validator<String?> {
  @override
  bool validate(String? value) {
    if (value == null) {
      return false;
    }

    return value.trim().isNotEmpty;
  }

  @override
  String getMessage() => '必須項目です';
}

//アカウント作成画面
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreen();
}

class _SignupScreen extends State<SignupScreen> {
  /// 半角英字と数字を両方含む、半角8文字以上。
  static final _passwordPattern = RegExp(
    r'^(?=.*[A-Za-z])(?=.*[0-9])[\x21-\x7E]{8,}$',
  );

  final familyNameController = TextEditingController();
  final givenNameController = TextEditingController();
  final familyNameKanaController = TextEditingController();
  final givenNameKanaController = TextEditingController();
  final nicknameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  /// 欄ごとのエラー。送信するまでは表示しない。
  Map<TextEditingController, String> errors = {};
  String? submitError;
  bool sending = false;

  @override
  void dispose() {
    for (final controller in [
      familyNameController,
      givenNameController,
      familyNameKanaController,
      givenNameKanaController,
      nicknameController,
      emailController,
      passwordController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  //バリデーション。必須の欄が空白のみでないことと、パスワードの形式を確かめる
  Map<TextEditingController, String> validate() {
    final required = RequiredValidator();
    final result = {
      for (final controller in [
        familyNameController,
        givenNameController,
        familyNameKanaController,
        givenNameKanaController,
        nicknameController,
        emailController,
        passwordController,
      ])
        if (!required.validate(controller.text))
          controller: required.getMessage(),
    };
    if (!result.containsKey(passwordController) &&
        !_passwordPattern.hasMatch(passwordController.text)) {
      result[passwordController] = '半角英字と数字を含む8文字以上にしてください';
    }
    return result;
  }

  /// Supabase Auth のエラーを、画面に表示する文言にする。
  String signupErrorMessage(AuthException error) => switch (error) {
    AuthWeakPasswordException() => 'パスワードは半角英字と数字を含む8文字以上にしてください',
    AuthException(code: 'user_already_exists' || 'email_exists') =>
      'このメールアドレスはすでに登録されています',
    AuthException(code: 'email_address_invalid' || 'validation_failed') =>
      'メールアドレスの形式が正しくありません',
    AuthException(
      code: 'over_request_rate_limit' || 'over_email_send_rate_limit',
    ) =>
      '時間をおいて、もう一度お試しください',
    _ => '登録に失敗しました。もう一度お試しください。',
  };

  Future<void> submit() async {
    final result = validate();
    setState(() {
      errors = result;
      submitError = null;
    });
    if (result.isNotEmpty) return;

    setState(() => sending = true);
    try {
      // アカウント登録。姓、名、せい、めい、ニックネームはトリガーで profiles に保存される
      await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        data: {
          'family_name': familyNameController.text.trim(),
          'given_name': givenNameController.text.trim(),
          'family_name_kana': familyNameKanaController.text.trim(),
          'given_name_kana': givenNameKanaController.text.trim(),
          'nickname': nicknameController.text.trim(),
        },
      );
      if (!mounted) return;
      context.go('/login'); //画面遷移
    } on AuthException catch (e) {
      if (!mounted) return;
      debugPrint('アカウント作成エラー: $e');
      setState(() => submitError = signupErrorMessage(e));
    } catch (e) {
      // その他の予期しないエラー
      if (!mounted) return;
      debugPrint('予期しないエラー: $e');
      setState(() => submitError = '通信に失敗しました。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget _textField(TextEditingController controller, String hint) => TextField(
    controller: controller,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(hintText: hint, errorText: errors[controller]),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [FieldLabel(label), _textField(controller, hint)],
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      banner: const HeroBanner(
        eyebrow: 'Nice to meet you!',
        title: 'わたしらしさを、一冊に。',
        caption: '「すき」から、つながりをはじめよう。',
        color: AppColors.lavender,
      ),
      tapeColor: AppColors.mint,
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(number: '01', title: 'アカウント作成'),
          const SizedBox(height: 16),
          _namePair(
            ('姓', familyNameController, '例：佐藤'),
            ('名', givenNameController, '例：みお'),
          ),
          const SizedBox(height: 14),
          _namePair(
            ('せい', familyNameKanaController, '例：さとう'),
            ('めい', givenNameKanaController, '例：みお'),
          ),
          const SizedBox(height: 14),
          const FieldLabel('ニックネーム'),
          _textField(nicknameController, '例：みお'),
          const SizedBox(height: 6),
          const Text(
            '交換する前の相手には、ニックネームだけが表示されます',
            style: TextStyle(fontSize: 10, color: AppColors.subText),
          ),
          const SizedBox(height: 14),
          const FieldLabel('メールアドレス'),
          _EmailField(
            hint: '例：mio@example.com',
            controller: emailController,
            errorText: errors[emailController],
          ),
          const SizedBox(height: 14),
          const FieldLabel('パスワード'),
          _PasswordField(
            hint: 'パスワードを設定',
            controller: passwordController,
            errorText: errors[passwordController],
          ),
          const SizedBox(height: 8),
          const Text(
            '半角英字と数字を含む8文字以上',
            style: TextStyle(fontSize: 10, color: AppColors.subText),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'アカウントを作成する',
            onPressed: sending ? null : submit,
          ),
          if (submitError != null) ...[
            const SizedBox(height: 8),
            Text(
              submitError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Color.fromARGB(255, 236, 14, 14),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            '登録後、メールアドレスの確認に進みます。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.subText),
          ),
        ],
      ),
      below: [
        const SizedBox(height: 22),
        const Text(
          'すでにアカウントをお持ちの方',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.subText),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: () => context.pop(),
          child: const Text('ログインする'),
        ),
      ],
    );
  }
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.banner,
    required this.tapeColor,
    required this.card,
    required this.below,
  });

  final Widget banner;
  final Color tapeColor;
  final Widget card;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandHeader(
                  trailing: Text(
                    'プロフィール帳交換アプリ',
                    style: TextStyle(fontSize: 9, color: AppColors.subText),
                  ),
                ),
                const SizedBox(height: 4),
                banner,
                const SizedBox(height: 24),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PaperCard(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                      child: card,
                    ),
                    Positioned(
                      top: -8,
                      right: 44,
                      child: Tape(color: tapeColor),
                    ),
                  ],
                ),
                ...below,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.hint,
    required this.controller,
    this.errorText,
  });

  final String hint;
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.emailAddress,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(hintText: hint, errorText: errorText),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.hint,
    required this.controller,
    this.errorText,
  });

  final String hint;
  final TextEditingController controller;
  final String? errorText;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: _obscured,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(
      hintText: widget.hint,
      errorText: widget.errorText,
      suffixIcon: IconButton(
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: AppColors.subText,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    ),
  );
}
