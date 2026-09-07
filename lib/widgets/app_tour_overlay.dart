import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final EdgeInsets highlightPadding;
  final double borderRadius;

  const AppTourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.highlightPadding = const EdgeInsets.all(14),
    this.borderRadius = 24,
  });
}

class AppTourOverlay extends StatefulWidget {
  final List<AppTourStep> steps;
  final ValueChanged<int>? onStepChanged;
  final VoidCallback onCompleted;
  final VoidCallback onDismissed;

  const AppTourOverlay({
    super.key,
    required this.steps,
    this.onStepChanged,
    required this.onCompleted,
    required this.onDismissed,
  });

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay> {
  int _currentStepIndex = 0;

  AppTourStep get _currentStep => widget.steps[_currentStepIndex];

  bool get _isLastStep => _currentStepIndex == widget.steps.length - 1;

  void _nextStep() {
    if (_isLastStep) {
      widget.onCompleted();
      return;
    }

    setState(() {
      _currentStepIndex += 1;
      widget.onStepChanged?.call(_currentStepIndex);
    });
  }

  Rect? _resolveTargetRect(AppTourStep step, Size screenSize) {
    final targetContext = step.targetKey.currentContext;
    if (targetContext == null) {
      return null;
    }

    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        !renderObject.attached) {
      return null;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    final rect = origin & renderObject.size;
    return Rect.fromLTRB(
      (rect.left - step.highlightPadding.left)
          .clamp(12.0, screenSize.width - 12.0)
          .toDouble(),
      (rect.top - step.highlightPadding.top)
          .clamp(12.0, screenSize.height - 12.0)
          .toDouble(),
      (rect.right + step.highlightPadding.right)
          .clamp(12.0, screenSize.width - 12.0)
          .toDouble(),
      (rect.bottom + step.highlightPadding.bottom)
          .clamp(12.0, screenSize.height - 12.0)
          .toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final highlightRect = _resolveTargetRect(_currentStep, screenSize);

    final cardWidth = math.min(screenSize.width - 32, 360.0);
    final cardLeft = highlightRect == null
        ? 16.0
        : (highlightRect.center.dx - (cardWidth / 2)).clamp(
            16.0,
            screenSize.width - cardWidth - 16.0,
          ).toDouble();
    final placeCardNearTop =
        highlightRect != null && highlightRect.center.dy > screenSize.height * 0.56;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: _TourScrimPainter(
                  highlightRect: highlightRect,
                  borderRadius: _currentStep.borderRadius,
                ),
              ),
            ),
          ),
          if (highlightRect != null)
            Positioned(
              left: highlightRect.left,
              top: highlightRect.top,
              width: highlightRect.width,
              height: highlightRect.height,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_currentStep.borderRadius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.96),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.24),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: cardLeft,
            width: cardWidth,
            top: placeCardNearTop ? safePadding.top + 18 : null,
            bottom: placeCardNearTop ? null : safePadding.bottom + 122,
            child: _TourMessageCard(
              theme: theme,
              title: _currentStep.title,
              description: _currentStep.description,
              currentStep: _currentStepIndex + 1,
              totalSteps: widget.steps.length,
              isLastStep: _isLastStep,
              onSkip: widget.onDismissed,
              onNext: _nextStep,
            ),
          ),
        ],
      ),
    );
  }
}

class _TourMessageCard extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final String description;
  final int currentStep;
  final int totalSteps;
  final bool isLastStep;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _TourMessageCard({
    required this.theme,
    required this.title,
    required this.description,
    required this.currentStep,
    required this.totalSteps,
    required this.isLastStep,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF16181C) : Colors.white;
    final bodyColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF5E6673);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE7ECF4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Tur $currentStep / $totalSteps',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: bodyColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: Text(isLastStep ? 'Tutup' : 'Lewati'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  child: Text(isLastStep ? 'Selesai' : 'Lanjut'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TourScrimPainter extends CustomPainter {
  final Rect? highlightRect;
  final double borderRadius;

  const _TourScrimPainter({
    required this.highlightRect,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (highlightRect != null) {
      path.addRRect(
        RRect.fromRectAndRadius(
          highlightRect!,
          Radius.circular(borderRadius),
        ),
      );
    }

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.76),
    );
  }

  @override
  bool shouldRepaint(covariant _TourScrimPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect ||
        oldDelegate.borderRadius != borderRadius;
  }
}
