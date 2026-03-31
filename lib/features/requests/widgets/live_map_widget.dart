import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/color_palette.dart';

class LiveMapWidget extends StatefulWidget {
  final String requestId;
  final bool isCarrier;
  final String? dropLocationQuery; 
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;

  const LiveMapWidget({
    super.key, 
    required this.requestId, 
    required this.isCarrier,
    this.dropLocationQuery,
    this.pickupLocation,
    this.dropoffLocation,
  });

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();
  
  // Markers & Polylines
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Realtime subscription
  StreamSubscription<DatabaseEvent>? _locationSubscription;

  // Initial generic location (VIT Vellore ish)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(12.9692, 79.1559),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _setupInitialMap();
    _initializeMap();
  }

  void _setupInitialMap() {
    if (widget.pickupLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ));
    }
    if (widget.dropoffLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: widget.dropoffLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Drop-off'),
      ));
    }

    if (widget.pickupLocation != null && widget.dropoffLocation != null) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [widget.pickupLocation!, widget.dropoffLocation!],
        color: Colors.green,
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    }
  }

  Future<void> _adjustBounds() async {
     if (widget.pickupLocation == null || widget.dropoffLocation == null) return;
     try {
       final controller = await _controller.future;
       
       double minLat = widget.pickupLocation!.latitude;
       double minLng = widget.pickupLocation!.longitude;
       double maxLat = widget.pickupLocation!.latitude;
       double maxLng = widget.pickupLocation!.longitude;

       void extend(LatLng p) {
         if (p.latitude < minLat) minLat = p.latitude;
         if (p.latitude > maxLat) maxLat = p.latitude;
         if (p.longitude < minLng) minLng = p.longitude;
         if (p.longitude > maxLng) maxLng = p.longitude;
       }

       extend(widget.dropoffLocation!);
       
       // Extend to carrier if we have it
       final carrierMarker = _markers.where((m) => m.markerId.value == 'carrier').firstOrNull;
       if (carrierMarker != null) extend(carrierMarker.position);

       controller.animateCamera(CameraUpdate.newLatLngBounds(
         LatLngBounds(
           southwest: LatLng(minLat, minLng),
           northeast: LatLng(maxLat, maxLng),
         ),
         80.0, // padding
       ));
     } catch(e) { /* ignore if map not ready */ }
  }

  Future<void> _initializeMap() async {
    if (widget.isCarrier) {
      // If carrier, start sharing location
      try {
        await _locationService.startSharingLocation(widget.requestId);
      } catch (e) {
        print("Error sharing location: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission needed for delivery')));
      }
    } else {
      // If requester, listen to carrier location
      _locationSubscription = _locationService.getLocationStream(widget.requestId).listen((event) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          final lat = data['latitude'] as double;
          final lng = data['longitude'] as double;
          final heading = data['heading'] as double? ?? 0.0;
          
          _updateCarrierMarker(LatLng(lat, lng), heading);
        }
      });
    }
  }
  
  void _updateCarrierMarker(LatLng pos, double heading) async {
    final marker = Marker(
      markerId: const MarkerId('carrier'),
      position: pos,
      rotation: heading,
      anchor: const Offset(0.5, 0.5),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'Carrier'),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'carrier');
      _markers.add(marker);
      
      // Update polyline to show path from carrier to destination
      if (widget.dropoffLocation != null) {
        _polylines.removeWhere((p) => p.polylineId.value == 'route');
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: [pos, widget.dropoffLocation!],
          color: Colors.green,
          width: 6,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));
      }
    });

    // Smoothly animate camera to follow carrier
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(pos));
  }
  
  @override
  void dispose() {
    if (widget.isCarrier) {
      _locationService.stopSharingLocation();
    }
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      mapType: MapType.satellite,
      initialCameraPosition: widget.pickupLocation != null 
          ? CameraPosition(target: widget.pickupLocation!, zoom: 15) 
          : _initialPosition,
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: widget.isCarrier, 
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      onMapCreated: (GoogleMapController controller) {
        _controller.complete(controller);
        // Remove custom styles for Satellite mode to keep labels visible
        Future.delayed(const Duration(milliseconds: 500), _adjustBounds);
      },
    );
  }
}
