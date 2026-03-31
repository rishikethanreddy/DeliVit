import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class LocationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Checks and requests location permission
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale 
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately. 
      return false;
    } 

    return true;
  }

  /// Starts streaming location to Firebase
  /// [requestId] is the ID of the active pickup request
  Future<void> startSharingLocation(String requestId) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) throw Exception('Location permission denied');

    final LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, 
      intervalDuration: const Duration(seconds: 3),
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        print("Sending location: ${position.latitude}, ${position.longitude}");
        _database.ref('pickups/$requestId/location').set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'speed': position.speed,
          'timestamp': DateTime.now().toIso8601String(),
        });
      },
      onError: (e) {
         print("Location stream error: $e");
      }
    );
  }

  /// Stops streaming location
  Future<void> stopSharingLocation() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Returns a stream of location updates for a specific request (for Requester)
  Stream<DatabaseEvent> getLocationStream(String requestId) {
    return _database.ref('pickups/$requestId/location').onValue;
  }
}
