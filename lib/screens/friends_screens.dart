import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/theme.dart';
import '../data/exchange.dart';
import '../data/friends.dart';
import '../data/mock_data.dart';
import '../data/my_profile.dart';
import '../widgets/common.dart';

/// 友だち一覧の並び替えの方法
enum _FriendSort {
  exchangedAt,

  ///交換した順
  name,

  ///名前順
  birthday,

  ///誕生日順
}

const _saveErrorMessage = '保存に失敗しました。もう一度お試しください。';

/// お気に入りを切り替え、保存に失敗したら知らせる。
Future<void> _toggleFavorite(
  BuildContext context,
  WidgetRef ref,
  String friendId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(friendsProvider.notifier).toggleFavorite(friendId);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text(_saveErrorMessage)));
  }
}

/// 一覧を読み込めなかったときの表示。
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        const Text(
          'ともだちのプロフィールを読み込めませんでした',
          style: TextStyle(fontSize: 12, color: AppColors.subText),
        ),
        TextButton(onPressed: onRetry, child: const Text('もう一度読み込む')),
      ],
    ),
  );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        content: const Text('ログイン画面に戻ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログアウトに失敗しました。もう一度お試しください。')),
      );
    }
  }

  String _query = '';
  bool _favoritesOnly = false;

  _FriendSort _sort = _FriendSort.exchangedAt;
  String get _sortLabel {
    switch (_sort) {
      case _FriendSort.exchangedAt:
        return '交換した順';
      case _FriendSort.name:
        return '名前順';
      case _FriendSort.birthday:
        return '誕生日順';
    }
  }

  bool _matches(Friend friend) {
    if (_favoritesOnly && !friend.isFavorite) return false;
    final profile = friend.profile;
    return [
      profile.displayName,
      profile.nickname,
      ...?profile.likes,
    ].any((text) => text.contains(_query));
  }

  void _sortFriends(List<Friend> friends) {
    friends.sort((a, b) {
      switch (_sort) {
        case _FriendSort.exchangedAt:
          return b.exchangedAt.compareTo(a.exchangedAt);
        case _FriendSort.name:
          final kanaA = a.profile.nameKana?.trim() ?? '';
          final kanaB = b.profile.nameKana?.trim() ?? '';
          if (kanaA.isEmpty && kanaB.isNotEmpty) return 1;
          if (kanaA.isNotEmpty && kanaB.isEmpty) return -1;
          final result = kanaA.compareTo(kanaB);
          if (result != 0) return result;
          final nameResult = a.profile.displayName.compareTo(
            b.profile.displayName,
          );
          if (nameResult != 0) return nameResult;
          return a.exchangedAt.compareTo(b.exchangedAt);

        case _FriendSort.birthday:
          final aMonth = a.profile.birthMonth;
          final aDay = a.profile.birthDay;
          final bMonth = b.profile.birthMonth;
          final bDay = b.profile.birthDay;

          final aHasBirthday = aMonth != null && aDay != null;
          final bHasBirthday = bMonth != null && bDay != null;

          if (!aHasBirthday && !bHasBirthday) {
            return a.profile.displayName.compareTo(b.profile.displayName);
          } //両方誕生日が登録されていない時は名前順で表示する

          if (!aHasBirthday) return 1;
          if (!bHasBirthday) return -1;

          // 誕生月を比較する
          final monthCompare = aMonth.compareTo(bMonth);
          if (monthCompare != 0) return monthCompare;
          //  誕生日を比較する
          final dayCompare = aDay.compareTo(bDay);
          if (dayCompare != 0) return dayCompare;

          // 誕生日が同じ場合は名前順で表示する
          return a.profile.displayName.compareTo(b.profile.displayName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsProvider);
    final friends = friendsState.value ?? const <Friend>[];
    final nickname = ref.watch(myProfileProvider).value?.nickname;
    final favorites = friends.where((f) => f.isFavorite).length;
    final visible = friends.where(_matches).toList();
    _sortFriends(visible);
    final incoming = ref.watch(incomingRequestsProvider).value ?? const [];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            BrandHeader(
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge.count(
                    count: incoming.length,
                    isLabelVisible: incoming.isNotEmpty,
                    backgroundColor: AppColors.accent,
                    child: CircleIconButton(
                      icon: Icons.notifications_none,
                      onPressed: () => context.push('/friends/requests'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: Icons.logout,
                    onPressed: _confirmLogout,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
            HeroBanner(
              eyebrow: nickname == null ? 'おかえりなさい' : '$nicknameさん、おかえりなさい',
              eyebrowIsSerif: false,
              title: '「すき」で、\nもっとなかよく。',
              caption: '友だちのこと、またひとつ知ろう。',
              color: AppColors.pink,
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: '名前や好きなもので検索',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'ともだちのプロフィール',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${friends.length}',
                  style: serif(size: 16, color: AppColors.accent),
                ),
                const Spacer(),

                PopupMenuButton<_FriendSort>(
                  initialValue: _sort,
                  onSelected: (value) {
                    setState(() {
                      _sort = value;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _FriendSort.exchangedAt,
                      child: Text('交換した順'),
                    ),
                    const PopupMenuItem(
                      value: _FriendSort.name,
                      child: Text('名前順'),
                    ),
                    const PopupMenuItem(
                      value: _FriendSort.birthday,
                      child: Text('誕生日順'),
                    ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sortLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.subText,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.sort,
                        size: 16,
                        color: AppColors.subText,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                _FilterChip(
                  label: 'すべて  ${friends.length}',
                  selected: !_favoritesOnly,
                  onTap: () => setState(() => _favoritesOnly = false),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'お気に入り  $favorites',
                  selected: _favoritesOnly,
                  onTap: () => setState(() => _favoritesOnly = true),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!friendsState.hasValue && friendsState.hasError)
              _LoadError(onRetry: () => ref.invalidate(friendsProvider))
            else if (!friendsState.hasValue)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  '見つかりませんでした',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.subText),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 13,
                  mainAxisSpacing: 13,
                  mainAxisExtent: 165,
                ),
                itemBuilder: (context, index) =>
                    _FriendCard(friend: visible[index], index: index),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.ink : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: selected ? Colors.white : AppColors.subText,
        ),
      ),
    ),
  );
}

class _FriendCard extends ConsumerWidget {
  const _FriendCard({required this.friend, required this.index});

  static const _colors = [
    AppColors.lavender,
    AppColors.blue,
    AppColors.yellow,
    AppColors.mint,
  ];

  final Friend friend;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = friend.profile;
    final like = profile.likes?.firstOrNull;
    return GestureDetector(
      onTap: () => context.push('/friends/${profile.id}'),
      child: PaperCard(
        padding: const EdgeInsets.all(13),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: friend.isNew
                  ? Text('new!', style: serifItalic(size: 12))
                  : GestureDetector(
                      onTap: () => _toggleFavorite(context, ref, profile.id),
                      child: Icon(
                        friend.isFavorite
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        size: 18,
                        color: friend.isFavorite
                            ? AppColors.accent
                            : AppColors.subText,
                      ),
                    ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(profile: profile),
                const SizedBox(height: 7),
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.messageHeadline ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.subText,
                  ),
                ),
                const SizedBox(height: 7),
                if (like != null)
                  LikeTag(label: like, color: _colors[index % _colors.length]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FriendDetailScreen extends ConsumerStatefulWidget {
  const FriendDetailScreen({super.key, required this.friendId});

  final String friendId;

  @override
  ConsumerState<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends ConsumerState<FriendDetailScreen> {
  final _memo = TextEditingController();
  bool _opened = false;

  Friend? _find(List<Friend>? friends) => friends
      ?.where((friend) => friend.profile.id == widget.friendId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    // 一覧の読み込みが終わってから開いた場合も、最初に表示した時点で1回だけ行う。
    ref.listenManual(friendsProvider, (_, next) {
      final friend = _find(next.value);
      if (friend == null || _opened) return;
      _opened = true;
      _memo.text = friend.memo ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(friendsProvider.notifier).markViewed(widget.friendId);
        }
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/friends');
    }
  }

  Future<void> _confirmRemove(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('友だちを解除しますか？', style: TextStyle(fontSize: 16)),
        content: Text(
          '${friend.profile.nickname}さんのプロフィールからも、あなたのプロフィール帳が消えます。メモも削除されます。',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final friends = ref.read(friendsProvider.notifier);
    _close();
    try {
      await friends.remove(widget.friendId);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('友だちを解除できませんでした。もう一度お試しください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsProvider);
    final friend = _find(friendsState.value);
    if (friend == null) {
      return Scaffold(
        body: switch (friendsState) {
          _ when friendsState.hasValue => const SizedBox.shrink(),
          AsyncError() => SafeArea(
            child: _LoadError(onRetry: () => ref.invalidate(friendsProvider)),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      );
    }
    final date = friend.exchangedAt;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            PageHeader(
              title: 'ともだちのプロフィール帳',
              onBack: _close,
              trailing: MenuAnchor(
                builder: (context, controller, _) => CircleIconButton(
                  icon: Icons.more_horiz,
                  onPressed: controller.open,
                ),
                menuChildren: [
                  MenuItemButton(
                    onPressed: () => _confirmRemove(friend),
                    child: const Text('友だちを解除'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ProfileBookCard(
              profile: friend.profile,
              trailing: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _toggleFavorite(context, ref, friend.profile.id),
                  child: SizedBox.square(
                    dimension: 30,
                    child: Icon(
                      friend.isFavorite
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              footer: Row(
                children: [
                  const Icon(
                    Icons.swap_horiz,
                    size: 14,
                    color: AppColors.subText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${date.year}.${date.month}.${date.day} に交換したプロフィール帳',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.subText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.edit_outlined, size: 13, color: AppColors.subText),
                SizedBox(width: 5),
                Text(
                  '自分だけのメモ',
                  style: TextStyle(fontSize: 10, color: AppColors.subText),
                ),
                Spacer(),
                Text(
                  '相手には見えません',
                  style: TextStyle(fontSize: 9, color: AppColors.subText),
                ),
              ],
            ),
            TextField(
              controller: _memo,
              onChanged: (value) => ref
                  .read(friendsProvider.notifier)
                  .updateMemo(friend.profile.id, value),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                filled: false,
                hintText: 'メモを残す',
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
