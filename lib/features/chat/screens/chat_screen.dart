import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/widgets/custom_error_widget.dart';
import '../../../core/utils/call_utils.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String otherName;
  final String? otherAvatar;
  final String? otherUserId;
  
  const ChatScreen({
    super.key, 
    required this.requestId,
    required this.otherName,
    this.otherAvatar,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _myId = Supabase.instance.client.auth.currentUser?.id;
  final _imagePicker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    // Also mark read when returning to app lifecycle state if needed, but simple init is fine for now
  }

  Future<void> _markMessagesAsRead() async {
    if (_myId == null) return;
    try {
      print('Attempting to mark messages as read for req: ${widget.requestId}, receiver: $_myId');
      
      try {
        await Supabase.instance.client.rpc('mark_messages_read', params: {
          'req_id': widget.requestId,
          'user_id': _myId,
        });
      } catch (_) {}

      final List<Map<String, dynamic>> updatedRows = await Supabase.instance.client
        .from('messages')
        .update({'is_read': true})
        .eq('request_id', widget.requestId)
        .eq('receiver_id', _myId!)
        .select();
      
      print('Successfully marked ${updatedRows.length} messages as read');
      
      if (updatedRows.isEmpty) {
        // Debug
        final count = await Supabase.instance.client
          .from('messages')
          .count(CountOption.exact)
          .eq('request_id', widget.requestId)
          .eq('receiver_id', _myId!);
        print('Debug Check: DB says there are $count total messages matching criteria.');
      }
    } catch (e) {
      print('Error marking read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update read status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _makeCall() async {
    await CallUtils.makeCall(context, widget.otherUserId);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _handleSend() async {
    if (_selectedImage != null) {
      final imageToUpload = _selectedImage!;
      setState(() => _selectedImage = null);
      await _uploadAndSendImage(imageToUpload);
    } else {
      await _sendMessage();
    }
  }

  Future<void> _uploadAndSendImage(XFile file) async {
    setState(() => _isUploading = true);
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = 'chat/${widget.requestId}/$fileName';
      
      final bytes = await file.readAsBytes();
      
      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('chat_images')
          .uploadBinary(path, bytes);

      // Get Public URL
      final imageUrl = Supabase.instance.client.storage
          .from('chat_images')
          .getPublicUrl(path);

      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    
    if (imageUrl == null) _messageController.clear();

    try {
      await Supabase.instance.client.from('pickup_requests').update({
        'visible_to_requester': true,
        'visible_to_carrier': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.requestId);

      await Supabase.instance.client.from('messages').insert({
        'request_id': widget.requestId,
        'sender_id': _myId,
        'content': text.isEmpty ? null : text,
        'image_url': imageUrl,
        'receiver_id': widget.otherUserId,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.otherAvatar != null 
                  ? NetworkImage(widget.otherAvatar!) 
                  : null,
              radius: 18,
              backgroundColor: AppPalette.primary.withOpacity(0.1),
              child: widget.otherAvatar == null 
                  ? Text(widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?', 
                      style: const TextStyle(fontSize: 14, color: AppPalette.primary, fontWeight: FontWeight.bold))
                  : null,
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(fontSize: 12, color: AppPalette.success),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded),
            onPressed: _makeCall,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .order('created_at', ascending: false)
                  .map((messages) => messages.where((msg) {
                    final senderId = msg['sender_id'];
                    final receiverId = msg['receiver_id'];
                    final isMyMessage = senderId == _myId && receiverId == widget.otherUserId;
                    final isTheirMessage = senderId == widget.otherUserId && receiverId == _myId;
                    return isMyMessage || isTheirMessage;
                  }).toList()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                   return CustomErrorWidget(
                     error: snapshot.error,
                     onRetry: () => setState(() {}),
                   );
                }
                
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hi!'),
                  );
                }

                // Check for unread messages sent TO ME
                final hasUnread = messages.any((m) => 
                    m['receiver_id'] == _myId && m['is_read'] != true);
                
                if (hasUnread) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markMessagesAsRead();
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true, // Scroll from bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myId;
                    final time = DateFormat.jm().format(DateTime.parse(msg['created_at']).toLocal());
                    
                    return _buildMessageBubble(
                      context, 
                      msg['content'] ?? '', 
                      isMe, 
                      time,
                      imageUrl: msg['image_url'],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(context),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, String text, bool isMe, String time, {String? imageUrl}) {
    final theme = Theme.of(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppPalette.primary : theme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey.withOpacity(0.1),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 100,
                    width: double.infinity,
                    color: Colors.grey.withOpacity(0.1),
                    child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                  ),
                ),
              ),
              const Gap(8),
            ],
            if (text.isNotEmpty)
              Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                  fontSize: 15,
                ),
              ),
            const Gap(4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: isMe ? Colors.white.withOpacity(0.7) : theme.disabledColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_rounded, color: AppPalette.primary, size: 20),
              const Gap(8),
              const Text(
                'Image Preview',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppPalette.primary),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _selectedImage = null),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb 
              ? Image.network(_selectedImage!.path, height: 150, fit: BoxFit.cover)
              : Image.file(File(_selectedImage!.path), height: 150, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildImagePreview(),
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_a_photo_outlined, color: AppPalette.primary),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: AppPalette.primary),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 4,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppPalette.primary),
                  onPressed: _handleSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
