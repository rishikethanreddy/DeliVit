import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/widgets/custom_error_widget.dart';

class RequestsListScreen extends StatefulWidget {
  const RequestsListScreen({super.key});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  // Key to force stream rebuild
  int _refreshKey = 0;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.tokenRefreshed || 
          data.event == AuthChangeEvent.signedIn) {
        if (mounted) _refresh();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _refreshKey++;
    });
  }

  Future<void> _deleteRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request?'),
        content: const Text('Are you sure you want to delete this Pickup Request? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('pickup_requests')
          .delete()
          .eq('id', requestId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request deleted successfully!')),
        );
        _refresh(); // Refresh the list
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editRequest(Map<String, dynamic> request) async {
    final result = await context.push('/create_request', extra: request);
    if (result == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pickup Requests'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/create_request');
          if (result == true) {
            _refresh();
          }
        },
        backgroundColor: AppPalette.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Request Pickup', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(_refreshKey),
          stream: Supabase.instance.client
              .from('pickup_requests')
              .stream(primaryKey: ['id'])
              .eq('status', 'WAITING')
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
               return CustomErrorWidget(
                 error: snapshot.error,
                 onRetry: _refresh,
               );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Stack(
                children: [
                   ListView(), // Allows Pull to refresh even when empty
                   Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 64, color: theme.disabledColor),
                        const Gap(16),
                        Text('No waiting requests found', style: TextStyle(color: theme.disabledColor)),
                      ],
                    ),
                  ),
                ],
              );
            }

            final requests = snapshot.data!;

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const Gap(12),
              itemBuilder: (context, index) {
                final req = requests[index];
                
                return _RequestCard(
                  req: req,
                  currentUserId: userId,
                  onEdit: () => _editRequest(req),
                  onDelete: () => _deleteRequest(req['id']),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final Map<String, dynamic> req;
  final String? currentUserId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RequestCard({
    required this.req,
    required this.currentUserId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  String? _requesterName;
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _fetchRequesterName();
  }

  Future<void> _fetchRequesterName() async {
    try {
      final requesterId = widget.req['requester_id'];
      if (requesterId == widget.currentUserId) {
        if (mounted) {
          setState(() {
            _requesterName = 'You';
            _isLoadingName = false;
          });
        }
        return;
      }

      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', requesterId)
          .single();
          
      if (mounted) {
        setState(() {
          _requesterName = data['full_name'] as String;
          _isLoadingName = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _requesterName = 'Unknown User';
          _isLoadingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isMyRequest = widget.req['requester_id'] == widget.currentUserId;
    final fee = widget.req['transport_fee'];
    final time = DateFormat.jm().format(DateTime.parse(widget.req['created_at']).toLocal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isMyRequest ? Border.all(color: AppPalette.primary.withOpacity(0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.warning.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'WAITING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    time,
                    style: textTheme.bodySmall,
                  ),
                  if (isMyRequest) ...[
                    const Gap(8),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.more_vert, size: 20, color: theme.disabledColor),
                      onSelected: (value) {
                        if (value == 'edit') widget.onEdit();
                        if (value == 'delete') widget.onDelete();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          height: 40,
                          child: Row(
                            children: [Icon(Icons.edit, size: 18), Gap(8), Text('Edit', style: TextStyle(fontSize: 14))],
                          ),
                        ),
                         const PopupMenuItem(
                          value: 'delete',
                          height: 40,
                          child: Row(
                            children: [Icon(Icons.delete, color: AppPalette.error, size: 18), Gap(8), Text('Delete', style: TextStyle(color: AppPalette.error, fontSize: 14))],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          const Gap(12),
          
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppPalette.primary.withOpacity(0.2),
                child: const Icon(Icons.person, size: 14, color: AppPalette.primary),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  _isLoadingName ? 'Loading...' : (_requesterName ?? 'Unknown User'),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const Gap(8),
          Text(
            '${widget.req['item_type']} from ${widget.req['delivery_partner']}',
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          if (isMyRequest)
            const Text('(Your Request)', style: TextStyle(color: AppPalette.primary, fontSize: 12)),

          const Gap(8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: theme.disabledColor),
              const Gap(4),
              Expanded(
                child: Text(
                  'Drop: ${widget.req['drop_location']}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.disabledColor,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fee: ₹$fee',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.primary,
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 14),
                ),
                onPressed: () => context.push('/request_details', extra: widget.req),
                child: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
