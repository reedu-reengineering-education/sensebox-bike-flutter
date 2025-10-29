import 'dart:convert';

/// Utility functions for openSenseMap API interactions

// ===== JSON PARSING UTILITIES =====

/// Safely parses JSON string with proper error handling
/// 
/// Throws [Exception] with descriptive message if parsing fails
/// or if the input is empty
Map<String, dynamic> safeJsonDecode(String jsonString) {
  if (jsonString.trim().isEmpty) {
    throw Exception('Empty response from API');
  }
  
  try {
    return jsonDecode(jsonString);
  } catch (e) {
    throw Exception('Invalid JSON response from API: $e');
  }
}

// ===== API RESPONSE EXTRACTION UTILITIES =====

/// Extracts user data from login/registration API response
/// 
/// Returns the user data if found, null otherwise
Map<String, dynamic>? extractUserData(Map<String, dynamic> responseData) {
  if (responseData.containsKey('data') && 
      responseData['data'] is Map<String, dynamic> &&
      responseData['data'].containsKey('user')) {
    return responseData['data']['user'] as Map<String, dynamic>;
  }
  return null;
}

/// Extracts box IDs from login/registration API response
/// 
/// Returns list of box IDs if found, empty list otherwise
List<String> extractBoxIds(Map<String, dynamic> responseData) {
  final userData = extractUserData(responseData);
  if (userData != null && userData.containsKey('boxes')) {
    final boxes = userData['boxes'];
    if (boxes is List) {
      return boxes.map((boxId) => boxId.toString()).toList();
    }
  }
  return [];
}

/// Checks if the response contains valid user data structure
bool hasValidUserData(Map<String, dynamic> responseData) {
  return extractUserData(responseData) != null;
}

/// Checks if the response contains box IDs
bool hasBoxIds(Map<String, dynamic> responseData) {
  return extractBoxIds(responseData).isNotEmpty;
}
