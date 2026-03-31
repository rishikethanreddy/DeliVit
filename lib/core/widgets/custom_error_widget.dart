import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../theme/color_palette.dart';

class CustomErrorWidget extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  final String? title;
  final String? message;
  final bool isCompact;

  const CustomErrorWidget({
    super.key,
    this.error,
    this.onRetry,
    this.title,
    this.message,
    this.isCompact = false,
  });

  String get _friendlyMessage {
    if (message != null) return message!;
    
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('socketexception') || 
        errorStr.contains('network') || 
        errorStr.contains('connection')) {
      return 'Please check your internet connection and try again.';
    }
    if (errorStr.contains('token') || errorStr.contains('jwt')) {
      return 'Session expired. Please refreshing...';
    }
     if (errorStr.contains('timeout')) {
      return 'The request took too long. Please try again.';
    }
    return 'Something went wrong. Please try again later.';
  }

  String get _friendlyTitle {
    if (title != null) return title!;
    
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('socketexception') || 
        errorStr.contains('network') || 
        errorStr.contains('connection')) {
      return 'No Connection';
    }
    if (errorStr.contains('token') || errorStr.contains('jwt')) {
      return 'Session Expired';
    }
    return 'Oops!';
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppPalette.error, size: 24),
              const Gap(4),
              Text(
                _friendlyTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: onRetry,
                  tooltip: 'Retry',
                )
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppPalette.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: AppPalette.error,
              ),
            ),
            const Gap(24),
            Text(
              _friendlyTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(12),
            Text(
              _friendlyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).disabledColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const Gap(32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const Gap(16),
          ],
        ),
      ),
    );
  }
}
