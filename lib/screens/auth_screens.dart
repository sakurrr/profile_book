import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../widgets/common.dart';

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

            //1.入力されたメールアドレスとパスワードを取得
            //2.バックエンドの認証APIをたたく
            //3.認証が成功したら画面遷移
            //4.認証失敗ならエラー表示
            onPressed: () {
              setState(() {
                email = emailController.text;
                password = passwordController.text;
              });

              //context.go('/friends'); //画面遷移(目的のページに直接ジャンプ，戻れない)
            },
          ),
          Text('email: $email , password: $password'),
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
        const Row(
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

//アカウント作成画面
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreen();
}

class _SignupScreen extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String name = '';
  String email = '';
  String password = '';
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

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
          const FieldLabel('呼んでほしい名前'),
          TextField(
            style: TextStyle(fontSize: 14),
            decoration: InputDecoration(hintText: '例：みお'),
            controller: nameController,
          ),
          const SizedBox(height: 14),
          const FieldLabel('メールアドレス'),
          _EmailField(hint: '例：mio@example.com', controller: emailController),
          const SizedBox(height: 14),
          const FieldLabel('パスワード'),
          _PasswordField(hint: 'パスワードを設定', controller: passwordController),
          const SizedBox(height: 8),
          const Text(
            '半角英字と数字を含む8文字以上',
            style: TextStyle(fontSize: 10, color: AppColors.subText),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'アカウントを作成する',
            //アカウント作成APIをたたく．入力された値をバックエンドに渡す．バックエンド側でDBへ登録
            //アカウント作成が成功したらそのままログイン画面？？
            onPressed: () {
              setState(() {
                name = nameController.text;
                email = emailController.text;
                password = passwordController.text;
              });
              //context.go('/friends');//画面遷移
            },
          ),
          Text('name: $name, email: $email, password: $password'),
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
  const _EmailField({required this.hint, required this.controller});

  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.emailAddress,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(hintText: hint),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.hint, required this.controller});

  final String hint;
  final TextEditingController controller;

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
