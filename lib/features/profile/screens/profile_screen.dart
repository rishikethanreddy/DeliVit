import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/color_palette.dart';

import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _profile = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading profile')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleCarrierMode(bool value) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Optimistic update
      setState(() {
         _profile!['is_carrier_mode'] = value;
      });

      await Supabase.instance.client.from('profiles').update({
        'is_carrier_mode': value,
        'carrier_mode_enabled_at': value ? DateTime.now().toIso8601String() : null,
      }).eq('id', userId);
      
    } catch (e) {
       // Revert on error
       setState(() {
         _profile!['is_carrier_mode'] = !value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }



  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppPalette.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String fullName = _profile?['full_name'] ?? 'User';
    final String regNo = _profile?['reg_number'] ?? '';
    final String block = _profile?['hostel_block'] ?? '';
    final bool isCarrier = _profile?['is_carrier_mode'] ?? false;
    final String rating = (_profile?['rating'] ?? 5.0).toString();
    final String pickups = (_profile?['pickups_completed'] ?? 0).toString();

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [

          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              // Navigate to Edit Profile and refresh on return
              final startArgs = _profile ?? {};
              await context.push('/profile_setup', extra: startArgs);
              _fetchProfile();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surface,
                      image: _profile?['avatar_url'] != null 
                        ? DecorationImage(
                            image: NetworkImage(_profile!['avatar_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _profile?['avatar_url'] == null 
                      ? Center(
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.disabledColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  ),
                  const Gap(16),
                  Text(
                    fullName,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$regNo • $block',
                    style: textTheme.bodyMedium?.copyWith(
                       color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(32),

            // Carrier Mode Toggle Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCarrier ? AppPalette.primary : theme.disabledColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isCarrier ? AppPalette.primary.withOpacity(0.3) : Colors.black12,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Colors.white),
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         const Text(
                          'Carrier Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                         Text(
                          isCarrier ? 'You are accepting requests' : 'Switch to accept requests',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isCarrier,
                    onChanged: _toggleCarrierMode,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.greenAccent,
                  ),
                ],
              ),
            ),
            const Gap(24),

            // Stats Row
            Row(
              children: [
                _buildStatCard(context, 'Completed', pickups, Icons.check_circle_rounded, AppPalette.success),
              ],
            ),
            const Gap(24),

            // Options List
            _buildOptionTile(
              context,
              icon: Icons.history_rounded,
              title: 'Pickup History',
              onTap: () => context.push('/pickup_history'), 
            ),
             _buildOptionTile(
              context,
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              onTap: () async {
                final Uri emailLaunchUri = Uri.parse('mailto:rishikethanreddywork@gmail.com?subject=Help and Support Request');
                try {
                  await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email app. Please email rishikethanreddywork@gmail.com directly.')));
                  }
                }
              },
            ),
             _buildOptionTile(
              context,
              icon: Icons.logout_rounded,
              title: 'Logout',
              isDestructive: true,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), // Softer shadow for dark mode
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const Gap(8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive ? AppPalette.error.withOpacity(0.1) : AppPalette.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDestructive ? AppPalette.error : AppPalette.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
             fontWeight: FontWeight.w500,
             color: isDestructive ? AppPalette.error : theme.textTheme.bodyMedium?.color,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: theme.disabledColor),
        onTap: onTap,
      ),
    );
  }
}
