import 'package:flutter/material.dart';

class StatusTimeline extends StatelessWidget {
	const StatusTimeline({super.key, required this.steps, required this.currentIndex});
	final List<String> steps;
	final int currentIndex;

	@override
	Widget build(BuildContext context) {
		return ListView.separated(
			shrinkWrap: true,
			physics: const NeverScrollableScrollPhysics(),
			itemCount: steps.length,
			separatorBuilder: (_, __) => const SizedBox(height: 8),
			itemBuilder: (context, i) {
				final isActive = i <= currentIndex;
				return Row(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Column(
							children: [
								Container(
									width: 12,
									height: 12,
									decoration: BoxDecoration(
										shape: BoxShape.circle,
										color: isActive ? Colors.blue : Colors.grey.shade400,
									),
								),
								if (i != steps.length - 1)
									Container(
										width: 2,
										height: 32,
										color: isActive ? Colors.blue : Colors.grey.shade300,
									),
							],
						),
						const SizedBox(width: 12),
						Expanded(child: Text(steps[i], style: TextStyle(color: isActive ? Colors.black : Colors.grey.shade500))),
					],
				);
			},
		);
	}
}