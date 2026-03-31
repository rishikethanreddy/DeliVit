import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/color_palette.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/custom_text_field.dart';

class CreateRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? initialRequest;
  const CreateRequestScreen({super.key, this.initialRequest});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _descController = TextEditingController();
  final _feeController = TextEditingController();
  final _dropController = TextEditingController();
  
  String _itemType = 'Food';
  String _partner = 'Swiggy';
  
  final List<String> _itemTypes = ['Food', 'Parcel', 'Essentials', 'Medicine', 'Other'];
  final List<String> _partners = ['Swiggy', 'Zomato', 'Amazon', 'Flipkart', 'Other'];
  
  @override
  void initState() {
    super.initState();
    if (widget.initialRequest != null) {
      final req = widget.initialRequest!;
      _itemType = req['item_type'] ?? 'Food';
      _partner = req['delivery_partner'] ?? 'Swiggy';
      _dropController.text = req['drop_location'] ?? '';
      _feeController.text = (req['transport_fee'] as num).toString();
      _descController.text = req['description'] ?? '';
      
      // Ensure dropdown values are valid
      if (!_itemTypes.contains(_itemType)) _itemType = 'Other';
      if (!_partners.contains(_partner)) _partner = 'Other';
    }
  }

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.initialRequest != null ? 'Edit Pickup Request' : 'New Pickup Request'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel(context, 'What are you ordering?'),
            const Gap(12),
            DropdownButtonFormField<String>(
              value: _itemType,
              items: _itemTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _itemType = v!),
              decoration: _inputDecoration(context, 'Item Type'),
              dropdownColor: theme.colorScheme.surface,
            ),
             const Gap(16),
             DropdownButtonFormField<String>(
              value: _partner,
              items: _partners.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _partner = v!),
              decoration: _inputDecoration(context, 'Delivery Partner'),
              dropdownColor: theme.colorScheme.surface,
            ),
             const Gap(24),

            _buildSectionLabel(context, 'Drop Details'),
            const Gap(12),
            CustomTextField(
              label: 'Drop Location',
              hint: 'e.g. L Block Main Gate',
              controller: _dropController,
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
             const Gap(16),
            CustomTextField(
              label: 'Transport Fee (₹)',
              hint: 'e.g. 30',
              controller: _feeController,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.currency_rupee_rounded),
            ),
             const Gap(24),

            _buildSectionLabel(context, 'Additional Info'),
            const Gap(12),
             CustomTextField(
              label: 'Description / Instructions',
              hint: 'e.g. Call me when you reach main gate',
              controller: _descController,
              keyboardType: TextInputType.multiline,
            ),
            
            const Gap(32),
              PrimaryButton(
              text: widget.initialRequest != null ? 'Update Request' : 'Post Request',
              isLoading: _isLoading,
              onPressed: () async {
                 if (_dropController.text.isEmpty || _feeController.text.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Please fill required fields')),
                   );
                   return;
                 }

                 setState(() => _isLoading = true);
                 try {
                   final userId = Supabase.instance.client.auth.currentUser?.id;
                   if (userId == null) throw 'User not logged in';

                   final requestData = {
                     'requester_id': userId,
                     'item_type': _itemType,
                     'delivery_partner': _partner,
                     'drop_location': _dropController.text,
                     'transport_fee': double.tryParse(_feeController.text) ?? 0,
                     'description': _descController.text,
                     'pickup_mode': 'Paid', // Assuming 'Paid' for now, or use existing
                     // Status is NOT updated during edit to preserve flow, or reset if needed (but requirement says only WAITING can be edited so it stays WAITING)
                     // If it's a new request, set status to WAITING
                     if (widget.initialRequest == null) 'status': 'WAITING',
                   };

                   if (widget.initialRequest != null) {
                     // Update existing
                      await Supabase.instance.client
                         .from('pickup_requests')
                         .update(requestData)
                         .eq('id', widget.initialRequest!['id']);
                      
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request updated successfully!'), backgroundColor: AppPalette.success),
                        );
                         context.pop(true); // Return true to indicate change
                      }
                   } else {
                     // Insert new
                     await Supabase.instance.client.from('pickup_requests').insert(requestData);
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request posted successfully!'), backgroundColor: AppPalette.success),
                        );
                        context.pop(true);
                      }
                   }
                 } catch (e) {
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Error: $e'), backgroundColor: AppPalette.error),
                     );
                   }
                 } finally {
                    if(mounted) setState(() => _isLoading = false);
                 }
              },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      fillColor: Theme.of(context).cardColor, // Use cardColor instead of explicitly surface if cleaner
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
