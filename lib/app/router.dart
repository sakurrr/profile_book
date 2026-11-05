import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth_screens.dart';
import '../screens/exchange_screens.dart';
import '../screens/friends_screens.dart';
import '../screens/my_profile_screen.dart';
import 'theme.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => _TabShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/friends',
              builder: (_, _) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => FriendDetailScreen(
                    friendId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/exchange',
              builder: (_, _) => const ExchangeScreen(),
              routes: [
                GoRoute(
                  path: 'confirm',
                  builder: (_, state) => ExchangeConfirmScreen(
                    token: state.uri.queryParameters['token'],
                  ),
                ),
                GoRoute(
                  path: 'requests/:id',
                  builder: (_, state) => ExchangeRequestScreen(
                    requestId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/mypage',
              builder: (_, _) => const MyProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (icon: Icons.menu_book_outlined, label: 'ともだち'),
      (icon: Icons.qr_code_scanner, label: '交換する'),
      (icon: Icons.person_outline, label: 'マイページ'),
    ];
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                for (final (index, tab) in tabs.indexed)
                  Expanded(
                    child: InkWell(
                      // 選択中のタブを押すと、そのタブの最初の画面に戻る。
                      onTap: () => shell.goBranch(
                        index,
                        initialLocation: index == shell.currentIndex,
                      ),
                      child: _TabItem(
                        icon: tab.icon,
                        label: tab.label,
                        selected: index == shell.currentIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.subText;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 23, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
