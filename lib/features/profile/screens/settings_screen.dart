import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
    });
  }

  Future<void> _togglePushNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', value);
    setState(() {
      _pushNotifications = value;
    });
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) context.go('/login');
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }



  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('General'),
          _buildSwitchTile(
            context, 
            'Push Notifications', 
            _pushNotifications, 
            _togglePushNotifications,
          ),
          _buildSwitchTile(
            context,
            'Dark Mode',
            isDark,
            (val) {
               ref.read(themeProvider.notifier).toggleTheme(val);
            },
          ),
          // _buildTile(context, 'Language', subtitle: 'English'), // Removed for MVPI
          
          const SizedBox(height: 24),
          _buildSectionHeader('Account'),
          _buildTile(
            context, 
            'Privacy Policy', 
            onTap: () => context.push('/privacy_policy'),
          ),
          _buildTile(
            context, 
            'Terms of Service',
             onTap: () => context.push('/terms_of_service'),
          ),
          _buildTile(
            context, 
            'Logout', 
            isDestructive: true,
            onTap: () => _logout(context),
          ),

        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppPalette.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, 
    String title, 
    bool value, 
    ValueChanged<bool> onChanged
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppPalette.primary,
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, 
    String title, 
    {String? subtitle, 
    bool isDestructive = false,
    required VoidCallback onTap}
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive ? AppPalette.error : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        trailing: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(color: AppPalette.textSecondary),
              )
            : const Icon(Icons.chevron_right_rounded, color: AppPalette.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
