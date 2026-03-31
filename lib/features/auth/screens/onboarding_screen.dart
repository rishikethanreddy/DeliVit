import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/color_palette.dart';
import '../../../widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Easy Campus Pickups',
      'description': 'Order something to the main gate? Find someone to pick it up for you instantly.',
      'icon': 'inventory_2_rounded',
    },
    {
      'title': 'Help & Earn',
      'description': 'Going inside campus? Pick up items for others and earn rewards or help a friend.',
      'icon': 'delivery_dining_rounded',
    },
    {
      'title': 'Secure & Trusted',
      'description': 'Verified VIT students only. Complete safety for your packages.',
      'icon': 'verified_user_rounded',
    },
  ];

  void _onNext() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) => _OnboardingContent(
                  data: _onboardingData[index],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _onboardingData.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppPalette.primary
                                : theme.disabledColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    FadeInUp(
                      child: PrimaryButton(
                        text: _currentPage == _onboardingData.length - 1
                            ? 'Get Started'
                            : 'Next',
                        onPressed: _onNext,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_currentPage != _onboardingData.length - 1)
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text('Skip', style: TextStyle(color: theme.disabledColor)),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  final Map<String, String> data;

  const _OnboardingContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Determine icon based on string name mockup
    IconData iconData;
    switch (data['icon']) {
      case 'inventory_2_rounded':
        iconData = Icons.inventory_2_rounded;
        break;
      case 'delivery_dining_rounded':
        iconData = Icons.delivery_dining_rounded;
        break;
      case 'verified_user_rounded':
        iconData = Icons.verified_user_rounded;
        break;
      default:
        iconData = Icons.info;
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppPalette.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              size: 80,
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            data['title']!,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data['description']!,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: theme.disabledColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
