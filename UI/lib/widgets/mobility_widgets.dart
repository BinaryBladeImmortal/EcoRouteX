// lib/widgets/mobility_widgets.dart
// EcoRouteX – Reusable UI Components

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

// ── Section Header ──────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
      ],
    );
  }
}

// ── Glowing Card ────────────────────────────────────────────
class GlowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? glowColor;
  final VoidCallback? onTap;
  final double radius;
  final Gradient? gradient;

  const GlowCard({super.key, required this.child, this.padding, this.glowColor, this.onTap, this.radius = 20, this.gradient});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient ?? AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: glowColor != null
              ? [BoxShadow(color: glowColor!.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))]
              : AppTheme.cardShadow,
          border: Border.all(color: (glowColor ?? AppTheme.textFaint).withOpacity(0.2), width: 1),
        ),
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

// ── Transport Mode Badge ────────────────────────────────────
class TransportBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const TransportBadge({super.key, required this.emoji, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.greenGradient : null,
          color: selected ? null : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : AppTheme.textFaint.withOpacity(0.4),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? AppTheme.greenGlow : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: selected ? AppTheme.primaryDark : AppTheme.textWhite, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Gradient Action Button ──────────────────────────────────
class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Gradient gradient;

  const ActionButton({super.key, required this.label, required this.onPressed, this.icon, this.gradient = AppTheme.greenGradient});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.greenGlow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: AppTheme.primaryDark, size: 20), const SizedBox(width: 10)],
            Text(label, style: const TextStyle(color: AppTheme.primaryDark, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

// ── Eco Score Ring ──────────────────────────────────────────
class EcoRing extends StatelessWidget {
  final int score;
  final double radius;
  final double lineWidth;

  const EcoRing({super.key, required this.score, this.radius = 50, this.lineWidth = 8});

  Color get _color {
    if (score >= 80) return AppTheme.primaryGreen;
    if (score >= 50) return AppTheme.accentAmber;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.cardMid, width: lineWidth),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: lineWidth,
              backgroundColor: AppTheme.cardMid,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: TextStyle(color: _color, fontSize: radius * 0.5, fontWeight: FontWeight.w800)),
              Text('/100', style: TextStyle(color: AppTheme.textFaint, fontSize: radius * 0.22)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Info Chip ───────────────────────────────────────────────
class InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const InfoChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, color: color, size: 13), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Map Route Visualizer ────────────────────────────────────
class RouteVisualizer extends StatelessWidget {
  final String origin;
  final String destination;
  final String mode;
  final String emoji;

  const RouteVisualizer({super.key, required this.origin, required this.destination, required this.mode, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.mapDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.accentBlue, shape: BoxShape.circle)),
              Container(width: 2, height: 30, color: AppTheme.primaryGreen.withOpacity(0.5)),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(origin, style: const TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 12),
                Text(destination, style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}

// ── Quick Stat Card ─────────────────────────────────────────
class QuickStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;

  const QuickStat({super.key, required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppTheme.textSoft, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}