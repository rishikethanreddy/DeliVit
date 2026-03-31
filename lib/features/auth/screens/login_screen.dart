
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/color_palette.dart';
// import '../../../widgets/primary_button.dart';
// import '../../../widgets/custom_text_field.dart';
import '../../../core/services/notification_service.dart';
import 'package:flutter/foundation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // Android / iOS / Web common implementation
      const webClientId = '1061488715765-kusg6mumb86dkkbomds0a47sfnca3ns3.apps.googleusercontent.com';
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? webClientId : null,
        serverClientId: kIsWeb ? null : webClientId,
        // Extremely restrictive scopes: By passing an empty array, we prevent the library
        // from injecting the default 'profile' scope, which natively forces the
        // People API requirement on the web.
        scopes: [], 
      );
      
      await googleSignIn.signOut();
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) throw 'No ID Token found.';

      final authResponse = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      final user = authResponse.user;
      if (user == null) throw 'Login failed';

      // Check if profile exists and is complete
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        await NotificationService().initialize();

        // Check for missing critical fields
        final isComplete = profile != null &&
            (profile['full_name'] as String?)?.isNotEmpty == true &&
            (profile['phone_number'] as String?)?.isNotEmpty == true &&
            (profile['reg_number'] as String?)?.isNotEmpty == true &&
            (profile['hostel_block'] as String?)?.isNotEmpty == true;

        if (!isComplete) {
          // Redirect to Profile Setup with pre-filled data from Google
          context.go('/profile_setup', extra: {
            'full_name': user.userMetadata?['full_name'] ?? googleUser.displayName,
            'avatar_url': user.userMetadata?['avatar_url'] ?? googleUser.photoUrl,
            'email': user.email,
          });
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: $e'), backgroundColor: AppPalette.error),
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Base Background
          Container(
            color: theme.colorScheme.background,
          ),




          // Content
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(Icons.lock_person_rounded, size: 40, color: AppPalette.primary),
                        ),
                        const Gap(32),
                        Text(
                          'Welcome Back',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'Sign in to your account',
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(60),
                  
                  FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    delay: const Duration(milliseconds: 200),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google Button
                        _buildIconBtn(
                          onTap: _isLoading ? null : _googleSignIn,
                          iconPath: 'assets/icons/google.svg',
                          label: 'Google',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn({
    required VoidCallback? onTap,
    String? iconPath,
    IconData? icon,
    bool isVector = true,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVector && iconPath != null)
                  SvgPicture.asset(iconPath, width: 24, height: 24)
                else
                  Icon(icon, size: 24, color: AppPalette.textPrimary),
                const Gap(12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
