import 'package:flutter/material.dart';

enum ToastType { info, error, success }

class TGToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _current?.remove();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          _current?.remove();
          _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
    Future.delayed(duration + const Duration(milliseconds: 400), () {
      if (_current == entry) {
        entry.remove();
        _current = null;
      }
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bg => switch (widget.type) {
        ToastType.error => const Color(0xE6FF5252),
        ToastType.success => const Color(0xE64CAF50),
        ToastType.info => const Color(0xE6757575),
      };

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: const Alignment(0, 0.35),
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFFFFFF),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
