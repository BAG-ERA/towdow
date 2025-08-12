// Custom CalDAV connection dialog
// Allows users to configure their own CalDAV server connection

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/caldav_account.dart';
import '../../../../data/services/caldav/caldav_discovery_service.dart';
import '../../../../data/providers/providers.dart';
import 'package:uuid/uuid.dart';
import '../../../widgets/utils/enhanced_text_field.dart';

class CustomCaldavDialog extends ConsumerStatefulWidget {
  const CustomCaldavDialog({super.key});

  @override
  ConsumerState<CustomCaldavDialog> createState() => _CustomCaldavDialogState();
}

class _CustomCaldavDialogState extends ConsumerState<CustomCaldavDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Copy email to username when email changes
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && _usernameController.text.trim().isEmpty) {
      _usernameController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_rounded),
          SizedBox(width: 8),
          Text('Custom CalDAV Server'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 500 ? 450 : MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Connect to your own CalDAV server. Make sure your server supports CalDAV (RFC 4791).',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // User Information Section
              Text(
                'User Information',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              // Responsive First Name and Last Name layout
              Builder(
                builder: (context) {
                  // Use MediaQuery to determine if we have enough space for side-by-side layout
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isWideEnough = screenWidth > 600; // If screen > 600px, use row layout
                  
                  if (isWideEnough) {
                    return Row(
                      children: [
                        Expanded(
                          child: EnhancedTextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              hintText: 'John',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: EnhancedTextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              hintText: 'Doe',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            hintText: 'John',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.givenName],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            hintText: 'Doe',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.familyName],
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Email field (mandatory)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'john.doe@example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 24),
              
              // Server Configuration Section
              Text(
                'Server Configuration',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              // Server URL field
              TextFormField(
                controller: _serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL *',
                  hintText: 'https://example.com/caldav/',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a server URL';
                  }
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || !uri.hasAbsolutePath) {
                    return 'Please enter a valid URL';
                  }
                  if (!value.trim().startsWith('http')) {
                    return 'URL must start with http:// or https://';
                  }
                  return null;
                },
                keyboardType: TextInputType.url,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              
              // Username field
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username *',
                  hintText: 'your-username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 16),
              
              // Password field
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  hintText: 'your-password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _connectToServer,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)!.connect),
        ),
      ],
    );
  }

  Future<void> _connectToServer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create account
      final account = CaldavAccount(
        id: const Uuid().v4(),
        providerType: 'custom',
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim().isEmpty ? null : _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      // Test the CalDAV connection
      final discovery = CalDavDiscoveryService(account: account);
      final testResult = await discovery.testConnection();
      
      await testResult.when(
        success: (capabilities) async {
          // Update account with discovered principal and calendarHome
          final updatedAccount = account.copyWith(
            principal: capabilities.principal,
            calendarHome: capabilities.calendarHome,
          );
          
          // Save the account
          final accountRepository = ref.read(accountRepositoryProvider);
          await accountRepository.save(updatedAccount);
          
          // Connection successful, redirect to today screen
          if (mounted) {
            // Close this dialog first
            Navigator.of(context).pop();
            
            // Invalidate the account status provider to ensure router recognizes the account
            ref.invalidate(hasActiveAccountProvider);
            
            // Navigate to projects screen on first connection (delay to avoid router race)
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                GoRouter.of(context).go('/projects');
              }
            });
          }
        },
        failure: (failure) {
          setState(() {
            _errorMessage = 'Connection failed: ${failure.message}';
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 
