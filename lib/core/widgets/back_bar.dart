import 'package:flutter/material.dart';

class BackBar extends StatelessWidget implements PreferredSizeWidget {
  const BackBar({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(title ?? ''),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
