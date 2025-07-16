// Task List Toolbar for task management across different screens
// Provides search functionality and task creation button
// Responsive design adapts to mobile and desktop layouts

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers.dart';
import 'buttons/create_task_button.dart';

class TaskListToolbar extends ConsumerStatefulWidget {
  final String projectPath;
  final String? projectName;
  
  const TaskListToolbar({
    super.key,
    required this.projectPath,
    this.projectName,
  });

  @override
  ConsumerState<TaskListToolbar> createState() => _TaskListToolbarState();
}

class _TaskListToolbarState extends ConsumerState<TaskListToolbar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    
    // Listen to search controller changes for debounced search
    _searchController.addListener(() {
      // Cancel previous timer
      _debounceTimer?.cancel();
      
      // Create new timer for debounced search
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          ref.read(projectSearchQueryProvider(widget.projectPath).notifier)
              .state = _searchController.text;
        }
      });
    });
  }

  @override
  void didUpdateWidget(TaskListToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If project changed, sync controller with new project's search state
    if (oldWidget.projectPath != widget.projectPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final searchQuery = ref.read(projectSearchQueryProvider(widget.projectPath));
          if (_searchController.text != searchQuery) {
            _searchController.text = searchQuery;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchQuery = ref.watch(projectSearchQueryProvider(widget.projectPath));
    final isSearchActive = searchQuery.trim().isNotEmpty;
    
    // Sync search controller with search state
    if (_searchController.text != searchQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchController.text = searchQuery;
        }
      });
    }
    
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(25),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          
                  if (isDesktop) {
          return _buildDesktopLayout(context, searchQuery, isSearchActive);
        } else {
          return _buildMobileLayout(context, searchQuery, isSearchActive);
        }
        },
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    String searchQuery,
    bool isSearchActive,
  ) {
    return Row(
      children: [
        // Search section
        Expanded(
          child: _buildSearchBar(context, searchQuery, isSearchActive),
        ),
        
        const SizedBox(width: 16),
        
        // Create task button
        CreateTaskButton.compact(
          projectCalendarUid: widget.projectPath,
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    String searchQuery,
    bool isSearchActive,
  ) {
    if (_isSearchExpanded) {
      return Row(
        children: [
          Expanded(
            child: _buildSearchBar(context, searchQuery, isSearchActive),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSearchExpanded = false;
              });
              _searchController.clear();
              ref.read(projectSearchQueryProvider(widget.projectPath).notifier).state = '';
            },
          ),
        ],
      );
    }
    
    return Row(
      children: [
        // Search button with icon and text stacked left
        InkWell(
          onTap: () {
            setState(() {
              _isSearchExpanded = true;
            });
            _searchFocusNode.requestFocus();
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Search',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Spacer to push create task button to the right
        const Spacer(),
        
        // Create task button
        CreateTaskButton.compact(
          projectCalendarUid: widget.projectPath,
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    String searchQuery,
    bool isSearchActive,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search tasks...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: isSearchActive
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(projectSearchQueryProvider(widget.projectPath).notifier).state = '';
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
} 