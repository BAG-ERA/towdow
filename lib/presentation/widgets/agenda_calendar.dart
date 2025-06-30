// Calendar agenda widget for displaying tasks by due date
// Shows tasks positioned on calendar days with visual indicators

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import 'task_item/task_item.dart';

class AgendaCalendar extends ConsumerStatefulWidget {
  final List<Task> tasks;
  final Function(Task)? onTaskTap;
  final Function(Task)? onTaskToggle;
  final Function(Task)? onTaskUpdated;
  final Function(Task)? onTaskDeleted;

  const AgendaCalendar({
    super.key,
    required this.tasks,
    this.onTaskTap,
    this.onTaskToggle,
    this.onTaskUpdated,
    this.onTaskDeleted,
  });

  @override
  ConsumerState<AgendaCalendar> createState() => _AgendaCalendarState();
}

class _AgendaCalendarState extends ConsumerState<AgendaCalendar> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Calendar Header
        _buildCalendarHeader(),
        
        // Calendar Grid
        Expanded(
          child: _buildCalendarGrid(),
        ),
        
        // Selected Date Tasks
        if (_selectedDate != null)
          _buildSelectedDateTasks(),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
              });
            },
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              _formatMonthYear(_currentMonth),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
              });
            },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startDate = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday - 1));
    
    return Column(
      children: [
        // Weekday headers
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        
        // Calendar days
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: 42, // 6 weeks × 7 days
            itemBuilder: (context, index) {
              final date = startDate.add(Duration(days: index));
              final tasksForDay = _getTasksForDate(date);
              final isCurrentMonth = date.month == _currentMonth.month;
              final isToday = _isSameDay(date, DateTime.now());
              final isSelected = _selectedDate != null && _isSameDay(date, _selectedDate!);
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate != null && _isSameDay(_selectedDate!, date) 
                        ? null 
                        : date;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                        : null,
                    border: isToday 
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Day number
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${date.day}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentMonth 
                                ? (isToday 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Theme.of(context).colorScheme.onSurface)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      
                      // Task indicators
                      if (tasksForDay.isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Column(
                              children: [
                                ...tasksForDay.take(3).map((task) {
                                  return Container(
                                    height: 3,
                                    margin: const EdgeInsets.only(bottom: 1),
                                    decoration: BoxDecoration(
                                      color: _getTaskColor(task),
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  );
                                }),
                                if (tasksForDay.length > 3)
                                  Text(
                                    '+${tasksForDay.length - 3}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 8,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDateTasks() {
    final tasksForDate = _getTasksForDate(_selectedDate!);
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSelectedDate(_selectedDate!),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasksForDate.length} task${tasksForDate.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasksForDate.isEmpty
                ? Center(
                    child: Text(
                      'No tasks for this date',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tasksForDate.length,
                    itemBuilder: (context, index) {
                      final task = tasksForDate[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TaskItem(
                          task: task,
                          onTap: widget.onTaskTap != null ? () => widget.onTaskTap!(task) : null,
                          onToggleComplete: widget.onTaskToggle != null ? () => widget.onTaskToggle!(task) : null,
                          onTaskUpdated: widget.onTaskUpdated != null ? (updatedTask) => widget.onTaskUpdated!(updatedTask) : null,
                          onTaskDeleted: widget.onTaskDeleted != null ? () => widget.onTaskDeleted!(task) : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }



  List<Task> _getTasksForDate(DateTime date) {
    return widget.tasks.where((task) {
      if (task.due == null) return false;
      return _isSameDay(task.due!, date);
    }).toList();
  }

  Color _getTaskColor(Task task) {
    if (task.status == 'COMPLETED') return Colors.green;
    if (task.due != null && task.due!.isBefore(DateTime.now())) return Colors.red;
    if (task.categories.isNotEmpty) {
      // Simple hash to get consistent colors for categories
      final hash = task.categories.first.hashCode;
      final colors = [Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.pink];
      return colors[hash.abs() % colors.length];
    }
    return Colors.grey;
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatSelectedDate(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
} 
