import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/widgets/custom_error_widget.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = Supabase.instance.client.auth.currentUser?.id;

    if (myId == null) return const Center(child: Text('Please log in'));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('pickup_requests')
            .stream(primaryKey: ['id'])
            .order('updated_at', ascending: false)
            .map((list) {
                  final uniqueChats = <String, Map<String, dynamic>>{}; // otherUserId -> mostRecentRequest

                  for (final req in list) {
                    final isRequester = req['requester_id'] == myId;
                    final isCarrier = req['carrier_id'] == myId;
                    
                    if (!isRequester && !isCarrier) continue;
                    if (req['status'] == 'WAITING') continue;

                    final isVisible = isRequester 
                        ? (req['visible_to_requester'] ?? true) 
                        : (req['visible_to_carrier'] ?? true);
                    
                    if (!isVisible) continue;

                    final otherUserId = isRequester ? req['carrier_id'] : req['requester_id'];
                    if (otherUserId == null) continue;

                    // Since list is ordered by updated_at desc, the first one we encounter is the latest
                    if (!uniqueChats.containsKey(otherUserId)) {
                      uniqueChats[otherUserId] = req;
                    }
                  }
                  
                  return uniqueChats.values.toList();
                }),
        builder: (context, requestsSnapshot) {
          if (requestsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (requestsSnapshot.hasError) {
             return CustomErrorWidget(
               error: requestsSnapshot.error,
               onRetry: () => (context as Element).markNeedsBuild(),
             );
          }
          
          final conversations = requestsSnapshot.data ?? [];
          
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.chat_bubble_outline, size: 48, color: theme.disabledColor),
                   const Gap(16),
                   Text('No active conversations', style: TextStyle(color: theme.disabledColor)),
                ],
              ),
            );
          }

          // Single stream for ALL unread messages for me
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('messages')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false)
                .map((messages) => messages.where((msg) => 
                    msg['receiver_id'] == myId && 
                    msg['is_read'] != true
                ).toList()),
            builder: (context, unreadSnapshot) {
               // Map of senderId -> unread count
               final unreadCounts = <String, int>{};
               if (unreadSnapshot.hasData) {
                 for (var msg in unreadSnapshot.data!) {
                   final senderId = msg['sender_id'] as String;
                   unreadCounts[senderId] = (unreadCounts[senderId] ?? 0) + 1;
                 }
               }

               return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: conversations.length,
                separatorBuilder: (context, index) => const Gap(12),
                itemBuilder: (context, index) {
                  final req = conversations[index];
                  final isRequester = req['requester_id'] == myId;
                  final otherUserId = isRequester ? req['carrier_id'] : req['requester_id'];
                  final count = unreadCounts[otherUserId] ?? 0;
                  
                  return _ChatListItem(req: req, myId: myId, unreadCount: count);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final Map<String, dynamic> req;
  final String myId;
  final int unreadCount;

  const _ChatListItem({
    required this.req, 
    required this.myId,
    required this.unreadCount,
  });

  Future<Map<String, dynamic>?> _fetchUserProfile(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', userId)
          .single();
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteChat(BuildContext context) async {
    final isRequester = req['requester_id'] == myId;
    final fieldToUpdate = isRequester ? 'visible_to_requester' : 'visible_to_carrier';

    try {
      await Supabase.instance.client
          .from('pickup_requests')
          .update({fieldToUpdate: false})
          .eq('id', req['id']);
      
      // Bypass RLS using RPC
      try {
        await Supabase.instance.client.rpc('mark_messages_read', params: {
          'req_id': req['id'],
          'user_id': myId,
        });
      } catch (_) {}

      // Fallback
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true})
          .eq('request_id', req['id'])
          .eq('receiver_id', myId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Chat deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error deleting chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRequester = req['requester_id'] == myId;
    
    // If I am requester, I talk to carrier. If I am carrier, I talk to requester.
    final otherUserId = isRequester ? req['carrier_id'] : req['requester_id'];
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: otherUserId != null ? _fetchUserProfile(otherUserId) : Future.value(null),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?['full_name'] ?? (isRequester ? 'Carrier' : 'Requester');
        final avatarUrl = profile?['avatar_url'];
        final item = req['item_type'] ?? 'Item';
        final status = req['status'] ?? 'Unknown';

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppPalette.primary.withOpacity(0.1),
              radius: 28,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppPalette.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Order: $item • $status',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.disabledColor, fontSize: 14),
              ),
            ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppPalette.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (unreadCount > 0) const Gap(4),
                  if (status == 'ACCEPTED')
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppPalette.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            onTap: () {
               context.push('/chat', extra: {
                 'requestId': req['id'],
                 'otherName': name,
                 'otherAvatar': avatarUrl,
                 'otherUserId': otherUserId,
               });
            },
            onLongPress: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Gap(12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Gap(12),
                       ListTile(
                        leading: const Icon(Icons.delete_outline_rounded, color: AppPalette.error),
                        title: const Text('Delete Chat', style: TextStyle(color: AppPalette.error)),
                        onTap: () async {
                          Navigator.pop(ctx); // Close bottom sheet
                          
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Delete Chat?'),
                              content: const Text('This will remove the chat from your list. The messages will be hidden from you.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                                  child: const Text('Delete', style: TextStyle(color: AppPalette.error)),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            await _deleteChat(context);
                          }
                        },
                      ),
                      const Gap(8),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
