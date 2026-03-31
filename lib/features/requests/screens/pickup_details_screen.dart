import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/color_palette.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/swipe_button.dart';

class PickupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const PickupDetailsScreen({super.key, required this.request});

  @override
  State<PickupDetailsScreen> createState() => _PickupDetailsScreenState();
}

class _PickupDetailsScreenState extends State<PickupDetailsScreen> {
  final _myId = Supabase.instance.client.auth.currentUser?.id;
  bool _isLoading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('pickup_requests')
          .update({'status': status})
          .eq('id', widget.request['id']);
    } catch (e) {
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

  Future<void> _acceptRequest() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('pickup_requests')
          .update({
            'carrier_id': _myId,
            'status': 'ACCEPTED',
          })
          .eq('id', widget.request['id']);

      // Send automated message to trigger push notification for the requester
      await Supabase.instance.client.from('messages').insert({
        'request_id': widget.request['id'],
        'sender_id': _myId,
        'receiver_id': widget.request['requester_id'],
        'content': 'Hi, I have accepted your pickup request! I am on my way.',
      });

      // Update the request visibility for the chat to work seamlessly
      await Supabase.instance.client.from('pickup_requests').update({
        'visible_to_requester': true,
        'visible_to_carrier': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.request['id']);
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request accepted! Go to pickups to manage.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request?'),
        content: const Text('Are you sure you want to delete this Pickup Request? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppPalette.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('pickup_requests')
          .delete()
          .eq('id', widget.request['id']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request deleted successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editRequest() async {
    // Navigate to CreateRequestScreen with initial data
    final result = await context.push('/create_request', extra: widget.request);
    if (result == true) {
      setState(() {}); // Rebuild to fetch new data (actually StreamBuilder handles it but good practice)
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          // Only show actions if I am the requester and status is WAITING (from initial data, stream updates will handle UI body but appbar actions might need setState if status changes, but for now using initial widget.request is risky if status changes while viewing. 
          // BETTER: We should use the stream data for this check. Moving AppBar inside StreamBuilder or using a heuristic. 
          // Since StreamBuilder is the body, we can't easily update AppBar actions based on stream data without more complex state management.
          // However, for simplicity, we can use widget.request but it might be stale.
          // Let's rely on the body content mostly or just check widget.request['requester_id'] == _myId.
          if (widget.request['requester_id'] == _myId && widget.request['status'] == 'WAITING')
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _editRequest();
                if (value == 'delete') _deleteRequest();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [Icon(Icons.edit, size: 20), Gap(12), Text('Edit Request')],
                  ),
                ),
                 const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [Icon(Icons.delete, color: AppPalette.error, size: 20), Gap(12), Text('Delete Request', style: TextStyle(color: AppPalette.error))],
                  ),
                ),
              ],
            ),
        ],
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
            return Center(
              child: Text(
                'Request not found',
                style: textTheme.bodyLarge,
              ),
            );
          }

          final req = snapshot.data!.first;
          final status = req['status'] as String;
          final requesterId = req['requester_id'];
          final carrierId = req['carrier_id'];
          final isRequester = requesterId == _myId;
          final isCarrier = carrierId == _myId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status Card
                _buildStatusTimeline(context, status),
                const Gap(24),
                
                // Item Details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${req['item_type']} from ${req['delivery_partner']}',
                              style: textTheme.headlineSmall?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                           Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppPalette.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.restaurant, color: AppPalette.primary),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      const Gap(8),
                      Text('Requester Details', style: textTheme.labelLarge?.copyWith(color: AppPalette.textSecondary)),
                      const Gap(12),
                      FutureBuilder<Map<String, dynamic>>(
                        future: Supabase.instance.client.from('profiles').select().eq('id', requesterId).single(),
                        builder: (context, profileSnapshot) {
                          if (profileSnapshot.connectionState == ConnectionState.waiting) {
                             return const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                          }
                          if (!profileSnapshot.hasData) return const Text('Unknown Requester');
                          final p = profileSnapshot.data!;
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppPalette.primary.withOpacity(0.1),
                                backgroundImage: p['avatar_url'] != null ? NetworkImage(p['avatar_url']) : null,
                                child: p['avatar_url'] == null ? Text((p['full_name'] ?? '?')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppPalette.primary)) : null,
                              ),
                              const Gap(12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('${p['reg_number'] ?? ''} • ${p['hostel_block'] ?? ''}', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const Gap(24),
                      _buildDetailRow(context, Icons.location_on, 'Drop Location', req['drop_location']),
                      const Gap(16),
                      _buildDetailRow(context, Icons.currency_rupee, 'Fee Offered', '₹${req['transport_fee']}'),
                      const Gap(16),
                      _buildDetailRow(context, Icons.notes, 'Instructions', req['description'] ?? 'None'),
                    ],
                  ),
                ),
                
                const Gap(32),

                // Actions
                if (status == 'WAITING' && !isRequester)
                  SwipeButton(
                    text: 'SWIPE TO ACCEPT', 
                    isLoading: _isLoading,
                    onSwipe: _acceptRequest
                  ),
                
                if (status == 'ACCEPTED' && isCarrier)
                  PrimaryButton(
                    text: 'Start Delivery', 
                    isLoading: _isLoading,
                    onPressed: () => _updateStatus('IN_TRANSIT')
                  ),
                  
                if (status == 'IN_TRANSIT' && isCarrier)
                  PrimaryButton(
                    text: 'Mark as Completed', 
                    isLoading: _isLoading,
                    onPressed: () => _updateStatus('COMPLETED'),
                    backgroundColor: AppPalette.success,
                  ),

                // Chat Button (Visible to involved parties)
                if ((isRequester || isCarrier) && status != 'WAITING' && status != 'COMPLETED') ...[
                  const Gap(16),
                  PrimaryButton(
                    text: 'Chat with ${isRequester ? 'Carrier' : 'Requester'}',
                    backgroundColor: AppPalette.secondary,
                    onPressed: () async {
                         final otherId = isRequester ? carrierId : requesterId;
                         final name = await _getOtherName(otherId, isRequester);
                         if (!context.mounted) return;
                         context.push('/chat', extra: {
                           'requestId': req['id'],
                           'otherName': name,
                           'otherUserId': otherId,
                         });
                    },
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusTimeline(BuildContext context, String currentStatus) {
    final theme = Theme.of(context);
    final steps = ['WAITING', 'ACCEPTED', 'IN_TRANSIT', 'COMPLETED'];
    int currentIndex = steps.indexOf(currentStatus);
    if(currentIndex == -1) currentIndex = 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isActive = index <= currentIndex;
          final isLine = index < steps.length - 1;
          
          return Expanded(
            flex: isLine ? 1 : 0,
            child: Row(
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isActive ? AppPalette.primary : theme.disabledColor,
                      child: isActive 
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                    ),
                    const Gap(4),
                    Text(
                      steps[index][0], // First letter
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppPalette.primary : theme.disabledColor,
                      ),
                    ),
                  ],
                ),
                if (isLine)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < currentIndex ? AppPalette.primary : theme.disabledColor.withOpacity(0.3),
                      margin: const EdgeInsets.only(bottom: 16),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.disabledColor),
        const Gap(12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: theme.disabledColor)),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16, fontWeight: FontWeight.w500)
            ),
          ],
        ),
      ],
    );
  }
}
