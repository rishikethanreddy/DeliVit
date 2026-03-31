import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_palette.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
              'Terms of Service',
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
            _buildSection(context, '1. Acceptance of Terms', 'By accessing and using the Vitpick application, you agree to be bound by these Terms of Service. If you do not agree with any part of these terms, you may not use our service.'),
            _buildSection(context, '2. User Conduct', 'Users agree to use the service for lawful purposes only. Carriers agree to perform their deliveries truthfully and safely, while Requesters agree to provide accurate information regarding their pickup requests.'),
            _buildSection(context, '3. Service Limitations', 'Vitpick acts as a facilitator between requesters and carriers. We do not guarantee the completion of any request and are not liable for lost or damaged goods during transit.'),
            _buildSection(context, '4. Account Termination', 'We reserve the right to suspend or terminate accounts that violate these terms, including fraudulent activity or repeated cancellations without valid reasons.'),
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
