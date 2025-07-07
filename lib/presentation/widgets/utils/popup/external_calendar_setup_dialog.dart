// External calendar setup dialog
// Allows users to add new external CalDAV calendars
// Performs discovery and calendar selection

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/models/external_caldav_account.dart';
import '../../../../data/models/external_calendar.dart';
import '../../../../data/providers/providers.dart';

class ExternalCalendarSetupDialog extends ConsumerStatefulWidget {
  const ExternalCalendarSetupDialog({super.key});

  @override
  ConsumerState<ExternalCalendarSetupDialog> createState() => _ExternalCalendarSetupDialogState();
}

class _ExternalCalendarSetupDialogState extends ConsumerState<ExternalCalendarSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _calendarPathController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _showAdvanced = false;
  bool _requiresAuth = true;
  ExternalCalendarAuthType _authType = ExternalCalendarAuthType.basic;
  
  List<ExternalCalendar> _discoveredCalendars = [];
  Set<String> _selectedCalendars = {};
  
  @override
  void dispose() {
    _serverUrlController.dispose();
    _calendarPathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add External Calendar'),
      content: SizedBox(
        width: double.maxFinite,
        height: 600,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_discoveredCalendars.isEmpty) ...[
                _buildConnectionForm(),
              ] else ...[
                _buildCalendarSelection(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_discoveredCalendars.isEmpty) ...[
          ElevatedButton(
            onPressed: _isLoading ? null : _testConnection,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect'),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: _selectedCalendars.isEmpty ? null : _saveCalendars,
            child: const Text('Add Selected'),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectionForm() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your CalDAV server details',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            
            // Server URL
            TextFormField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://caldav.example.com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a server URL';
                }
                final trimmedValue = value.trim();
                final uri = Uri.tryParse(trimmedValue);
                if (uri == null || !uri.hasScheme) {
                  return 'Please enter a valid URL';
                }
                return null;
              },
              onChanged: (value) {
                // Auto-generate display name from URL
                if (_displayNameController.text.isEmpty) {
                  final trimmedValue = value.trim();
                  final uri = Uri.tryParse(trimmedValue);
                  if (uri != null) {
                    _displayNameController.text = uri.host;
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Calendar path
            TextFormField(
              controller: _calendarPathController,
              decoration: const InputDecoration(
                labelText: 'Calendar Path',
                hintText: '/dav/calendars/username/ (leave empty for auto-discovery)',
                border: OutlineInputBorder(),
                helperText: 'Path to your calendar collection (e.g., /dav/calendars/user/, /remote.php/dav/calendars/user/)',
              ),
            ),
            const SizedBox(height: 16),
            
            // Display name
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'My Calendar',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a display name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Authentication toggle
            CheckboxListTile(
              title: const Text('Requires Authentication'),
              value: _requiresAuth,
              onChanged: (value) {
                setState(() {
                  _requiresAuth = value ?? false;
                });
              },
            ),
            
            if (_requiresAuth) ...[
              const SizedBox(height: 8),
              
              // Username
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_requiresAuth && (value == null || value.trim().isEmpty)) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Password
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (_requiresAuth && (value == null || value.trim().isEmpty)) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Advanced options
            ExpansionTile(
              title: const Text('Advanced Options'),
              initiallyExpanded: _showAdvanced,
              onExpansionChanged: (expanded) {
                setState(() {
                  _showAdvanced = expanded;
                });
              },
              children: [
                const SizedBox(height: 8),
                
                // Auth type
                DropdownButtonFormField<ExternalCalendarAuthType>(
                  value: _authType,
                  decoration: const InputDecoration(
                    labelText: 'Authentication Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ExternalCalendarAuthType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _authType = value ?? ExternalCalendarAuthType.basic;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Help text
                Text(
                  'Basic: Use username/password authentication\n'
                  'OAuth: Use OAuth2 authentication (advanced)\n'
                  'Anonymous: No authentication required',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSelection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select calendars to sync',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Found ${_discoveredCalendars.length} calendars',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView.builder(
              itemCount: _discoveredCalendars.length,
              itemBuilder: (context, index) {
                final calendar = _discoveredCalendars[index];
                return CheckboxListTile(
                  title: Text(calendar.displayName),
                  subtitle: Text(calendar.description ?? 'No description'),
                  secondary: calendar.color != null
                      ? Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Color(int.parse(calendar.color!.replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                  value: _selectedCalendars.contains(calendar.id),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedCalendars.add(calendar.id);
                      } else {
                        _selectedCalendars.remove(calendar.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Actions
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _discoveredCalendars.clear();
                    _selectedCalendars.clear();
                  });
                },
                child: const Text('Back'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _selectedCalendars.isEmpty ? null : () {
                  setState(() {
                    _selectedCalendars.addAll(
                      _discoveredCalendars.map((c) => c.id),
                    );
                  });
                },
                child: const Text('Select All'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _selectedCalendars.isEmpty ? null : () {
                  setState(() {
                    _selectedCalendars.clear();
                  });
                },
                child: const Text('Select None'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Create temporary account for testing
      final tempAccount = ExternalCaldavAccount(
        id: 'temp',
        serverUrl: _serverUrlController.text.trim(),
        username: _requiresAuth ? _usernameController.text.trim() : '',
        password: _requiresAuth ? _passwordController.text.trim() : null,
        displayName: _displayNameController.text.trim(),
        authType: _requiresAuth ? _authType : ExternalCalendarAuthType.anonymous,
        createdAt: DateTime.now(),
      );
      
      final caldavService = ref.read(externalCalDAVServiceProvider(tempAccount));
      
      // Test connection
      final connectionResult = await caldavService.testConnection();
      await connectionResult.when(
        success: (_) async {
          // Connection successful, proceed to discovery
        },
        failure: (failure) async {
          throw Exception('Connection failed: ${failure.message}');
        },
      );
      
      // Discover calendars
      final calendarPath = _calendarPathController.text.trim().isEmpty 
          ? null 
          : _calendarPathController.text.trim();
      final discoveryResult = await caldavService.discoverCalendars(calendarPath: calendarPath);
      final calendars = await discoveryResult.when(
        success: (calendars) async => calendars,
        failure: (failure) async {
          throw Exception('Calendar discovery failed: ${failure.message}');
        },
      );
      
      // Filter to only VEVENT calendars
      final eventCalendars = calendars.where((cal) => 
        cal.supportedComponents.contains('VEVENT')
      ).toList();
      
      if (eventCalendars.isEmpty) {
        throw Exception('No calendars with VEVENT support found');
      }
      
      setState(() {
        _discoveredCalendars = eventCalendars;
        _selectedCalendars.clear();
      });
      
      AppLogger.info('ExternalCalendarSetupDialog: Discovered ${eventCalendars.length} calendars');
      
    } catch (e) {
      AppLogger.error('ExternalCalendarSetupDialog: Connection test failed: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCalendars() async {
    setState(() => _isLoading = true);
    
    try {
      final accountRepository = ref.read(externalAccountRepositoryProvider);
      final calendarRepository = ref.read(externalCalendarRepositoryProvider);
      
      // Check if account already exists
      final existingAccountResult = await accountRepository.getByServerAndUsername(
        _serverUrlController.text.trim(),
        _usernameController.text.trim(),
      );
      
      await existingAccountResult.when(
        success: (existingAccount) async {
          if (existingAccount != null) {
            throw Exception('Account already exists for this server and username');
          }
        },
        failure: (_) async {
          // No existing account found, continue
        },
      );
      
      // Create account
      final account = ExternalCaldavAccount(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        serverUrl: _serverUrlController.text.trim(),
        username: _requiresAuth ? _usernameController.text.trim() : '',
        password: _requiresAuth ? _passwordController.text.trim() : null,
        displayName: _displayNameController.text.trim(),
        authType: _requiresAuth ? _authType : ExternalCalendarAuthType.anonymous,
        createdAt: DateTime.now(),
      );
      
      // Save account
      final accountResult = await accountRepository.save(account);
      await accountResult.when(
        success: (_) async {
          // Account saved successfully
        },
        failure: (failure) async {
          throw Exception('Failed to save account: ${failure.message}');
        },
      );
      
      // Save selected calendars
      final selectedCalendarList = _discoveredCalendars
          .where((cal) => _selectedCalendars.contains(cal.id))
          .toList();
      
      for (final calendar in selectedCalendarList) {
        final calendarWithAccount = calendar.copyWith(
          accountId: account.id,
          uid: '${account.id}_${calendar.uid}',
          isEnabled: true,
        );
        
        final calendarResult = await calendarRepository.save(calendarWithAccount);
        await calendarResult.when(
          success: (_) async {
            // Calendar saved successfully
          },
          failure: (failure) async {
            AppLogger.warning('ExternalCalendarSetupDialog: Failed to save calendar ${calendar.displayName}: ${failure.message}');
          },
        );
      }
      
      AppLogger.info('ExternalCalendarSetupDialog: Successfully added external calendar account "${account.displayName}" with ${selectedCalendarList.length} calendars');
      
      // Trigger immediate sync for the new account
      final externalSyncService = ref.read(externalCalendarSyncServiceProvider);
      await externalSyncService.syncAccount(account.id);
      
      if (mounted) {
        Navigator.of(context).pop(account);
      }
      
    } catch (e) {
      AppLogger.error('ExternalCalendarSetupDialog: Failed to save calendars: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save calendars: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
} 