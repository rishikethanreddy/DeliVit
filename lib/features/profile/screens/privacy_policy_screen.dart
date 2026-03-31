import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_palette.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
              style: const TextStyle(color: AppPalette.textSecondary),
            ),
            const SizedBox(height: 32),
            _buildSection(context, '1. Information We Collect', 'When you register for Vitpick, we collect basic profile information including your name, email, registration number, and hostel block. We also collect real-time location data when you are acting as an active carrier to securely track deliveries.'),
            _buildSection(context, '2. How We Use Information', 'Your information is fundamentally used to facilitate pickup requests. Requester names and active pickup locations are shared exclusively with the paired carrier during an active delivery session.'),
            _buildSection(context, '3. Data Security', 'All authentication and database operations are securely processed via Supabase. We implement standard security measures to protect your personal information against unauthorized access or disclosure.'),
            _buildSection(context, '4. Your Rights', 'You have the right to request the deletion of your account and associated profile data at any time by contacting our support team.'),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© ${DateTime.now().year} Vitpick. All rights reserved.',
                style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
