import 'package:flutter/material.dart';
import 'dart:async';
import '../../requests/screens/requests_list_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../chat/screens/chat_list_screen.dart'; // Will create placeholder
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../requests/widgets/active_pickup_floating_card.dart';
import '../../../core/theme/color_palette.dart';

import '../../../core/services/notification_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const RequestsListScreen(),
    const ChatListScreen(), // Placeholder
    const ProfileScreen(),
  ];

  // Track handled redirects to prevent loops
  final Set<String> _handledRedirects = {};
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize notifications (ask permission + save token)
    NotificationService().initialize();
    
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.tokenRefreshed || 
          data.event == AuthChangeEvent.signedIn) {
        if (mounted) setState(() {}); // Rebuild to refresh streams with new token
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }



  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: myId == null ? const Stream.empty() : Supabase.instance.client
            .from('pickup_requests')
            .stream(primaryKey: ['id'])
            .order('updated_at', ascending: false)
            .map((list) => list.where((req) => 
                (req['requester_id'] == myId || req['carrier_id'] == myId) && 
                (req['status'] == 'ACCEPTED' || req['status'] == 'IN_TRANSIT')
            ).toList()),
        builder: (context, snapshot) {
          Map<String, dynamic>? activeRequest;
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            activeRequest = snapshot.data!.first;
            
            // One-time Redirect Logic
            final reqId = activeRequest['id'];
            final status = activeRequest['status'];
            final redirectKey = '$reqId-$status'; // Composite key to redirect on status change too

            if (!_handledRedirects.contains(redirectKey)) {
              _handledRedirects.add(redirectKey);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                 final location = GoRouterState.of(context).uri.toString();
                 if (!location.startsWith('/active_pickup')) {
                    context.push('/active_pickup', extra: activeRequest);
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(
                         content: Text('Your pickup is active!'),
                         backgroundColor: AppPalette.success,
                         duration: Duration(seconds: 2),
                       ),
                    );
                 }
              });
            }
          }

          return Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),
              
              // Floating Active Pickup Indicator
              if (activeRequest != null)
                Positioned(
                  bottom: 16, // Above bottom nav? No, MainScreen is usually above nav or contains it? 
                  // MainScreen HAS BottomNavigationBar. Scaffold body does not include it.
                  // So Positioned bottom: 0 is right above Body bottom.
                  // But we want it ABOVE the BottomNavigationBar? 
                  // Currently Scaffold body is separate from BottomNav.
                  // If we want it floating OVER everything, we should put it in Scaffold floatingActionButton or just bottom of body.
                  // Let's create a nice effect at the bottom of the body area.
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ActivePickupFloatingCard(
                      request: activeRequest, 
                      isRequester: activeRequest['requester_id'] == myId,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: AppPalette.primary,
          unselectedItemColor: Theme.of(context).disabledColor,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
             BottomNavigationBarItem(
              icon: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('messages')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false)
                    .map((messages) => messages.where((msg) => 
                        msg['receiver_id'] == Supabase.instance.client.auth.currentUser?.id && 
                        msg['is_read'] != true
                    ).toList()),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.hasData ? snapshot.data!.length : 0;
                  return Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
                    child: const Icon(Icons.chat_bubble_rounded),
                  );
                },
              ),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
