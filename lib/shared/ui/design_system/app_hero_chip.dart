import 'package:flutter/material.dart';

/// Shared hero-card inline chip used by Room, Group, and Project list screens.
class AppHeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color onCard;
  final Color onCardMuted;

  const AppHeroChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onCard,
    required this.onCardMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: onCardMuted),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: onCardMuted, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onCard)),
            ],
          ),
        ],
      ),
    );
  }
}
