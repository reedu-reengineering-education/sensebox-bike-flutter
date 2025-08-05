# 📋 **SenseBox Bike - Data Flow Architecture Documentation**

## 🎯 **Overview**

This document describes the complete data flow from track recording initiation to data upload to openSenseMap, including the role of each component in the system.

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
  - Manages upload timing and retry logic

### **2.2 Data Storage Layers**

#### **Temporary Buffers (In-Memory)**
1. **`_groupedBuffer`** (in each Sensor):
   - **Purpose**: Temporary storage during data processing
   - **Lifetime**: Until data is processed and saved to Isar
   - **Clearing**: After successful upload or recording stop

2. **`_accumulatedSensorData`** (in DirectUploadService):
   - **Purpose**: Accumulates sensor data for batch upload
   - **Lifetime**: Until upload threshold is met (3+ GPS points)
   - **Clearing**: Immediately after `_prepareAndUploadData()` call

3. **`_directUploadBuffer`** (in DirectUploadService):
   - **Purpose**: Prepares data for API upload
   - **Lifetime**: Until upload threshold is met (10+ buffers)
   - **Clearing**: After successful API upload

#### **Permanent Storage (Isar Database)**
1. **`SensorData`**: Individual sensor readings with timestamps
2. **`GeolocationData`**: GPS coordinates and metadata
3. **`TrackData`**: Track metadata and relationships

---

## ⬆️ **3. Upload System Architecture**

### **3.1 Upload Triggers**

#### **Threshold-Based Upload**
- **Trigger**: When `_accumulatedSensorData.length >= 3`
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

#### **Step 1: Data Preparation**
```dart
_prepareAndUploadData(gpsBuffer) {
  // 1. Check if data exists
  if (_accumulatedSensorData.isEmpty) return;
  
  // 2. Store GPS points being uploaded for success callback
  final List<GeolocationData> gpsPointsBeingUploaded =
      _accumulatedSensorData.keys.toList();
  
  // 3. Prepare upload data
  final uploadData = _dataPreparer.prepareDataFromGroupedData(
      _accumulatedSensorData, gpsBuffer);
  
  // 4. Add to upload buffer
  _directUploadBuffer.add(uploadData);
  
  // 5. CRITICAL: Clear accumulated data immediately after preparation
  // This prevents duplicate data from being uploaded in subsequent batches
  _accumulatedSensorData.clear();
  
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
    
    // 3. Upload via API
    await _uploadDirectBufferWithRetry(data);
    
    // 4. Clear upload buffer after successful upload
    // Note: _accumulatedSensorData already cleared in _prepareAndUploadData
    _directUploadBuffer.clear();
  }
}
```

### **3.3 Error Handling & Retry Logic**

#### **Authentication Errors**
- **Detection**: "Not authenticated" or "401 Unauthorized"
- **Action**: Let `OpenSenseMapService` handle token refresh
- **Behavior**: Continue processing, don't disable service

#### **Temporary Errors**
- **Detection**: Network timeouts, temporary API failures
- **Action**: Call `disableTemporarily()`
- **Behavior**: Preserve data, retry on next cycle

#### **Permanent Errors**
- **Detection**: Max retries exceeded or long-term connectivity issues
- **Action**: Permanently disable service
- **Behavior**: Set `permanentUploadLossNotifier.value = true`

#### **Recording Stop Upload Failures**
- **Detection**: `uploadRemainingBufferedData()` fails
- **Retry Limit**: Uses same `maxRetries` constant (10 attempts)
- **Action**: After max retries, flush all buffers to prevent data accumulation
- **Behavior**: Clear `_accumulatedSensorData`, `_directUploadBuffer`, and reset counters

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
- **Primary Role**: Real-time data upload management
- **Key Methods**:
  - `addGroupedDataForUpload()`: Accumulate sensor data
  - `_uploadDirectBuffer()`: Execute API uploads
  - `uploadRemainingBufferedData()`: Final upload on stop
- **Buffers Managed**: `_accumulatedSensorData`, `_directUploadBuffer`

#### **`OpenSenseMapService`**
- **Primary Role**: API communication with openSenseMap
- **Key Methods**:
  - `uploadData()`: Send data to API
  - `refreshToken()`: Handle authentication
- **Error Handling**: Token refresh, API retries

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
  - `_flushBuffers()`: Save data to Isar
- **Buffering**: `_groupedBuffer` management

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
2. **Network Issues**: Data preserved for retry
3. **API Errors**: Graceful degradation with error reporting

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

### **6.3 Common Issues & Solutions**

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

#### **Authentication Error Handling**

The DirectUploadService classifies authentication errors into two categories based on the actual error messages thrown by OpenSenseMapService:

**Permanent Authentication Failures** (Service Disabled):
- `'Authentication failed - user needs to re-login'` - When token refresh fails in OpenSenseMapService
- `'No refresh token found'` - When trying to refresh but no refresh token exists  
- `'Failed to refresh token: $refreshError'` - When token refresh throws an error

**Temporary Authentication Errors** (Handled by OpenSenseMap Service):
- `'Not authenticated'` - When no access token is available
- `'Token refreshed, retrying'` - After successful token refresh (caught by retry mechanism)

**Behavior:**
- **Permanent failures**: Service is permanently disabled, buffers cleared, error logged to Sentry
- **Temporary errors**: Service remains enabled, errors delegated to OpenSenseMap service's retry mechanism
- **Logging**: Permanent failures sent to Sentry, temporary errors logged locally only

#### **Buffer Clearing on Recording Stop**
- **Symptom**: Buffers not cleared when upload fails during recording stop
- **Cause**: Buffers only cleared after successful upload
- **Solution**: Always clear buffers regardless of upload success/failure to prevent memory leaks

#### **Automatic Service Restart**
- **Symptom**: Service permanently disabled after connectivity issues
- **Cause**: No automatic restart mechanism
- **Solution**: Implement exponential backoff restart with up to 5 attempts (2, 4, 6, 8, 10 minutes delays)
- **Buffer Management**: Clear all buffers on restart for fresh start

#### **Data Buffering During Service Disabled**
- **Symptom**: Data continues to be buffered when service is disabled
- **Cause**: No check for service state before buffering
- **Solution**: Reject data when service is temporarily or permanently disabled

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
│   ├── direct_upload_service.dart    # Real-time upload management
│   ├── opensensemap_service.dart     # API communication
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
4. Upload executed via `OpenSenseMapService`
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

### **9.3 Error Handling**

**Authentication Error Classification:**
- **Permanent failures** (service disabled): `'Authentication failed - user needs to re-login'`, `'No refresh token found'`, `'Failed to refresh token:'`
- **Temporary errors** (handled by OpenSenseMap service): `'Not authenticated'`, `'Token refreshed, retrying'`

**Server Error Handling:**
- **Temporary server errors** (5xx): `'Server error 502'`, `'Server error 503'`, `'Server error 504'`, `'Server error 500'`
- **Rate limiting**: `'TooManyRequestsException'`, `'429'`
- **Other errors**: Treated as potential permanent failures, counted toward retry limits

**Logging Strategy:**
- Permanent failures sent to Sentry for monitoring
- Temporary errors logged locally only
- Network timeouts and connectivity issues handled separately

**Error Message Sources:**
All error messages are based on actual exceptions thrown by OpenSenseMapService, ensuring accurate classification and handling.

### **9.4 Performance Tuning**
- **Buffer Sizes**: Balance between memory usage and upload efficiency
- **Upload Frequency**: Balance between real-time updates and API load
- **Error Recovery**: Preserve data while maintaining system stability

---

This documentation provides a complete overview of how data flows through the system from recording start to successful upload to openSenseMap. 