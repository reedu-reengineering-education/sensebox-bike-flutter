import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_indicator.dart';

/// Demo widget showing different states of the UploadProgressIndicator
/// This is for development and testing purposes only
class UploadProgressIndicatorDemo extends StatefulWidget {
  const UploadProgressIndicatorDemo({super.key});

  @override
  State<UploadProgressIndicatorDemo> createState() => _UploadProgressIndicatorDemoState();
}

class _UploadProgressIndicatorDemoState extends State<UploadProgressIndicatorDemo> {
  int _currentStateIndex = 0;
  
  final List<UploadProgress> _demoStates = [
    // Preparing state
    const UploadProgress(
      totalChunks: 0,
      completedChunks: 0,
      failedChunks: 0,
      status: UploadStatus.preparing,
      canRetry: false,
    ),
    
    // Uploading state - 30% complete
    const UploadProgress(
      totalChunks: 10,
      completedChunks: 3,
      failedChunks: 0,
      status: UploadStatus.uploading,
      canRetry: false,
    ),
    
    // Uploading state - 70% complete
    const UploadProgress(
      totalChunks: 10,
      completedChunks: 7,
      failedChunks: 0,
      status: UploadStatus.uploading,
      canRetry: false,
    ),
    
    // Retrying state
    const UploadProgress(
      totalChunks: 5,
      completedChunks: 2,
      failedChunks: 1,
      status: UploadStatus.retrying,
      canRetry: true,
    ),
    
    // Completed state
    const UploadProgress(
      totalChunks: 8,
      completedChunks: 8,
      failedChunks: 0,
      status: UploadStatus.completed,
      canRetry: false,
    ),
    
    // Failed state - retryable
    const UploadProgress(
      totalChunks: 6,
      completedChunks: 3,
      failedChunks: 3,
      status: UploadStatus.failed,
      errorMessage: 'Network connection failed',
      canRetry: true,
    ),
    
    // Failed state - authentication error (not retryable)
    const UploadProgress(
      totalChunks: 4,
      completedChunks: 0,
      failedChunks: 0,
      status: UploadStatus.failed,
      errorMessage: 'Authentication failed - user needs to re-login',
      canRetry: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Progress Demo'),
        actions: [
          IconButton(
            onPressed: _nextState,
            icon: const Icon(Icons.skip_next),
            tooltip: 'Next State',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current State: ${_getStateName(_demoStates[_currentStateIndex].status)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Full indicator
            Text(
              'Full Indicator:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            UploadProgressIndicator(
              progress: _demoStates[_currentStateIndex],
              onRetry: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Retry button pressed')),
                );
              },
              onCancel: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cancel button pressed')),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Compact indicator
            Text(
              'Compact Indicator:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            UploadProgressIndicator(
              progress: _demoStates[_currentStateIndex],
              compact: true,
              onRetry: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Compact retry button pressed')),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // State information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'State Information:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Status: ${_demoStates[_currentStateIndex].status}'),
                    Text('Total Chunks: ${_demoStates[_currentStateIndex].totalChunks}'),
                    Text('Completed: ${_demoStates[_currentStateIndex].completedChunks}'),
                    Text('Failed: ${_demoStates[_currentStateIndex].failedChunks}'),
                    Text('Progress: ${_demoStates[_currentStateIndex].progressPercentageInt}%'),
                    Text('Can Retry: ${_demoStates[_currentStateIndex].canRetry}'),
                    if (_demoStates[_currentStateIndex].errorMessage != null)
                      Text('Error: ${_demoStates[_currentStateIndex].errorMessage}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nextState,
        child: const Icon(Icons.navigate_next),
      ),
    );
  }

  void _nextState() {
    setState(() {
      _currentStateIndex = (_currentStateIndex + 1) % _demoStates.length;
    });
  }

  String _getStateName(UploadStatus status) {
    switch (status) {
      case UploadStatus.preparing:
        return 'Preparing';
      case UploadStatus.uploading:
        return 'Uploading';
      case UploadStatus.retrying:
        return 'Retrying';
      case UploadStatus.completed:
        return 'Completed';
      case UploadStatus.failed:
        return 'Failed';
    }
  }
}