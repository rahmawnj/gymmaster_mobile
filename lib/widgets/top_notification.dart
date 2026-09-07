import 'dart:async';

import 'package:flutter/material.dart';

enum TopNotificationType { info, success, error }

class TopNotification {
  TopNotification._();

  static final Map<Object, Timer> _timers = <Object, Timer>{};
  static final List<_TopNotificationItem> _pendingItems =
      <_TopNotificationItem>[];
  static OverlayEntry? _overlayEntry;
  static _TopNotificationStackState? _stackState;

  static void show(
    BuildContext context, {
    required String message,
    TopNotificationType type = TopNotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _overlayEntry ??= OverlayEntry(builder: _buildOverlay);
    if (!_overlayEntry!.mounted) {
      overlay.insert(_overlayEntry!);
    }

    final item = _TopNotificationItem(
      id: Object(),
      message: message,
      type: type,
      duration: duration,
    );

    final stackState = _stackState;
    if (stackState == null) {
      _pendingItems.insert(0, item);
      if (_pendingItems.length > 2) {
        final removedItems = _pendingItems.sublist(2);
        _pendingItems.removeRange(2, _pendingItems.length);
        for (final removed in removedItems) {
          _timers.remove(removed.id)?.cancel();
        }
      }
    } else {
      stackState.show(item);
    }
    _timers[item.id] = Timer(duration, () => dismiss(item.id));
  }

  static void dismiss(Object id) {
    _timers.remove(id)?.cancel();
    _pendingItems.removeWhere((item) => identical(item.id, id));
    _stackState?.dismiss(id);
  }

  static void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pendingItems.clear();
    _stackState?.clear();

    if (_overlayEntry?.mounted ?? false) {
      _overlayEntry?.remove();
    }
    _overlayEntry = null;
  }

  static Widget _buildOverlay(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 12,
      left: 18,
      right: 18,
      child: IgnorePointer(
        ignoring: false,
        child: Material(
          color: Colors.transparent,
          child: _TopNotificationStack(
            onReady: (state) {
              _stackState = state;
              final pendingItems = List<_TopNotificationItem>.of(
                _pendingItems.reversed,
              );
              _pendingItems.clear();
              for (final item in pendingItems) {
                state.show(item);
              }
            },
            onDisposed: (state) {
              if (identical(_stackState, state)) {
                _stackState = null;
              }
            },
          ),
        ),
      ),
    );
  }
}

class _TopNotificationStack extends StatefulWidget {
  final ValueChanged<_TopNotificationStackState> onReady;
  final ValueChanged<_TopNotificationStackState> onDisposed;

  const _TopNotificationStack({
    required this.onReady,
    required this.onDisposed,
  });

  @override
  State<_TopNotificationStack> createState() => _TopNotificationStackState();
}

class _TopNotificationStackState extends State<_TopNotificationStack> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<_TopNotificationItem> _items = <_TopNotificationItem>[];

  @override
  void initState() {
    super.initState();
    widget.onReady(this);
  }

  @override
  void dispose() {
    widget.onDisposed(this);
    super.dispose();
  }

  void show(_TopNotificationItem item) {
    _items.insert(0, item);
    _listKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 360),
    );

    while (_items.length > 2) {
      final removed = _items.removeAt(_items.length - 1);
      _listKey.currentState?.removeItem(
        _items.length,
        (context, animation) => _buildAnimatedItem(
          item: removed,
          animation: animation,
          isRemoving: true,
        ),
        duration: const Duration(milliseconds: 240),
      );
      TopNotification._timers.remove(removed.id)?.cancel();
    }
  }

  void dismiss(Object id) {
    final index = _items.indexWhere((item) => identical(item.id, id));
    if (index == -1) {
      _removeOverlayIfEmpty();
      return;
    }

    final removed = _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildAnimatedItem(
        item: removed,
        animation: animation,
        isRemoving: true,
      ),
      duration: const Duration(milliseconds: 240),
    );
    _removeOverlayIfEmpty();
  }

  void clear() {
    for (var index = _items.length - 1; index >= 0; index--) {
      final removed = _items.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildAnimatedItem(
          item: removed,
          animation: animation,
          isRemoving: true,
        ),
        duration: Duration.zero,
      );
    }
  }

  void _removeOverlayIfEmpty() {
    if (_items.isNotEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_items.isEmpty) {
        TopNotification._overlayEntry?.remove();
        TopNotification._overlayEntry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedList(
        key: _listKey,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        initialItemCount: _items.length,
        itemBuilder: (context, index, animation) {
          return _buildAnimatedItem(
            item: _items[index],
            animation: animation,
            isRemoving: false,
          );
        },
      ),
    );
  }

  Widget _buildAnimatedItem({
    required _TopNotificationItem item,
    required Animation<double> animation,
    required bool isRemoving,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slideTween = isRemoving
        ? Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.36))
        : Tween<Offset>(begin: const Offset(0, -0.36), end: Offset.zero);

    return SizeTransition(
      sizeFactor: curvedAnimation,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: slideTween.animate(curvedAnimation),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TopNotificationCard(
              item: item,
              onDismissed: () => TopNotification.dismiss(item.id),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNotificationItem {
  final Object id;
  final String message;
  final TopNotificationType type;
  final Duration duration;

  const _TopNotificationItem({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
  });
}

class _TopNotificationCard extends StatefulWidget {
  final _TopNotificationItem item;
  final VoidCallback onDismissed;

  const _TopNotificationCard({required this.item, required this.onDismissed});

  @override
  State<_TopNotificationCard> createState() => _TopNotificationCardState();
}

class _TopNotificationCardState extends State<_TopNotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.item.duration,
    )..forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(widget.item.type);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SizedBox(
        width: double.infinity,
        child: Dismissible(
          key: ValueKey(widget.item.id),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => widget.onDismissed(),
          background: const SizedBox.shrink(),
          secondaryBackground: const SizedBox.shrink(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ColoredBox(
                color: colors.background,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(colors.icon, color: colors.foreground, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.item.message,
                              style: TextStyle(
                                color: colors.foreground,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: 4,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.12),
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, _) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor:
                                      1 - _progressController.value.clamp(0, 1),
                                  child: ColoredBox(
                                    color: colors.foreground.withValues(
                                      alpha: 0.68,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _TopNotificationColors _resolveColors(TopNotificationType type) {
    switch (type) {
      case TopNotificationType.success:
        return const _TopNotificationColors(
          background: Color(0xFF14A76C),
          foreground: Colors.white,
          icon: Icons.check_circle_outline_rounded,
        );
      case TopNotificationType.error:
        return const _TopNotificationColors(
          background: Color(0xFFFF4D55),
          foreground: Colors.white,
          icon: Icons.error_outline_rounded,
        );
      case TopNotificationType.info:
        return const _TopNotificationColors(
          background: Color(0xFF111111),
          foreground: Colors.white,
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class _TopNotificationColors {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _TopNotificationColors({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}
