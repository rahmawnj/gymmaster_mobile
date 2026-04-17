import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry padding;
  final BoxFit fit;
  final AppLogoVariant variant;
  final double? iconSize;
  final double? textSize;
  final double spacing;
  final AppLogoTone tone;

  const AppLogo({
    super.key,
    this.size = 24,
    this.padding = EdgeInsets.zero,
    this.fit = BoxFit.contain,
    this.variant = AppLogoVariant.textOnly,
    this.iconSize,
    this.textSize,
    this.spacing = 8,
    this.tone = AppLogoTone.auto,
  });

  static const String _textWhitePath =
      'assets/images/logo/logo-text-white.png';
  static const String _textBlackPath =
      'assets/images/logo/logo-text-black.png';
  static const String _iconRedPath =
      'assets/images/logo/logo-swoosh-red.png';
  static const String _iconBlackRedPath =
      'assets/images/logo/logo-icon-black-red.png';
  static const String _lockupHorizontalLightPath =
      'assets/images/logo/logo-lockup-horizontal-black-red.png';
  static const String _lockupHorizontalDarkPath =
      'assets/images/logo/logo-swoosh-red-left.png';

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = iconSize ?? size * 0.7;
    final resolvedTextSize = textSize ?? size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useDark = switch (tone) {
      AppLogoTone.auto => isDark,
      AppLogoTone.light => false,
      AppLogoTone.dark => true,
    };
    final textPath = useDark ? _textWhitePath : _textBlackPath;
    final iconPath = useDark ? _iconRedPath : _iconBlackRedPath;

    return Padding(
      padding: padding,
      child: switch (variant) {
        AppLogoVariant.textOnly => Image.asset(
            textPath,
            width: size,
            height: size,
            fit: fit,
          ),
        AppLogoVariant.iconOnly => Image.asset(
            iconPath,
            width: size,
            height: size,
            fit: fit,
          ),
        AppLogoVariant.lockupStacked => SizedBox(
            width: size,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  iconPath,
                  width: resolvedIconSize,
                  height: resolvedIconSize,
                  fit: fit,
                ),
                SizedBox(height: spacing),
                Image.asset(
                  textPath,
                  width: resolvedTextSize,
                  fit: fit,
                ),
              ],
            ),
          ),
        AppLogoVariant.lockupHorizontal => SizedBox(
            child: Image.asset(
              useDark
                  ? _lockupHorizontalDarkPath
                  : _lockupHorizontalLightPath,
              height: resolvedTextSize,
              fit: fit,
            ),
          ),
      },
    );
  }
}

enum AppLogoVariant {
  textOnly,
  iconOnly,
  lockupStacked,
  lockupHorizontal,
}

enum AppLogoTone {
  auto,
  light,
  dark,
}
