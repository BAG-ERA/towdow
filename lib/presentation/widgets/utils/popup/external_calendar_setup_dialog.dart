// External calendar setup dialog
// Allows users to add new external CalDAV calendars
// Performs discovery and calendar selection

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/models/external_caldav_account.dart';
import '../../../../data/models/external_calendar.dart';
import '../../../../data/providers/providers.dart';
import '../../../../core/result.dart';

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
  ExternalCalendarAuthType _authType = ExternalCalendarAuthType.anonymous;
  final Map<String, Color?> _calendarColors = {};
  
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
      title: Text(AppLocalizations.of(context)!.addExternalCalendar),
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
          child: Text(AppLocalizations.of(context)!.cancel),
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
                : Text(AppLocalizations.of(context)!.connect),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: _selectedCalendars.isEmpty ? null : _saveCalendars,
            child: Text(AppLocalizations.of(context)!.add),
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
              AppLocalizations.of(context)!.enterCaldavDetails,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            
            // Server URL
            TextFormField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.serverUrlLabel,
                hintText: 'https://caldav.example.com',
                border: const OutlineInputBorder(),
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
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.calendarPath,
                hintText: '/dav/calendars/username/ (leave empty for auto-discovery)',
                border: const OutlineInputBorder(),
                helperText: AppLocalizations.of(context)!.calendarPathHelper,
              ),
            ),
            const SizedBox(height: 16),
            
            // Display name
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.displayName,
                hintText: 'My Calendar',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a display name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Authentication type selector (always visible)
            DropdownButtonFormField<ExternalCalendarAuthType>(
              value: _authType,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.authenticationType,
                border: const OutlineInputBorder(),
              ),
              items: ExternalCalendarAuthType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _authType = value ?? ExternalCalendarAuthType.anonymous;
                });
              },
            ),
            
            // Username/password fields (only for basic or oauth)
            if (_authType == ExternalCalendarAuthType.basic || _authType == ExternalCalendarAuthType.oauth) ...[
              const SizedBox(height: 8),
              
              // Username
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.username,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((_authType == ExternalCalendarAuthType.basic || _authType == ExternalCalendarAuthType.oauth) && (value == null || value.trim().isEmpty)) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Password
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if ((_authType == ExternalCalendarAuthType.basic || _authType == ExternalCalendarAuthType.oauth) && (value == null || value.trim().isEmpty)) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
            ],
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
            AppLocalizations.of(context)!.selectCalendarsToSync,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.foundCalendars(_discoveredCalendars.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView.builder(
              itemCount: _discoveredCalendars.length,
              itemBuilder: (context, index) {
                final calendar = _discoveredCalendars[index];
                final color = _calendarColors[calendar.id] ??
                  (calendar.color != null ? Color(int.parse(calendar.color!.replaceFirst('#', '0xFF'))) : Colors.blue);
                return CheckboxListTile(
                  title: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picked = await _showColorPickerDialog(context, color);
                          if (picked != null) {
                            setState(() {
                              _calendarColors[calendar.id] = picked;
                            });
                          }
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: Text(calendar.displayName)),
                    ],
                  ),
                  subtitle: Text(calendar.description ?? AppLocalizations.of(context)!.noDescription),
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
                child: Text(AppLocalizations.of(context)!.back),
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
                child: Text(AppLocalizations.of(context)!.selectAll),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _selectedCalendars.isEmpty ? null : () {
                  setState(() {
                    _selectedCalendars.clear();
                  });
                },
                child: Text(AppLocalizations.of(context)!.selectNone),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Color?> _showColorPickerDialog(BuildContext context, Color currentColor) async {
    Color? pickedColor = currentColor;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final colors = [
            Colors.red,
            Colors.pink,
            Colors.purple,
            Colors.deepPurple,
            Colors.indigo,
            Colors.blue,
            Colors.lightBlue,
            Colors.cyan,
            Colors.teal,
            Colors.green,
            Colors.lightGreen,
            Colors.lime,
            Colors.yellow,
            Colors.orange,
            Colors.deepOrange,
            Colors.brown,
            Colors.grey,
            Colors.blueGrey,
          ];
          final controller = TextEditingController();
          String? errorText;
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.chooseCalendarColor),
            content: SizedBox(
              width: 300,
              height: 420,
              child: Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: colors.length,
                      itemBuilder: (context, index) {
                        final color = colors[index];
                        final isSelected = pickedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              pickedColor = color;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: Text(AppLocalizations.of(context)!.customColor),
                    onPressed: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(AppLocalizations.of(context)!.enterCustomColor),
                          content: TextField(
                            controller: controller,
                              decoration: InputDecoration(
                                labelText: 'Hex Color (e.g. #FF8800 or 0088FF)',
                                errorText: errorText,
                              ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                final input = controller.text.trim();
                                final hex = input.startsWith('#') ? input.substring(1) : input;
                                if (hex.length == 6 || hex.length == 8) {
                                  try {
                                    final color = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
                                    Navigator.of(context).pop('#${hex.toUpperCase()}');
                                  } catch (_) {
                                    setState(() { errorText = AppLocalizations.of(context)!.invalidHexColor; });
                                  }
                                } else {
                                  setState(() { errorText = AppLocalizations.of(context)!.enter6or8HexDigits; });
                                }
                              },
                              child: Text(AppLocalizations.of(context)!.ok),
                            ),
                          ],
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          pickedColor = Color(int.parse(result.substring(1), radix: 16));
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(pickedColor),
                child: Text(AppLocalizations.of(context)!.ok),
              ),
            ],
          );
        },
      ),
    );
    return pickedColor;
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Create temporary account for testing
      final tempAccount = ExternalCaldavAccount(
        id: 'temp',
        serverUrl: _serverUrlController.text.trim(),
        username: _authType == ExternalCalendarAuthType.basic ? _usernameController.text.trim() : '',
        password: _authType == ExternalCalendarAuthType.basic ? _passwordController.text.trim() : null,
        displayName: _displayNameController.text.trim(),
        authType: _authType,
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
        username: _authType == ExternalCalendarAuthType.basic ? _usernameController.text.trim() : '',
        password: _authType == ExternalCalendarAuthType.basic ? _passwordController.text.trim() : null,
        displayName: _displayNameController.text.trim(),
        authType: _authType,
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
        // Use the selected color for this calendar, or fallback to the calendar's original color
        final colorHex = _calendarColors[calendar.id] != null
            ? '#${_calendarColors[calendar.id]!.value.toRadixString(16).padLeft(8, '0').substring(2)}'
            : calendar.color;
            
        final calendarWithAccount = calendar.copyWith(
          accountId: account.id,
          uid: '${account.id}_${calendar.uid}',
          isEnabled: true,
          color: colorHex,
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