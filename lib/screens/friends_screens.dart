import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  bool _favoritesOnly = false;

  bool _matches(Friend friend) {
    if (_favoritesOnly && !friend.isFavorite) return false;
    final profile = friend.profile;
    return [
      profile.displayName,
      profile.nickname,
      ...?profile.likes,
    ].any((text) => text.contains(_query));
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final nickname = ref.watch(myProfileProvider).nickname;
    final favorites = friends.where((f) => f.isFavorite).length;
    final visible = friends.where(_matches).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            BrandHeader(
              trailing: CircleIconButton(
                icon: Icons.notifications_none,
                onPressed: () => showComingSoon(context, '届いた申請の画面'),
              ),
            ),
            const SizedBox(height: 4),
            HeroBanner(
              eyebrow: '$nicknameさん、おかえりなさい',
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
                  'ともだちの帳',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${friends.length}',
                  style: serif(size: 16, color: AppColors.accent),
                ),
                const Spacer(),
                const Text(
                  '交換した順',
                  style: TextStyle(fontSize: 10, color: AppColors.subText),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.sort, size: 16),
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
            if (visible.isEmpty)
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
                      onTap: () => ref
                          .read(friendsProvider.notifier)
                          .toggleFavorite(profile.id),
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
  late final TextEditingController _memo;

  Friend? _find(List<Friend> friends) => friends
      .where((friend) => friend.profile.id == widget.friendId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _memo = TextEditingController(
      text: _find(ref.read(friendsProvider))?.memo,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(friendsProvider.notifier).markViewed(widget.friendId);
      }
    });
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
          '${friend.profile.nickname}さんの帳からも、あなたのプロフィール帳が消えます。メモも削除されます。',
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
    _close();
    ref.read(friendsProvider.notifier).remove(widget.friendId);
  }

  @override
  Widget build(BuildContext context) {
    final friend = _find(ref.watch(friendsProvider));
    if (friend == null) {
      return const Scaffold(body: SizedBox.shrink());
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
                  onTap: () => ref
                      .read(friendsProvider.notifier)
                      .toggleFavorite(friend.profile.id),
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
