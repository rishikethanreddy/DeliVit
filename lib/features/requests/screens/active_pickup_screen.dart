import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/color_palette.dart';
import '../../../widgets/primary_button.dart';
import '../../../core/utils/call_utils.dart';
import '../widgets/live_map_widget.dart';

class ActivePickupScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const ActivePickupScreen({super.key, required this.request});

  @override
  State<ActivePickupScreen> createState() => _ActivePickupScreenState();
}

class _ActivePickupScreenState extends State<ActivePickupScreen> {
  final _myId = Supabase.instance.client.auth.currentUser?.id;
  bool _isLoading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      if (status == 'COMPLETED' && _myId != null) {
         try {
           final profile = await Supabase.instance.client.from('profiles').select('pickups_completed').eq('id', _myId!).single();
           int currentCount = profile['pickups_completed'] ?? 0;
           await Supabase.instance.client.from('profiles').update({'pickups_completed': currentCount + 1}).eq('id', _myId!);
         } catch(e) {
            // Silently fail if count update error occurs so we don't break the main request
         }
      }

      await Supabase.instance.client
          .from('pickup_requests')
          .update({
            'status': status,
          })
          .eq('id', widget.request['id']);
      
      // print('Status updated to $status'); // Debug
      if (mounted) {
         // Show success for Carrier
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Status updated to $status')),
         );
      }
    } catch (e) {
      // print('Error updating status: $e'); // Debug
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _getOtherName(String userId, bool isRequester) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .single();
      return data['full_name'] as String;
    } catch (_) {
      return isRequester ? 'Carrier' : 'Requester';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Active Pickup'),
        centerTitle: true,
        automaticallyImplyLeading: false, // Don't allow going back easily to emphasize active state
        leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () {
               if (context.canPop()) {
                 context.pop();
               } else {
                 context.go('/home');
               }
            },
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('pickup_requests')
            .stream(primaryKey: ['id'])
            .eq('id', widget.request['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Request not found or completed'));
          }

          final req = snapshot.data!.first;
          final status = req['status'] as String;
          final isRequester = req['requester_id'] == _myId;
          final partner = req['delivery_partner'];
          final item = req['item_type'];
          final fee = req['transport_fee'];
          
          if (status == 'COMPLETED') {
             // Optional: Auto-redirect to home or show completion celebration
             // For now, simple message
          }

          LatLng? pickup;
          if (req['pickup_latitude'] != null && req['pickup_longitude'] != null) {
            pickup = LatLng((req['pickup_latitude'] as num).toDouble(), (req['pickup_longitude'] as num).toDouble());
          }
          LatLng? dropoff;
          if (req['dropoff_latitude'] != null && req['dropoff_longitude'] != null) {
            dropoff = LatLng((req['dropoff_latitude'] as num).toDouble(), (req['dropoff_longitude'] as num).toDouble());
          }

          return Column(
            children: [
              // 1. Zomato style Half-Screen Live Map
              if (status != 'COMPLETED')
                Expanded(
                  flex: 4,
                  child: LiveMapWidget(
                    requestId: req['id'],
                    isCarrier: !isRequester,
                    dropLocationQuery: req['drop_location'],
                    pickupLocation: pickup,
                    dropoffLocation: dropoff,
                  ),
                )
              else 
                Expanded(
                  flex: 4, 
                  child: Container(
                     color: AppPalette.success.withOpacity(0.1),
                     child: const Center(
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                            Icon(Icons.check_circle, size: 64, color: AppPalette.success),
                            Gap(16),
                            Text('Order Completed Successfully!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppPalette.success)),
                         ],
                       ),
                     ),
                  )
                ),

              // 2. White Details Pane (Bottom Half)
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Main Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: theme.dividerColor, width: 1),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppPalette.primary.withOpacity(0.1),
                                    child: Text(
                                       isRequester ? 'C' : 'R', 
                                       style: const TextStyle(fontSize: 20, color: AppPalette.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Gap(16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getStatusText(status, isRequester),
                                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '$item from $partner',
                                          style: textTheme.bodySmall?.copyWith(color: theme.disabledColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                               Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildInfoCol(context, 'Drop Location', req['drop_location'] ?? 'Unknown'),
                                  _buildInfoCol(context, 'Fee', '₹$fee'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const Gap(24),
                        
                        // Actions
                        if (status != 'COMPLETED') ...[
                          Row(
                            children: [
                              Expanded(
                                child: PrimaryButton(
                                  text: 'Chat',
                                  icon: Icons.chat_bubble_outline,
                                  onPressed: () async {
                                     final otherId = isRequester ? req['carrier_id'] : req['requester_id'];
                                     final name = await _getOtherName(otherId, isRequester);
                                     if (!context.mounted) return;
                                     context.push('/chat', extra: {
                                       'requestId': req['id'],
                                       'otherName': name,
                                       'otherUserId': otherId,
                                     });
                                  },
                                ),
                              ),
                              const Gap(16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                     padding: const EdgeInsets.symmetric(vertical: 16),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                     backgroundColor: theme.cardColor,
                                  ),
                                  onPressed: () {
                                     // Determine other user ID
                                     final otherId = isRequester ? req['carrier_id'] : req['requester_id'];
                                     CallUtils.makeCall(context, otherId);
                                  },
                                  icon: const Icon(Icons.phone),
                                  label: const Text('Call'),
                                ),
                              ),
                            ],
                          ),
                          
                          const Gap(24),

                          // Status Controls (Carrier Only)
                          if (!isRequester) ...[
                             if (status == 'ACCEPTED')
                              PrimaryButton(
                                text: 'Swipe to Start Delivery',
                                isLoading: _isLoading,
                                onPressed: () => _updateStatus('IN_TRANSIT'),
                              ),
                             if (status == 'IN_TRANSIT')
                              PrimaryButton(
                                text: 'Mark as Delivered',
                                backgroundColor: AppPalette.success,
                                isLoading: _isLoading,
                                onPressed: () => _updateStatus('COMPLETED'),
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, String currentStatus) {
    // Waiting -> Accepted -> In Transit -> Completed
    final steps = ['ACCEPTED', 'IN_TRANSIT', 'COMPLETED'];
    // Assuming we arrive here only after Accepted
    int index = steps.indexOf(currentStatus);
    if (index == -1) index = 0; // Default to Accepted if weird state

    return Row(
      children: [
        _buildStep(context, 'Accepted', index >= 0, isFirst: true),
        _buildLine(context, index >= 1),
        _buildStep(context, 'On Way', index >= 1),
        _buildLine(context, index >= 2),
        _buildStep(context, 'Delivered', index >= 2, isLast: true),
      ],
    );
  }

  Widget _buildStep(BuildContext context, String label, bool isActive, {bool isFirst = false, bool isLast = false}) {
    final color = isActive ? AppPalette.primary : Colors.grey.shade300;
    return Expanded(
      flex: 0,
       child: Column(
         children: [
           CircleAvatar(
             radius: 12,
             backgroundColor: color,
             child: const Icon(Icons.check, size: 14, color: Colors.white),
           ),
           const Gap(8),
           Text(label, style: TextStyle(
             fontSize: 10, 
             fontWeight: FontWeight.bold,
             color: isActive ? Theme.of(context).textTheme.bodyMedium?.color : Colors.grey,
           )),
         ],
       ),
    );
  }
  
  Widget _buildLine(BuildContext context, bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? AppPalette.primary : Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 14), // Align with circle center roughly
      ),
    );
  }

  Widget _buildInfoCol(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Gap(4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
  String _getStatusText(String status, bool isRequester) {
    if (status == 'ACCEPTED') {
      return isRequester ? 'Carrier is on the way!' : 'You are delivering';
    } else if (status == 'IN_TRANSIT') {
      return isRequester ? 'Order arriving soon!' : 'Delivery in progress';
    } else if (status == 'COMPLETED') {
      return isRequester ? 'Order Delivered!' : 'Delivery Completed';
    }
    return 'Active Pickup';
  }
}
