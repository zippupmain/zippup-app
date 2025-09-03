const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { GeoFirestore } = require('geofirestore');

// Initialize Firestore and GeoFirestore
const db = admin.firestore();
const geofirestore = new GeoFirestore(db);

/**
 * Real-Time Order Dispatch and Matching Engine
 * 
 * Core Features:
 * - Intelligent service and class matching
 * - Geographic proximity filtering
 * - Automatic timeout and re-dispatch
 * - Provider scoring and selection
 * - Real-time state management
 */

class MatchingEngine {
  constructor() {
    this.timeoutTimers = new Map();
    this.dispatchAttempts = new Map();
    this.attemptedProviders = new Map();
    
    // Configuration
    this.config = {
      REQUEST_TIMEOUT_MS: 60000,        // 60 seconds
      DEFAULT_RADIUS_KM: 5.0,
      MAX_DISPATCH_ATTEMPTS: 5,
      MAX_PROVIDERS_PER_ATTEMPT: 10,
      RETRY_DELAY_MS: 10000,            // 10 seconds between retries
    };

    // Service class definitions
    this.serviceClasses = {
      transport: ['tricycle', 'compact', 'standard', 'suv', 'bike_economy', 'bike_luxury', 
                  'bus_charter', 'bus_mini', 'bus_standard', 'bus_large'],
      moving: ['truck_small', 'truck_medium', 'truck_large', 'pickup_small', 'pickup_large',
               'courier_bike', 'courier_intracity', 'courier_intrastate', 'courier_nationwide'],
      emergency: ['ambulance', 'fire_services', 'security_services', 'towing_van', 
                   'roadside_tyre_fix', 'roadside_battery', 'roadside_fuel', 
                   'roadside_mechanic', 'roadside_lockout', 'roadside_jumpstart'],
      hire: ['plumber', 'electrician', 'hairstylist', 'cleaner', 'tutor', 'carpenter', 'painter', 'mechanic']
    };
  }

  /**
   * Core matching algorithm - finds eligible providers
   * 
   * @param {Object} params - Matching parameters
   * @param {string} params.service - Service type (transport, emergency, etc.)
   * @param {string} params.serviceClass - Specific class within service
   * @param {number} params.customerLat - Customer latitude
   * @param {number} params.customerLng - Customer longitude
   * @param {string} params.orderId - Order ID for tracking
   * @param {number} params.radiusKm - Search radius in kilometers
   * @returns {Promise<Array>} Sorted list of eligible providers
   */
  async findEligibleProviders({
    service,
    serviceClass,
    customerLat,
    customerLng,
    orderId,
    radiusKm = this.config.DEFAULT_RADIUS_KM
  }) {
    console.log(`🔍 Finding providers for ${service}/${serviceClass} at (${customerLat}, ${customerLng})`);
    
    try {
      // Step 1: Validate service class
      if (!this._isValidServiceClass(service, serviceClass)) {
        throw new Error(`Invalid service class: ${service}/${serviceClass}`);
      }

      // Step 2: Geographic query for nearby providers
      const center = new admin.firestore.GeoPoint(customerLat, customerLng);
      const radiusInM = radiusKm * 1000;

      // Use GeoFirestore for efficient proximity queries
      const geoCollection = geofirestore.collection('provider_profiles');
      const geoQuery = geoCollection.near({
        center: center,
        radius: radiusInM
      });

      // Step 3: Apply service and availability filters
      const query = geoQuery
        .where('service', '==', service)
        .where('status', '==', 'active')
        .where('availabilityOnline', '==', true)
        .where('availabilityStatus', 'in', ['available', 'idle'])
        .limit(50);

      const snapshot = await query.get();
      console.log(`📊 Found ${snapshot.docs.length} nearby ${service} providers`);

      if (snapshot.empty) {
        console.log(`❌ No providers found within ${radiusKm}km`);
        return [];
      }

      // Step 4: Filter and score providers
      const eligibleProviders = [];
      const attemptedList = this.attemptedProviders.get(orderId) || [];

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const providerId = data.userId;

        // Skip if already attempted
        if (attemptedList.includes(providerId)) {
          continue;
        }

        // Step 4a: Service class validation
        if (!this._supportsServiceClass(data, serviceClass)) {
          console.log(`❌ Provider ${providerId} doesn't support class: ${serviceClass}`);
          continue;
        }

        // Step 4b: Service-specific validation
        if (!this._passesServiceValidation(service, serviceClass, data)) {
          console.log(`❌ Provider ${providerId} failed service validation`);
          continue;
        }

        // Step 4c: Availability validation
        if (!this._isProviderAvailable(data)) {
          console.log(`❌ Provider ${providerId} is not available`);
          continue;
        }

        // Step 5: Calculate provider score
        const distance = this._calculateDistance(
          customerLat, customerLng,
          data.currentLocation.latitude, data.currentLocation.longitude
        );

        const score = this._calculateProviderScore({
          distance,
          rating: data.rating || 4.0,
          completedOrders: data.completedOrders || 0,
          responseTime: data.avgResponseTime || 30.0,
          completionRate: data.completionRate || 0.9
        });

        eligibleProviders.push({
          id: providerId,
          profileId: doc.id,
          distance,
          score,
          rating: data.rating || 4.0,
          completedOrders: data.completedOrders || 0,
          metadata: data
        });

        console.log(`✅ Eligible: ${providerId} (${distance.toFixed(2)}km, score: ${score.toFixed(2)})`);
      }

      // Step 6: Sort by score (descending)
      eligibleProviders.sort((a, b) => b.score - a.score);

      console.log(`🎯 Found ${eligibleProviders.length} eligible providers`);
      return eligibleProviders.slice(0, this.config.MAX_PROVIDERS_PER_ATTEMPT);

    } catch (error) {
      console.error('❌ Error in findEligibleProviders:', error);
      throw error;
    }
  }

  /**
   * Main dispatch function - orchestrates matching and timeout handling
   * 
   * @param {string} orderId - Unique order identifier
   * @param {Object} orderData - Complete order information
   * @returns {Promise<boolean>} Success status
   */
  async dispatchRequest(orderId, orderData = null) {
    console.log(`🚀 Dispatching order: ${orderId}`);
    
    try {
      // Fetch order data if not provided
      if (!orderData) {
        orderData = await this._getOrderData(orderId);
        if (!orderData) {
          throw new Error(`Order not found: ${orderId}`);
        }
      }

      // Extract required fields
      const {
        service,
        serviceClass,
        customerLocation,
        customerId
      } = orderData;

      if (!service || !serviceClass || !customerLocation) {
        throw new Error('Missing required order data for dispatch');
      }

      // Track dispatch attempt
      const attemptNumber = (this.dispatchAttempts.get(orderId) || 0) + 1;
      this.dispatchAttempts.set(orderId, attemptNumber);

      if (attemptNumber > this.config.MAX_DISPATCH_ATTEMPTS) {
        console.log(`❌ Max attempts reached for order: ${orderId}`);
        await this._updateOrderStatus(orderId, 'failed', 'No providers available');
        this._cleanup(orderId);
        return false;
      }

      console.log(`📈 Dispatch attempt ${attemptNumber}/${this.config.MAX_DISPATCH_ATTEMPTS}`);

      // Find eligible providers
      const providers = await this.findEligibleProviders({
        service,
        serviceClass,
        customerLat: customerLocation.latitude,
        customerLng: customerLocation.longitude,
        orderId,
        radiusKm: this._getSearchRadius(service, attemptNumber)
      });

      if (providers.length === 0) {
        console.log(`❌ No eligible providers found for order: ${orderId}`);
        
        if (attemptNumber >= this.config.MAX_DISPATCH_ATTEMPTS) {
          await this._updateOrderStatus(orderId, 'failed', 'No providers available in area');
          this._cleanup(orderId);
          return false;
        } else {
          // Schedule retry with expanded radius
          setTimeout(() => {
            this.dispatchRequest(orderId, orderData);
          }, this.config.RETRY_DELAY_MS);
          return false;
        }
      }

      // Select best provider
      const selectedProvider = providers[0];
      console.log(`🎯 Selected provider: ${selectedProvider.id} (score: ${selectedProvider.score.toFixed(2)})`);

      // Assign provider to order
      await this._assignProviderToOrder(orderId, selectedProvider, orderData);

      // Track attempted provider
      const attempted = this.attemptedProviders.get(orderId) || [];
      attempted.push(selectedProvider.id);
      this.attemptedProviders.set(orderId, attempted);

      // Start timeout timer
      this._startTimeoutTimer(orderId, orderData);

      return true;

    } catch (error) {
      console.error(`❌ Error dispatching order ${orderId}:`, error);
      await this._updateOrderStatus(orderId, 'failed', `Dispatch error: ${error.message}`);
      return false;
    }
  }

  /**
   * Timeout handler - automatically re-dispatches when provider doesn't respond
   */
  _startTimeoutTimer(orderId, orderData) {
    // Clear existing timer
    if (this.timeoutTimers.has(orderId)) {
      clearTimeout(this.timeoutTimers.get(orderId));
    }

    const timer = setTimeout(async () => {
      console.log(`⏰ Timeout reached for order: ${orderId}`);
      
      try {
        // Check if order was accepted in the meantime
        const currentOrderData = await this._getOrderData(orderId);
        if (currentOrderData && currentOrderData.status === 'accepted') {
          console.log(`✅ Order ${orderId} was accepted, canceling timeout`);
          this._cleanup(orderId);
          return;
        }

        // Mark current provider as timed out
        if (currentOrderData && currentOrderData.providerId) {
          await this._handleProviderTimeout(orderId, currentOrderData.providerId);
        }

        // Update order status
        await this._updateOrderStatus(orderId, 'searching', 'Finding another provider...');

        // Re-dispatch to next provider
        const success = await this.dispatchRequest(orderId, orderData);
        if (!success) {
          console.log(`❌ Failed to re-dispatch order: ${orderId}`);
        }

      } catch (error) {
        console.error(`❌ Error in timeout handler for ${orderId}:`, error);
      }
    }, this.config.REQUEST_TIMEOUT_MS);

    this.timeoutTimers.set(orderId, timer);
    console.log(`⏱️ Started ${this.config.REQUEST_TIMEOUT_MS/1000}s timeout for order: ${orderId}`);
  }

  /**
   * Handle provider acceptance
   */
  async handleProviderAcceptance(orderId, providerId) {
    console.log(`✅ Provider ${providerId} accepted order: ${orderId}`);
    
    // Clear timeout timer
    if (this.timeoutTimers.has(orderId)) {
      clearTimeout(this.timeoutTimers.get(orderId));
      this.timeoutTimers.delete(orderId);
    }

    // Update order status
    await this._updateOrderStatus(orderId, 'accepted', 'Provider accepted request');
    
    // Update provider status
    await this._updateProviderStatus(providerId, 'busy', orderId);
    
    // Cleanup tracking
    this._cleanup(orderId);
    
    return true;
  }

  /**
   * Handle provider decline
   */
  async handleProviderDecline(orderId, providerId, reason = 'declined') {
    console.log(`❌ Provider ${providerId} declined order: ${orderId} (${reason})`);
    
    // Add to attempted list
    const attempted = this.attemptedProviders.get(orderId) || [];
    if (!attempted.includes(providerId)) {
      attempted.push(providerId);
      this.attemptedProviders.set(orderId, attempted);
    }

    // Reset provider availability
    await this._updateProviderStatus(providerId, 'available', null);
    
    // Get fresh order data and re-dispatch
    const orderData = await this._getOrderData(orderId);
    if (orderData) {
      // Small delay before re-dispatch
      setTimeout(() => {
        this.dispatchRequest(orderId, orderData);
      }, 2000);
    }
  }

  /**
   * Handle provider timeout
   */
  async _handleProviderTimeout(orderId, providerId) {
    console.log(`⏰ Provider ${providerId} timed out for order: ${orderId}`);
    
    // Update dispatch history
    await this._recordDispatchAttempt(orderId, providerId, 'timed_out');
    
    // Reset provider status
    await this._updateProviderStatus(providerId, 'available', null);
    
    return this.handleProviderDecline(orderId, providerId, 'timeout');
  }

  /**
   * Service class support validation
   */
  _supportsServiceClass(providerData, requestedClass) {
    // Check explicit enabledClasses
    const enabledClasses = providerData.enabledClasses || {};
    if (enabledClasses.hasOwnProperty(requestedClass)) {
      return enabledClasses[requestedClass] === true;
    }

    // Check serviceClasses array
    const serviceClasses = providerData.serviceClasses || [];
    if (serviceClasses.includes(requestedClass)) {
      return true;
    }

    // Fallback: subcategory compatibility
    return this._isClassCompatibleWithSubcategory(requestedClass, providerData.subcategory);
  }

  /**
   * Service-specific validation logic
   */
  _passesServiceValidation(service, serviceClass, providerData) {
    switch (service) {
      case 'transport':
        return this._validateTransportProvider(serviceClass, providerData);
      case 'emergency':
        return this._validateEmergencyProvider(serviceClass, providerData);
      case 'hire':
        return this._validateHireProvider(serviceClass, providerData);
      case 'moving':
        return this._validateMovingProvider(serviceClass, providerData);
      default:
        return true;
    }
  }

  /**
   * Transport service validation
   */
  _validateTransportProvider(requestedClass, data) {
    const subcategory = data.subcategory;
    const vehicleCapacity = data.metadata?.vehicleCapacity || 1;

    // Class-subcategory mapping
    const classMapping = {
      'tricycle': 'Tricycle',
      'compact': 'Taxi',
      'standard': 'Taxi',
      'suv': 'Taxi',
      'bike_economy': 'Bike',
      'bike_luxury': 'Bike',
      'bus_charter': 'Bus',
      'bus_mini': 'Bus',
      'bus_standard': 'Bus',
      'bus_large': 'Bus'
    };

    const requiredSubcategory = classMapping[requestedClass];
    if (requiredSubcategory && subcategory !== requiredSubcategory) {
      console.log(`❌ Subcategory mismatch: need ${requiredSubcategory}, have ${subcategory}`);
      return false;
    }

    // Bus capacity validation
    if (requestedClass.startsWith('bus_')) {
      const minCapacity = this._getBusCapacityRequirement(requestedClass);
      if (vehicleCapacity < minCapacity) {
        console.log(`❌ Insufficient capacity: need ${minCapacity}, have ${vehicleCapacity}`);
        return false;
      }
    }

    return true;
  }

  /**
   * Emergency service validation - strict matching
   */
  _validateEmergencyProvider(requestedClass, data) {
    const enabledClasses = data.enabledClasses || {};
    const certifications = data.certifications || [];

    // Emergency services require explicit class enablement
    if (!enabledClasses[requestedClass]) {
      console.log(`❌ Emergency class not enabled: ${requestedClass}`);
      return false;
    }

    // Class-specific certification requirements
    const requiredCerts = {
      'ambulance': ['medical_transport', 'first_aid'],
      'fire_services': ['fire_safety', 'emergency_response'],
      'security_services': ['security_license'],
      'towing_van': ['towing_license', 'commercial_driving_license'],
      'roadside_tyre_fix': ['automotive_repair', 'tyre_specialist'],
      'roadside_battery': ['automotive_electrical', 'battery_specialist'],
      'roadside_fuel': ['fuel_handling_license'],
      'roadside_mechanic': ['automotive_repair', 'mechanical_certification'],
      'roadside_lockout': ['locksmith_certification'],
      'roadside_jumpstart': ['automotive_electrical']
    };

    const required = requiredCerts[requestedClass] || [];
    const hasRequiredCerts = required.some(cert => certifications.includes(cert));

    if (required.length > 0 && !hasRequiredCerts) {
      console.log(`❌ Missing certifications for ${requestedClass}: need ${required.join(' or ')}`);
      return false;
    }

    return true;
  }

  /**
   * Hire service validation
   */
  _validateHireProvider(requestedClass, data) {
    const enabledClasses = data.enabledClasses || {};
    const skills = data.skills || [];

    // Check explicit enablement or skills array
    return enabledClasses[requestedClass] === true || skills.includes(requestedClass);
  }

  /**
   * Moving service validation
   */
  _validateMovingProvider(requestedClass, data) {
    const enabledClasses = data.enabledClasses || {};
    const vehicleType = data.metadata?.vehicleType;

    // Check explicit enablement
    if (enabledClasses[requestedClass] === true) {
      return true;
    }

    // Vehicle type compatibility
    const vehicleCompatibility = {
      'truck_small': ['truck', 'pickup'],
      'truck_medium': ['truck'],
      'truck_large': ['truck'],
      'pickup_small': ['pickup'],
      'pickup_large': ['pickup'],
      'courier_bike': ['bike', 'motorcycle'],
      'courier_intracity': ['bike', 'motorcycle', 'car'],
      'courier_intrastate': ['car', 'van'],
      'courier_nationwide': ['van', 'truck']
    };

    const compatible = vehicleCompatibility[requestedClass] || [];
    return compatible.includes(vehicleType?.toLowerCase());
  }

  /**
   * Provider scoring algorithm
   */
  _calculateProviderScore({ distance, rating, completedOrders, responseTime, completionRate }) {
    // Multi-factor scoring (0-100 scale)
    const distanceScore = Math.max(0, 100 - (distance * 15));  // Penalty for distance
    const ratingScore = (rating / 5.0) * 100;                  // 5-star rating = 100
    const experienceScore = Math.min(50, completedOrders * 0.5); // Experience bonus
    const speedScore = Math.max(0, 50 - responseTime);         // Fast response bonus
    const reliabilityScore = completionRate * 50;              // Completion rate bonus

    // Weighted average
    const totalScore = 
      (distanceScore * 0.35) +      // Distance is most important
      (ratingScore * 0.25) +        // Customer satisfaction
      (experienceScore * 0.20) +    // Experience matters
      (speedScore * 0.10) +         // Response speed
      (reliabilityScore * 0.10);    // Reliability

    return Math.round(totalScore * 100) / 100; // Round to 2 decimals
  }

  /**
   * Assign provider to order
   */
  async _assignProviderToOrder(orderId, provider, orderData) {
    const collection = this._getCollectionForService(orderData.service);
    
    const updateData = {
      providerId: provider.id,
      status: 'dispatched',
      dispatchedAt: admin.firestore.FieldValue.serverTimestamp(),
      dispatchAttempt: this.dispatchAttempts.get(orderId) || 1,
      estimatedDistance: provider.distance,
      estimatedArrival: new Date(Date.now() + (provider.distance * 2 * 60 * 1000)), // 2 min per km
      selectedProviderScore: provider.score,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Update order
    await db.collection(collection).doc(orderId).update(updateData);

    // Update provider status
    await db.collection('provider_profiles')
      .where('userId', '==', provider.id)
      .limit(1)
      .get()
      .then(snapshot => {
        if (!snapshot.empty) {
          return snapshot.docs[0].ref.update({
            availabilityStatus: 'assigned',
            currentOrderId: orderId,
            lastAssignedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      });

    // Record dispatch attempt
    await this._recordDispatchAttempt(orderId, provider.id, 'dispatched');

    console.log(`✅ Assigned provider ${provider.id} to order ${orderId}`);
  }

  /**
   * Update order status
   */
  async _updateOrderStatus(orderId, status, message = null) {
    const collections = ['rides', 'orders', 'emergency_bookings', 'moving_bookings', 'hire_bookings'];
    
    for (const collection of collections) {
      try {
        const doc = await db.collection(collection).doc(orderId).get();
        if (doc.exists) {
          const updateData = {
            status,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          };
          if (message) updateData.statusMessage = message;
          
          await doc.ref.update(updateData);
          console.log(`✅ Updated ${collection}/${orderId} status: ${status}`);
          return;
        }
      } catch (error) {
        // Continue to next collection
      }
    }
    
    console.warn(`⚠️ Could not find order ${orderId} in any collection`);
  }

  /**
   * Update provider status
   */
  async _updateProviderStatus(providerId, status, currentOrderId) {
    try {
      const snapshot = await db.collection('provider_profiles')
        .where('userId', '==', providerId)
        .limit(1)
        .get();

      if (!snapshot.empty) {
        const updateData = {
          availabilityStatus: status,
          currentOrderId: currentOrderId,
          lastStatusUpdate: admin.firestore.FieldValue.serverTimestamp()
        };

        await snapshot.docs[0].ref.update(updateData);
        console.log(`✅ Updated provider ${providerId} status: ${status}`);
      }
    } catch (error) {
      console.error(`❌ Error updating provider status:`, error);
    }
  }

  /**
   * Record dispatch attempt for analytics
   */
  async _recordDispatchAttempt(orderId, providerId, status) {
    try {
      await db.collection('dispatch_analytics').add({
        orderId,
        providerId,
        status, // dispatched | accepted | declined | timed_out
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        attemptNumber: this.dispatchAttempts.get(orderId) || 1
      });
    } catch (error) {
      console.error('❌ Error recording dispatch attempt:', error);
    }
  }

  /**
   * Utility methods
   */
  _getOrderData(orderId) {
    // Try to find order in appropriate collection
    const collections = ['rides', 'orders', 'emergency_bookings', 'moving_bookings', 'hire_bookings'];
    
    return Promise.all(
      collections.map(collection => 
        db.collection(collection).doc(orderId).get()
      )
    ).then(snapshots => {
      for (const snapshot of snapshots) {
        if (snapshot.exists) {
          return { id: snapshot.id, ...snapshot.data() };
        }
      }
      return null;
    });
  }

  _getCollectionForService(service) {
    const mapping = {
      'transport': 'rides',
      'emergency': 'emergency_bookings',
      'moving': 'moving_bookings',
      'hire': 'hire_bookings',
      'personal': 'personal_bookings'
    };
    return mapping[service] || 'orders';
  }

  _getSearchRadius(service, attemptNumber) {
    // Expand search radius with each attempt
    const baseRadius = this.config.DEFAULT_RADIUS_KM;
    const expansion = attemptNumber * 2; // Add 2km per attempt
    return Math.min(baseRadius + expansion, 25); // Max 25km radius
  }

  _calculateDistance(lat1, lng1, lat2, lng2) {
    const R = 6371; // Earth's radius in km
    const dLat = this._toRadians(lat2 - lat1);
    const dLng = this._toRadians(lng2 - lng1);
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(this._toRadians(lat1)) * Math.cos(this._toRadians(lat2)) *
      Math.sin(dLng/2) * Math.sin(dLng/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }

  _toRadians(degrees) {
    return degrees * (Math.PI / 180);
  }

  _isValidServiceClass(service, serviceClass) {
    const validClasses = this.serviceClasses[service] || [];
    return validClasses.includes(serviceClass);
  }

  _isClassCompatibleWithSubcategory(requestedClass, subcategory) {
    const compatibility = {
      'Taxi': ['compact', 'standard', 'suv'],
      'Bike': ['bike_economy', 'bike_luxury'],
      'Bus': ['bus_charter', 'bus_mini', 'bus_standard', 'bus_large'],
      'Tricycle': ['tricycle']
    };
    
    const compatible = compatibility[subcategory] || [];
    return compatible.includes(requestedClass);
  }

  _getBusCapacityRequirement(busClass) {
    const requirements = {
      'bus_mini': 8,
      'bus_standard': 14,
      'bus_large': 20,
      'bus_charter': 30
    };
    return requirements[busClass] || 4;
  }

  _isProviderAvailable(data) {
    return data.availabilityOnline === true && 
           ['available', 'idle'].includes(data.availabilityStatus) &&
           !data.currentOrderId;
  }

  _cleanup(orderId) {
    if (this.timeoutTimers.has(orderId)) {
      clearTimeout(this.timeoutTimers.get(orderId));
      this.timeoutTimers.delete(orderId);
    }
    this.attemptedProviders.delete(orderId);
    this.dispatchAttempts.delete(orderId);
    console.log(`🧹 Cleaned up tracking for order: ${orderId}`);
  }
}

// Export singleton instance
module.exports = new MatchingEngine();

/**
 * Firebase Cloud Functions for real-time dispatch
 */

// Trigger dispatch when new order is created
exports.onOrderCreated = functions.firestore
  .document('{collection}/{orderId}')
  .onCreate(async (snapshot, context) => {
    const { collection, orderId } = context.params;
    const orderData = snapshot.data();

    // Only process orders that need provider matching
    if (!orderData.service || !orderData.serviceClass || orderData.status !== 'pending') {
      return;
    }

    console.log(`🆕 New order created: ${collection}/${orderId}`);

    const matchingEngine = require('./matchingEngine');
    await matchingEngine.dispatchRequest(orderId, {
      id: orderId,
      ...orderData
    });
  });

// Handle provider responses
exports.onProviderResponse = functions.firestore
  .document('provider_responses/{responseId}')
  .onCreate(async (snapshot, context) => {
    const response = snapshot.data();
    const { orderId, providerId, action } = response; // action: accept | decline

    const matchingEngine = require('./matchingEngine');

    if (action === 'accept') {
      await matchingEngine.handleProviderAcceptance(orderId, providerId);
    } else if (action === 'decline') {
      await matchingEngine.handleProviderDecline(orderId, providerId, 'declined');
    }

    // Clean up response document
    await snapshot.ref.delete();
  });

// Monitor provider status changes
exports.onProviderStatusChange = functions.firestore
  .document('provider_profiles/{profileId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // If provider went offline while assigned, handle gracefully
    if (before.availabilityOnline === true && 
        after.availabilityOnline === false && 
        after.currentOrderId) {
      
      console.log(`⚠️ Provider ${after.userId} went offline during order ${after.currentOrderId}`);
      
      const matchingEngine = require('./matchingEngine');
      await matchingEngine.handleProviderDecline(
        after.currentOrderId, 
        after.userId, 
        'went_offline'
      );
    }
  });

// Cleanup expired orders (runs every 5 minutes)
exports.cleanupExpiredOrders = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const cutoff = new Date(Date.now() - (24 * 60 * 60 * 1000)); // 24 hours ago
    
    const collections = ['rides', 'orders', 'emergency_bookings', 'moving_bookings', 'hire_bookings'];
    
    for (const collection of collections) {
      try {
        const expiredQuery = await db.collection(collection)
          .where('status', 'in', ['pending', 'searching', 'dispatched'])
          .where('createdAt', '<', cutoff)
          .limit(100)
          .get();

        const batch = db.batch();
        expiredQuery.docs.forEach(doc => {
          batch.update(doc.ref, {
            status: 'expired',
            statusMessage: 'Order expired due to inactivity',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        });

        if (!expiredQuery.empty) {
          await batch.commit();
          console.log(`🧹 Cleaned up ${expiredQuery.size} expired orders from ${collection}`);
        }
      } catch (error) {
        console.error(`❌ Error cleaning up ${collection}:`, error);
      }
    }
  });