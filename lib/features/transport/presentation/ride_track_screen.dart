import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart' show MapsObjectId;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';
import 'package:zippup/features/transport/providers/ride_service.dart';
import 'package:zippup/services/location/distance_service.dart';
import 'package:zippup/services/notifications/sound_service.dart';
import 'package:zippup/services/currency/currency_service.dart';
import 'package:go_router/go_router.dart';

class RideTrackScreen extends StatefulWidget {
 const RideTrackScreen({super.key, required this.rideId});
 final String rideId;

 @override
 State<RideTrackScreen> createState() => _RideTrackScreenState();
}

class _RideTrackScreenState extends State<RideTrackScreen> {
 final _distance = DistanceService();
 final _rideService = RideService();
 Set<Polyline> _polylines = {};
 int? _etaMinutes;
 DateTime? _waitingSince;
 bool _mockStarted = false;
 // Rider-side simulation when no live driver location
 Timer? _riderSimTimer;
 LatLng? _simulatedDriver;
 bool _shownSummary = false;
 bool _isDriver = false;

 @override
 void dispose() {
  _riderSimTimer?.cancel();
  _riderSimTimer = null;
  super.dispose();
 }

 Future<void> _updateRideStatus(String rideId, RideStatus status) async {
  try {
   await FirebaseFirestore.instance.collection('rides').doc(rideId).update({
	'status': status.name,
	'updatedAt': FieldValue.serverTimestamp(),
   });
   
   // Play completion sound for completed rides
   if (status == RideStatus.completed) {
	SoundService.instance.playTrill();
   }
   
   print('✅ Updated ride $rideId to status: ${status.name}');
  } catch (e) {
   print('❌ Failed to update ride status: $e');
   if (mounted) {
	ScaffoldMessenger.of(context).showSnackBar(
	 SnackBar(content: Text('Failed to update status: $e')),
	);
   }
  }
 }

 List<Widget> _getDriverActions(Ride ride, Map<String, dynamic> data) {
  if (!_isDriver) return [];
  
  final driverLat = (data['driverLat'] as num?)?.toDouble();
  final driverLng = (data['driverLng'] as num?)?.toDouble();
  final pickupLat = (data['pickupLat'] as num?)?.toDouble();
  final pickupLng = (data['pickupLng'] as num?)?.toDouble();
  final destLat = (data['destLat'] as num?)?.toDouble();
  final destLng = (data['destLng'] as num?)?.toDouble();
  
  // Navigation button for active rides
  Widget? navButton;
  if (driverLat != null && driverLng != null) {
    double? targetLat, targetLng;
    String navLabel = 'Navigate';
    
    // Determine navigation target based on ride status
    if ((ride.status == RideStatus.accepted || ride.status == RideStatus.arriving) && 
        pickupLat != null && pickupLng != null) {
      targetLat = pickupLat;
      targetLng = pickupLng;
      navLabel = 'Navigate to Pickup';
    } else if ((ride.status == RideStatus.arrived || ride.status == RideStatus.enroute) && 
               destLat != null && destLng != null) {
      targetLat = destLat;
      targetLng = destLng;
      navLabel = 'Navigate to Destination';
    }
    
    if (targetLat != null && targetLng != null) {
      navButton = OutlinedButton.icon(
        onPressed: () => _openGoogleNavigation(driverLat, driverLng, targetLat!, targetLng!),
        icon: const Icon(Icons.navigation),
        label: Text(navLabel),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
        ),
      );
    }
  }
  
  List<Widget> actions = [];
  
  switch (ride.status) {
   case RideStatus.accepted:
    actions.add(ElevatedButton.icon(
     onPressed: () => _updateRideStatus(ride.id, RideStatus.arriving),
     icon: const Icon(Icons.directions_car),
     label: const Text('I\'m on my way'),
     style: ElevatedButton.styleFrom(
      backgroundColor: Colors.orange,
      foregroundColor: Colors.white,
     ),
    ));
    break;
   case RideStatus.arriving:
    actions.add(ElevatedButton.icon(
     onPressed: () => _updateRideStatus(ride.id, RideStatus.arrived),
     icon: const Icon(Icons.location_on),
     label: const Text('I have arrived'),
     style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
     ),
    ));
    break;
   case RideStatus.arrived:
    actions.add(ElevatedButton.icon(
     onPressed: () => _updateRideStatus(ride.id, RideStatus.enroute),
     icon: const Icon(Icons.play_arrow),
     label: const Text('Start Trip'),
     style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
     ),
    ));
    break;
   case RideStatus.enroute:
    actions.add(ElevatedButton.icon(
     onPressed: () => _updateRideStatus(ride.id, RideStatus.completed),
     icon: const Icon(Icons.check_circle),
     label: const Text('Complete Trip'),
     style: ElevatedButton.styleFrom(
      backgroundColor: Colors.purple,
      foregroundColor: Colors.white,
     ),
    ));
    break;
   default:
    break;
  }
  
  // Add navigation button if available - make it prominent
  if (navButton != null) {
    actions.insert(0, navButton); // Put navigation first for visibility
  }
  
  // Always add a fallback navigation option for drivers
  if (_isDriver && (pickupLat != null && pickupLng != null || destLat != null && destLng != null)) {
    final fallbackLat = (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving) 
        ? pickupLat : destLat;
    final fallbackLng = (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving) 
        ? pickupLng : destLng;
    
    if (fallbackLat != null && fallbackLng != null) {
      final fallbackLabel = (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving) 
          ? 'Navigate to Pickup' : 'Navigate to Destination';
      
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _openPhoneNavigation(fallbackLat, fallbackLng, fallbackLabel),
          icon: const Icon(Icons.map),
          label: Text('📱 $fallbackLabel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green,
            side: const BorderSide(color: Colors.green),
          ),
        ),
      );
    }
  }
  
  return actions;
 }

 List<String> _stepsFor(RideType type) => const ['Accepted', 'Arriving', 'Arrived', 'Enroute', 'Completed'];

 int _indexFor(RideStatus status, List<String> steps) {
  final map = {
   RideStatus.accepted: 'Accepted',
   RideStatus.arriving: 'Arriving',
   RideStatus.arrived: 'Arrived',
   RideStatus.enroute: 'Enroute',
   RideStatus.completed: 'Completed',
   RideStatus.cancelled: 'Completed',
   RideStatus.requested: 'Accepted',
  };
  final label = map[status] ?? 'Accepted';
  return steps.indexOf(label).clamp(0, steps.length - 1);
 }

 Future<void> _buildPolyline(String origin, String destination) async {
  try {
   print('🗺️ Building polyline from $origin to $destination');
   final poly = await _distance.getDirectionsPolyline(origin: origin, destination: destination);
   if (poly == null) {
    print('❌ No polyline data received from directions service');
    return;
   }
   print('✅ Polyline data received, decoding...');
   final points = _decodePolyline(poly);
   print('✅ Polyline decoded with ${points.length} points');
   setState(() {
    _polylines = {
     Polyline(polylineId: const PolylineId('route'), points: points, color: Colors.blue, width: 5),
    };
   });
   print('✅ Polyline added to map');
  } catch (e) {
   print('❌ Error building polyline: $e');
  }
 }

 Future<void> _updateEta({required double originLat, required double originLng, required double destLat, required double destLng}) async {
  try {
   final matrix = await _distance.getMatrix(origin: '$originLat,$originLng', destinations: ['$destLat,$destLng']);
   final elements = (matrix['rows'][0]['elements'] as List);
   for (final el in elements) {
	if (el['status'] == 'OK') {
	 setState(() => _etaMinutes = ((el['duration']['value'] as num).toInt() / 60).round());
	 return;
	}
   }
  } catch (_) {
   // ignore errors
  }
 }

 List<LatLng> _decodePolyline(String polyline) {
  int index = 0, len = polyline.length;
  int lat = 0, lng = 0;
  final List<LatLng> coordinates = [];
  while (index < len) {
   int b, shift = 0, result = 0;
   do {
	b = polyline.codeUnitAt(index++) - 63;
	result |= (b & 0x1f) << shift;
	shift += 5;
   } while (b >= 0x20);
   final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
   lat += dlat;
   shift = 0;
   result = 0;
   do {
	b = polyline.codeUnitAt(index++) - 63;
	result |= (b & 0x1f) << shift;
	shift += 5;
   } while (b >= 0x20);
   final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
   lng += dlng;
   coordinates.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return coordinates;
 }

 Future<void> _promptWaitRedirect() async {
  if (!mounted) return;
  final go = await showDialog<bool>(
   context: context,
   builder: (c) => AlertDialog(
	title: const Text('Provider is taking long to accept'),
	content: const Text('Do you want to try other providers or continue waiting?'),
	actions: [
	 TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continue waiting')),
	 FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Find others')),
	],
   ),
  );
  if (go == true && mounted) {
   context.push('/transport');
  } else {
   _waitingSince = DateTime.now();
  }
 }

 Future<void> _maybeStartMockAccept(Map<String, dynamic> data) async {
  if (_mockStarted) return;
  try {
   final conf = await FirebaseFirestore.instance.collection('_config').doc('mock').get();
   final auto = (conf.data() ?? const {})['autoAccept'] == true;
   if (!auto) return;
   _mockStarted = true;
   await Future.delayed(const Duration(seconds: 10));
   final pickupLat = (data['pickupLat'] as num?)?.toDouble();
   final pickupLng = (data['pickupLng'] as num?)?.toDouble();
   await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).set({
	'driverId': 'mock_driver',
	'status': 'accepted',
	if (pickupLat != null && pickupLng != null) 'driverLat': pickupLat,
	if (pickupLat != null && pickupLng != null) 'driverLng': pickupLng,
   }, SetOptions(merge: true));
  } catch (_) {}
 }

 @override
 Widget build(BuildContext context) {
  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
   stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
   builder: (context, snap) {
	if (!snap.hasData) {
	 return Scaffold(
	  appBar: AppBar(title: const Text('Track Ride')),
	  body: const Center(child: CircularProgressIndicator()),
	 );
	}
	
	final data = snap.data!.data() ?? {};
	final ride = Ride.fromJson(widget.rideId, data);
	final steps = _stepsFor(ride.type);
	final idx = _indexFor(ride.status, steps);
	
	// Check if current user is the driver
	final currentUserId = FirebaseAuth.instance.currentUser?.uid;
	_isDriver = currentUserId != null && currentUserId == ride.driverId;
	
	return Scaffold(
	 appBar: AppBar(title: Text(_isDriver ? 'Manage Ride' : 'Track Ride')),
	 body: _buildRideContent(context, ride, steps, idx, data),
	);
   },
  );
 }
 
 Widget _buildRideContent(BuildContext context, Ride ride, List<String> steps, int idx, Map<String, dynamic> data) {
  final driverLat = (data['driverLat'] as num?)?.toDouble();
  final driverLng = (data['driverLng'] as num?)?.toDouble();
  final pickupLat = (data['pickupLat'] as num?)?.toDouble();
  final pickupLng = (data['pickupLng'] as num?)?.toDouble();
  final destLat = (data['destLat'] as num?)?.toDouble();
  final destLng = (data['destLng'] as num?)?.toDouble();

  // On completion, show comprehensive summary with payment and rating - ONLY to the rider/customer
  if (ride.status == RideStatus.completed && !_shownSummary && !_isDriver) {
   _shownSummary = true;
   WidgetsBinding.instance.addPostFrameCallback((_) async {
	   // Play completion sound
	   try {
		await SoundService.instance.playTrill();
	   } catch (_) {}
	   
	   // Fetch appropriate profile info for summary
	   final profileUserId = _isDriver ? ride.riderId : ride.driverId;
	   String driverName = _isDriver ? 'Customer' : 'Driver';
	   String driverPhoto = '';
	   try {
		if (profileUserId != null) {
		 final results = await Future.wait([
		  FirebaseFirestore.instance.collection('public_profiles').doc(profileUserId).get(),
		  FirebaseFirestore.instance.collection('users').doc(profileUserId).get(),
		 ]);
		 final pu = results[0].data() ?? const {};
		 final u = results[1].data() ?? const {};
		 
		 if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
		  driverName = pu['name'].toString().trim();
		 } else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
		  driverName = u['name'].toString().trim();
		 }
		 
		 if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
		  driverPhoto = pu['photoUrl'].toString().trim();
		 } else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
		  driverPhoto = u['photoUrl'].toString().trim();
		 }
		}
	   } catch (_) {}
	   
	   await showDialog(context: context, builder: (_) {
		final fare = ride.fareEstimate;
		int? stars;
		final ctl = TextEditingController();
		String paymentMethod = 'card'; // Move outside StatefulBuilder
		
		return FutureBuilder<List<String>>(
			future: Future.wait([
				CurrencyService.getSymbol(),
				CurrencyService.getCode(),
			]),
			builder: (context, currencySnapshot) {
				final currencySymbol = currencySnapshot.data?[0] ?? CurrencyService.getCachedSymbol();
				final currencyCode = currencySnapshot.data?[1] ?? CurrencyService.getCachedCode();
				
				return StatefulBuilder(builder: (context, setDialogState) {
		 return AlertDialog(
		  title: const Text('🎉 Ride Completed!'),
		  content: SingleChildScrollView(
		   child: Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
			 // Show appropriate profile based on who is viewing
			 if ((_isDriver && ride.riderId != null) || (!_isDriver && ride.driverId != null)) Card(
			  child: ListTile(
			   leading: CircleAvatar(
				backgroundImage: driverPhoto.isNotEmpty ? NetworkImage(driverPhoto) : null,
				child: driverPhoto.isEmpty ? const Icon(Icons.person) : null,
			   ),
			   title: Text(driverName),
			   subtitle: Text('${_isDriver ? "Customer" : "Driver"} • ${ride.type.name.toUpperCase()}'),
			  ),
			 ),
			 const SizedBox(height: 16),
			 
			 // Trip details
			 Card(
			  child: Padding(
			   padding: const EdgeInsets.all(16),
			   child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				 const Text('Trip Details', style: TextStyle(fontWeight: FontWeight.bold)),
				 const SizedBox(height: 8),
				 Text('From: ${data['pickupAddress'] ?? 'Unknown'}'),
				 Text('To: ${data['destinationAddresses'] is List && (data['destinationAddresses'] as List).isNotEmpty ? (data['destinationAddresses'] as List).first.toString() : 'Unknown'}'),
				 if (data['distance'] != null) Text('Distance: ${(data['distance'] as num).toStringAsFixed(1)} km'),
				 if (data['duration'] != null) Text('Duration: ${((data['duration'] as num) / 60).toStringAsFixed(0)} min'),
				],
			   ),
			  ),
			  ),
			 const SizedBox(height: 16),
			 
			 // Payment section
			 Card(
			  color: Colors.green.shade50,
			  child: Padding(
			   padding: const EdgeInsets.all(16),
			   child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				 const Text('💳 Payment', style: TextStyle(fontWeight: FontWeight.bold)),
				 const SizedBox(height: 8),
				 Text('Amount to pay: $currencySymbol${fare.toStringAsFixed(2)}', 
				  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
				 const SizedBox(height: 12),
				 
				 // Payment method selection
				 const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.w600)),
				 const SizedBox(height: 8),
				 Row(
				  children: [
				   Expanded(
					child: Card(
					 child: RadioListTile<String>(
					  value: 'card',
					  groupValue: paymentMethod,
					  onChanged: (value) {
					   if (value != null) {
						setDialogState(() => paymentMethod = value);
					   }
					  },
					  title: const Text('💳 Card'),
					  subtitle: const Text('Auto-processed'),
					  dense: true,
					 ),
					),
				   ),
				   Expanded(
					child: Card(
					 child: RadioListTile<String>(
					  value: 'cash',
					  groupValue: paymentMethod,
					  onChanged: (value) {
					   if (value != null) {
						setDialogState(() => paymentMethod = value);
					   }
					  },
					  title: const Text('💵 Cash'),
					  subtitle: const Text('Pay driver'),
					  dense: true,
					 ),
					),
				   ),
				  ],
				 ),
				 const SizedBox(height: 8),
				 Text(
				  paymentMethod == 'card' 
				   ? 'Card payments are processed automatically.' 
				   : 'Please pay the driver $currencySymbol${fare.toStringAsFixed(2)} in cash.',
				  style: TextStyle(
				   color: paymentMethod == 'cash' ? Colors.orange[700] : Colors.grey[600], 
				   fontSize: 12,
				   fontWeight: paymentMethod == 'cash' ? FontWeight.w600 : FontWeight.normal,
				  ),
				 ),
				],
			   ),
			  ),
			 ),
			 const SizedBox(height: 16),
			 
			 // Rating section
			 const Text('Rate your driver (optional):', style: TextStyle(fontWeight: FontWeight.bold)),
			 const SizedBox(height: 8),
			 Row(
			  mainAxisAlignment: MainAxisAlignment.center,
			  children: List.generate(5, (i) => IconButton(
			   onPressed: () => setState(() => stars = i + 1),
			   icon: Icon(
				stars != null && stars! > i ? Icons.star : Icons.star_border,
				color: Colors.amber,
				size: 32,
			   ),
			  )),
			 ),
			 const SizedBox(height: 8),
			 TextField(
			  controller: ctl,
			  decoration: const InputDecoration(
			   labelText: 'Feedback (optional)',
			   border: OutlineInputBorder(),
			  ),
			  maxLines: 3,
			 ),
			],
		   ),
		  ),
		  actions: [
		   TextButton(
			onPressed: () => Navigator.pop(context),
			child: const Text('Skip Rating'),
		   ),
		   FilledButton(
			onPressed: () async {
			 try {
			  // Save payment method to ride
			  await FirebaseFirestore.instance
			   .collection('rides')
			   .doc(widget.rideId)
			   .set({
				'paymentMethod': paymentMethod,
				'paymentStatus': paymentMethod == 'cash' ? 'pending_cash' : 'processed',
				'completedAt': DateTime.now().toIso8601String(),
			   }, SetOptions(merge: true));
			  
			  // Save rating if provided
			  if (stars != null) {
			   await FirebaseFirestore.instance
				.collection('rides')
				.doc(widget.rideId)
				.collection('ratings')
				.add({
				 'stars': stars,
				 'text': ctl.text.trim(),
				 'createdAt': DateTime.now().toIso8601String(),
				 'riderId': FirebaseAuth.instance.currentUser?.uid,
				 'driverId': ride.driverId,
				});
			  }
			 } catch (_) {}
			 if (context.mounted) Navigator.pop(context);
			},
			child: const Text('Submit'),
		   ),
		  ],
		 );
		});
			},
		);
	   });
	  });
	 }

	 if (ride.status == RideStatus.requested) {
	  _waitingSince ??= DateTime.now();
	  // prompt every 70 seconds
	  if (DateTime.now().difference(_waitingSince!).inSeconds >= 70) {
	   _waitingSince = DateTime.now();
	   _promptWaitRedirect();
	  }
	  _maybeStartMockAccept(data);
	 }

	 LatLng? center;
	 final markers = <Marker>{};
	 if (pickupLat != null && pickupLng != null) {
	  final pos = LatLng(pickupLat, pickupLng);
	  markers.add(Marker(markerId: const MarkerId('pickup'), position: pos, infoWindow: const InfoWindow(title: 'Pickup')));
	  center ??= pos;
	 }
	 if (destLat != null && destLng != null) {
	  final pos = LatLng(destLat, destLng);
	  markers.add(Marker(markerId: const MarkerId('dest'), position: pos, infoWindow: const InfoWindow(title: 'Destination')));
	  center ??= pos;
	 }
	 if (driverLat != null && driverLng != null) {
	  final pos = LatLng(driverLat, driverLng);
	  markers.add(Marker(
	   markerId: const MarkerId('driver'),
	   position: pos,
	   infoWindow: const InfoWindow(title: 'Driver'),
	   icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
	  ));
	  center = pos;
	 }

	 final origin = pickupLat != null && pickupLng != null ? '$pickupLat,$pickupLng' : null;
	 final dest = destLat != null && destLng != null ? '$destLat,$destLng' : null;
	 if (origin != null && dest != null) {
	  _buildPolyline(origin, dest);
	 }

	 // Update ETA when positions are available
	 if (driverLat != null && driverLng != null) {
	  // Before pickup: ETA to pickup; otherwise ETA to destination
	  if (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving || ride.status == RideStatus.requested) {
	   if (pickupLat != null && pickupLng != null) {
		_updateEta(originLat: driverLat, originLng: driverLng, destLat: pickupLat, destLng: pickupLng);
	   }
	  } else if (destLat != null && destLng != null) {
	   _updateEta(originLat: driverLat, originLng: driverLng, destLat: destLat, destLng: destLng);
	  }
	  // Keep simulation running but use real position when available
	  _simulatedDriver = LatLng(driverLat, driverLng); // Update simulated position with real position
	 } else {
	  // Enhanced simulation: show realistic driver movement
	  if (pickupLat != null && pickupLng != null && destLat != null && destLng != null) {
	   _riderSimTimer ??= Timer.periodic(const Duration(seconds: 3), (t) {
		// More realistic movement simulation
		double progress;
		switch (ride.status) {
		 case RideStatus.accepted:
		 case RideStatus.arriving:
		  // Driver moving towards pickup (0% to 100% of route to pickup)
		  progress = ((t.tick % 20) / 20.0).clamp(0.0, 1.0);
		  break;
		 case RideStatus.arrived:
		  // Driver at pickup location
		  progress = 1.0;
		  break;
		 case RideStatus.enroute:
		  // Driver moving from pickup to destination (0% to 100% of main route)
		  progress = ((t.tick % 30) / 30.0).clamp(0.0, 1.0);
		  final lat = pickupLat + (destLat - pickupLat) * progress;
		  final lng = pickupLng + (destLng - pickupLng) * progress;
		  setState(() { _simulatedDriver = LatLng(lat, lng); });
		  return;
		 default:
		  progress = 0.0;
		}
		
		// For arriving/accepted status, move towards pickup
		if (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving) {
		 // Start driver at a reasonable distance from pickup
		 final startLat = pickupLat + (destLat - pickupLat) * 0.3; // 30% towards destination as starting point
		 final startLng = pickupLng + (destLng - pickupLng) * 0.3;
		 final lat = startLat + (pickupLat - startLat) * progress;
		 final lng = startLng + (pickupLng - startLng) * progress;
		 setState(() { _simulatedDriver = LatLng(lat, lng); });
		} else if (ride.status == RideStatus.arrived) {
		 // Keep driver at pickup location
		 setState(() { _simulatedDriver = LatLng(pickupLat, pickupLng); });
		}
	   });
	   
	   // Initialize driver position if not set
	   _simulatedDriver ??= LatLng(
		pickupLat + (destLat - pickupLat) * 0.3,
		pickupLng + (destLng - pickupLng) * 0.3,
	   );
	   
	   if (_simulatedDriver != null) {
		markers.add(Marker(
		 markerId: const MarkerId('driver'),
		 position: _simulatedDriver!,
		 infoWindow: InfoWindow(
		  title: '🚗 Your Driver',
		  snippet: ride.status == RideStatus.arrived ? '✅ Arrived at pickup' : '🚗 En route to you',
		 ),
		 icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
		));
		center = _simulatedDriver;
	   }
	  }
	 }

	 return Column(
	  children: [
	   Expanded(
		child: Builder(builder: (context) {
		 if (center == null) {
		  print('❌ Map center is null - no location data available');
		  return const Center(
		   child: Column(
			mainAxisAlignment: MainAxisAlignment.center,
			children: [
			 Icon(Icons.location_off, size: 64, color: Colors.grey),
			 SizedBox(height: 16),
			 Text('Waiting for location...', style: TextStyle(fontSize: 18)),
			 SizedBox(height: 8),
			 Text('Map will appear when location is available', style: TextStyle(color: Colors.grey)),
			],
		   ),
		  );
		 }
		 
		 print('✅ Map center available: ${center!.latitude}, ${center!.longitude}');
		 print('📍 Markers count: ${markers.length}');
		 
		 try {
		  if (kIsWeb) {
		   final fmMarkers = markers.map<lm.Marker>((m) {
			final isDriver = (m.markerId == const MarkerId('driver'));
			return lm.Marker(
			 point: ll.LatLng(m.position.latitude, m.position.longitude),
			 width: isDriver ? 44 : 36,
			 height: isDriver ? 44 : 36,
			 child: isDriver
			  ? Container(
			   decoration: BoxDecoration(
				color: Colors.blue,
				borderRadius: BorderRadius.circular(20),
				boxShadow: [
				 BoxShadow(
				  color: Colors.blue.withOpacity(0.3),
				  spreadRadius: 3,
				  blurRadius: 5,
				 ),
				],
			   ),
			   child: const Icon(Icons.directions_car, color: Colors.white, size: 36),
			  )
			  : const Icon(Icons.location_on, color: Colors.redAccent),
			);
		   }).toList();
		   return lm.FlutterMap(
			options: lm.MapOptions(initialCenter: ll.LatLng(center!.latitude, center!.longitude), initialZoom: 14),
			children: [
			 lm.TileLayer(
			  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
			  userAgentPackageName: 'com.zippup.app',
			  maxZoom: 19,
			 ),
			 lm.MarkerLayer(markers: fmMarkers),
			],
		   );
		  }
		  return GoogleMap(
		   initialCameraPosition: CameraPosition(target: center!, zoom: 14),
		   markers: markers,
		   polylines: _polylines,
		   myLocationEnabled: false,
		   compassEnabled: false,
		  );
		 } catch (_) {
		  return const Center(child: Text('Map failed to load. Check API key/config.'));
		 }
	   }),
	   ),
	   Padding(
		padding: const EdgeInsets.all(16),
		child: Column(
		 children: [
		  Card(
		   child: FutureBuilder<List<dynamic>>(
			future: () {
			 // Show appropriate profile based on who is viewing
			 final profileUserId = _isDriver ? ride.riderId : ride.driverId;
			 if (profileUserId == null) return Future.value([]);
			 
			 return Future.wait([
			  FirebaseFirestore.instance.collection('users').doc(profileUserId).get(),
			  FirebaseFirestore.instance.collection('public_profiles').doc(profileUserId).get(),
			  _isDriver 
			   ? FirebaseFirestore.instance.collection('users').doc(profileUserId).get() // For rider, just get user info
			   : FirebaseFirestore.instance
				 .collection('provider_profiles')
				 .where('userId', isEqualTo: profileUserId)
				 .where('service', isEqualTo: 'transport')
				 .limit(1)
				 .get(),
			  _isDriver 
			   ? FirebaseFirestore.instance.collection('users').doc(profileUserId).get() // For rider, no application needed
			   : FirebaseFirestore.instance.collection('applications').doc(profileUserId).get(),
			 ]).timeout(const Duration(seconds: 10), onTimeout: () {
			  print('⏰ ${_isDriver ? "Rider" : "Driver"} info fetch timed out after 10 seconds');
			  throw TimeoutException('${_isDriver ? "Rider" : "Driver"} info fetch timed out', const Duration(seconds: 10));
			 });
			}(),
			builder: (context, s) {
			 if (s.connectionState == ConnectionState.waiting) {
			  return ListTile(
			   leading: const CircularProgressIndicator(),
			   title: Text('Loading ${_isDriver ? "rider" : "driver"} info...'),
			  );
			 }
			 
			 if (s.hasError) {
			  print('❌ Error loading ${_isDriver ? "rider" : "driver"} info: ${s.error}');
			  return ListTile(
			   leading: const Icon(Icons.error, color: Colors.red),
			   title: Text('${_isDriver ? "Rider" : "Driver"} info unavailable'),
			   subtitle: const Text('Please check connection'),
			  );
			 }
			 
			 if (!s.hasData || s.data == null || s.data!.isEmpty) {
			  print('⚠️ No data received for ${_isDriver ? "rider" : "driver"} info');
			  return ListTile(
			   leading: const Icon(Icons.person, color: Colors.grey),
			   title: Text('${_isDriver ? "Rider" : "Driver"} details pending...'),
			  );
			 }
			 
			 final u = (s.data?[0] as DocumentSnapshot<Map<String, dynamic>>?)?.data() ?? const {};
			 final pu = (s.data?[1] as DocumentSnapshot<Map<String, dynamic>>?)?.data() ?? const {};
			 
			 // Debug: Print profile data
			 final profileType = _isDriver ? "Rider" : "Driver";
			 print('🔍 $profileType Profile Debug:');
			 print('User profile exists: ${(s.data?[0] as DocumentSnapshot?)?.exists ?? false}');
			 print('Public profile exists: ${(s.data?[1] as DocumentSnapshot?)?.exists ?? false}');
			 print('User profile data: $u');
			 print('Public profile data: $pu');
			 
			 // Create public profile if missing but user profile exists
			 final profileUserId = _isDriver ? ride.riderId : ride.driverId;
			 if (!(s.data?[1] as DocumentSnapshot?)!.exists && (s.data?[0] as DocumentSnapshot?)!.exists && u['name'] != null && profileUserId != null) {
			  // Fire and forget - don't await in builder
			  FirebaseFirestore.instance.collection('public_profiles').doc(profileUserId).set({
			   'name': u['name'],
			   'photoUrl': u['photoUrl'] ?? '',
			   'createdAt': DateTime.now().toIso8601String(),
			  }).then((_) {
			   print('✅ Created missing public profile for $profileType: ${u['name']}');
			  }).catchError((e) {
			   print('❌ Failed to create $profileType public profile: $e');
			  });
			 }
			 
			 // Better name resolution with fallbacks
			 String name = _isDriver ? 'Rider' : 'Driver';
			 if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
			  name = pu['name'].toString().trim();
			  print('✅ Found $profileType name in public profile: $name');
			 } else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
			  name = u['name'].toString().trim();
			  print('✅ Found $profileType name in user profile: $name');
			 } else if (u['displayName'] != null && u['displayName'].toString().trim().isNotEmpty) {
			  name = u['displayName'].toString().trim();
			 } else if (u['email'] != null) {
			  // Extract name from email as last resort
			  final email = u['email'].toString();
			  final atIndex = email.indexOf('@');
			  if (atIndex > 0) {
			   name = email.substring(0, atIndex).replaceAll('.', ' ').replaceAll('_', ' ');
			   name = name.split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '').join(' ');
			  }
			 }
			 
			 // Better photo resolution
			 String photo = '';
			 if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
			  photo = pu['photoUrl'].toString().trim();
			 } else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
			  photo = u['photoUrl'].toString().trim();
			 } else if (u['profilePicture'] != null && u['profilePicture'].toString().trim().isNotEmpty) {
			  photo = u['profilePicture'].toString().trim();
			 }
			 
			 // Vehicle details only for drivers (when viewed by riders)
			 String vehicleLine = '';
			 String plateLine = '';
			 if (!_isDriver) {
			  String plate = '';
			  String car = '';
			  try {
			   final prof = (s.data?[2] as QuerySnapshot<Map<String, dynamic>>?);
			   final app = (s.data?[3] as DocumentSnapshot<Map<String, dynamic>>?);
			   final meta = prof != null && prof.docs.isNotEmpty ? (prof.docs.first.data()['metadata'] as Map<String, dynamic>? ?? const {}) : const {};
			   final public = (meta['publicDetails'] as Map<String, dynamic>? ?? const {});
			   plate = (public['plateNumber'] ?? '').toString();
			   final a = app?.data() ?? const {};
			   final color = (a['vehicleColor'] ?? '').toString();
			   final brand = (a['vehicleBrand'] ?? '').toString();
			   final model = (a['vehicleModel'] ?? '').toString();
			   final parts = [color, brand, model].where((e) => e.trim().isNotEmpty).toList();
			   car = parts.isEmpty ? '' : parts.join(' ');
			  } catch (_) {}
			  vehicleLine = 'Vehicle: ' + (car.isNotEmpty ? car : 'details pending');
			  plateLine = 'Plate: ' + (plate.isNotEmpty ? plate : '—');
			 }
			 final displayUserId = _isDriver ? ride.riderId : ride.driverId;
			 final subtitleText = _isDriver 
			  ? 'Customer • ${ride.type.name.toUpperCase()}'
			  : 'ID: ${ride.driverId!.substring(0, 6)} • ${ride.type.name.toUpperCase()}\n$vehicleLine\n$plateLine';
			 
			 return ListTile(
			  leading: CircleAvatar(backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, child: photo.isEmpty ? const Icon(Icons.person) : null),
			  title: Text(name),
			  subtitle: Text(subtitleText),
			  trailing: const Icon(Icons.star_border),
			 );
			},
		   ),
		  ),
		  StatusTimeline(steps: steps, currentIndex: idx),
		  if (_etaMinutes != null) Padding(
		   padding: const EdgeInsets.only(top: 8.0),
		   child: Text('ETA: $_etaMinutes min'),
		  ),
		  if (_rideCancelable(ride.status) && !_isDriver) Align(
		   alignment: Alignment.centerRight,
		   child: TextButton.icon(onPressed: () => _cancel(context, widget.rideId), icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel ride')),
		  ),
		  // Driver action buttons
		  ..._getDriverActions(ride, data).map((button) => Padding(
		   padding: const EdgeInsets.only(top: 8.0),
		   child: SizedBox(
			width: double.infinity,
			child: button,
		   ),
		  )),
		 				],
			),
		),
	],
	);
}

 Future<void> _cancel(BuildContext context, String rideId) async {
  final reasons = <String>['Change of plans', 'Booked by mistake', 'Driver taking too long', 'Other'];
  String? selected = reasons.first;
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
   context: context,
   builder: (context) => AlertDialog(
	title: const Text('Cancel ride'),
	content: Column(
	 mainAxisSize: MainAxisSize.min,
	 children: [
	  DropdownButtonFormField<String>(
	   value: selected,
	   items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
	   onChanged: (v) => selected = v,
	   decoration: const InputDecoration(labelText: 'Reason'),
	  ),
	  TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Details (optional)')),
	 ],
	),
	actions: [
	 TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
	 FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel ride')),
	],
   ),
  );
  if (confirmed == true) {
   final reason = selected == 'Other' && controller.text.trim().isNotEmpty ? controller.text.trim() : selected ?? 'Cancelled';
   await _rideService.cancel(rideId, reason: reason, cancelledBy: 'rider');
   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride cancelled')));
  }
 }

 	bool _rideCancelable(RideStatus s) {
		return s == RideStatus.requested || s == RideStatus.accepted || s == RideStatus.arriving || s == RideStatus.arrived;
	}

	Future<void> _openGoogleNavigation(double originLat, double originLng, double destLat, double destLng) async {
		final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving');
		try {
			if (await canLaunchUrl(uri)) {
				await launchUrl(uri, mode: LaunchMode.externalApplication);
			} else {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(content: Text('Could not open Google Maps')),
					);
				}
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Navigation error: $e')),
				);
			}
		}
	}

	Future<void> _openPhoneNavigation(double destLat, double destLng, String label) async {
		// Show navigation options dialog
		if (!mounted) return;
		
		final selected = await showDialog<String>(
			context: context,
			builder: (context) => AlertDialog(
				title: Text('📱 $label'),
				content: const Text('Choose your preferred navigation app:'),
				actions: [
					TextButton.icon(
						onPressed: () => Navigator.pop(context, 'google'),
						icon: const Icon(Icons.map, color: Colors.blue),
						label: const Text('Google Maps'),
					),
					TextButton.icon(
						onPressed: () => Navigator.pop(context, 'apple'),
						icon: const Icon(Icons.navigation, color: Colors.green),
						label: const Text('Apple Maps'),
					),
					TextButton.icon(
						onPressed: () => Navigator.pop(context, 'waze'),
						icon: const Icon(Icons.traffic, color: Colors.orange),
						label: const Text('Waze'),
					),
				],
			),
		);

		if (selected == null) return;

		Uri? uri;
		switch (selected) {
			case 'google':
				uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving');
				break;
			case 'apple':
				uri = Uri.parse('http://maps.apple.com/?daddr=$destLat,$destLng&dirflg=d');
				break;
			case 'waze':
				uri = Uri.parse('https://waze.com/ul?ll=$destLat,$destLng&navigate=yes');
				break;
		}

		if (uri != null) {
			try {
				if (await canLaunchUrl(uri)) {
					await launchUrl(uri, mode: LaunchMode.externalApplication);
				} else {
					if (mounted) {
						ScaffoldMessenger.of(context).showSnackBar(
							SnackBar(content: Text('Could not open ${selected.toUpperCase()}')),
						);
					}
				}
			} catch (e) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						SnackBar(content: Text('Navigation error: $e')),
					);
				}
			}
		}
	}
}