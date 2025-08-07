# 📋 **SenseBox Bike - Data Flow Architecture Documentation**

## 🎯 **Overview**

This document describes the complete data flow from track recording initiation to data upload to openSenseMap, including the role of each component in the system. The architecture has been updated to implement a decoupled retry logic system that prevents circular retry patterns and app hangs.

## 🔄 **High-Level Data Flow**

```
Track Recording Start → Sensor Data Collection → Local Storage → Upload Preparation → API Upload → openSenseMap
```

---

## 📱 **1. Track Recording Lifecycle**

### **1.1 Recording Initiation**
- **Trigger**: User presses "Start Recording" button in the app
- **Component**: `RecordingBloc` (via UI interaction)
- **Actions**:
  - Sets `isRecording = true`
  - Initializes `DirectUploadService`
  - Enables sensor data collection
  - Starts GPS tracking

### **1.2 Recording Active State**
- **Duration**: From start until user stops recording
- **Components Active**:
  - `BleBloc`: Maintains BLE connection to SenseBox device
  - `SensorBloc`: Manages all sensor data collection
  - `GeolocationBloc`: Handles GPS location data
  - `DirectUploadService`: Manages real-time data upload

### **1.3 Recording Stop**
- **Trigger**: User presses "Stop Recording" button
- **Component**: `RecordingBloc`
- **Actions**:
  - Sets `isRecording = false`
  - Calls `DirectUploadService.uploadRemainingBufferedData()`
  - **Always clears sensor buffers regardless of upload success/failure**
  - Disables `DirectUploadService`

---

## 📊 **2. Data Collection & Storage Architecture**

### **2.1 Sensor Data Pipeline**

#### **Layer 1: Raw Data Reception**
```
SenseBox Device (BLE) → BleBloc → Individual Sensor Classes
```

**Components**:
- **`BleBloc`**: Manages BLE connection and characteristic streams
- **Sensor Classes**: `TemperatureSensor`, `GPSSensor`, `HumiditySensor`, etc.
- **Data Format**: Raw byte streams from BLE characteristics

#### **Layer 2: Data Processing & Buffering**
```
Individual Sensors → Data Processing → Local Buffering → Isar Database
```

**Components**:
- **`Sensor` (Base Class)**: 
  - Receives raw data via `onDataReceived()`
  - Processes and aggregates data
  - Maintains `_groupedBuffer` for temporary storage
  - Saves to Isar database via `SensorService`

#### **Layer 3: Upload Preparation**
```
Sensor Buffers → DirectUploadService → Upload Buffers → API
```

**Components**:
- **`DirectUploadService`**: 
  - Accumulates data from all sensors (`_accumulatedSensorData`)
  - Prepares data for API upload (`_directUploadBuffer`)
  - Manages upload timing and delegates retry logic to OpenSenseMapService

### **2.2 Data Storage Layers**

#### **Temporary Buffers (In-Memory)**
1. **`_groupedBuffer`** (in each Sensor):
   - **Purpose**: Temporary storage during data processing
   - **Lifetime**: Until data is processed and saved to Isar
   - **Clearing**: After successful upload or recording stop

2. **`_accumulatedSensorData`** (in DirectUploadService):
   - **Purpose**: Accumulates sensor data for batch upload
   - **Lifetime**: Until upload threshold is met (3+ GPS points)
   - **Clearing**: Only the exact GPS points that were prepared for upload (atomic operations with data snapshots)

3. **`_directUploadBuffer`** (in DirectUploadService):
   - **Purpose**: Prepares data for API upload
   - **Lifetime**: Until upload threshold is met (3+ buffers)
   - **Clearing**: After successful API upload

#### **Permanent Storage (Isar Database)**
1. **`SensorData`**: Individual sensor readings with timestamps
2. **`GeolocationData`**: GPS coordinates and metadata
3. **`TrackData`**: Track metadata and relationships

---

## ⬆️ **3. Upload System Architecture**

### **3.1 Upload Triggers**

#### **Threshold-Based Upload**
- **Trigger**: When `_accumulatedSensorData.length >= 6`
- **Action**: Calls `_prepareAndUploadData()`
- **Frequency**: Every 3 GPS points received

#### **Timer-Based Upload**
- **Trigger**: Every 15 seconds via `Timer.periodic`
- **Action**: Calls `_prepareAndUploadData([])` if data exists
- **Purpose**: Ensures data upload even with low GPS frequency

#### **Recording Stop Upload**
- **Trigger**: When recording stops
- **Action**: Calls `uploadRemainingBufferedData()`
- **Purpose**: Ensures all buffered data is uploaded

### **3.2 Upload Process**

#### **Step 1: Data Preparation (Atomic Operations)**
```dart
_prepareAndUploadData(gpsBuffer) {
  // 1. Check if data exists
  if (_accumulatedSensorData.isEmpty) return;
  
  // 2. Create data snapshot for atomic operation
  final Map<GeolocationData, Map<String, List<double>>> dataSnapshot = 
      Map.from(_accumulatedSensorData);
  final List<GeolocationData> gpsPointsBeingUploaded = dataSnapshot.keys.toList();
  
  // 3. Prepare upload data using snapshot
  final uploadData = _dataPreparer.prepareDataFromGroupedData(
      dataSnapshot, gpsBuffer);
  
  // 4. Add to upload buffer
  _directUploadBuffer.add(uploadData);
  
  // 5. ATOMIC: Only clear the exact GPS points that were prepared for upload
  // This prevents race conditions and data loss during concurrent operations
  for (final gpsPoint in gpsPointsBeingUploaded) {
    _accumulatedSensorData.remove(gpsPoint);
  }
  
  // 6. Trigger upload if buffer threshold met
  if (_directUploadBuffer.length >= 3) {
    _uploadDirectBuffer().then((_) {
      _onUploadSuccess?.call(gpsPointsBeingUploaded);
    });
  }
}
```

#### **Step 2: Upload Execution**
```dart
_uploadDirectBuffer() {
  // 1. Check buffer threshold (3+ items for frequent uploads)
  if (_directUploadBuffer.length >= 3) {
    
    // 2. Merge all prepared data
    final Map<String, dynamic> data = {};
    for (final preparedData in _directUploadBuffer) {
      data.addAll(preparedData);
    }
    
    // 3. Upload via API - OpenSenseMapService handles all retries internally
    await openSenseMapService.uploadData(senseBox.id, data);
    
    // 4. Clear upload buffer after successful upload
    // Note: _accumulatedSensorData already cleared in _prepareAndUploadData
    _directUploadBuffer.clear();
  }
}
```

### **3.3 Decoupled Error Handling & Retry Logic**

#### **OpenSenseMapService Retry Logic**
The `OpenSenseMapService` now handles all retry logic internally with the following configuration:
- **Max Attempts**: 6 attempts per minute
- **Delay Factor**: 10 seconds between attempts
- **Max Delay**: 15 seconds maximum delay
- **Retry Conditions**: Only retry on appropriate errors:
  - `TooManyRequestsException` (rate limiting)
  - `'Token refreshed, retrying'` (authentication refresh)
  - `'Server error'` (5xx server errors)
  - `TimeoutException` (network timeouts)

#### **DirectUploadService Error Handling**
The `DirectUploadService` now only handles permanent failures and delegates all retry logic to `OpenSenseMapService`:

**Permanent Failures (Service Disabled)**:
- **Authentication Failures** (No restart scheduled): 
  - `'Authentication failed - user needs to re-login'`
  - `'No refresh token found'`
  - `'Failed to refresh token:'`
  - `'Not authenticated'`
- **Client Errors (4xx)** (Restart scheduled): 
  - `'Client error 403: Forbidden'`
  - `'Client error 400: Bad Request'`
  - Any 4xx status code errors

**Temporary Errors (Handled by OpenSenseMapService)**:
- **Network Timeouts**: `'Network timeout'`
- **Server Errors (5xx)**: `'Server error 503 - retrying'`
- **Rate Limiting**: `'TooManyRequestsException'`
- **Token Refresh**: `'Token refreshed, retrying'`

#### **Error Handling Behavior**
- **Permanent Authentication Failures**: Service is permanently disabled, buffers cleared, NO restart scheduled (user must re-login)
- **Permanent Client Errors (4xx)**: Service is permanently disabled, buffers cleared, restart scheduled
- **Temporary Errors**: Service remains enabled, errors logged but no action taken
- **No Circular Retries**: Eliminates the feedback loop that was causing app hangs

#### **Automatic Restart Mechanism**
- **Authentication Failures**: No restart attempts - service permanently disabled until user re-logs in
- **Client Errors (4xx)**: Max 3 restart attempts with exponential backoff (5, 10, 15 minutes)
- **Buffer Management**: All buffers cleared on restart for fresh start
- **Restart Failure Handling**: When max restart attempts are reached, sensors are notified to clear their buffers to prevent memory leaks

---

## 🔧 **4. Component Responsibilities**

### **4.1 Core BLoCs**

#### **`RecordingBloc`**
- **Primary Role**: Manages recording lifecycle
- **Key Methods**:
  - `startRecording()`: Initialize recording session
  - `stopRecording()`: End recording and finalize upload
- **State Management**: `isRecording` boolean

#### **`BleBloc`**
- **Primary Role**: BLE device connection and data streaming
- **Key Methods**:
  - `connectToDevice()`: Establish BLE connection
  - `subscribeToCharacteristics()`: Set up data streams
- **Data Flow**: Raw BLE data → Sensor classes

#### **`SensorBloc`**
- **Primary Role**: Orchestrates all sensor data collection
- **Key Methods**:
  - `_onRecordingStart()`: Initialize sensors
  - `_onRecordingStop()`: Clean up sensors
- **Components Managed**: All individual sensor instances

### **4.2 Service Layer**

#### **`DirectUploadService`**
- **Primary Role**: Real-time data upload management (simplified)
- **Key Methods**:
  - `addGroupedDataForUpload()`: Accumulate sensor data
  - `_uploadDirectBuffer()`: Execute API uploads (no retry logic)
  - `uploadRemainingBufferedData()`: Final upload on stop
  - `permanentlyDisabled` getter: Check if service is permanently disabled
- **Buffers Managed**: `_accumulatedSensorData`, `_directUploadBuffer`
- **Error Handling**: Uses `UploadErrorClassifier` for centralized error classification, only handles permanent failures, delegates retries to OpenSenseMapService
- **Performance Optimization**: Prevents unnecessary processing when permanently disabled
- **Refactored Architecture**: Clean separation between error classification (`UploadErrorClassifier`) and error handling (`_handleUploadError`)

#### **`OpenSenseMapService`**
- **Primary Role**: API communication with openSenseMap (enhanced)
- **Key Methods**:
  - `uploadData()`: Send data to API with comprehensive retry logic
  - `refreshToken()`: Handle authentication
- **Retry Logic**: Handles all retry attempts internally (6 attempts, 10-15s delays)
- **Error Classification**: Distinguishes between client errors (4xx) and server errors (5xx)

#### **`IsarService`**
- **Primary Role**: Local database operations
- **Key Methods**:
  - `saveSensorData()`: Store sensor readings
  - `saveGeolocationData()`: Store GPS data
- **Data Persistence**: Permanent local storage

### **4.3 Sensor Classes**

#### **Base `Sensor` Class**
- **Primary Role**: Common sensor functionality
- **Key Methods**:
  - `onDataReceived()`: Process raw BLE data
  - `_flushBuffers()`: Save data to Isar and prepare for upload
- **Buffering**: `_groupedBuffer` management
- **Upload Integration**: Sends data to DirectUploadService via `addGroupedDataForUpload()` only when service is not permanently disabled
- **Performance Optimization**: Checks `_directUploadService!.permanentlyDisabled` before calling upload methods

#### **Individual Sensor Implementations**
- **Examples**: `TemperatureSensor`, `GPSSensor`, `HumiditySensor`
- **Primary Role**: Sensor-specific data processing
- **Key Methods**:
  - `processData()`: Convert raw bytes to sensor values
  - `aggregateData()`: Combine multiple readings

---

## 🚨 **5. Critical Data Flow Points**

### **5.1 Data Loss Prevention**
1. **Buffer Clearing**: Clear buffers when service is permanently disabled to prevent data accumulation
2. **Error Recovery**: Automatic restart with exponential backoff after permanent failures
3. **Recording Stop**: Attempt upload but always clear buffers to prevent memory leaks
4. **Service State Management**: Prevent data buffering when service is disabled

### **5.2 Performance Considerations**
1. **Batch Uploads**: Accumulate data to reduce API calls
2. **Threshold Management**: Balance between latency and efficiency
3. **Memory Management**: Clear buffers to prevent memory leaks

### **5.3 Error Scenarios**
1. **BLE Disconnection**: Data continues to accumulate locally
2. **Network Issues**: Data preserved for retry by OpenSenseMapService
3. **API Errors**: Graceful degradation with proper error classification

### **5.4 Performance Optimizations**
1. **Sensor Upload Prevention**: Sensors check `permanentlyDisabled` status before calling upload methods
2. **Periodic Timer Optimization**: Periodic upload checks are skipped when service is permanently disabled
3. **Early Return in Upload Methods**: Upload methods return early when service is permanently disabled
4. **Buffer Clearing on Permanent Disable**: All buffers are cleared immediately when service is permanently disabled

---

## 📈 **6. Monitoring & Debugging**

### **6.1 Key Metrics**
- **Upload Success Rate**: Percentage of successful API calls
- **Buffer Sizes**: Monitor accumulation in each buffer layer
- **Data Loss**: Track missing data points between local and remote

### **6.2 Debug Logs**
- **Timestamps**: All upload-related logs include timestamps
- **Buffer States**: Monitor accumulation and clearing
- **Error Tracking**: Comprehensive error logging with Sentry integration

### **6.3 Test Coverage**
- **Error Handling Tests**: Comprehensive tests for all error scenarios (429, 502, authentication errors, token refresh)
- **Performance Tests**: Tests verify that sensors don't call upload methods when service is permanently disabled
- **State Management Tests**: Tests verify proper service state transitions and buffer clearing
- **Integration Tests**: Tests verify end-to-end behavior from sensor data collection to upload completion

### **6.4 Common Issues & Solutions**

#### **Buffer Accumulation**
- **Symptom**: Buffer size grows indefinitely
- **Cause**: `_accumulatedSensorData` not cleared after preparation
- **Solution**: Clear immediately after `_prepareAndUploadData()` call

#### **Timer Not Firing**
- **Symptom**: No "Timer fired" messages in logs
- **Cause**: Threshold condition preventing timer execution
- **Solution**: Remove timer condition from threshold check

#### **Data Loss During Auth Errors**
- **Symptom**: Data lost during token refresh
- **Cause**: Service disabled during auth errors
- **Solution**: Let `OpenSenseMapService` handle auth, preserve data

#### **Data from Previous Tracks**
- **Symptom**: Data from previous recording appears in new track
- **Cause**: Buffers not cleared when starting new recording
- **Solution**: Clear all buffers in `enable()` and `_onRecordingStart()`

#### **Decoupled Error Handling**

The error handling system has been completely decoupled to prevent circular retry patterns:

**OpenSenseMapService Responsibilities**:
- Handle all retry logic internally (6 attempts, 10-15s delays)
- Classify errors as retryable vs non-retryable
- Handle authentication token refresh
- Manage rate limiting with proper delays

**DirectUploadService Responsibilities**:
- Only handle permanent failures that require service disable
- Delegate all temporary errors to OpenSenseMapService
- Schedule automatic restarts for permanent failures
- Clear buffers on permanent failures

**Error Classification**:
- **Permanent failures** (service disabled): Authentication failures, client errors (4xx)
- **Temporary errors** (handled by OpenSenseMapService): Network timeouts, server errors (5xx), rate limiting

**Benefits**:
- ✅ No more circular retry patterns
- ✅ No more app hangs
- ✅ Clear separation of concerns
- ✅ Proper error recovery

#### **Buffer Clearing on Recording Stop**
- **Symptom**: Buffers not cleared when upload fails during recording stop
- **Cause**: Buffers only cleared after successful upload
- **Solution**: Always clear buffers regardless of upload success/failure to prevent memory leaks

#### **Automatic Service Restart**
- **Symptom**: Service permanently disabled after connectivity issues
- **Cause**: No automatic restart mechanism
- **Solution**: Implement exponential backoff restart with up to 3 attempts (5, 10, 15 minutes delays)
- **Buffer Management**: Clear all buffers on restart for fresh start

#### **Data Buffering During Service Disabled**
- **Symptom**: Data continues to be buffered when service is disabled
- **Cause**: No check for service state before buffering
- **Solution**: Reject data when service is temporarily or permanently disabled

#### **App Performance Issues After Authentication Errors**
- **Symptom**: App becomes slow after permanent authentication errors
- **Cause**: Sensors continue to call upload methods even when service is permanently disabled
- **Solution**: Added `permanentlyDisabled` getter and sensor checks to prevent unnecessary processing
- **Implementation**: 
  - Added `bool get permanentlyDisabled => _isPermanentlyDisabled;` to DirectUploadService
  - Updated sensors to check `!_directUploadService!.permanentlyDisabled` before calling upload methods
  - Added early returns in upload methods when service is permanently disabled
  - Optimized periodic timer to skip operations when service is permanently disabled

---

## 📁 **7. File Structure**

### **7.1 Core Components**
```
lib/
├── blocs/
│   ├── recording_bloc.dart      # Recording lifecycle management
│   ├── ble_bloc.dart           # BLE connection management
│   ├── sensor_bloc.dart        # Sensor orchestration
│   └── geolocation_bloc.dart   # GPS data management
├── services/
│   ├── direct_upload_service.dart    # Real-time upload management (simplified)
│   ├── opensensemap_service.dart     # API communication (enhanced retry logic)
│   └── isar_service.dart             # Local database operations
└── sensors/
    ├── sensor.dart             # Base sensor class
    ├── temperature_sensor.dart # Temperature data processing
    ├── gps_sensor.dart         # GPS data processing
    └── ...                     # Other sensor implementations
```

### **7.2 Data Models**
```
lib/models/
├── sensor_data.dart            # Sensor reading model
├── geolocation_data.dart       # GPS coordinate model
└── track_data.dart             # Track metadata model
```

---

## 🔄 **8. Data Flow Summary**

### **8.1 Recording Start**
1. User initiates recording
2. `RecordingBloc` enables all components
3. **Buffer Clearing**: All sensor and upload buffers are cleared to prevent uploading data from previous tracks
4. `BleBloc` establishes device connection
5. `SensorBloc` initializes all sensors
6. `DirectUploadService` starts upload management

### **8.2 Data Collection**
1. BLE data streams to individual sensors
2. Sensors process and aggregate data
3. Data saved to Isar database
4. Data accumulated in `DirectUploadService`
5. Upload triggered by thresholds or timer

### **8.3 Data Upload**
1. Data prepared for API format
2. **Accumulated data cleared immediately** after preparation to prevent duplicates
3. Buffered until threshold met (3+ items for frequent uploads)
4. Upload executed via `OpenSenseMapService` (with internal retry logic)
5. Upload buffer cleared after successful upload
6. Success callback notifies sensors to clear their buffers

### **8.4 Recording Stop**
1. User stops recording
2. Final upload of remaining data (attempted)
3. **Buffers always cleared regardless of upload success/failure**
4. All services disabled
5. Data not preserved across sessions to prevent accumulation

---

## 📝 **9. Configuration & Tuning**

### **9.1 Upload Thresholds**
- **GPS Threshold**: 3+ GPS points for immediate upload
- **Buffer Threshold**: 3+ prepared buffers for API upload (reduced from 10 for more frequent uploads)
- **Timer Interval**: 15 seconds for fallback upload

### **9.2 Critical Fixes**
- **Data Loss Prevention**: `_accumulatedSensorData` cleared immediately after preparing upload data to prevent duplicate uploads
- **Buffer Management**: Separate clearing of accumulated data (after preparation) and upload buffer (after successful upload)
- **Upload Frequency**: Reduced buffer threshold from 10 to 3 for more frequent uploads

### **9.3 Decoupled Error Handling**

**OpenSenseMapService Retry Configuration:**
- **Max Attempts**: 6 attempts per minute
- **Delay Factor**: 10 seconds between attempts
- **Max Delay**: 15 seconds maximum delay
- **Retry Conditions**: Only retry on appropriate errors (server errors, rate limiting, timeouts)

**DirectUploadService Error Classification:**
- **Permanent failures** (service disabled): Authentication failures, client errors (4xx)
- **Temporary errors** (handled by OpenSenseMapService): Network timeouts, server errors (5xx), rate limiting

**502 Error Handling:**
- **Classification**: 502 errors are classified as temporary errors
- **Retry Logic**: OpenSenseMapService handles retries with exponential backoff
- **Data Preservation**: Data is preserved during 502 errors and retried automatically
- **Atomic Operations**: Data snapshots prevent race conditions during 502 error retries
- **Logging**: 502 errors are logged to Sentry for monitoring but don't cause service disablement

**Error Classification Architecture:**
The system uses a dedicated `UploadErrorClassifier` class for centralized error classification:

```dart
class UploadErrorClassifier {
  // Centralized error patterns for maintainability
  static const List<String> _permanentAuthErrorPatterns = [
    'Authentication failed - user needs to re-login',
    'No refresh token found',
    'Failed to refresh token:',
    'Not authenticated',
  ];

  static const List<String> _temporaryErrorPatterns = [
    'Server error',
    'Token refreshed',
  ];

  static const List<Type> _temporaryExceptionTypes = [
    TooManyRequestsException,
    TimeoutException,
  ];

  // Single method to classify any error
  static UploadErrorType classifyError(dynamic error) {
    // Classification logic with clear priority order
  }
}
```

**Benefits of Centralized Classification:**
- ✅ **DRY Principle**: Error patterns defined once, used everywhere
- ✅ **Maintainability**: Adding new error types requires only updating the classifier
- ✅ **Testability**: Dedicated tests ensure classification accuracy
- ✅ **Consistency**: All error classification follows the same pattern
- ✅ **Extensibility**: Easy to add new error types or modify existing ones

**Error Message Sources:**
All error messages are based on actual exceptions thrown by OpenSenseMapService, ensuring accurate classification and handling.

**Benefits of Decoupling:**
- ✅ Eliminates circular retry patterns that caused app hangs
- ✅ Clear separation of responsibilities
- ✅ Proper error recovery without infinite loops
- ✅ Better performance and reliability

### **9.4 Performance Tuning**
- **Buffer Sizes**: Balance between memory usage and upload efficiency
- **Upload Frequency**: Balance between real-time updates and API load
- **Error Recovery**: Preserve data while maintaining system stability

### **9.5 Recent Performance Improvements**

#### **Sensor Upload Optimization**
- **Problem**: Sensors continued to call `addGroupedDataForUpload()` even when DirectUploadService was permanently disabled
- **Solution**: Added `permanentlyDisabled` getter and sensor checks
- **Implementation**: 
  ```dart
  if (!_directUploadService!.permanentlyDisabled) {
    _directUploadService!.addGroupedDataForUpload(groupedData, gpsBuffer);
  }
  ```
- **Benefit**: Prevents unnecessary processing and improves app performance after authentication errors

#### **Service State Management**
- **Problem**: Periodic timers and upload methods continued to run when service was permanently disabled
- **Solution**: Added early returns and state checks throughout DirectUploadService
- **Implementation**:
  - Early returns in `_uploadDirectBuffer()` and `_uploadDirectBufferSync()` when `_isPermanentlyDisabled`
  - Periodic timer skips operations when service is permanently disabled
  - Immediate buffer clearing when service is permanently disabled
- **Benefit**: Eliminates performance degradation after permanent authentication errors

#### **Comprehensive Test Coverage**
- **Added**: Tests for all error scenarios (429, 502, authentication errors, token refresh)
- **Coverage**: Performance tests verify sensors don't call upload methods when service is permanently disabled
- **Validation**: All 111+ tests pass, ensuring reliability of the performance improvements

#### **Error Classification Refactoring**
- **Problem**: Error classification logic was duplicated and embedded in `_handleUploadError`
- **Solution**: Created dedicated `UploadErrorClassifier` class with centralized error patterns
- **Implementation**: 
  - Extracted error patterns into static constants for maintainability
  - Created `UploadErrorType` enum for clear error categorization
  - Simplified `_handleUploadError` to use switch statement with classifier
  - Added comprehensive tests for the error classifier
- **Benefits**: 
  - ✅ **DRY Principle**: Error patterns defined once, used everywhere
  - ✅ **Maintainability**: Adding new error types requires only updating the classifier
  - ✅ **Testability**: Dedicated tests ensure classification accuracy
  - ✅ **Readability**: Clear separation between classification and handling logic

#### **Data Loss Prevention with Atomic Operations**
- **Problem**: Data loss occurred at 10:03 due to race conditions during data preparation
- **Root Cause**: `_accumulatedSensorData.clear()` was called immediately after data preparation, but new data could arrive during upload
- **Solution**: Implemented atomic operations with data snapshots
- **Implementation**:
  ```dart
  // Create data snapshot for atomic operation
  final Map<GeolocationData, Map<String, List<double>>> dataSnapshot = 
      Map.from(_accumulatedSensorData);
  final List<GeolocationData> gpsPointsBeingUploaded = dataSnapshot.keys.toList();
  
  // Prepare upload data using snapshot
  final uploadData = _dataPreparer.prepareDataFromGroupedData(
      dataSnapshot, gpsBuffer);
  
  // Only clear the exact GPS points that were prepared for upload
  for (final gpsPoint in gpsPointsBeingUploaded) {
    _accumulatedSensorData.remove(gpsPoint);
  }
  ```
- **Benefits**:
  - ✅ **Atomic Operations**: Data captured in snapshot before processing
  - ✅ **Race Condition Prevention**: No interference between data preparation and new data arrival
  - ✅ **Precise Data Management**: Only removes exact GPS points that were prepared for upload
  - ✅ **Backward Compatibility**: Maintains existing API and behavior
  - ✅ **Minimal Changes**: Low-risk solution with maximum impact

---

This documentation provides a complete overview of how data flows through the system from recording start to successful upload to openSenseMap, with the updated decoupled retry logic architecture that prevents circular retry patterns and app hangs. The recent performance improvements ensure optimal app performance even after authentication errors, with comprehensive test coverage validating all error scenarios and performance optimizations. The error classification refactoring implements DRY principles and improves maintainability through centralized error pattern management. The data loss prevention with atomic operations ensures data integrity by preventing race conditions during data preparation and upload processes. 