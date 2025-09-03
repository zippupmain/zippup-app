# 🍔 Food & Grocery Delivery System - Complete Architecture

## 📊 Database Schema Design

### Core Collections

#### 1. `food_orders` Collection
```javascript
{
  // Document ID: auto-generated order ID
  id: "order_abc123",
  customerId: "customer_456",
  vendorId: "vendor_789",
  driverId: null, // Set when assigned by vendor
  
  // Order Classification
  category: "food", // food | grocery
  orderType: "delivery", // delivery | pickup
  
  // Order State Management
  status: "pending_vendor_acceptance", // See state diagram below
  statusUpdatedAt: Timestamp,
  statusUpdatedBy: "customer_456", // Track who updated status
  
  // Items & Pricing
  items: [
    {
      id: "item_001",
      name: "Jollof Rice with Chicken",
      price: 2500,
      quantity: 2,
      specialInstructions: "Extra spicy",
      options: ["Large portion", "Extra meat"]
    }
  ],
  subtotal: 5000,
  deliveryFee: 500,
  serviceFee: 250,
  tax: 375,
  total: 6125,
  currency: "NGN",
  
  // Timing & Logistics
  prepTimeEstimate: null, // Set by vendor (in minutes)
  prepTimeDeadline: null, // Calculated deadline
  estimatedDeliveryTime: null,
  
  // Locations
  customerLocation: {
    latitude: 6.5244,
    longitude: 3.3792,
    address: "123 Customer St, Lagos",
    instructions: "Blue gate, ring bell twice"
  },
  vendorLocation: {
    latitude: 6.5200,
    longitude: 3.3750,
    address: "456 Restaurant Ave, Lagos"
  },
  
  // Security
  deliveryCode: "A7B3C9", // 6-digit alphanumeric
  codeGeneratedAt: Timestamp,
  codeAttempts: 0, // Track failed attempts
  maxCodeAttempts: 3,
  
  // Driver Tracking
  driverLocation: {
    latitude: null,
    longitude: null,
    lastUpdated: null,
    heading: null // Direction of movement
  },
  
  // Timestamps
  createdAt: Timestamp,
  acceptedByVendorAt: null,
  prepStartedAt: null,
  readyForPickupAt: null,
  assignedToDriverAt: null,
  acceptedByDriverAt: null,
  pickedUpAt: null,
  deliveredAt: null,
  
  // Audit Trail
  statusHistory: [
    {
      status: "pending_vendor_acceptance",
      timestamp: Timestamp,
      updatedBy: "customer_456",
      note: "Order placed"
    }
  ],
  
  // Payment & Rating
  paymentStatus: "pending", // pending | paid | refunded
  paymentMethod: "card",
  rating: null, // Customer rating after delivery
  feedback: null
}
```

#### 2. `vendors` Collection
```javascript
{
  // Document ID: vendor ID
  id: "vendor_789",
  userId: "user_owner_123", // Owner's user account
  businessName: "Mama's Kitchen",
  
  // Business Details
  category: "food", // food | grocery
  cuisine: ["Nigerian", "Continental"],
  businessType: "restaurant", // restaurant | grocery_store | supermarket
  
  // Location & Service Area
  location: {
    latitude: 6.5200,
    longitude: 3.3750,
    address: "456 Restaurant Ave, Lagos"
  },
  serviceRadius: 5.0, // km
  deliveryZones: ["Ikeja", "Victoria Island", "Lagos Island"],
  
  // Operational Status
  isOpen: true,
  isAcceptingOrders: true,
  operatingHours: {
    monday: { open: "08:00", close: "22:00" },
    tuesday: { open: "08:00", close: "22:00" },
    // ... other days
  },
  
  // Order Management
  avgPrepTime: 25, // minutes
  maxOrdersPerHour: 12,
  currentActiveOrders: 3,
  
  // Delivery Management
  preferredDrivers: ["driver_001", "driver_002"], // Preferred delivery partners
  allowsExternalDrivers: true, // Can use platform drivers
  
  // Performance Metrics
  rating: 4.7,
  totalOrders: 1250,
  acceptanceRate: 0.95,
  avgPrepTimeAccuracy: 0.88, // How often they meet prep time estimates
  
  // Financial
  commissionRate: 0.15, // Platform commission (15%)
  minimumOrderAmount: 1000,
  deliveryFeeStructure: {
    baseDeliveryFee: 500,
    perKmRate: 100,
    freeDeliveryThreshold: 5000
  }
}
```

#### 3. `delivery_drivers` Collection
```javascript
{
  // Document ID: driver ID
  id: "driver_001",
  userId: "user_driver_456", // Driver's user account
  
  // Driver Details
  name: "John Doe",
  phone: "+234801234567",
  profilePhoto: "https://...",
  
  // Vehicle Information
  vehicle: {
    type: "motorcycle", // motorcycle | car | bicycle
    model: "Honda CB150",
    plateNumber: "ABC123DE",
    color: "Red"
  },
  
  // Real-Time Status
  isOnline: true,
  availabilityStatus: "available", // available | assigned | busy | offline
  currentOrderId: null,
  
  // Location Tracking
  currentLocation: {
    latitude: 6.5220,
    longitude: 3.3770,
    lastUpdated: Timestamp,
    accuracy: 5.0, // meters
    heading: 45.0 // degrees (0-360)
  },
  
  // Service Areas
  serviceZones: ["Ikeja", "Victoria Island"],
  maxDeliveryRadius: 10.0, // km from current location
  
  // Performance Metrics
  rating: 4.8,
  totalDeliveries: 450,
  completionRate: 0.98,
  avgDeliveryTime: 18, // minutes
  onTimeDeliveryRate: 0.92,
  
  // Financial
  earningsToday: 8500,
  earningsThisWeek: 45000,
  earningsThisMonth: 180000,
  
  // Certifications & Equipment
  certifications: ["food_handling", "safe_driving"],
  equipment: ["insulated_bag", "phone_mount", "helmet"],
  
  // Operational
  workingHours: {
    start: "07:00",
    end: "23:00"
  },
  maxOrdersPerHour: 4,
  
  // Timestamps
  lastOnlineAt: Timestamp,
  joinedAt: Timestamp
}
```

#### 4. `order_status_log` Collection (Audit Trail)
```javascript
{
  // Document ID: auto-generated
  orderId: "order_abc123",
  previousStatus: "pending_vendor_acceptance",
  newStatus: "accepted_by_vendor",
  
  // Change Details
  updatedBy: "vendor_789", // user ID who made the change
  updatedByRole: "vendor", // customer | vendor | driver | system
  timestamp: Timestamp,
  
  // Additional Data
  changeReason: "Vendor accepted order",
  additionalData: {
    prepTimeEstimate: 25, // When vendor accepts
    driverId: "driver_001", // When driver assigned
    deliveryCode: "A7B3C9" // When code verified
  },
  
  // Location Context (where the change happened)
  changeLocation: {
    latitude: 6.5200,
    longitude: 3.3750
  },
  
  // System Metadata
  appVersion: "1.2.3",
  platform: "web" // web | android | ios
}
```

#### 5. `saved_carts` Collection (Multi-Vendor Support)
```javascript
{
  // Document ID: auto-generated
  customerId: "customer_456",
  vendorId: "vendor_789",
  vendorName: "Mama's Kitchen",
  
  // Saved Items
  items: [
    {
      id: "item_001",
      name: "Jollof Rice",
      price: 2500,
      quantity: 1
    }
  ],
  subtotal: 2500,
  
  // Metadata
  savedAt: Timestamp,
  lastUpdated: Timestamp,
  expiresAt: Timestamp // Auto-delete after 7 days
}
```

## 🔄 Order State Transition Diagram

```
[PENDING_VENDOR_ACCEPTANCE] ──────────────┐
         │                                │
         ▼                                ▼
[ACCEPTED_BY_VENDOR] ────────────────> [DECLINED_BY_VENDOR]
         │                                │
         ▼                                ▼
[PREPARING] ──────────────────────────> [CANCELLED]
         │                                ▲
         ▼                                │
[READY_FOR_PICKUP] ──────────────────────┤
         │                                │
         ▼                                │
[ASSIGNED_TO_DRIVER] ────────────────────┤
         │                                │
         ▼                                │
[ACCEPTED_BY_DRIVER] ────────────────────┤
         │                                │
         ▼                                │
[DRIVER_EN_ROUTE_TO_VENDOR] ─────────────┤
         │                                │
         ▼                                │
[DRIVER_AT_VENDOR] ──────────────────────┤
         │                                │
         ▼                                │
[ORDER_PICKED_UP] ───────────────────────┤
         │                                │
         ▼                                │
[DRIVER_EN_ROUTE_TO_CUSTOMER] ───────────┤
         │                                │
         ▼                                │
[DRIVER_AT_CUSTOMER] ────────────────────┤
         │                                │
         ▼                                │
[DELIVERY_CODE_VERIFICATION] ────────────┤
         │                                │
         ▼                                ▼
[DELIVERED] ◄────────────────────────> [FAILED_DELIVERY]
                                          │
                                          ▼
                                    [RETURN_TO_VENDOR]
```

### State Descriptions

| State | Description | Triggered By | Duration |
|-------|-------------|--------------|----------|
| `PENDING_VENDOR_ACCEPTANCE` | Order placed, waiting for vendor | Customer checkout | 5-10 min |
| `ACCEPTED_BY_VENDOR` | Vendor confirmed order | Vendor action | Instant |
| `PREPARING` | Food being prepared | Vendor sets prep time | 15-45 min |
| `READY_FOR_PICKUP` | Food ready, needs driver | Vendor marks ready | Until assigned |
| `ASSIGNED_TO_DRIVER` | Driver assigned by vendor | Vendor action | 2-5 min |
| `ACCEPTED_BY_DRIVER` | Driver confirmed pickup | Driver action | Instant |
| `DRIVER_EN_ROUTE_TO_VENDOR` | Driver going to restaurant | Driver status | 5-15 min |
| `DRIVER_AT_VENDOR` | Driver arrived at restaurant | Driver status | 2-5 min |
| `ORDER_PICKED_UP` | Driver collected food | Driver status | Instant |
| `DRIVER_EN_ROUTE_TO_CUSTOMER` | Driver delivering to customer | Driver status | 10-25 min |
| `DRIVER_AT_CUSTOMER` | Driver arrived at customer | Driver status | 2-5 min |
| `DELIVERY_CODE_VERIFICATION` | Verifying delivery code | Driver action | 1-2 min |
| `DELIVERED` | Order completed successfully | Code verification | Terminal |

## 🔧 API Endpoint Design

### Vendor Management Endpoints

```javascript
// Accept order and set preparation time
POST /api/vendor/orders/{orderId}/accept
Headers: { Authorization: "Bearer {vendor_token}" }
Body: {
  prepTimeEstimate: 25, // minutes
  specialInstructions: "Will call when ready",
  estimatedReadyTime: "2024-01-15T14:30:00Z"
}
Response: {
  success: true,
  orderId: "order_abc123",
  newStatus: "accepted_by_vendor",
  prepDeadline: "2024-01-15T14:30:00Z"
}

// Decline order with reason
POST /api/vendor/orders/{orderId}/decline  
Body: {
  reason: "out_of_ingredients", // out_of_ingredients | too_busy | closed
  message: "Sorry, we're out of chicken today"
}

// Mark order as ready for pickup
POST /api/vendor/orders/{orderId}/ready
Body: {
  actualPrepTime: 23, // minutes (for analytics)
  pickupInstructions: "Order ready at counter #3"
}

// Get nearby available drivers
GET /api/vendor/drivers/nearby?lat={lat}&lng={lng}&radius={km}
Response: {
  drivers: [
    {
      id: "driver_001",
      name: "John Doe",
      rating: 4.8,
      distance: 2.3, // km
      estimatedArrival: 8, // minutes
      vehicle: { type: "motorcycle", plateNumber: "ABC123" },
      currentLocation: { lat: 6.5220, lng: 3.3770 }
    }
  ]
}

// Assign driver to order
POST /api/vendor/orders/{orderId}/assign-driver
Body: {
  driverId: "driver_001",
  estimatedPickupTime: "2024-01-15T14:45:00Z"
}
```

### Driver Management Endpoints

```javascript
// Accept driver assignment
POST /api/driver/assignments/{orderId}/accept
Headers: { Authorization: "Bearer {driver_token}" }
Body: {
  estimatedArrivalAtVendor: 8, // minutes
  currentLocation: { lat: 6.5220, lng: 3.3770 }
}

// Decline driver assignment
POST /api/driver/assignments/{orderId}/decline
Body: {
  reason: "too_far", // too_far | already_busy | vehicle_issue
  message: "Currently handling another delivery"
}

// Update driver status during delivery
POST /api/driver/orders/{orderId}/status
Body: {
  status: "driver_at_vendor", // See state diagram
  location: { lat: 6.5200, lng: 3.3750 },
  timestamp: "2024-01-15T14:45:00Z",
  note: "Arrived at restaurant, waiting for order"
}

// Update driver location (real-time)
POST /api/driver/location/update
Body: {
  latitude: 6.5244,
  longitude: 3.3792,
  accuracy: 5.0, // meters
  heading: 45.0, // degrees
  speed: 25.0 // km/h
}

// Verify delivery code
POST /api/driver/orders/{orderId}/verify-delivery
Body: {
  deliveryCode: "A7B3C9",
  customerSignature: "base64_signature_data", // Optional
  deliveryPhoto: "base64_image_data", // Optional proof
  deliveryNotes: "Delivered to customer at door"
}
Response: {
  success: true,
  codeValid: true,
  orderCompleted: true,
  earnings: 850 // Driver earnings for this delivery
}
```

### Customer Tracking Endpoints

```javascript
// Get real-time order status
GET /api/customer/orders/{orderId}/status
Response: {
  orderId: "order_abc123",
  status: "driver_en_route_to_customer",
  estimatedDeliveryTime: "2024-01-15T15:15:00Z",
  
  // Driver Info (when assigned)
  driver: {
    id: "driver_001", 
    name: "John Doe",
    rating: 4.8,
    phone: "+234801234567", // Masked: "+234801***567"
    vehicle: { type: "motorcycle", color: "Red", plate: "ABC***" },
    currentLocation: { lat: 6.5230, lng: 3.3780 },
    estimatedArrival: 12 // minutes
  },
  
  // Vendor Info
  vendor: {
    name: "Mama's Kitchen",
    phone: "+234802345678",
    location: { lat: 6.5200, lng: 3.3750 }
  },
  
  // Delivery Code (only visible to customer)
  deliveryCode: "A7B3C9",
  
  // Timeline
  timeline: [
    { status: "pending_vendor_acceptance", time: "14:00", completed: true },
    { status: "preparing", time: "14:05", completed: true },
    { status: "ready_for_pickup", time: "14:30", completed: true },
    { status: "driver_assigned", time: "14:32", completed: true },
    { status: "driver_en_route_to_customer", time: "14:45", completed: false }
  ]
}

// Cancel order (if allowed)
POST /api/customer/orders/{orderId}/cancel
Body: {
  reason: "changed_mind", // changed_mind | wrong_order | emergency
  message: "Need to cancel due to emergency"
}
```

## 🔄 Enhanced Cart System

### Vendor-Centric Cart Logic

```dart
class EnhancedCartProvider extends StateNotifier<CartState> {
  EnhancedCartProvider() : super(CartState.empty());

  // Check if item can be added to current cart
  Future<bool> canAddItem(CartItem newItem) async {
    if (state.items.isEmpty) return true;
    
    final currentVendorId = state.items.first.vendorId;
    return currentVendorId == newItem.vendorId;
  }

  // Add item with vendor conflict resolution
  Future<void> addItem(CartItem newItem, BuildContext context) async {
    if (await canAddItem(newItem)) {
      _addItemDirectly(newItem);
      return;
    }

    // Show vendor conflict dialog
    final action = await showVendorConflictDialog(context, newItem);
    
    switch (action) {
      case VendorConflictAction.replaceCart:
        await _replaceCart(newItem);
        break;
      case VendorConflictAction.saveCurrentCart:
        await _saveCurrentCartAndReplace(newItem);
        break;
      case VendorConflictAction.cancel:
        // Do nothing
        break;
    }
  }

  // Save current cart for later
  Future<void> _saveCurrentCartAndReplace(CartItem newItem) async {
    if (state.items.isNotEmpty) {
      await _saveCartToFirestore(state);
      await _showCartSavedMessage();
    }
    
    state = CartState.fromItems([newItem]);
  }

  // Load saved cart
  Future<void> loadSavedCart(String customerId, String vendorId) async {
    final savedCart = await _getSavedCart(customerId, vendorId);
    if (savedCart != null) {
      state = savedCart;
    }
  }
}

enum VendorConflictAction { replaceCart, saveCurrentCart, cancel }

class CartState {
  final List<CartItem> items;
  final String? vendorId;
  final String? vendorName;
  final double subtotal;
  final double deliveryFee;
  final double total;

  const CartState({
    required this.items,
    this.vendorId,
    this.vendorName,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });

  factory CartState.empty() => const CartState(
    items: [],
    subtotal: 0,
    deliveryFee: 0,
    total: 0,
  );

  factory CartState.fromItems(List<CartItem> items) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
    final deliveryFee = subtotal >= 5000 ? 0 : 500; // Free delivery over ₦5000
    
    return CartState(
      items: items,
      vendorId: items.isNotEmpty ? items.first.vendorId : null,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: subtotal + deliveryFee,
    );
  }
}
```

## 🏪 Vendor Order Management Dashboard

### Dashboard Features

```dart
class VendorOrderDashboard extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order Management')),
      body: Column(
        children: [
          // Real-time metrics
          _buildMetricsRow(),
          
          // Order filters
          _buildOrderFilters(),
          
          // Orders list with real-time updates
          Expanded(child: _buildOrdersList()),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_orders')
          .where('vendorId', isEqualTo: currentVendorId)
          .where('status', whereIn: ['pending_vendor_acceptance', 'preparing', 'ready_for_pickup'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Build order cards with action buttons
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) => OrderCard(
            order: orders[index],
            onAccept: (prepTime) => _acceptOrder(orders[index].id, prepTime),
            onDecline: (reason) => _declineOrder(orders[index].id, reason),
            onMarkReady: () => _markOrderReady(orders[index].id),
            onAssignDriver: (driverId) => _assignDriver(orders[index].id, driverId),
          ),
        );
      },
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  final Function(int) onAccept;
  final Function(String) onDecline;
  final VoidCallback onMarkReady;
  final Function(String) onAssignDriver;

  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        children: [
          // Order header with timing
          _buildOrderHeader(),
          
          // Items list
          _buildItemsList(),
          
          // Customer info and location
          _buildCustomerInfo(),
          
          // Action buttons based on status
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (order.status) {
      case 'pending_vendor_acceptance':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showDeclineDialog(),
                icon: Icon(Icons.close),
                label: Text('Decline'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => _showAcceptDialog(),
                icon: Icon(Icons.check),
                label: Text('Accept Order'),
              ),
            ),
          ],
        );
        
      case 'preparing':
        return FilledButton.icon(
          onPressed: onMarkReady,
          icon: Icon(Icons.restaurant_menu),
          label: Text('Mark as Ready'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
        );
        
      case 'ready_for_pickup':
        return FilledButton.icon(
          onPressed: () => _showDriverAssignmentDialog(),
          icon: Icon(Icons.delivery_dining),
          label: Text('Assign Driver'),
          style: FilledButton.styleFrom(backgroundColor: Colors.blue),
        );
        
      default:
        return _buildStatusDisplay();
    }
  }

  void _showAcceptDialog() {
    showDialog(
      context: context,
      builder: (context) => AcceptOrderDialog(
        onAccept: (prepTime) {
          onAccept(prepTime);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class AcceptOrderDialog extends StatefulWidget {
  final Function(int) onAccept;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Accept Order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('How long will this order take to prepare?'),
          SizedBox(height: 16),
          
          // Quick time buttons
          Wrap(
            spacing: 8,
            children: [15, 20, 25, 30, 35, 40].map((minutes) =>
              ActionChip(
                label: Text('${minutes}m'),
                onPressed: () => onAccept(minutes),
              ),
            ).toList(),
          ),
          
          SizedBox(height: 16),
          
          // Custom time input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTimeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Custom time (minutes)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final customTime = int.tryParse(_customTimeController.text);
                  if (customTime != null && customTime > 0) {
                    onAccept(customTime);
                  }
                },
                child: Text('Set'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

## 🚚 Driver Assignment System

### Available Drivers Query

```dart
class DriverAssignmentService {
  static Future<List<AvailableDriver>> getNearbyDrivers({
    required String vendorId,
    required double vendorLat,
    required double vendorLng,
    double radiusKm = 5.0,
  }) async {
    try {
      // Query available drivers within radius
      final driversQuery = await FirebaseFirestore.instance
          .collection('delivery_drivers')
          .where('isOnline', isEqualTo: true)
          .where('availabilityStatus', isEqualTo: 'available')
          .get();

      final availableDrivers = <AvailableDriver>[];

      for (final doc in driversQuery.docs) {
        final data = doc.data();
        final driverLat = data['currentLocation']['latitude'] as double?;
        final driverLng = data['currentLocation']['longitude'] as double?;

        if (driverLat == null || driverLng == null) continue;

        final distance = _calculateDistance(vendorLat, vendorLng, driverLat, driverLng);
        
        if (distance <= radiusKm) {
          availableDrivers.add(AvailableDriver(
            id: data['userId'],
            name: data['name'],
            rating: (data['rating'] as num?)?.toDouble() ?? 4.0,
            distance: distance,
            estimatedArrival: (distance * 2).ceil(), // 2 minutes per km
            vehicle: DriverVehicle.fromMap(data['vehicle']),
            currentLocation: DriverLocation(lat: driverLat, lng: driverLng),
          ));
        }
      }

      // Sort by distance (closest first)
      availableDrivers.sort((a, b) => a.distance.compareTo(b.distance));
      
      return availableDrivers;

    } catch (e) {
      print('Error fetching nearby drivers: $e');
      return [];
    }
  }

  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    // Haversine formula implementation
    const double earthRadius = 6371; // km
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180);
}

class DriverAssignmentDialog extends StatefulWidget {
  final String orderId;
  final double vendorLat;
  final double vendorLng;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.delivery_dining, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Assign Driver', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Drivers list
            Expanded(
              child: FutureBuilder<List<AvailableDriver>>(
                future: DriverAssignmentService.getNearbyDrivers(
                  vendorId: currentVendorId,
                  vendorLat: vendorLat,
                  vendorLng: vendorLng,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading drivers: ${snapshot.error}'));
                  }
                  
                  final drivers = snapshot.data ?? [];
                  
                  if (drivers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.no_accounts, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No drivers available nearby'),
                          Text('Try again in a few minutes'),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.separated(
                    padding: EdgeInsets.all(16),
                    itemCount: drivers.length,
                    separatorBuilder: (_, __) => Divider(),
                    itemBuilder: (context, index) => _buildDriverCard(drivers[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(AvailableDriver driver) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.person, color: Colors.blue.shade700),
        ),
        title: Text(driver.name, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${driver.vehicle.type} • ${driver.vehicle.plateNumber}'),
            Text('${driver.distance.toStringAsFixed(1)}km away • ETA: ${driver.estimatedArrival}min'),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                Text('${driver.rating.toStringAsFixed(1)}'),
              ],
            ),
          ],
        ),
        trailing: FilledButton(
          onPressed: () => _assignDriver(driver.id),
          child: Text('Assign'),
        ),
        isThreeLine: true,
      ),
    );
  }
}
```

## 📱 Driver App Flow

### Driver Status Management

```dart
class DriverOrderScreen extends StatefulWidget {
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, snapshot) {
        final order = FoodOrder.fromSnapshot(snapshot.data!);
        
        return Scaffold(
          appBar: AppBar(title: Text('Delivery #${order.id.substring(0, 6)}')),
          body: Column(
            children: [
              // Order info card
              _buildOrderInfoCard(order),
              
              // Map with real-time tracking
              Expanded(child: _buildTrackingMap(order)),
              
              // Status action buttons
              _buildStatusActionButtons(order),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusActionButtons(FoodOrder order) {
    switch (order.status) {
      case 'accepted_by_driver':
        return _buildActionButton(
          'Going to Restaurant',
          Icons.restaurant,
          Colors.orange,
          () => _updateStatus('driver_en_route_to_vendor'),
        );
        
      case 'driver_en_route_to_vendor':
        return _buildActionButton(
          'Arrived at Restaurant',
          Icons.store,
          Colors.blue,
          () => _updateStatus('driver_at_vendor'),
        );
        
      case 'driver_at_vendor':
        return _buildActionButton(
          'Order Picked Up',
          Icons.shopping_bag,
          Colors.green,
          () => _updateStatus('order_picked_up'),
        );
        
      case 'order_picked_up':
        return _buildActionButton(
          'Going to Customer',
          Icons.directions,
          Colors.purple,
          () => _updateStatus('driver_en_route_to_customer'),
        );
        
      case 'driver_en_route_to_customer':
        return _buildActionButton(
          'Arrived at Customer',
          Icons.location_on,
          Colors.teal,
          () => _updateStatus('driver_at_customer'),
        );
        
      case 'driver_at_customer':
        return _buildDeliveryCodeInput(order);
        
      default:
        return _buildStatusDisplay(order);
    }
  }

  Widget _buildDeliveryCodeInput(FoodOrder order) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Enter Delivery Code',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Ask customer for the 6-digit delivery code',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(height: 16),
          
          // 6-digit code input
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) => 
              Container(
                width: 40,
                height: 50,
                child: TextField(
                  controller: _codeControllers[index],
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _onCodeDigitChanged(index, value),
                ),
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reportDeliveryIssue(),
                  icon: Icon(Icons.report_problem),
                  label: Text('Report Issue'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _verifyDeliveryCode,
                  icon: Icon(Icons.verified),
                  label: Text('Complete Delivery'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _verifyDeliveryCode() async {
    final enteredCode = _codeControllers.map((c) => c.text).join('');
    
    if (enteredCode.length != 6) {
      _showError('Please enter all 6 digits');
      return;
    }

    try {
      // Call verification API
      final result = await DeliveryCodeService.verifyCode(
        orderId: widget.orderId,
        enteredCode: enteredCode,
        driverLocation: await _getCurrentLocation(),
      );

      if (result.isValid) {
        // Success - order completed
        await _updateStatus('delivered');
        _showSuccessDialog();
      } else {
        // Invalid code
        await _handleInvalidCode(result);
      }

    } catch (e) {
      _showError('Verification failed: $e');
    }
  }
}
```

## 🔐 Secure Delivery Code System

### Code Generation & Validation

```dart
class DeliveryCodeService {
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude confusing chars
  static const int _codeLength = 6;
  static const int _maxAttempts = 3;

  /// Generate secure delivery code
  static String generateDeliveryCode() {
    final random = math.Random.secure();
    final code = List.generate(_codeLength, 
      (index) => _chars[random.nextInt(_chars.length)]
    ).join('');
    
    return code;
  }

  /// Verify delivery code with security measures
  static Future<CodeVerificationResult> verifyCode({
    required String orderId,
    required String enteredCode,
    required DriverLocation driverLocation,
  }) async {
    try {
      // Get order data
      final orderDoc = await FirebaseFirestore.instance
          .collection('food_orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        return CodeVerificationResult(
          isValid: false,
          errorMessage: 'Order not found',
          shouldBlock: false,
        );
      }

      final orderData = orderDoc.data()!;
      final correctCode = orderData['deliveryCode'] as String;
      final currentAttempts = (orderData['codeAttempts'] as int?) ?? 0;
      final maxAttempts = (orderData['maxCodeAttempts'] as int?) ?? _maxAttempts;

      // Check if too many attempts
      if (currentAttempts >= maxAttempts) {
        return CodeVerificationResult(
          isValid: false,
          errorMessage: 'Too many failed attempts. Contact support.',
          shouldBlock: true,
        );
      }

      // Verify code
      final isCodeCorrect = enteredCode.toUpperCase() == correctCode.toUpperCase();

      // Update attempt count
      await orderDoc.reference.update({
        'codeAttempts': currentAttempts + 1,
        'lastCodeAttemptAt': FieldValue.serverTimestamp(),
        'lastCodeAttemptLocation': {
          'latitude': driverLocation.lat,
          'longitude': driverLocation.lng,
        },
      });

      if (isCodeCorrect) {
        // Success - mark as delivered
        await _completeDelivery(orderId, orderData);
        
        return CodeVerificationResult(
          isValid: true,
          message: 'Delivery completed successfully!',
        );
      } else {
        // Invalid code
        final remainingAttempts = maxAttempts - (currentAttempts + 1);
        
        if (remainingAttempts <= 0) {
          // Block further attempts and notify support
          await _handleMaxAttemptsReached(orderId, orderData);
        }
        
        return CodeVerificationResult(
          isValid: false,
          errorMessage: 'Invalid code. $remainingAttempts attempts remaining.',
          shouldBlock: remainingAttempts <= 0,
          remainingAttempts: remainingAttempts,
        );
      }

    } catch (e) {
      return CodeVerificationResult(
        isValid: false,
        errorMessage: 'Verification error: $e',
        shouldBlock: false,
      );
    }
  }

  /// Complete delivery process
  static Future<void> _completeDelivery(String orderId, Map<String, dynamic> orderData) async {
    final batch = FirebaseFirestore.instance.batch();

    // Update order status
    final orderRef = FirebaseFirestore.instance.collection('food_orders').doc(orderId);
    batch.update(orderRef, {
      'status': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
      'codeVerifiedAt': FieldValue.serverTimestamp(),
    });

    // Log status change
    final statusLogRef = FirebaseFirestore.instance.collection('order_status_log').doc();
    batch.set(statusLogRef, {
      'orderId': orderId,
      'previousStatus': orderData['status'],
      'newStatus': 'delivered',
      'updatedBy': orderData['driverId'],
      'updatedByRole': 'driver',
      'timestamp': FieldValue.serverTimestamp(),
      'changeReason': 'Delivery code verified',
      'additionalData': {
        'deliveryCodeUsed': orderData['deliveryCode'],
        'totalCodeAttempts': (orderData['codeAttempts'] ?? 0) + 1,
      },
    });

    // Update driver availability
    if (orderData['driverId'] != null) {
      final driverQuery = await FirebaseFirestore.instance
          .collection('delivery_drivers')
          .where('userId', '==', orderData['driverId'])
          .limit(1)
          .get();

      if (driverQuery.docs.isNotEmpty) {
        batch.update(driverQuery.docs.first.reference, {
          'availabilityStatus': 'available',
          'currentOrderId': null,
          'lastDeliveryCompletedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    
    // Send completion notifications
    await _sendDeliveryCompletionNotifications(orderId, orderData);
  }

  /// Handle max attempts reached
  static Future<void> _handleMaxAttemptsReached(String orderId, Map<String, dynamic> orderData) async {
    // Flag order for manual review
    await FirebaseFirestore.instance.collection('food_orders').doc(orderId).update({
      'status': 'delivery_verification_failed',
      'flaggedForReview': true,
      'flaggedAt': FieldValue.serverTimestamp(),
      'flagReason': 'Max delivery code attempts exceeded',
    });

    // Notify support team
    await FirebaseFirestore.instance.collection('support_tickets').add({
      'type': 'delivery_code_failure',
      'orderId': orderId,
      'customerId': orderData['customerId'],
      'driverId': orderData['driverId'],
      'vendorId': orderData['vendorId'],
      'description': 'Driver exceeded maximum delivery code attempts',
      'priority': 'high',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('🚨 Max code attempts reached for order $orderId - flagged for review');
  }
}

class CodeVerificationResult {
  final bool isValid;
  final String? message;
  final String? errorMessage;
  final bool shouldBlock;
  final int? remainingAttempts;

  const CodeVerificationResult({
    required this.isValid,
    this.message,
    this.errorMessage,
    this.shouldBlock = false,
    this.remainingAttempts,
  });
}
```

## 🗺️ Real-Time Tracking System

### Live Driver Location Updates

```dart
class RealTimeTrackingService {
  static Timer? _locationTimer;
  static StreamSubscription? _orderStatusSubscription;

  /// Start real-time location updates for driver
  static void startLocationTracking(String orderId, String driverId) {
    _locationTimer?.cancel();
    
    _locationTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Update driver location in database
        await FirebaseFirestore.instance
            .collection('food_orders')
            .doc(orderId)
            .update({
          'driverLocation': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'lastUpdated': FieldValue.serverTimestamp(),
            'accuracy': position.accuracy,
            'heading': position.heading,
            'speed': position.speed,
          },
        });

        // Also update driver's global location
        final driverQuery = await FirebaseFirestore.instance
            .collection('delivery_drivers')
            .where('userId', '==', driverId)
            .limit(1)
            .get();

        if (driverQuery.docs.isNotEmpty) {
          await driverQuery.docs.first.reference.update({
            'currentLocation': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'lastUpdated': FieldValue.serverTimestamp(),
              'accuracy': position.accuracy,
              'heading': position.heading,
            },
          });
        }

        print('📍 Updated driver location: ${position.latitude}, ${position.longitude}');

      } catch (e) {
        print('❌ Error updating driver location: $e');
      }
    });
  }

  /// Stop location tracking
  static void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _orderStatusSubscription?.cancel();
    _orderStatusSubscription = null;
  }

  /// Customer tracking screen with live map
  static Widget buildCustomerTrackingScreen(String orderId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final order = FoodOrder.fromSnapshot(snapshot.data!);
        
        return Scaffold(
          appBar: AppBar(title: Text('Track Order')),
          body: Column(
            children: [
              // Order status timeline
              _buildStatusTimeline(order),
              
              // Live map with driver location
              Expanded(child: _buildLiveTrackingMap(order)),
              
              // Order details and delivery code
              _buildOrderDetailsCard(order),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildLiveTrackingMap(FoodOrder order) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          order.customerLocation.latitude,
          order.customerLocation.longitude,
        ),
        zoom: 14,
      ),
      markers: _buildMapMarkers(order),
      polylines: _buildRoutePolylines(order),
      onMapCreated: (GoogleMapController controller) {
        // Auto-center map to show all relevant points
        _fitMapToPoints(controller, order);
      },
    );
  }

  static Set<Marker> _buildMapMarkers(FoodOrder order) {
    final markers = <Marker>{};

    // Customer location marker
    markers.add(Marker(
      markerId: MarkerId('customer'),
      position: LatLng(order.customerLocation.latitude, order.customerLocation.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(title: 'Delivery Address'),
    ));

    // Vendor location marker
    markers.add(Marker(
      markerId: MarkerId('vendor'),
      position: LatLng(order.vendorLocation.latitude, order.vendorLocation.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: InfoWindow(title: order.vendorName),
    ));

    // Driver location marker (if available and active)
    if (order.driverLocation != null && 
        order.driverLocation!.latitude != null && 
        order.driverLocation!.longitude != null &&
        ['driver_en_route_to_vendor', 'driver_en_route_to_customer', 'driver_at_customer'].contains(order.status)) {
      
      markers.add(Marker(
        markerId: MarkerId('driver'),
        position: LatLng(order.driverLocation!.latitude!, order.driverLocation!.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Your Driver',
          snippet: '${order.driverName} • ${order.driverVehicle}',
        ),
      ));
    }

    return markers;
  }
}
```

## 🔒 Security Implementation

### Advanced Code Security

```dart
class SecureDeliveryCodeService {
  // Use cryptographically secure random generator
  static final _secureRandom = math.Random.secure();
  
  // Exclude visually similar characters to prevent confusion
  static const _validChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  
  /// Generate cryptographically secure delivery code
  static String generateSecureCode() {
    final code = List.generate(6, (index) => 
      _validChars[_secureRandom.nextInt(_validChars.length)]
    ).join('');
    
    // Ensure code doesn't contain common words or patterns
    if (_isProblematicCode(code)) {
      return generateSecureCode(); // Regenerate if problematic
    }
    
    return code;
  }

  /// Check if code contains problematic patterns
  static bool _isProblematicCode(String code) {
    final problematicPatterns = [
      'AAAAAA', 'BBBBBB', '123456', '654321', 'ABCDEF'
    ];
    
    return problematicPatterns.any((pattern) => code.contains(pattern));
  }

  /// Enhanced verification with fraud prevention
  static Future<CodeVerificationResult> verifyCodeSecure({
    required String orderId,
    required String enteredCode,
    required String driverId,
    required DriverLocation driverLocation,
  }) async {
    try {
      // Rate limiting check
      final rateLimitResult = await _checkRateLimit(orderId, driverId);
      if (!rateLimitResult.allowed) {
        return CodeVerificationResult(
          isValid: false,
          errorMessage: rateLimitResult.message,
          shouldBlock: true,
        );
      }

      // Get order with transaction to prevent race conditions
      final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderRef = FirebaseFirestore.instance.collection('food_orders').doc(orderId);
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw Exception('Order not found');
        }

        final orderData = orderSnapshot.data()!;
        final correctCode = orderData['deliveryCode'] as String;
        final currentAttempts = (orderData['codeAttempts'] as int?) ?? 0;
        final maxAttempts = (orderData['maxCodeAttempts'] as int?) ?? 3;

        // Validate driver assignment
        if (orderData['driverId'] != driverId) {
          throw Exception('Driver not assigned to this order');
        }

        // Check order status
        if (orderData['status'] != 'driver_at_customer') {
          throw Exception('Order not ready for delivery verification');
        }

        // Location validation (driver must be near customer)
        final customerLat = orderData['customerLocation']['latitude'] as double;
        final customerLng = orderData['customerLocation']['longitude'] as double;
        final distance = _calculateDistance(
          customerLat, customerLng,
          driverLocation.lat, driverLocation.lng,
        );

        if (distance > 0.1) { // Must be within 100 meters
          throw Exception('Driver too far from delivery location');
        }

        // Check if max attempts exceeded
        if (currentAttempts >= maxAttempts) {
          // Flag for manual review
          transaction.update(orderRef, {
            'status': 'delivery_verification_failed',
            'flaggedForReview': true,
            'flaggedAt': FieldValue.serverTimestamp(),
          });
          
          return CodeVerificationResult(
            isValid: false,
            errorMessage: 'Maximum attempts exceeded. Order flagged for review.',
            shouldBlock: true,
          );
        }

        // Verify code
        final isCodeCorrect = enteredCode.toUpperCase() == correctCode.toUpperCase();

        // Update attempt tracking
        transaction.update(orderRef, {
          'codeAttempts': currentAttempts + 1,
          'lastCodeAttemptAt': FieldValue.serverTimestamp(),
          'codeAttemptHistory': FieldValue.arrayUnion([
            {
              'attempt': currentAttempts + 1,
              'enteredCode': enteredCode, // For debugging (hashed in production)
              'isCorrect': isCodeCorrect,
              'timestamp': FieldValue.serverTimestamp(),
              'driverLocation': {
                'latitude': driverLocation.lat,
                'longitude': driverLocation.lng,
              },
            }
          ]),
        });

        if (isCodeCorrect) {
          // Complete delivery
          transaction.update(orderRef, {
            'status': 'delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
            'codeVerifiedAt': FieldValue.serverTimestamp(),
            'deliveryCompletedBy': driverId,
          });

          // Update driver status
          final driverQuery = await FirebaseFirestore.instance
              .collection('delivery_drivers')
              .where('userId', '==', driverId)
              .limit(1)
              .get();

          if (driverQuery.docs.isNotEmpty) {
            transaction.update(driverQuery.docs.first.reference, {
              'availabilityStatus': 'available',
              'currentOrderId': null,
              'lastDeliveryCompletedAt': FieldValue.serverTimestamp(),
              'totalDeliveries': FieldValue.increment(1),
            });
          }

          return CodeVerificationResult(
            isValid: true,
            message: 'Delivery completed successfully!',
          );
        } else {
          final remainingAttempts = maxAttempts - (currentAttempts + 1);
          
          return CodeVerificationResult(
            isValid: false,
            errorMessage: 'Invalid delivery code. $remainingAttempts attempts remaining.',
            remainingAttempts: remainingAttempts,
          );
        }
      });

      return result;

    } catch (e) {
      print('❌ Code verification error: $e');
      return CodeVerificationResult(
        isValid: false,
        errorMessage: 'Verification failed: ${e.toString()}',
        shouldBlock: false,
      );
    }
  }

  /// Rate limiting to prevent brute force attacks
  static Future<RateLimitResult> _checkRateLimit(String orderId, String driverId) async {
    try {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(Duration(hours: 1));

      // Check attempts in last hour
      final recentAttempts = await FirebaseFirestore.instance
          .collection('code_attempt_log')
          .where('driverId', isEqualTo: driverId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      const maxAttemptsPerHour = 20; // Prevent brute force
      
      if (recentAttempts.docs.length >= maxAttemptsPerHour) {
        return RateLimitResult(
          allowed: false,
          message: 'Too many verification attempts. Try again later.',
        );
      }

      // Log this attempt
      await FirebaseFirestore.instance.collection('code_attempt_log').add({
        'orderId': orderId,
        'driverId': driverId,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': await _getClientIP(), // If available
      });

      return RateLimitResult(allowed: true);

    } catch (e) {
      print('❌ Rate limit check error: $e');
      return RateLimitResult(allowed: true); // Fail open for availability
    }
  }
}

class RateLimitResult {
  final bool allowed;
  final String? message;

  const RateLimitResult({required this.allowed, this.message});
}
```

## 📱 Real-Time Components Implementation

### WebSocket Integration for Live Updates

```dart
class OrderTrackingWebSocket {
  static IOWebSocketChannel? _channel;
  static StreamSubscription? _subscription;

  /// Connect to real-time order updates
  static void connectToOrderUpdates(String orderId, Function(OrderUpdate) onUpdate) {
    try {
      // Use Firestore real-time listeners (more reliable than WebSocket for this use case)
      _subscription = FirebaseFirestore.instance
          .collection('food_orders')
          .doc(orderId)
          .snapshots()
          .listen((snapshot) {
        
        if (snapshot.exists) {
          final orderData = snapshot.data()!;
          final update = OrderUpdate.fromMap(orderData);
          onUpdate(update);
          
          // Trigger UI updates based on status changes
          _handleStatusChange(update);
        }
      });

      print('🔗 Connected to real-time updates for order: $orderId');

    } catch (e) {
      print('❌ Error connecting to order updates: $e');
    }
  }

  /// Handle status changes with appropriate UI updates
  static void _handleStatusChange(OrderUpdate update) {
    switch (update.status) {
      case 'accepted_by_vendor':
        _showNotification('Order Accepted!', 'Your order is being prepared');
        break;
      case 'preparing':
        _showNotification('Preparing Order', 'Estimated time: ${update.prepTimeEstimate}min');
        break;
      case 'driver_assigned':
        _showNotification('Driver Assigned', '${update.driverName} will deliver your order');
        break;
      case 'driver_en_route_to_customer':
        _showNotification('Driver on the way!', 'Your order will arrive soon');
        _startLocationTracking(update.orderId);
        break;
      case 'driver_at_customer':
        _showNotification('Driver Arrived!', 'Your delivery code is: ${update.deliveryCode}');
        _vibrate(); // Alert customer
        break;
      case 'delivered':
        _showNotification('Order Delivered!', 'Enjoy your meal!');
        _stopLocationTracking();
        break;
    }
  }

  /// Enhanced map integration with real-time polylines
  static Widget buildLiveTrackingMap(OrderUpdate order) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(order.customerLat, order.customerLng),
        zoom: 14,
      ),
      markers: _buildTrackingMarkers(order),
      polylines: _buildLivePolylines(order),
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _animateToShowAllPoints(order);
      },
    );
  }

  /// Build polylines showing route and driver progress
  static Set<Polyline> _buildLivePolylines(OrderUpdate order) {
    final polylines = <Polyline>{};

    // Route from vendor to customer (static)
    if (order.vendorLat != null && order.vendorLng != null) {
      polylines.add(Polyline(
        polylineId: PolylineId('vendor_to_customer'),
        points: [
          LatLng(order.vendorLat!, order.vendorLng!),
          LatLng(order.customerLat, order.customerLng),
        ],
        color: Colors.grey.shade400,
        width: 3,
        patterns: [PatternItem.dash(10), PatternItem.gap(5)], // Dashed line
      ));
    }

    // Live driver route (dynamic)
    if (order.driverLat != null && order.driverLng != null) {
      LatLng destination;
      Color routeColor;
      
      if (['driver_en_route_to_vendor', 'driver_at_vendor'].contains(order.status)) {
        // Driver going to vendor
        destination = LatLng(order.vendorLat!, order.vendorLng!);
        routeColor = Colors.orange;
      } else {
        // Driver going to customer
        destination = LatLng(order.customerLat, order.customerLng);
        routeColor = Colors.green;
      }

      polylines.add(Polyline(
        polylineId: PolylineId('driver_route'),
        points: [
          LatLng(order.driverLat!, order.driverLng!),
          destination,
        ],
        color: routeColor,
        width: 5,
      ));
    }

    return polylines;
  }

  /// Disconnect from updates
  static void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    print('🔌 Disconnected from order updates');
  }
}

class OrderUpdate {
  final String orderId;
  final String status;
  final int? prepTimeEstimate;
  final String? driverName;
  final String? deliveryCode;
  final double customerLat;
  final double customerLng;
  final double? vendorLat;
  final double? vendorLng;
  final double? driverLat;
  final double? driverLng;
  final DateTime? estimatedDelivery;

  const OrderUpdate({
    required this.orderId,
    required this.status,
    this.prepTimeEstimate,
    this.driverName,
    this.deliveryCode,
    required this.customerLat,
    required this.customerLng,
    this.vendorLat,
    this.vendorLng,
    this.driverLat,
    this.driverLng,
    this.estimatedDelivery,
  });

  factory OrderUpdate.fromMap(Map<String, dynamic> data) {
    return OrderUpdate(
      orderId: data['id'],
      status: data['status'],
      prepTimeEstimate: data['prepTimeEstimate'],
      driverName: data['driverName'],
      deliveryCode: data['deliveryCode'],
      customerLat: data['customerLocation']['latitude'],
      customerLng: data['customerLocation']['longitude'],
      vendorLat: data['vendorLocation']?['latitude'],
      vendorLng: data['vendorLocation']?['longitude'],
      driverLat: data['driverLocation']?['latitude'],
      driverLng: data['driverLocation']?['longitude'],
      estimatedDelivery: data['estimatedDeliveryTime'] != null 
          ? DateTime.parse(data['estimatedDeliveryTime'])
          : null,
    );
  }
}
```

This comprehensive design provides:

- ✅ **Vendor-centric cart** with conflict resolution
- ✅ **Complete order state management** with 15 distinct states
- ✅ **Vendor dashboard** with prep time and driver assignment
- ✅ **Driver app flow** with status updates and location tracking
- ✅ **Secure delivery codes** with fraud prevention
- ✅ **Real-time tracking** with live maps and notifications
- ✅ **Comprehensive API design** for all interactions
- ✅ **Security measures** including rate limiting and location validation

Ready for implementation! 🚀