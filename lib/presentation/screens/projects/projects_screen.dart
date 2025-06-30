/// Projects screen showing all project portfolios
/// Allows users to view, create, and manage their project portfolios

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar
          const SliverAppBar(
            title: Text('Project Portfolios'),
            floating: true,
            automaticallyImplyLeading: false,
          ),
          
          // Main content
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Empty state
                _buildEmptyState(),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateProjectDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Portfolio'),
      ),
    );
  }

  /// Build empty state when no projects exist
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 64),
          
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.work_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Title
          Text(
            'No Project Portfolios Yet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Project portfolios help you organize your tasks and projects. Create your first portfolio to get started.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Create button
          ElevatedButton.icon(
            onPressed: () => _showCreateProjectDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Your First Portfolio'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
          
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  /// Show create project dialog
  void _showCreateProjectDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Project Portfolio'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Portfolio Name',
                  hintText: 'Enter portfolio name',
                  prefixIcon: Icon(Icons.work_rounded),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Enter portfolio description',
                  prefixIcon: Icon(Icons.description_rounded),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                _createProject(name, descriptionController.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Create a new project portfolio
  void _createProject(String name, String description) {
    // TODO: Implement project creation logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Project "$name" will be created soon!'),
        backgroundColor: Colors.green,
      ),
    );
  }
} 
