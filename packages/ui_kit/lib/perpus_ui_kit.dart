import 'package:flutter/material.dart';

abstract final class PerpusColors {
  static const ink = Color(0xFF2D3939);
  static const muted = Color(0xFF5B6972);
  static const surface = Color(0xFFCFD8DF);
  static const accent = Color(0xFF9DADA3);
  static const primary = Color(0xFF273E20);
}

ThemeData perpusTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PerpusColors.primary,
    primary: PerpusColors.primary,
    onPrimary: PerpusColors.surface,
    surface: PerpusColors.surface,
    onSurface: PerpusColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PerpusColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: PerpusColors.surface,
      foregroundColor: PerpusColors.ink,
      centerTitle: false,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
        color: PerpusColors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -.8,
        color: PerpusColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: PerpusColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: PerpusColors.ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: PerpusColors.ink,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: PerpusColors.muted,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: PerpusColors.surface,
      indicatorColor: PerpusColors.accent,
    ),
    dividerTheme: DividerThemeData(
      color: PerpusColors.ink.withValues(alpha: .12),
    ),
  );
}

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.dark = false,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final bool dark;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: dark ? PerpusColors.primary : Colors.white.withValues(alpha: .38),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: dark ? Colors.transparent : Colors.white.withValues(alpha: .5),
      ),
    ),
    child: child,
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.icon = Icons.circle_outlined});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: PerpusColors.accent.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_stories_outlined,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Icon(icon, size: 44, color: PerpusColors.primary),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

/// Keeps the no-image cover artwork consistent between demo and server data.
class PerpusBookCover extends StatelessWidget {
  const PerpusBookCover({
    super.key,
    required this.bookId,
    required this.code,
    this.width = 62,
    this.height = 86,
    this.imageUrl,
  });

  final String bookId;
  final String code;
  final double width;
  final double height;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl;
    if (image != null && image.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          image,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _artwork(),
        ),
      );
    }
    return _artwork();
  }

  Widget _artwork() => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: bookId.hashCode.isEven ? PerpusColors.primary : PerpusColors.ink,
      borderRadius: BorderRadius.circular(6),
      border: const Border(
        left: BorderSide(color: PerpusColors.accent, width: 5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(
          Icons.auto_stories_outlined,
          color: PerpusColors.accent,
          size: 16,
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              code,
              maxLines: 1,
              style: TextStyle(
                fontSize: width > 80 ? 32 : 20,
                color: PerpusColors.surface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Container(height: 2, width: 24, color: PerpusColors.accent),
      ],
    ),
  );
}
