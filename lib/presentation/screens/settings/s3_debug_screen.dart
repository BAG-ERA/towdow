// S3 Debug screen for testing S3 operations
// Provides debugging interface for S3 storage operations

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/providers/providers.dart';
import '../../../data/services/s3_storage_service.dart';
import '../../../data/services/encryption_service.dart';
import '../../../data/services/webdav_client.dart';
import '../../../core/logger.dart';

class S3DebugScreen extends ConsumerStatefulWidget {
  const S3DebugScreen({super.key});

  @override
  ConsumerState<S3DebugScreen> createState() => _S3DebugScreenState();
}

class _S3DebugScreenState extends ConsumerState<S3DebugScreen> {
  final _scrollController = ScrollController();
  final List<String> _logs = [];
  bool _isLoading = false;
  String? _selectedBucket;
  List<String> _buckets = [];
  List<S3FileInfo> _files = [];
  final _encryptionService = EncryptionService();

  @override
  void initState() {
    super.initState();
    _addLog('S3 Debug Screen initialized');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19); // HH:MM:SS format
      _logs.add('$timestamp: $message');
    });
    AppLogger.debug('S3DebugScreen: $message');
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }



  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _showJwtClaims() async {
    _addLog('=== JWT CLAIMS ===');
    
    try {
      final s3Service = await _getS3Service();
      if (s3Service == null) return;

      final claims = s3Service.getJwtClaims();
      
      if (claims.containsKey('error')) {
        _addLog('ERROR: ${claims['error']}');
      } else {
        _addLog('JWT Claims found:');
        claims.forEach((key, value) {
          _addLog('  $key: $value');
        });
      }

      s3Service.dispose();
    } catch (e) {
      _addLog('ERROR: Exception getting JWT claims: $e');
    }
  }

  Future<void> _showConnectionInfo() async {
    _addLog('=== CONNECTION INFO ===');
    
    try {
      // First, let's check the account directly
      final accountAsync = await ref.read(accountRepositoryProvider).getActiveAccount();
      await accountAsync.when(
        success: (account) async {
          if (account == null) {
            _addLog('ERROR: No active account found');
            return;
          }
          
          _addLog('Account Info:');
          _addLog('  ID: ${account.id}');
          _addLog('  Provider: ${account.providerType}');
          _addLog('  Server URL: ${account.serverUrl}');
          _addLog('  Username: ${account.username}');
          _addLog('  Has Access Token: ${account.accessToken != null}');
          if (account.accessToken != null) {
            _addLog('  Token Length: ${account.accessToken!.length}');
          }
          _addLog('  Token Expiry: ${account.tokenExpiry}');
          _addLog('  Is Active: ${account.isActive}');
          
          final s3Service = await _getS3Service();
          if (s3Service == null) return;

          final connectionInfo = s3Service.getConnectionInfo();
          _addLog('S3 Connection Info:');
          connectionInfo.forEach((key, value) {
            _addLog('  $key: $value');
          });

          final credentialsInfo = s3Service.getCredentialsInfo();
          _addLog('=== CREDENTIALS INFO ===');
          credentialsInfo.forEach((key, value) {
            _addLog('  $key: $value');
          });

          s3Service.dispose();
        },
        failure: (failure) async {
          _addLog('ERROR: Failed to get account: ${failure.message}');
        },
      );
    } catch (e) {
      _addLog('ERROR: Exception getting connection info: $e');
    }
  }

  Future<void> _refreshToken() async {
    _addLog('=== REFRESHING TOKEN ===');
    
    try {
      final s3Service = await _getS3Service();
      if (s3Service == null) return;

      // Force token refresh by trying to get STS credentials
      _addLog('Attempting to refresh token...');
      final result = await s3Service.listBuckets();
      
      result.when(
        success: (buckets) {
          _addLog('SUCCESS: Token refresh successful! Found ${buckets.length} buckets');
        },
        failure: (failure) {
          _addLog('ERROR: Token refresh failed: ${failure.message}');
        },
      );

      s3Service.dispose();
    } catch (e) {
      _addLog('ERROR: Exception during token refresh: $e');
    }
  }

  Future<S3StorageService?> _getS3Service() async {
    final accountAsync = await ref.read(accountRepositoryProvider).getActiveAccount();
    return accountAsync.when(
      success: (account) {
        if (account == null) {
          _addLog('ERROR: No active account found');
          return null;
        }
        if (account.accessToken == null) {
          _addLog('ERROR: No access token available');
          return null;
        }
        return S3StorageService(
          account: account,
          onTokenRefresh: (accessToken, refreshToken, tokenExpiry) {
            _addLog('INFO: Token refreshed, new expiry: $tokenExpiry');
            // Update the account with new tokens
            // In a real app, you'd save this to the repository
          },
        );
      },
      failure: (failure) {
        _addLog('ERROR: Failed to get account: ${failure.message}');
        return null;
      },
    );
  }

  Future<void> _listBuckets() async {
    setState(() => _isLoading = true);
    _addLog('Listing S3 buckets...');

    try {
      final s3Service = await _getS3Service();
      if (s3Service == null) return;

      final result = await s3Service.listBuckets();
      result.when(
        success: (buckets) {
          setState(() {
            _buckets = buckets;
            _selectedBucket = buckets.isNotEmpty ? buckets.first : null;
          });
          _addLog('SUCCESS: Found ${buckets.length} buckets: ${buckets.join(', ')}');
        },
        failure: (failure) {
          _addLog('ERROR: Failed to list buckets: ${failure.message}');
        },
      );

      s3Service.dispose();
    } on RefreshTokenExpiredException catch (e) {
      _addLog('ERROR: Session expired - $e');
      _addLog('INFO: Please log in again to refresh your session');
    } catch (e) {
      _addLog('ERROR: Exception during listBuckets: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _listObjects() async {
    if (_selectedBucket == null) {
      _addLog('ERROR: No bucket selected');
      return;
    }

    setState(() => _isLoading = true);
    _addLog('Listing objects in bucket: $_selectedBucket');

    try {
      final s3Service = await _getS3Service();
      if (s3Service == null) return;

      final result = await s3Service.listObjects(_selectedBucket!);
      result.when(
        success: (files) {
          setState(() {
            _files = files;
          });
          _addLog('SUCCESS: Found ${files.length} objects in $_selectedBucket');
          for (final file in files) {
            _addLog('  - ${file.key} (${file.size} bytes, ${file.lastModified})');
          }
        },
        failure: (failure) {
          _addLog('ERROR: Failed to list objects: ${failure.message}');
        },
      );

      s3Service.dispose();
    } catch (e) {
      _addLog('ERROR: Exception during listObjects: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadTestFile() async {
    if (_selectedBucket == null) {
      _addLog('ERROR: No bucket selected');
      return;
    }

    setState(() => _isLoading = true);
    _addLog('Selecting file to upload...');

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        _addLog('File selection cancelled');
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      Uint8List? fileBytes = file.bytes;

      // On desktop platforms, file.bytes might be null, so read from path
      if (fileBytes == null && file.path != null) {
        try {
          final fileObj = File(file.path!);
          fileBytes = await fileObj.readAsBytes();
          _addLog('Read file from path: ${file.path} (${fileBytes.length} bytes)');
        } catch (e) {
          _addLog('ERROR: Could not read file from path: $e');
          return;
        }
      }

      if (fileBytes == null) {
        _addLog('ERROR: Could not read file bytes and no file path available');
        return;
      }

      _addLog('Uploading file: $fileName (${fileBytes.length} bytes)');

      final s3Service = await _getS3Service();
      if (s3Service == null) return;

      // Determine if uploading to private or shared bucket based on selected bucket
      final isPrivate = _selectedBucket == 'towdow-private';
      final prefix = isPrivate ? s3Service.getUserPrefix() : s3Service.getSharedPrefix('test');
      final key = '$prefix$fileName';
      
      _addLog('Uploading to ${isPrivate ? 'private' : 'shared'} bucket ($_selectedBucket)');
      _addLog('Using key: $key');

      final uploadResult = await s3Service.uploadFile(
        key: key,
        data: fileBytes,
        isPrivate: isPrivate,
        contentType: _getContentType(fileName),
      );

      uploadResult.when(
        success: (fileUrl) {
          _addLog('SUCCESS: File uploaded to: $fileUrl');
          _addLog('Key: $key');
          
          // Refresh the file list
          _listObjects();
        },
        failure: (failure) {
          _addLog('ERROR: Failed to upload file: ${failure.message}');
        },
      );

      s3Service.dispose();
    } catch (e) {
      _addLog('ERROR: Exception during file upload: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadFile(S3FileInfo fileInfo) async {
    setState(() => _isLoading = true);
    _addLog('Downloading file: ${fileInfo.key}');

    try {
      final s3Service = await _getS3Service();
      if (s3Service == null) return;

      // Determine if the file is in private or shared bucket based on selected bucket
      final isPrivate = _selectedBucket == 'towdow-private';
      _addLog('Using ${isPrivate ? 'private' : 'shared'} bucket ($_selectedBucket)');

      final result = await s3Service.downloadFile(
        key: fileInfo.key,
        isPrivate: isPrivate,
      );

      result.when(
        success: (data) async {
          _addLog('SUCCESS: Downloaded ${fileInfo.key} (${data.length} bytes)');
          _addLog('File content type: ${fileInfo.contentType ?? 'unknown'}');
          
          // Save file to Downloads directory
          try {
            final fileName = fileInfo.key.split('/').last; // Get filename from key
            final downloadsDir = Directory('${Platform.environment['HOME']}/Downloads');
            
            // Create Downloads directory if it doesn't exist
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            
            final filePath = '${downloadsDir.path}/s3_download_$fileName';
            final file = File(filePath);
            await file.writeAsBytes(data);
            
            _addLog('File saved to: $filePath');
          } catch (e) {
            _addLog('ERROR: Could not save file to Downloads: $e');
          }
          
          // Show some metadata
          _addLog('File metadata:');
          _addLog('  Size: ${fileInfo.size} bytes');
          _addLog('  ETag: ${fileInfo.etag ?? 'none'}');
          _addLog('  Last Modified: ${fileInfo.lastModified}');
        },
        failure: (failure) {
          _addLog('ERROR: Failed to download file: ${failure.message}');
        },
      );

      s3Service.dispose();
    } catch (e) {
      _addLog('ERROR: Exception during file download: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFile(S3FileInfo fileInfo) async {
    setState(() => _isLoading = true);
    _addLog('Deleting file: ${fileInfo.key}');

    try {
      final s3Service = await _getS3Service();
      if (s3Service == null) return;

      final result = await s3Service.deleteFile(
        key: fileInfo.key,
        isPrivate: true, // Assuming we're testing with private bucket
      );

      result.when(
        success: (_) {
          _addLog('SUCCESS: Deleted file: ${fileInfo.key}');
          
          // Refresh the file list
          _listObjects();
        },
        failure: (failure) {
          _addLog('ERROR: Failed to delete file: ${failure.message}');
        },
      );

      s3Service.dispose();
    } catch (e) {
      _addLog('ERROR: Exception during file deletion: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testEncryption() async {
    _addLog('Testing encryption service...');

    try {
      const testData = 'Hello, World! This is a test of the encryption service.';
      final testBytes = Uint8List.fromList(testData.codeUnits);
      final key = _encryptionService.generateUserKey('test-user');

      _addLog('Original data: $testData (${testBytes.length} bytes)');
      _addLog('Encryption key: $key');
      _addLog('Algorithm: ${_encryptionService.algorithmInfo}');
      _addLog('Encryption enabled: ${_encryptionService.isEncryptionEnabled}');

      // Test encryption
      final encryptResult = await _encryptionService.encryptFile(testBytes, key);
      encryptResult.when(
        success: (encryptedData) {
          _addLog('SUCCESS: Encrypted data (${encryptedData.length} bytes)');

          // Test decryption
          _encryptionService.decryptFile(encryptedData, key).then((decryptResult) {
            decryptResult.when(
              success: (decryptedData) {
                final decryptedText = String.fromCharCodes(decryptedData);
                _addLog('SUCCESS: Decrypted data: $decryptedText');
                
                if (decryptedText == testData) {
                  _addLog('SUCCESS: Encryption/decryption test passed!');
                } else {
                  _addLog('ERROR: Decrypted data does not match original');
                }
              },
              failure: (failure) {
                _addLog('ERROR: Failed to decrypt: ${failure.message}');
              },
            );
          });
        },
        failure: (failure) {
          _addLog('ERROR: Failed to encrypt: ${failure.message}');
        },
      );
    } catch (e) {
      _addLog('ERROR: Exception during encryption test: $e');
    }
  }

  String? _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('S3 Storage Debug'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bucket selection
                if (_buckets.isNotEmpty) ...[
                  Text(
                    'Selected Bucket:',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedBucket,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _buckets.map((bucket) {
                      return DropdownMenuItem(
                        value: bucket,
                        child: Text(bucket),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBucket = value;
                        _files.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Debug info buttons
                Text(
                  'Debug Information:',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _showConnectionInfo,
                      icon: const Icon(Icons.info),
                      label: const Text('Connection Info'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _showJwtClaims,
                      icon: const Icon(Icons.key),
                      label: const Text('JWT Claims'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _refreshToken,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Token'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons
                Text(
                  'S3 Operations:',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _listBuckets,
                      icon: const Icon(Icons.refresh),
                      label: const Text('List Buckets'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading || _selectedBucket == null ? null : _listObjects,
                      icon: const Icon(Icons.folder),
                      label: const Text('List Objects'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading || _selectedBucket == null ? null : _uploadTestFile,
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload File'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testEncryption,
                      icon: const Icon(Icons.security),
                      label: const Text('Test Encryption'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // File list
          if (_files.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Files in ${_selectedBucket}:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_files.length, (index) {
                    final file = _files[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          file.key,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        subtitle: Text('${file.size} bytes • ${file.lastModified}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: _isLoading ? null : () => _downloadFile(file),
                              tooltip: 'Download',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: _isLoading ? null : () => _deleteFile(file),
                              tooltip: 'Delete',
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          
          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Processing...'),
                ],
              ),
            ),
          
          // Logs
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Logs:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final isError = log.contains('ERROR:');
                          final isSuccess = log.contains('SUCCESS:');
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: isError
                                    ? Theme.of(context).colorScheme.error
                                    : isSuccess
                                        ? Colors.green
                                        : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 