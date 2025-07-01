// Example chart widget demonstrating chart theme usage
// Shows how to properly use ChartTheme constants throughout the app

import 'package:flutter/material.dart';
import '../../../core/theme/chart_theme.dart';

class ExampleProgressChart extends StatelessWidget {
  const ExampleProgressChart({
    super.key,
    required this.title,
    required this.data,
    this.showLegend = true,
  });

  final String title;
  final Map<String, double> data;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    // Access chart theme using the extension
    final chartTheme = context.chartTheme;
    
    return Container(
      padding: EdgeInsets.all(chartTheme.dimensions.paddingMedium),
      decoration: BoxDecoration(
        color: chartTheme.colors.surface,
        borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
        border: Border.all(
          color: chartTheme.colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart title
          Text(
            title,
            style: chartTheme.typography.titleMedium,
          ),
          SizedBox(height: chartTheme.dimensions.paddingMedium),
          
          // Chart content
          SizedBox(
            height: chartTheme.dimensions.chartMinHeight,
            child: Row(
              children: [
                // Chart bars
                Expanded(
                  flex: 3,
                  child: _buildChart(context, chartTheme),
                ),
                
                // Legend
                if (showLegend) ...[
                  SizedBox(width: chartTheme.dimensions.paddingMedium),
                  Expanded(
                    flex: 1,
                    child: _buildLegend(context, chartTheme),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, ChartTheme chartTheme) {
    final maxValue = data.values.isEmpty ? 1.0 : data.values.reduce((a, b) => a > b ? a : b);
    final colors = chartTheme.colors.chartSeries;
    
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.entries.map((entry) {
              final index = data.keys.toList().indexOf(entry.key);
              final color = colors[index % colors.length];
              final height = (entry.value / maxValue).clamp(0.0, 1.0);
              
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: chartTheme.dimensions.paddingSmall / 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value label
                      Text(
                        '${entry.value.toInt()}',
                        style: chartTheme.typography.labelMedium,
                      ),
                      SizedBox(height: chartTheme.dimensions.paddingSmall),
                      
                      // Bar
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(
                              chartTheme.dimensions.cornerRadius / 2,
                            ),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: height,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    color.withValues(alpha: 0.8),
                                    color,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  chartTheme.dimensions.cornerRadius / 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        SizedBox(height: chartTheme.dimensions.paddingSmall),
        
        // X-axis labels
        Row(
          children: data.keys.map((key) {
            return Expanded(
              child: Text(
                key,
                style: chartTheme.typography.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context, ChartTheme chartTheme) {
    final colors = chartTheme.colors.chartSeries;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legend',
          style: chartTheme.typography.titleSmall,
        ),
        SizedBox(height: chartTheme.dimensions.paddingSmall),
        
        ...data.entries.map((entry) {
          final index = data.keys.toList().indexOf(entry.key);
          final color = colors[index % colors.length];
          
          return Padding(
            padding: EdgeInsets.only(
              bottom: chartTheme.dimensions.legendItemSpacing,
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: chartTheme.dimensions.paddingSmall),
                Expanded(
                  child: Text(
                    entry.key,
                    style: chartTheme.typography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// Example usage widget showing different chart scenarios
class ChartExamples extends StatelessWidget {
  const ChartExamples({super.key});

  @override
  Widget build(BuildContext context) {
    final chartTheme = context.chartTheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chart Theme Examples'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(chartTheme.dimensions.paddingMedium),
        child: Column(
          children: [
            // Task status chart
            ExampleProgressChart(
              title: 'Task Status Distribution',
              data: const {
                'To Do': 12,
                'In Progress': 8,
                'Completed': 15,
                'Cancelled': 2,
              },
            ),
            
            SizedBox(height: chartTheme.dimensions.paddingLarge),
            
            // Project progress chart
            ExampleProgressChart(
              title: 'Project Progress',
              data: const {
                'Planning': 5,
                'Development': 20,
                'Testing': 12,
                'Deployment': 3,
              },
              showLegend: false,
            ),
            
            SizedBox(height: chartTheme.dimensions.paddingLarge),
            
            // Color palette demonstration
            _buildColorPalette(context, chartTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette(BuildContext context, ChartTheme chartTheme) {
    return Container(
      padding: EdgeInsets.all(chartTheme.dimensions.paddingMedium),
      decoration: BoxDecoration(
        color: chartTheme.colors.surface,
        borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
        border: Border.all(
          color: chartTheme.colors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chart Color Palette',
            style: chartTheme.typography.titleMedium,
          ),
          SizedBox(height: chartTheme.dimensions.paddingMedium),
          
          Wrap(
            spacing: chartTheme.dimensions.paddingSmall,
            runSpacing: chartTheme.dimensions.paddingSmall,
            children: [
              _buildColorSwatch('Primary', chartTheme.colors.primary, chartTheme),
              _buildColorSwatch('Secondary', chartTheme.colors.secondary, chartTheme),
              _buildColorSwatch('Tertiary', chartTheme.colors.tertiary, chartTheme),
              _buildColorSwatch('Success', chartTheme.colors.success, chartTheme),
              _buildColorSwatch('Warning', chartTheme.colors.warning, chartTheme),
              _buildColorSwatch('Error', chartTheme.colors.error, chartTheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(String label, Color color, ChartTheme chartTheme) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        SizedBox(height: chartTheme.dimensions.paddingSmall / 2),
        Text(
          label,
          style: chartTheme.typography.labelSmall,
        ),
      ],
    );
  }
} 