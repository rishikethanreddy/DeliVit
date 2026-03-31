import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/color_palette.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/custom_text_field.dart';

class ProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const ProfileSetupScreen({super.key, this.initialData});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _hostelController = TextEditingController();
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  String? _avatarUrl;
  String _residentType = 'Hosteller';

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['full_name'] ?? '';
      _regNoController.text = widget.initialData!['reg_number'] ?? '';
      _hostelController.text = widget.initialData!['hostel_block'] ?? '';
      _phoneController.text = widget.initialData!['phone_number'] ?? '';
      _avatarUrl = widget.initialData!['avatar_url'];
      if (_hostelController.text == 'Day Scholar') {
        _residentType = 'Day Scholar';
      } else {
        _residentType = 'Hosteller';
      }
    }
  }



  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final updates = {
        'id': userId,
        'full_name': _nameController.text,
        'reg_number': _regNoController.text,
        'hostel_block': _hostelController.text,
        'phone_number': _phoneController.text,
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client
          .from('profiles')
          .upsert(updates);
      
      if (mounted) {
      if (mounted) {
        if (context.canPop()) {
          context.pop(); // Go back if pushed (Editing)
        } else {
          context.go('/home'); // Go to Home if navigated via go (Onboarding)
        }
      }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
         title: Text(widget.initialData != null ? 'Edit Profile' : 'Complete Profile'),
         centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppPalette.primary.withOpacity(0.1),
              backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
              child: _avatarUrl == null 
                  ? Text(
                      _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 40, color: AppPalette.primary, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const Gap(32),
             CustomTextField(
              label: 'Full Name',
              hint: 'e.g. Adarsh Pal',
              controller: _nameController,
            ),
             const Gap(24),
             CustomTextField(
              label: 'Phone Number',
              hint: 'e.g. 9876543210',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
             const Gap(24),
             CustomTextField(
              label: 'Registration Number',
              hint: 'e.g. 21BCE0001',
              controller: _regNoController,
            ),
             const Gap(24),
             SizedBox(
               width: double.infinity,
               child: SegmentedButton<String>(
                 segments: const [
                   ButtonSegment(value: 'Hosteller', label: Text('Hosteller')),
                   ButtonSegment(value: 'Day Scholar', label: Text('Day Scholar')),
                 ],
                 selected: {_residentType},
                 onSelectionChanged: (newSelection) {
                   setState(() {
                     _residentType = newSelection.first;
                     if (_residentType == 'Day Scholar') {
                       _hostelController.text = 'Day Scholar';
                     } else {
                       if (_hostelController.text == 'Day Scholar') {
                         _hostelController.clear();
                       }
                     }
                   });
                 },
               ),
             ),
             const Gap(24),
             if (_residentType == 'Hosteller') ...[
               CustomTextField(
                 label: 'Hostel Block',
                 hint: 'e.g. L Block',
                 controller: _hostelController,
                 validator: (v) => v!.isEmpty ? 'Hostel block is required' : null,
               ),
               const Gap(24),
             ],
             const Gap(24),
            PrimaryButton(
              text: 'Save Details',
              isLoading: _isLoading,
              onPressed: _saveProfile,
            ),
          ],
        ),
      ),
    );
  }
}
