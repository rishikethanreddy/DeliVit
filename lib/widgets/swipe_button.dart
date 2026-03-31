import 'package:flutter/material.dart';
import '../core/theme/color_palette.dart';
import 'package:gap/gap.dart';

class SwipeButton extends StatefulWidget {
  final String text;
  final Future<void> Function() onSwipe;
  final bool isLoading;

  const SwipeButton({
    super.key,
    required this.text,
    required this.onSwipe,
    this.isLoading = false,
  });

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton> {
  double _dragPosition = 0;
  bool _isFinished = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppPalette.primary.withOpacity(0.5),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        ),
      );
    }

    if (_isFinished) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppPalette.success,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: Icon(Icons.check, color: Colors.white, size: 30),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = constraints.maxWidth;
        final sliderWidth = 56.0;
        final maxDrag = buttonWidth - sliderWidth;

        return Container(
          height: sliderWidth,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(sliderWidth / 2),
            border: Border.all(color: AppPalette.primary.withOpacity(0.5), width: 1),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.only(left: sliderWidth / 2),
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: AppPalette.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) async {
                    if (_dragPosition > maxDrag * 0.8) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _isFinished = true;
                      });
                      await widget.onSwipe();
                    } else {
                      setState(() {
                        _dragPosition = 0;
                      });
                    }
                  },
                  child: Container(
                    height: sliderWidth,
                    width: sliderWidth,
                    decoration: BoxDecoration(
                      color: AppPalette.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.primary.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
