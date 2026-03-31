import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/color_palette.dart';
import 'package:timeago/timeago.dart' as timeago;

class PickupHistoryScreen extends StatefulWidget {
  const PickupHistoryScreen({super.key});

  @override
  State<PickupHistoryScreen> createState() => _PickupHistoryScreenState();
}

class _PickupHistoryScreenState extends State<PickupHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch requests where the user is either the requester or the carrier
      final response = await Supabase.instance.client
          .from('requests')
          .select()
          .or('requester_id.eq.$userId,carrier_id.eq.$userId')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _history = response as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pickup History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Text(
                    'No past pickups found.',
                    style: TextStyle(color: AppPalette.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final req = _history[index];
                    final String title = req['item_name'] ?? 'Unknown Item';
                    final String status = (req['status'] ?? 'UNKNOWN').toString().toUpperCase();
                    final DateTime createdAt = DateTime.parse(req['created_at']);
                    
                    final isCarrier = req['carrier_id'] == Supabase.instance.client.auth.currentUser?.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCarrier ? AppPalette.primary.withOpacity(0.1) : AppPalette.success.withOpacity(0.1),
                          child: Icon(
                            isCarrier ? Icons.local_shipping_rounded : Icons.move_to_inbox_rounded,
                            color: isCarrier ? AppPalette.primary : AppPalette.success,
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${isCarrier ? 'Delivered' : 'Requested'} • ${timeago.format(createdAt)}',
                          style: const TextStyle(color: AppPalette.textSecondary),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'COMPLETED' ? AppPalette.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: status == 'COMPLETED' ? AppPalette.success : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
