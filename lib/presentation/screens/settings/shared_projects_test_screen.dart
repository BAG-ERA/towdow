// Shared Projects Test Screen
// Test screen for testing the shared project functionality
// Provides UI to test all sharing API endpoints

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logger.dart';
import '../../../data/providers/providers.dart';
import '../../../data/services/towdow_sharing_service.dart';
import '../../../data/models/task_calendar.dart';

class SharedProjectsTestScreen extends ConsumerStatefulWidget {
  const SharedProjectsTestScreen({super.key});

  @override
  ConsumerState<SharedProjectsTestScreen> createState() => _SharedProjectsTestScreenState();
}

class _SharedProjectsTestScreenState extends ConsumerState<SharedProjectsTestScreen> {
  final _projectPathController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _result = '';
  TowDowSharingService? _sharingService;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _projectPathController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(activeAccountProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Projects Test'),
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: accountAsync.when(
        data: (account) {
          if (account == null) {
            return const Center(
              child: Text('No active account found'),
            );
          }

          // Initialize sharing service with the account
          if (_sharingService == null) {
            _sharingService = TowDowSharingService(account: account);
          }

          if (!_sharingService!.supportsSharing) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Sharing not supported',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sharing is only available for TowDow Cloud and TowDow self-hosted accounts.\n'
                    'Current account type: ${account.providerType}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return _buildTestInterface(account);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading account: $error'),
        ),
      ),
    );
  }

  Widget _buildTestInterface(account) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Account info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Server: ${account.serverUrl}'),
                  Text('Username: ${account.username}'),
                  Text('Provider: ${account.providerType}'),
                  if (account.calendarHome != null)
                    Text('Calendar Home: ${account.calendarHome}'),
                  if (account.principal != null)
                    Text('Principal: ${account.principal}'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Input fields
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Parameters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                                    // Project Selector Dropdown
                  Consumer(
                    builder: (context, ref, child) {
                      final calendarsAsync = ref.watch(calendarListProvider);
                      return calendarsAsync.when(
                        data: (calendars) {
                          final projects = calendars.where((c) => c.supportsTodos && c.isActive).toList();
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButton<String>(
                                hint: const Text('Choose a project'),
                                isExpanded: true,
                                items: projects.map((project) {
                                  final uuid = _extractProjectPathFromCalendarPath(project.path);
                                  return DropdownMenuItem<String>(
                                    value: uuid,
                                    child: Text('${project.displayName} ($uuid)'),
                                  );
                                }).toList(),
                                onChanged: (uuid) {
                                  if (uuid != null) {
                                    _projectPathController.text = uuid;
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _projectPathController,
                                decoration: const InputDecoration(
                                  labelText: 'Project Path (UUID)',
                                  hintText: 'e.g., 16754745-576e-4c12-a1e2-65d26b01ddc2',
                                  border: OutlineInputBorder(),
                                  helperText: 'Auto-filled when selecting from dropdown above',
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stack) => Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Error loading projects: $error',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Target User Email',
                      hintText: 'e.g., user@example.com',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Test buttons
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'API Tests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testAddMember,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Project Member'),
                  ),
                  
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testGetMembers,
                    icon: const Icon(Icons.people),
                    label: const Text('Get Project Members'),
                  ),
                  
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testGetSharedWithMe,
                    icon: const Icon(Icons.share),
                    label: const Text('Get Projects Shared With Me'),
                  ),
                  
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testRemoveMember,
                    icon: const Icon(Icons.person_remove),
                    label: const Text('Remove Project Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testExitShare,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Exit Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Results
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Results',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_result.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _result = ''),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Loading...'),
                      ],
                    )
                  else if (_result.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _result,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    )
                  else
                    Text(
                      'No results yet. Run a test to see the output.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testAddMember() async {
    if (_sharingService == null) return;
    
    final projectPath = _projectPathController.text.trim();
    final email = _emailController.text.trim();
    
    if (projectPath.isEmpty || email.isEmpty) {
      setState(() {
        _result = 'Error: Project path and email are required';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    try {
      final result = await _sharingService!.addProjectMember(
        projectPath: projectPath,
        targetUserEmail: email,
      );
      
      setState(() {
        _result = result.when(
          success: (_) => 'Success: Member added successfully',
          failure: (failure) => 'Error: ${failure.message}',
        );
      });
    } catch (e) {
      setState(() {
        _result = 'Exception: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testGetMembers() async {
    if (_sharingService == null) return;
    
    final projectPath = _projectPathController.text.trim();
    
    if (projectPath.isEmpty) {
      setState(() {
        _result = 'Error: Project path is required';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    try {
      final result = await _sharingService!.getProjectMembers(projectPath);
      
      setState(() {
        _result = result.when(
          success: (members) {
            if (members.isEmpty) {
              return 'Success: No members found for this project';
            }
            final membersText = members.map((m) => 
              '- ${m.targetUserEmail} (${m.projectRight}) from ${m.sourceUserEmail}'
            ).join('\n');
            return 'Success: Found ${members.length} members:\n$membersText';
          },
          failure: (failure) => 'Error: ${failure.message}',
        );
      });
    } catch (e) {
      setState(() {
        _result = 'Exception: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testGetSharedWithMe() async {
    if (_sharingService == null) return;
    
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    try {
      final result = await _sharingService!.getProjectsSharedWithMe();
      
      setState(() {
        _result = result.when(
          success: (projects) {
            if (projects.isEmpty) {
              return 'Success: No projects shared with you';
            }
            final projectsText = projects.map((p) => 
              '- ${p.projectPath} shared by ${p.sourceUserEmail} (${p.projectRight})'
            ).join('\n');
            return 'Success: Found ${projects.length} shared projects:\n$projectsText';
          },
          failure: (failure) => 'Error: ${failure.message}',
        );
      });
    } catch (e) {
      setState(() {
        _result = 'Exception: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRemoveMember() async {
    if (_sharingService == null) return;
    
    final projectPath = _projectPathController.text.trim();
    final email = _emailController.text.trim();
    
    if (projectPath.isEmpty || email.isEmpty) {
      setState(() {
        _result = 'Error: Project path and email are required';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    try {
      final result = await _sharingService!.removeProjectMember(
        projectPath: projectPath,
        targetUserEmail: email,
      );
      
      setState(() {
        _result = result.when(
          success: (_) => 'Success: Member removed successfully',
          failure: (failure) => 'Error: ${failure.message}',
        );
      });
    } catch (e) {
      setState(() {
        _result = 'Exception: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testExitShare() async {
    if (_sharingService == null) return;
    
    final projectPath = _projectPathController.text.trim();
    
    if (projectPath.isEmpty) {
      setState(() {
        _result = 'Error: Project path is required';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    try {
      final result = await _sharingService!.exitShare(projectPath);
      
      setState(() {
        _result = result.when(
          success: (_) => 'Success: Exited share successfully',
          failure: (failure) => 'Error: ${failure.message}',
        );
      });
    } catch (e) {
      setState(() {
        _result = 'Exception: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Extract project path (UUID) from calendar path
  String _extractProjectPathFromCalendarPath(String calendarPath) {
    // Calendar paths typically look like: /calendars/username/uuid/
    // Extract the UUID part
    final segments = calendarPath.split('/').where((s) => s.isNotEmpty).toList();
    
    // Look for a UUID pattern (8-4-4-4-12 format)
    for (final segment in segments) {
      if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(segment)) {
        return segment;
      }
    }
    
    return '';
  }
} 