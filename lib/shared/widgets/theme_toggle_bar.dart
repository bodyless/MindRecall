import 'package:flutter/material.dart';

class ThemeToggleBar extends StatelessWidget {
  const ThemeToggleBar({
    super.key,
    required this.themeMode,
    required this.onToggle,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = themeMode == ThemeMode.dark;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    isDark ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                    size: 18,
                  ),
                  label: Text(isDark ? '切换浅色模式' : '切换暗色模式'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
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
