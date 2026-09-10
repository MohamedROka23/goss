import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../app/theme.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/export_service.dart';
/// Colour used to paint a request status.
Color requestStatusColor(String status) {
  switch (status) {
    case RequestStatus.accepted:
      return GossColors.blue;
    case RequestStatus.preparing:
      return const Color(0xFFB06A00);
    case RequestStatus.arriving:
      return const Color(0xFF7A5BC0);
    case RequestStatus.delivering:
      return const Color(0xFFD21F26);
    case RequestStatus.delivered:
      return const Color(0xFF1F8A4C);
    case RequestStatus.confirmed:
      return GossColors.green;
    case RequestStatus.rejected:
      return GossColors.red;
    default:
      return GossColors.red;
  }
}

/// Small coloured pill showing a request status, bilingual.
class RequestStatusChip extends StatelessWidget {
  final String status;
  final bool isArabic;
  const RequestStatusChip({super.key, required this.status, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final color = requestStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        requestStatusLabel(status, ar: isArabic),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Shows the installed app version and build number.
/// Horizontal stage-by-stage timeline for an order's journey.
class RequestStatusTimeline extends StatelessWidget {
  final int step;
  const RequestStatusTimeline({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(RequestStatus.stages.length, (i) {
        final done = i <= step;
        final color = done ? requestStatusColor(RequestStatus.stages[i]) : GossColors.navy2;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : GossColors.navy2,
                  border: Border.all(color: done ? color : GossColors.navy2, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        );
      }),
    );
  }
}

class VersionBadge extends StatelessWidget {
  final bool compact;
  final bool light;
  const VersionBadge({super.key, this.compact = false, this.light = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        final version = info?.version ?? '1.0.0';
        final build = info?.buildNumber ?? '1';
        final text = compact ? 'v$version' : 'Version $version ($build)';
        return Text(
          'GOSST $text',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: light ? const Color(0xFFC9D3E0) : context.mutedColor,
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

class ExportButtons extends StatelessWidget {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  const ExportButtons({
    super.key,
    required this.title,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<AppProvider>().isArabic;
    return Row(
      children: [
        _pill(
          icon: Icons.picture_as_pdf_outlined,
          label: 'PDF',
          color: GossColors.red,
          onTap: () => ExportService.exportPdf(title: title, headers: headers, rows: rows, isArabic: isArabic),
        ),
        const SizedBox(width: 8),
        _pill(
          icon: Icons.table_chart_outlined,
          label: 'Excel',
          color: const Color(0xFF1A7A3C),
          onTap: () => ExportService.exportExcel(sheetName: title, headers: headers, rows: rows, isArabic: isArabic),
        ),
      ],
    );
  }

  Widget _pill({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

class GossButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isSmall;
  final IconData? icon;

  const GossButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = GossColors.blue,
    this.isSmall = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 14 : 22,
          vertical: isSmall ? 10 : 14,
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: isSmall ? 13 : 15,
          letterSpacing: 0.04,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 14 : 18),
            SizedBox(width: isSmall ? 4 : 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final bool isArabic;

  const SectionTitle({super.key, required this.title, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: context.headingColor,
      ),
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
    );
  }
}

class PageHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isArabic;

  const PageHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GossColors.navy, GossColors.navy2],
        ),
      ),
      child: Column(
        crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
            textDirection: direction,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFC9D3E0),
              fontSize: 15,
              height: 1.6,
            ),
            textDirection: direction,
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final bool isArabic;
  final VoidCallback? onAdd;
  final Widget? child;

  const ProductCard({
    super.key,
    required this.product,
    required this.isArabic,
    this.onAdd,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? product.nameAr : product.nameEn,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.headingColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              isArabic ? product.descAr : product.descEn,
              style: TextStyle(color: context.mutedColor, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Text(
              '${isArabic ? '\u062c.\u0645' : 'EGP'} ${product.price.toStringAsFixed(2)} / ${product.unit}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: GossColors.red, fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 10),
              GossButton(
                label: isArabic ? '\u0623\u0636\u0641 \u0644\u0644\u0637\u0644\u0628' : 'Add to request',
                onPressed: onAdd,
                isSmall: true,
              ),
            ],
            ?child,
          ],
        ),
      ),
    );
  }
}

/// Animated (frame-by-frame) GOSST logo used on the app loading screen.
/// The frames are exported from the official .webm loop and bundled under
/// `assets/anim_logo/` (frame_01..frame_46 at ~30fps = ~1.5s loop).
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key, this.size = 160});

  final double size;

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> {
  static const int _frameCount = 46;
  static const Duration _framePeriod = Duration(milliseconds: 33);

  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    // Pre-decode every frame up front so the first loop plays smoothly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (var i = 1; i <= _frameCount; i++) {
        final asset =
            AssetImage('assets/anim_logo/frame_${i.toString().padLeft(2, '0')}.png');
        unawaited(precacheImage(asset, context));
      }
    });
    _timer = Timer.periodic(_framePeriod, (_) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % _frameCount);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = (_frame + 1).toString().padLeft(2, '0');
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.asset(
        'assets/anim_logo/frame_$frame.png',
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
  }
}
