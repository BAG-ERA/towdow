import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownEditor extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? labelText;
  final String? hintText;

  const MarkdownEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.labelText,
    this.hintText,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _controller;
  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Editor/Preview toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.labelText ?? 'Description',
              style: theme.textTheme.titleMedium,
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.edit),
                  label: Text('Edit'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.preview),
                  label: Text('Preview'),
                ),
              ],
              selected: {_isPreviewMode},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _isPreviewMode = newSelection.first;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Editor or Preview
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isPreviewMode
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _controller.text.isEmpty
                        ? Text(
                            widget.hintText ?? 'No description',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : MarkdownBody(
                            data: _controller.text,
                            styleSheet: MarkdownStyleSheet(
                              p: theme.textTheme.bodyMedium,
                              h1: theme.textTheme.headlineMedium,
                              h2: theme.textTheme.headlineSmall,
                              h3: theme.textTheme.titleLarge,
                              h4: theme.textTheme.titleMedium,
                              h5: theme.textTheme.titleSmall,
                              h6: theme.textTheme.bodyLarge,
                              blockquote: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              code: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                backgroundColor: theme.colorScheme.surfaceVariant,
                              ),
                            ),
                          ),
                  ),
                )
              : TextField(
                  controller: _controller,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Enter description (supports markdown)',
                    border: const OutlineInputBorder(),
                    helperText: 'Supports Markdown formatting',
                    helperMaxLines: 2,
                  ),
                  onChanged: widget.onChanged,
                ),
        ),
        if (!_isPreviewMode) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildMarkdownButton('**Bold**', '**'),
              _buildMarkdownButton('*Italic*', '*'),
              _buildMarkdownButton('# Heading', '# '),
              _buildMarkdownButton('- List', '- '),
              _buildMarkdownButton('1. Numbered', '1. '),
              _buildMarkdownButton('> Quote', '> '),
              _buildMarkdownButton('`Code`', '`'),
              _buildMarkdownButton('---', '---\n'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMarkdownButton(String label, String markdown) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        final text = _controller.text;
        final selection = _controller.selection;
        
        if (selection.isValid) {
          final before = text.substring(0, selection.start);
          final selected = text.substring(selection.start, selection.end);
          final after = text.substring(selection.end);

          String newText;
          int newCursorPosition;

          if (markdown.endsWith(' ')) {
            // For prefixes like "# " or "- "
            newText = '$before$markdown$selected$after';
            newCursorPosition = selection.start + markdown.length + selected.length;
          } else if (markdown.contains('\n')) {
            // For horizontal rule
            newText = '$before$markdown$selected$after';
            newCursorPosition = selection.start + markdown.length + selected.length;
          } else {
            // For wrapping markdown like **bold** or *italic*
            newText = '$before$markdown$selected$markdown$after';
            newCursorPosition = selection.start + markdown.length + selected.length + markdown.length;
          }

          _controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCursorPosition),
          );
          widget.onChanged(newText);
        }
      },
    );
  }
} 