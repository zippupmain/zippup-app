# Optimized Database Schema for Order Dispatch & Matching System

## Core Collections

### 1. `provider_profiles` Collection
```javascript
{
  // Document ID: auto-generated
  userId: "user_123",                    // Reference to users collection
  service: "transport",                  // Primary service type
  subcategory: "Taxi",                  // Service subcategory
  status: "active",                     // active | inactive | suspended
  
  // Availability & Location (Critical for real-time matching)
  availabilityOnline: true,             // Boolean for quick filtering
  availabilityStatus: "available",      // available | assigned | busy | offline
  currentOrderId: null,                 // Current active order (if any)
  currentLocation: {                    // GeoPoint for proximity queries
    latitude: 6.5244,
    longitude: 3.3792,
    lastUpdated: Timestamp,
    accuracy: 10.5                      // meters
  },
  
  // Service Class Configuration (Critical for matching)
  enabledClasses: {                     // Explicit class enablement
    "standard": true,
    "compact": true,
    "suv": false,
    "luxury": true
  },
  serviceClasses: [                     // Array for backward compatibility
    "standard", "compact", "luxury"
  ],
  
  // Provider Capabilities & Constraints
  metadata: {
    vehicleCapacity: 4,                 // For transport/moving
    vehicleType: "sedan",               // car | bike | truck | van
    serviceRadius: 5.0,                 // km - provider's coverage area
    maxOrdersPerDay: 20,
    operatingHours: {
      start: "06:00",
      end: "22:00",
      timezone: "Africa/Lagos"
    }
  },
  
  // Performance Metrics (for scoring)
  rating: 4.7,                          // Average rating
  completedOrders: 156,                 // Total completed orders
  avgResponseTime: 25.0,                // Seconds average acceptance time
  completionRate: 0.95,                 // Percentage of accepted orders completed
  
  // Emergency/Specialized Service Data
  certifications: [                     // For emergency/hire services
    "medical_transport",
    "first_aid_certified"
  ],
  equipment: [                          // Available equipment/tools
    "medical_equipment",
    "oxygen_tank"
  ],
  skills: [                             // For hire services
    "plumbing", "electrical_work"
  ],
  
  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp,
  lastOnlineAt: Timestamp
}
```

### 2. `orders` Collection (Generic)
```javascript
{
  // Document ID: auto-generated order ID
  customerId: "user_456",
  providerId: null,                     // Set when dispatched
  
  // Service Classification
  service: "transport",                 // Service type
  serviceClass: "standard",             // Specific class within service
  category: "transport",                // For backward compatibility
  
  // Order State Management
  status: "pending",                    // pending | searching | dispatched | accepted | in_progress | completed | cancelled | failed
  statusMessage: "Finding providers...", // Human-readable status
  
  // Location Data (Critical for matching)
  customerLocation: {
    latitude: 6.5244,
    longitude: 3.3792,
    address: "123 Main St, Lagos"
  },
  pickupLocation: {                     // For transport/delivery
    latitude: 6.5244,
    longitude: 3.3792,
    address: "123 Main St, Lagos"
  },
  destinationLocation: {                // For transport/delivery
    latitude: 6.5300,
    longitude: 3.3800,
    address: "456 Oak Ave, Lagos"
  },
  
  // Dispatch Tracking
  dispatchHistory: [                    // Track all dispatch attempts
    {
      attemptNumber: 1,
      providerId: "provider_789",
      dispatchedAt: Timestamp,
      status: "timed_out",              // dispatched | accepted | declined | timed_out
      responseTime: 60                  // seconds
    }
  ],
  currentDispatchAttempt: 1,
  maxDispatchAttempts: 5,
  
  // Service-Specific Data
  serviceData: {
    // Transport
    rideType: "standard",
    passengerCount: 2,
    fareEstimate: 1500,
    
    // Emergency
    emergencyType: "ambulance",
    urgencyLevel: "high",
    patientCondition: "stable",
    
    // Hire
    skillRequired: "plumber",
    estimatedDuration: 120,             // minutes
    tools_required: ["wrench", "pipe_fittings"],
    
    // Moving
    movingType: "truck_small",
    itemCount: 5,
    weight: 500                         // kg
  },
  
  // Financial
  pricing: {
    basePrice: 1000,
    distancePrice: 500,
    totalEstimate: 1500,
    currency: "NGN"
  },
  
  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp,
  dispatchedAt: Timestamp,
  acceptedAt: Timestamp,
  completedAt: Timestamp
}
```

### 3. Service-Specific Collections

#### `rides` Collection (Transport)
```javascript
{
  // Inherits from orders + transport-specific fields
  riderId: "user_456",                  // Customer
  driverId: "user_789",                 // Provider
  type: "standard",                     // Ride class
  status: "requested",                  // Transport-specific statuses
  
  // Location tracking
  pickupLat: 6.5244,
  pickupLng: 3.3792,
  destLat: 6.5300,
  destLng: 3.3800,
  driverLat: 6.5240,                   // Real-time driver location
  driverLng: 3.3790,
  
  // Transport metadata
  passengerCount: 2,
  fareEstimate: 1500,
  distance: 5.2,                        // km
  estimatedDuration: 15                 // minutes
}
```

#### `emergency_bookings` Collection
```javascript
{
  clientId: "user_456",
  providerId: "emergency_provider_123",
  emergencyType: "ambulance",           // ambulance | fire_services | security_services
  urgencyLevel: "critical",             // low | medium | high | critical
  
  // Location
  incidentLocation: {
    latitude: 6.5244,
    longitude: 3.3792,
    address: "Emergency at 123 Main St"
  },
  
  // Emergency-specific data
  patientInfo: {
    age: 45,
    condition: "chest_pain",
    consciousness: "conscious"
  },
  
  requiredCertifications: [
    "medical_transport",
    "first_aid"
  ]
}
```

#### `hire_bookings` Collection
```javascript
{
  clientId: "user_456",
  providerId: "hire_provider_789",
  skillRequired: "plumber",             // Specific skill/class
  
  // Job details
  jobDetails: {
    description: "Fix leaking pipe",
    estimatedDuration: 120,             // minutes
    toolsRequired: ["wrench", "pipe_fittings"],
    difficultyLevel: "medium"
  },
  
  // Scheduling
  preferredTimeSlot: {
    start: Timestamp,
    end: Timestamp,
    flexible: true
  }
}
```

## Database Indexes (Critical for Performance)

### Firestore Composite Indexes

```javascript
// Provider matching indexes
provider_profiles: [
  ["service", "availabilityOnline", "availabilityStatus"],
  ["service", "status", "availabilityOnline", "currentLocation"],
  ["userId", "service", "status"],
  ["service", "subcategory", "availabilityOnline"],
  ["availabilityStatus", "service", "currentLocation"]
]

// Order tracking indexes
orders: [
  ["customerId", "status", "createdAt"],
  ["providerId", "status", "updatedAt"],
  ["service", "status", "createdAt"],
  ["status", "createdAt"]
]

// Service-specific indexes
rides: [
  ["riderId", "status", "createdAt"],
  ["driverId", "status", "updatedAt"],
  ["status", "createdAt"]
]
```

### Geographic Queries (for proximity matching)
```javascript
// Use Firestore's built-in geohash or implement custom geo-indexing
provider_profiles: [
  ["service", "availabilityOnline", "geoHash"],
  ["currentLocation", "service", "availabilityOnline"]
]
```

## Optimizations & Best Practices

### 1. Real-Time Updates
```javascript
// Use Firestore triggers for real-time provider status updates
exports.updateProviderStatus = functions.firestore
  .document('provider_profiles/{providerId}')
  .onUpdate((change, context) => {
    // Automatically update matching eligibility
    // Trigger re-dispatch if provider goes offline during assignment
  });
```

### 2. Caching Strategy
```javascript
// Cache frequently accessed data
const providerCache = {
  "transport_active_providers": {
    data: [...],
    lastUpdated: Timestamp,
    ttl: 30 // seconds
  }
};
```

### 3. Geographic Partitioning
```javascript
// Partition providers by geographic regions for faster queries
provider_profiles: {
  region: "lagos_mainland",             // Geographic partition key
  subregion: "ikeja",                   // Finer geographic division
  // ... other fields
}
```

### 4. Load Balancing
```javascript
// Distribute requests across multiple providers in same area
const loadBalancingStrategy = {
  method: "round_robin",                // round_robin | least_busy | highest_rated
  maxConcurrentOrders: 3,               // Per provider limit
  cooldownPeriod: 300                   // Seconds between assignments
};
```

## Performance Considerations

### Query Optimization
1. **Always filter by service first** - most selective field
2. **Use composite indexes** for multi-field queries
3. **Limit result sets** to prevent large data transfers
4. **Cache provider lists** for frequently requested services
5. **Use geographic indexes** for proximity queries

### Real-Time Efficiency
1. **Firestore listeners** for provider status changes
2. **Background location updates** for providers
3. **Efficient timeout management** with cleanup
4. **Connection pooling** for database operations

### Scalability Features
1. **Horizontal partitioning** by geographic regions
2. **Service-specific collections** to reduce query complexity
3. **Automated cleanup** of expired orders and timeouts
4. **Rate limiting** to prevent spam requests

This schema supports:
- ✅ Exact service and class matching
- ✅ Real-time proximity queries
- ✅ Efficient timeout handling
- ✅ Comprehensive order state tracking
- ✅ Performance optimization at scale