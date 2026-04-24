import 'package:flutter/material.dart';
import '../../models/member.dart';
import 'member_avatar.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Member? currentMember;
  final List<Widget>? actions;
  final bool showDrawerButton;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.currentMember,
    this.actions,
    this.showDrawerButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
        ],
      ),
      leading: showDrawerButton
          ? Builder(
              builder: (ctx) => IconButton(
                icon: currentMember != null
                    ? MemberAvatar(member: currentMember, radius: 14)
                    : const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      actions: actions,
    );
  }
}
