import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

class CopyButton extends StatefulWidget {
  final String text;
  const CopyButton({super.key, required this.text});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _copy() {
    if (_copied) return;
    Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copy output',
      child: Semantics(
        label: 'Copy output',
        button: true,
        child: ElevatedButton.icon(
          onPressed: _copied ? null : _copy,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Icon(
              _copied ? Icons.check : Icons.copy,
              key: ValueKey(_copied),
              size: 16,
            ),
          ),
          label: Text(_copied ? 'Copied!' : 'Copy'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _copied ? AppColors.success : AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.success,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: AppTextStyles.ui(13, weight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
