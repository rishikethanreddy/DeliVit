import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../core/theme/color_palette.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../core/services/notification_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _hostelController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  File? _selectedImage;
  String _residentType = 'Hosteller';

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        String? avatarUrl;
        
        // Upload Avatar if selected
        if (_selectedImage != null) {
          try {
             final userId = response.user!.id;
             final fileExt = _selectedImage!.path.split('.').last;
             final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
             
             await Supabase.instance.client.storage
                .from('avatars')
                .upload(fileName, _selectedImage!);
                
             avatarUrl = Supabase.instance.client.storage
                .from('avatars')
                .getPublicUrl(fileName);
          } catch (e) {
             print('Avatar upload failed: $e');
             // Proceed without avatar
          }
        }

        await Supabase.instance.client.from('profiles').insert({
          'id': response.user!.id,
          'full_name': _nameController.text.trim(),
          'reg_number': _regNoController.text.trim(),
          'hostel_block': _hostelController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'avatar_url': avatarUrl,
        });
        
        if (mounted) {
           if (response.session != null) {
              await NotificationService().initialize();
              context.go('/home');
           } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please verify your email to login.')),
              );
              context.go('/login');
           }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppPalette.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unexpected error during signup'), backgroundColor: AppPalette.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Column(
                children: [
                   Text(
                    'Join VIT Pick',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                   Text(
                    'Fill in your details to get started.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                  const Gap(32),

                  // Avatar Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                         CircleAvatar(
                           radius: 50,
                           backgroundColor: AppPalette.primary.withOpacity(0.1),
                           backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                           child: _selectedImage == null 
                               ? const Icon(Icons.camera_alt, size: 40, color: AppPalette.primary)
                               : null,
                         ),
                         /* 
                         // Optional: Add plus icon if needed, but simple camera icon inside is clean enough
                         Positioned(
                           bottom: 0,
                           right: 0,
                           child: Container(
                             padding: const EdgeInsets.all(4),
                             decoration: const BoxDecoration(color: AppPalette.primary, shape: BoxShape.circle),
                             child: const Icon(Icons.add, color: Colors.white, size: 20),
                           ),
                         ), 
                         */
                      ],
                    ),
                  ),
                  const Gap(32),
                  
                  CustomTextField(
                    label: 'Full Name',
                    hint: 'John Doe',
                    controller: _nameController,
                    prefixIcon: Icon(Icons.person_outline, color: theme.disabledColor),
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const Gap(16),

                   CustomTextField(
                    label: 'Phone Number',
                    hint: '9876543210',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icon(Icons.phone_outlined, color: theme.disabledColor),
                    validator: (v) => v!.isEmpty ? 'Phone number is required' : null,
                  ),
                  const Gap(16),
                  
                  CustomTextField(
                    label: 'Registration Number',
                    hint: '21BCE1234',
                    controller: _regNoController,
                    prefixIcon: Icon(Icons.badge_outlined, color: theme.disabledColor),
                    validator: (v) => v!.isEmpty ? 'Reg No is required' : null,
                  ),
                  const Gap(16),
                  
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
                            _hostelController.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const Gap(16),
                  
                  if (_residentType == 'Hosteller') ...[
                    CustomTextField(
                      label: 'Hostel Block',
                      hint: 'L Block',
                      controller: _hostelController,
                      prefixIcon: Icon(Icons.apartment_rounded, color: theme.disabledColor),
                      validator: (v) => v!.isEmpty ? 'Hostel block is required' : null,
                    ),
                    const Gap(16),
                  ],
                  
                  CustomTextField(
                    label: 'VIT Email',
                    hint: 'firstname.lastname202X@vitstudent.ac.in',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icon(Icons.email_outlined, color: theme.disabledColor),
                    validator: (value) {
                       if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@vitstudent.ac.in')) {
                        return 'Please use your VIT email';
                      }
                      return null;
                    },
                  ),
                  const Gap(16),
                  
                  CustomTextField(
                    label: 'Password',
                    hint: 'Create a strong password',
                    controller: _passwordController,
                    obscureText: true,
                    prefixIcon: Icon(Icons.lock_outline, color: theme.disabledColor),
                    validator: (v) => v != null && v.length < 6 ? 'Password too short' : null,
                  ),
                  
                  const Gap(32),
                  PrimaryButton(
                    text: 'Sign Up',
                    onPressed: _signup,
                    isLoading: _isLoading,
                  ),
                  const Gap(24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text(
                        "Already have an account? ",
                        style: TextStyle(color: theme.disabledColor),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: AppPalette.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                   const Gap(32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
