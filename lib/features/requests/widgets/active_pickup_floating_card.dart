import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/color_palette.dart';

class ActivePickupFloatingCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isRequester;

  const ActivePickupFloatingCard({
    super.key,
    required this.request,
    required this.isRequester,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = request['status'] as String;
    
    // Status Text & Icon
    String label = 'Pickup Active';
    IconData icon = Icons.local_shipping_outlined;
    
    if (status == 'ACCEPTED') {
      label = isRequester ? 'Carrier found!' : 'Pickup accepted';
      icon = Icons.check_circle_outline;
    } else if (status == 'IN_TRANSIT') {
      label = isRequester ? 'Order on the way' : 'Delivery in progress';
      icon = Icons.directions_bike;
    }

    return GestureDetector(
      onTap: () => context.push('/active_pickup', extra: request),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: AppPalette.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Pulse Icon Integration could go here, for now static
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppPalette.primary, size: 20),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Tap to track',
                    style: TextStyle(fontSize: 12, color: theme.disabledColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.disabledColor),
          ],
        ),
      ),
    );
  }
}
