import 'package:flutter/material.dart';

List<Widget> buildCloseActions(BuildContext context) => [
	IconButton(
		icon: const Icon(Icons.close),
		onPressed: () => Navigator.maybePop(context),
	),
];