# 🧠 Core Order Dispatch Algorithm - Language-Agnostic Pseudocode

## 📋 Main Matching Function

```pseudocode
FUNCTION findEligibleProviders(requested_service, requested_class, customer_location)
RETURNS: sorted_list_of_eligible_providers

BEGIN
    // Input validation
    IF NOT isValidServiceClass(requested_service, requested_class) THEN
        THROW InvalidServiceClassError
    END IF
    
    // Step 1: Geographic proximity query
    nearby_providers = DATABASE.query({
        collection: "provider_profiles",
        where: [
            ("service", "==", requested_service),
            ("status", "==", "active"),
            ("availabilityOnline", "==", true),
            ("availabilityStatus", "IN", ["available", "idle"]),
            ("currentLocation", "NEAR", customer_location, DEFAULT_RADIUS_KM)
        ],
        limit: 50
    })
    
    IF nearby_providers.isEmpty() THEN
        RETURN empty_list
    END IF
    
    // Step 2: Filter and score providers
    eligible_providers = []
    
    FOR EACH provider IN nearby_providers DO
        provider_id = provider.userId
        
        // Skip if already attempted for this order
        IF attempted_providers_list.contains(provider_id) THEN
            CONTINUE
        END IF
        
        // Step 2a: Service class validation
        IF NOT supportsServiceClass(provider, requested_class) THEN
            LOG("Provider " + provider_id + " doesn't support class: " + requested_class)
            CONTINUE
        END IF
        
        // Step 2b: Service-specific validation
        IF NOT passesServiceSpecificValidation(requested_service, requested_class, provider) THEN
            LOG("Provider " + provider_id + " failed service-specific validation")
            CONTINUE
        END IF
        
        // Step 2c: Calculate distance and score
        distance = calculateDistance(customer_location, provider.currentLocation)
        IF distance > provider.serviceRadius THEN
            LOG("Provider " + provider_id + " outside service radius")
            CONTINUE
        END IF
        
        score = calculateProviderScore(
            distance: distance,
            rating: provider.rating,
            completed_orders: provider.completedOrders,
            response_time: provider.avgResponseTime,
            completion_rate: provider.completionRate
        )
        
        eligible_providers.add({
            id: provider_id,
            distance: distance,
            score: score,
            metadata: provider
        })
        
        LOG("Eligible provider: " + provider_id + " (distance: " + distance + "km, score: " + score + ")")
    END FOR
    
    // Step 3: Sort by score (descending - higher score is better)
    eligible_providers.sortBy(score, DESCENDING)
    
    // Step 4: Return top candidates
    RETURN eligible_providers.take(MAX_PROVIDERS_PER_ATTEMPT)
END

FUNCTION supportsServiceClass(provider, requested_class)
RETURNS: boolean

BEGIN
    // Method 1: Check explicit class enablement (preferred)
    enabled_classes = provider.enabledClasses OR empty_map
    IF enabled_classes.hasKey(requested_class) THEN
        RETURN enabled_classes[requested_class] == true
    END IF
    
    // Method 2: Check service classes array (backward compatibility)
    service_classes = provider.serviceClasses OR empty_array
    IF service_classes.contains(requested_class) THEN
        RETURN true
    END IF
    
    // Method 3: Fallback subcategory compatibility
    RETURN isClassCompatibleWithSubcategory(requested_class, provider.subcategory)
END

FUNCTION passesServiceSpecificValidation(service, service_class, provider)
RETURNS: boolean

BEGIN
    SWITCH service DO
        CASE "transport":
            RETURN validateTransportProvider(service_class, provider)
        CASE "emergency":
            RETURN validateEmergencyProvider(service_class, provider)
        CASE "hire":
            RETURN validateHireProvider(service_class, provider)
        CASE "moving":
            RETURN validateMovingProvider(service_class, provider)
        DEFAULT:
            RETURN true  // Allow other services
    END SWITCH
END

FUNCTION calculateProviderScore(distance, rating, completed_orders, response_time, completion_rate)
RETURNS: numeric_score

BEGIN
    // Scoring components (0-100 scale each)
    distance_score = max(0, 100 - (distance * 15))        // Penalty for distance
    rating_score = (rating / 5.0) * 100                   // 5-star rating = 100 points
    experience_score = min(50, completed_orders * 0.5)    // Experience bonus (max 50)
    speed_score = max(0, 50 - response_time)              // Fast response bonus
    reliability_score = completion_rate * 50               // Reliability bonus
    
    // Weighted average (weights sum to 1.0)
    total_score = (distance_score * 0.35) +               // Distance most important
                  (rating_score * 0.25) +                 // Customer satisfaction
                  (experience_score * 0.20) +             // Experience matters
                  (speed_score * 0.10) +                  // Response speed
                  (reliability_score * 0.10)              // Reliability
    
    RETURN round(total_score, 2)
END
```

---

## 🚀 Main Dispatch Function

```pseudocode
FUNCTION dispatchRequest(order_id, service, service_class, customer_location, customer_id)
RETURNS: success_boolean

BEGIN
    // Initialize attempt tracking
    attempt_number = getDispatchAttempts(order_id) + 1
    setDispatchAttempts(order_id, attempt_number)
    
    LOG("Dispatching order: " + order_id + " (attempt " + attempt_number + ")")
    
    // Check max attempts
    IF attempt_number > MAX_DISPATCH_ATTEMPTS THEN
        updateOrderStatus(order_id, "failed", "Max attempts reached")
        cleanup(order_id)
        RETURN false
    END IF
    
    // Find eligible providers
    eligible_providers = findEligibleProviders(service, service_class, customer_location)
    
    IF eligible_providers.isEmpty() THEN
        LOG("No eligible providers found for order: " + order_id)
        
        IF attempt_number >= MAX_DISPATCH_ATTEMPTS THEN
            updateOrderStatus(order_id, "failed", "No providers available")
            cleanup(order_id)
            RETURN false
        ELSE
            // Schedule retry with expanded radius
            expanded_radius = DEFAULT_RADIUS_KM + (attempt_number * 2)
            scheduleRetry(order_id, RETRY_DELAY_SECONDS, expanded_radius)
            RETURN false
        END IF
    END IF
    
    // Select best provider (highest score)
    selected_provider = eligible_providers[0]
    
    LOG("Selected provider: " + selected_provider.id + " (score: " + selected_provider.score + ")")
    
    // Assign provider to order
    assignProviderToOrder(order_id, selected_provider, service)
    
    // Track attempted provider
    addToAttemptedProviders(order_id, selected_provider.id)
    
    // Start timeout timer
    startTimeoutTimer(order_id, REQUEST_TIMEOUT_SECONDS)
    
    RETURN true
END

FUNCTION timeoutHandler(order_id)
RETURNS: void

BEGIN
    LOG("Timeout reached for order: " + order_id)
    
    // Check if order was accepted in the meantime
    current_order = getOrderData(order_id)
    IF current_order.status == "accepted" THEN
        LOG("Order was accepted, canceling timeout")
        cleanup(order_id)
        RETURN
    END IF
    
    // Handle provider timeout
    IF current_order.providerId != null THEN
        handleProviderTimeout(current_order.providerId)
        recordDispatchAttempt(order_id, current_order.providerId, "timed_out")
    END IF
    
    // Update order status
    updateOrderStatus(order_id, "searching", "Finding another provider...")
    
    // Re-dispatch to next provider
    success = dispatchRequest(
        order_id, 
        current_order.service, 
        current_order.serviceClass, 
        current_order.customerLocation,
        current_order.customerId
    )
    
    IF NOT success THEN
        LOG("Failed to re-dispatch order: " + order_id)
        updateOrderStatus(order_id, "failed", "No more providers available")
    END IF
END
```

---

## 🔧 Service-Specific Validation Algorithms

### Transport Service Validation

```pseudocode
FUNCTION validateTransportProvider(requested_class, provider)
RETURNS: boolean

BEGIN
    subcategory = provider.subcategory
    vehicle_capacity = provider.metadata.vehicleCapacity OR 1
    
    // Step 1: Subcategory matching
    class_subcategory_map = {
        "tricycle": "Tricycle",
        "compact": "Taxi",
        "standard": "Taxi", 
        "suv": "Taxi",
        "bike_economy": "Bike",
        "bike_luxury": "Bike",
        "bus_charter": "Bus",
        "bus_mini": "Bus",
        "bus_standard": "Bus",
        "bus_large": "Bus"
    }
    
    required_subcategory = class_subcategory_map[requested_class]
    IF required_subcategory != null AND subcategory != required_subcategory THEN
        LOG("Subcategory mismatch: need " + required_subcategory + ", have " + subcategory)
        RETURN false
    END IF
    
    // Step 2: Capacity validation for buses
    IF requested_class.startsWith("bus_") THEN
        min_capacity = getBusCapacityRequirement(requested_class)
        IF vehicle_capacity < min_capacity THEN
            LOG("Insufficient capacity: need " + min_capacity + ", have " + vehicle_capacity)
            RETURN false
        END IF
    END IF
    
    RETURN true
END

FUNCTION getBusCapacityRequirement(bus_class)
RETURNS: integer

BEGIN
    capacity_requirements = {
        "bus_mini": 8,
        "bus_standard": 14,
        "bus_large": 20,
        "bus_charter": 30
    }
    
    RETURN capacity_requirements[bus_class] OR 4
END
```

### Emergency Service Validation (Strict Matching)

```pseudocode
FUNCTION validateEmergencyProvider(requested_class, provider)
RETURNS: boolean

BEGIN
    enabled_classes = provider.enabledClasses OR empty_map
    certifications = provider.certifications OR empty_array
    
    // Step 1: Explicit class enablement required
    IF enabled_classes[requested_class] != true THEN
        LOG("Emergency class not explicitly enabled: " + requested_class)
        RETURN false
    END IF
    
    // Step 2: Required certifications
    certification_requirements = {
        "ambulance": ["medical_transport", "first_aid"],
        "fire_services": ["fire_safety", "emergency_response"],
        "security_services": ["security_license", "law_enforcement"],
        "roadside_assistance": ["automotive_repair", "towing_license"],
        "technical_services": ["technical_certification"]
    }
    
    required_certs = certification_requirements[requested_class] OR empty_array
    
    IF required_certs.isNotEmpty() THEN
        has_required_cert = false
        FOR EACH cert IN required_certs DO
            IF certifications.contains(cert) THEN
                has_required_cert = true
                BREAK
            END IF
        END FOR
        
        IF NOT has_required_cert THEN
            LOG("Missing required certifications for " + requested_class)
            RETURN false
        END IF
    END IF
    
    // Step 3: Equipment validation (for ambulance)
    IF requested_class == "ambulance" THEN
        required_equipment = ["medical_equipment", "oxygen_tank", "stretcher"]
        provider_equipment = provider.equipment OR empty_array
        
        has_medical_equipment = false
        FOR EACH equipment IN required_equipment DO
            IF provider_equipment.contains(equipment) THEN
                has_medical_equipment = true
                BREAK
            END IF
        END FOR
        
        IF NOT has_medical_equipment THEN
            LOG("Ambulance provider missing medical equipment")
            RETURN false
        END IF
    END IF
    
    RETURN true
END
```

### Hire Service Validation (Skill-Based)

```pseudocode
FUNCTION validateHireProvider(requested_class, provider)
RETURNS: boolean

BEGIN
    enabled_classes = provider.enabledClasses OR empty_map
    skills = provider.skills OR empty_array
    
    // Method 1: Check explicit class enablement
    IF enabled_classes.hasKey(requested_class) THEN
        RETURN enabled_classes[requested_class] == true
    END IF
    
    // Method 2: Check skills array
    IF skills.contains(requested_class) THEN
        RETURN true
    END IF
    
    // Method 3: Skill category matching (for flexibility)
    skill_categories = {
        "plumber": ["plumbing", "pipe_repair", "water_systems"],
        "electrician": ["electrical", "wiring", "electrical_repair"],
        "hairstylist": ["hairstyling", "beauty", "salon_services"],
        "cleaner": ["cleaning", "housekeeping", "sanitation"],
        "tutor": ["tutoring", "education", "teaching"]
    }
    
    related_skills = skill_categories[requested_class] OR empty_array
    FOR EACH skill IN related_skills DO
        IF skills.contains(skill) THEN
            RETURN true
        END IF
    END FOR
    
    LOG("Hire provider doesn't support skill: " + requested_class)
    RETURN false
END
```

---

## 🔄 Timeout and Re-dispatch Algorithm

```pseudocode
FUNCTION handleProviderTimeout(order_id, timed_out_provider_id)
RETURNS: void

BEGIN
    LOG("Provider timeout: " + timed_out_provider_id + " for order: " + order_id)
    
    // Step 1: Record timeout in analytics
    recordDispatchAttempt(order_id, timed_out_provider_id, "timed_out")
    
    // Step 2: Reset provider availability
    updateProviderStatus(timed_out_provider_id, "available", null)
    
    // Step 3: Add to attempted providers list
    addToAttemptedProviders(order_id, timed_out_provider_id)
    
    // Step 4: Update order status
    updateOrderStatus(order_id, "searching", "Finding another provider...")
    
    // Step 5: Get fresh order data
    order_data = getOrderData(order_id)
    IF order_data == null THEN
        LOG("Order not found during timeout handling: " + order_id)
        RETURN
    END IF
    
    // Step 6: Re-dispatch with delay to prevent rapid cycling
    scheduleDelayedExecution(2_seconds, FUNCTION() {
        success = dispatchRequest(
            order_id,
            order_data.service,
            order_data.serviceClass,
            order_data.customerLocation,
            order_data.customerId
        )
        
        IF NOT success THEN
            LOG("Re-dispatch failed for order: " + order_id)
        END IF
    })
END

FUNCTION startTimeoutTimer(order_id, timeout_seconds)
RETURNS: void

BEGIN
    // Cancel existing timer if any
    IF timeout_timers.hasKey(order_id) THEN
        cancelTimer(timeout_timers[order_id])
    END IF
    
    // Create new timeout timer
    timer = createTimer(timeout_seconds * 1000, FUNCTION() {
        // Timeout callback
        current_order = getOrderData(order_id)
        
        // Double-check order wasn't accepted
        IF current_order != null AND current_order.status == "accepted" THEN
            LOG("Order accepted during timeout period, canceling timeout")
            cleanup(order_id)
            RETURN
        END IF
        
        // Handle timeout
        IF current_order != null AND current_order.providerId != null THEN
            handleProviderTimeout(order_id, current_order.providerId)
        ELSE
            LOG("No provider assigned during timeout for order: " + order_id)
            updateOrderStatus(order_id, "failed", "Dispatch timeout")
        END IF
    })
    
    timeout_timers[order_id] = timer
    LOG("Started " + timeout_seconds + "s timeout timer for order: " + order_id)
END
```

---

## 📊 Provider Scoring Algorithm

```pseudocode
FUNCTION calculateProviderScore(distance, rating, completed_orders, response_time, completion_rate)
RETURNS: numeric_score_0_to_100

BEGIN
    // Component scores (each 0-100)
    
    // Distance component (closer is better)
    distance_score = max(0, 100 - (distance * 15))
    // 0km = 100 points, 1km = 85 points, 5km = 25 points, 7km+ = 0 points
    
    // Rating component (5-star system)
    rating_score = (rating / 5.0) * 100
    // 5.0 stars = 100 points, 4.0 stars = 80 points, etc.
    
    // Experience component (completed orders)
    experience_score = min(50, completed_orders * 0.5)
    // 100+ orders = max 50 points, diminishing returns
    
    // Response speed component (faster is better)
    speed_score = max(0, 50 - response_time)
    // 0s response = 50 points, 30s = 20 points, 50s+ = 0 points
    
    // Reliability component (completion rate)
    reliability_score = completion_rate * 50
    // 100% completion = 50 points, 80% = 40 points, etc.
    
    // Weighted final score
    final_score = (distance_score * 0.35) +      // 35% weight - proximity is critical
                  (rating_score * 0.25) +        // 25% weight - customer satisfaction
                  (experience_score * 0.20) +    // 20% weight - provider experience
                  (speed_score * 0.10) +         // 10% weight - response speed
                  (reliability_score * 0.10)     // 10% weight - completion reliability
    
    RETURN round(final_score, 2)
END
```

---

## 🎯 Service-Specific Validation Logic

### Emergency Service (Strictest Matching)

```pseudocode
FUNCTION validateEmergencyProvider(requested_class, provider)
RETURNS: boolean

BEGIN
    // CRITICAL: Emergency services require exact matching
    // An ambulance request must ONLY go to ambulance providers
    
    enabled_classes = provider.enabledClasses OR empty_map
    
    // Step 1: Explicit class enablement required
    IF enabled_classes[requested_class] != true THEN
        RETURN false
    END IF
    
    // Step 2: Certification validation
    certifications = provider.certifications OR empty_array
    
    SWITCH requested_class DO
        CASE "ambulance":
            required_certs = ["medical_transport", "first_aid", "emergency_medical_technician"]
            equipment = provider.equipment OR empty_array
            required_equipment = ["medical_equipment", "oxygen_tank", "stretcher", "defibrillator"]
            
            has_cert = false
            FOR EACH cert IN required_certs DO
                IF certifications.contains(cert) THEN
                    has_cert = true
                    BREAK
                END IF
            END FOR
            
            has_equipment = false
            FOR EACH equip IN required_equipment DO
                IF equipment.contains(equip) THEN
                    has_equipment = true
                    BREAK
                END IF
            END FOR
            
            RETURN has_cert AND has_equipment
            
        CASE "fire_services":
            required_certs = ["fire_safety", "emergency_response", "firefighter_certification"]
            RETURN certifications.containsAny(required_certs)
            
        CASE "security_services":
            required_certs = ["security_license", "law_enforcement", "private_security"]
            RETURN certifications.containsAny(required_certs)
            
        CASE "roadside_assistance":
            required_certs = ["automotive_repair", "towing_license", "mechanical_certification"]
            RETURN certifications.containsAny(required_certs)
            
        DEFAULT:
            RETURN true
    END SWITCH
END
```

### Hire Service (Skill-Based Matching)

```pseudocode
FUNCTION validateHireProvider(requested_class, provider)
RETURNS: boolean

BEGIN
    // CRITICAL: A plumber request must ONLY go to plumber providers
    
    enabled_classes = provider.enabledClasses OR empty_map
    skills = provider.skills OR empty_array
    
    // Step 1: Explicit class enablement (preferred)
    IF enabled_classes.hasKey(requested_class) THEN
        RETURN enabled_classes[requested_class] == true
    END IF
    
    // Step 2: Direct skill matching
    IF skills.contains(requested_class) THEN
        RETURN true
    END IF
    
    // Step 3: Skill verification for critical services
    critical_skills = ["plumber", "electrician", "gas_technician", "medical_professional"]
    
    IF critical_skills.contains(requested_class) THEN
        // These skills require explicit enablement or certification
        certifications = provider.certifications OR empty_array
        skill_certifications = {
            "plumber": ["plumbing_license", "pipe_fitting_certification"],
            "electrician": ["electrical_license", "electrical_certification"],
            "gas_technician": ["gas_safety_certification"],
            "medical_professional": ["medical_license", "healthcare_certification"]
        }
        
        required_certs = skill_certifications[requested_class] OR empty_array
        IF required_certs.isNotEmpty() THEN
            RETURN certifications.containsAny(required_certs)
        END IF
    END IF
    
    LOG("Hire provider validation failed for class: " + requested_class)
    RETURN false
END
```

---

## 📍 Geographic Distance Calculation

```pseudocode
FUNCTION calculateDistance(lat1, lng1, lat2, lng2)
RETURNS: distance_in_kilometers

BEGIN
    // Haversine formula for accurate distance calculation
    EARTH_RADIUS_KM = 6371
    
    // Convert to radians
    lat1_rad = toRadians(lat1)
    lng1_rad = toRadians(lng1)
    lat2_rad = toRadians(lat2)
    lng2_rad = toRadians(lng2)
    
    // Calculate differences
    dlat = lat2_rad - lat1_rad
    dlng = lng2_rad - lng1_rad
    
    // Haversine calculation
    a = sin(dlat/2) * sin(dlat/2) + 
        cos(lat1_rad) * cos(lat2_rad) * 
        sin(dlng/2) * sin(dlng/2)
    
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    
    distance = EARTH_RADIUS_KM * c
    
    RETURN round(distance, 3)
END

FUNCTION toRadians(degrees)
RETURNS: radians

BEGIN
    RETURN degrees * (PI / 180)
END
```

---

## 🔄 State Transition Management

```pseudocode
FUNCTION transitionOrderState(order_id, current_state, new_state, reason)
RETURNS: success_boolean

BEGIN
    // Validate transition
    allowed_transitions = {
        "pending": ["searching", "cancelled"],
        "searching": ["dispatched", "failed", "cancelled"],
        "dispatched": ["accepted", "searching", "cancelled"],
        "accepted": ["in_progress", "cancelled"],
        "in_progress": ["completed", "cancelled"],
        "completed": [],  // Terminal
        "cancelled": [],  // Terminal
        "failed": []      // Terminal
    }
    
    allowed = allowed_transitions[current_state] OR empty_array
    IF NOT allowed.contains(new_state) THEN
        LOG("Invalid transition: " + current_state + " -> " + new_state)
        RETURN false
    END IF
    
    // Update order state
    update_data = {
        "status": new_state,
        "updatedAt": getCurrentTimestamp(),
        "stateHistory": appendToArray({
            "state": new_state,
            "previousState": current_state,
            "timestamp": getCurrentTimestamp(),
            "reason": reason
        })
    }
    
    // Add state-specific data
    SWITCH new_state DO
        CASE "searching":
            update_data["searchStartedAt"] = getCurrentTimestamp()
        CASE "dispatched":
            update_data["dispatchedAt"] = getCurrentTimestamp()
        CASE "accepted":
            update_data["acceptedAt"] = getCurrentTimestamp()
        CASE "completed":
            update_data["completedAt"] = getCurrentTimestamp()
    END SWITCH
    
    updateOrderInDatabase(order_id, update_data)
    
    // Trigger side effects
    handleStateTransitionEffects(order_id, current_state, new_state)
    
    RETURN true
END
```

---

## 🧪 Testing Pseudocode

```pseudocode
FUNCTION testCompleteDispatchFlow()
RETURNS: test_result

BEGIN
    // Setup test data
    test_order_id = "test_order_" + generateRandomId()
    test_customer_location = { lat: 6.5244, lng: 3.3792 }
    test_service = "transport"
    test_class = "standard"
    
    // Step 1: Test provider matching
    providers = findEligibleProviders(test_service, test_class, test_customer_location)
    ASSERT(providers.length > 0, "Should find eligible providers")
    ASSERT(providers[0].score > 0, "Provider should have valid score")
    
    // Step 2: Test dispatch
    success = dispatchRequest(test_order_id, test_service, test_class, test_customer_location, "test_customer")
    ASSERT(success == true, "Dispatch should succeed")
    
    // Step 3: Test timeout handling
    wait(61_seconds)  // Wait for timeout
    order_data = getOrderData(test_order_id)
    ASSERT(order_data.status == "searching" OR order_data.status == "dispatched", "Should handle timeout")
    
    // Step 4: Test acceptance
    simulateProviderAcceptance(test_order_id, providers[0].id)
    wait(2_seconds)
    final_order_data = getOrderData(test_order_id)
    ASSERT(final_order_data.status == "accepted", "Should handle acceptance")
    
    // Cleanup
    cleanup(test_order_id)
    
    RETURN "PASS"
END

FUNCTION testServiceSpecificMatching()
RETURNS: test_result

BEGIN
    // Test emergency strict matching
    ambulance_provider = createTestProvider("emergency", "ambulance", ["medical_transport"])
    plumber_provider = createTestProvider("hire", "plumber", ["plumbing_license"])
    
    // Ambulance request should ONLY go to ambulance providers
    ambulance_eligible = validateEmergencyProvider("ambulance", ambulance_provider)
    plumber_for_ambulance = validateEmergencyProvider("ambulance", plumber_provider)
    
    ASSERT(ambulance_eligible == true, "Ambulance provider should be eligible for ambulance request")
    ASSERT(plumber_for_ambulance == false, "Plumber should NOT be eligible for ambulance request")
    
    // Plumber request should ONLY go to plumber providers
    plumber_eligible = validateHireProvider("plumber", plumber_provider)
    ambulance_for_plumber = validateHireProvider("plumber", ambulance_provider)
    
    ASSERT(plumber_eligible == true, "Plumber should be eligible for plumber request")
    ASSERT(ambulance_for_plumber == false, "Ambulance provider should NOT be eligible for plumber request")
    
    RETURN "PASS"
END
```

---

## 🎯 Key Implementation Points

### Critical Success Factors

1. **Exact Service/Class Matching**
   ```pseudocode
   // MUST be strictly enforced
   IF requested_service == "emergency" AND requested_class == "ambulance" THEN
       eligible_providers = providers.where(
           service == "emergency" AND 
           enabledClasses["ambulance"] == true AND
           certifications.contains("medical_transport")
       )
   END IF
   ```

2. **Geographic Efficiency**
   ```pseudocode
   // Use spatial indexing for performance
   spatial_query = {
       center: customer_location,
       radius: search_radius_km,
       index: "geohash" OR "geo_firestore"
   }
   ```

3. **Timeout Reliability**
   ```pseudocode
   // Robust timeout handling
   timeout_timer = createReliableTimer(60_seconds, FUNCTION() {
       handleTimeout(order_id)
   })
   
   // Always cleanup on success
   ON provider_acceptance DO
       cancelTimer(timeout_timer)
       cleanup(order_id)
   END ON
   ```

4. **State Consistency**
   ```pseudocode
   // Atomic state updates
   BEGIN_TRANSACTION
       updateOrderStatus(order_id, new_status)
       updateProviderStatus(provider_id, new_availability)
       recordStateTransition(order_id, transition_data)
   COMMIT_TRANSACTION
   ```

This pseudocode provides the complete algorithmic foundation for implementing a robust, scalable order dispatch and matching system that ensures:

- ✅ **Exact service and class matching** (ambulance → ambulance only)
- ✅ **Intelligent provider scoring** based on multiple factors
- ✅ **Automatic timeout and re-dispatch** with fallback mechanisms
- ✅ **Geographic proximity optimization** for fast matching
- ✅ **State consistency and reliability** across all operations
- ✅ **Comprehensive error handling** and edge case management