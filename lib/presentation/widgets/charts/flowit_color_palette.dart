// FlowIt Color Palette Showcase Widget
// Displays the complete FlowIt brand color system organized by color families

import 'package:flutter/material.dart';
import '../../../core/theme/chart_theme.dart';

class FlowItColorPalette extends StatelessWidget {
  const FlowItColorPalette({super.key});

  @override
  Widget build(BuildContext context) {
    final chartTheme = context.chartTheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowIt Color Palette'),
        backgroundColor: FlowItColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(chartTheme.dimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with primary color showcase
            Container(
              padding: EdgeInsets.all(chartTheme.dimensions.paddingLarge),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [FlowItColors.primary, FlowItColors.blueLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FlowIt Brand Colors',
                    style: chartTheme.typography.titleLarge.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                    ),
                  ),
                  SizedBox(height: chartTheme.dimensions.paddingSmall),
                  Text(
                    'Complete color system for consistent UI design',
                    style: chartTheme.typography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: chartTheme.dimensions.paddingLarge),
            
            // Color families
            _buildColorFamily(
              context,
              chartTheme,
              'Blue Family (Primary)',
              [
                ColorInfo('Blue Dark', FlowItColors.blueDark, '#192440'),
                ColorInfo('Blue', FlowItColors.blue, '#223A7B'),
                ColorInfo('Blue Medium', FlowItColors.blueMedium, '#0068B3', isPrimary: true),
                ColorInfo('Blue Light', FlowItColors.blueLight, '#85CAED'),
              ],
            ),
            
            _buildColorFamily(
              context,
              chartTheme,
              'Water Green Family',
              [
                ColorInfo('Water Green', FlowItColors.waterGreen, '#6CBD97'),
                ColorInfo('Water Green Light', FlowItColors.waterGreenLight, '#D3E6C7'),
              ],
            ),
            
            _buildColorFamily(
              context,
              chartTheme,
              'Violet Family',
              [
                ColorInfo('Violet Dark', FlowItColors.violetDark, '#463077'),
                ColorInfo('Violet', FlowItColors.violet, '#6A5195'),
                ColorInfo('Violet Light', FlowItColors.violetLight, '#8C89C2'),
              ],
            ),
            
            _buildColorFamily(
              context,
              chartTheme,
              'Green Family',
              [
                ColorInfo('Green Apple', FlowItColors.greenApple, '#96B522'),
                ColorInfo('Green Anis', FlowItColors.greenAnis, '#C5C741'),
                ColorInfo('Green Light', FlowItColors.greenLight, '#D8D596'),
              ],
            ),
            
            _buildColorFamily(
              context,
              chartTheme,
              'Red/Pink Family',
              [
                ColorInfo('Pink', FlowItColors.pink, '#E83947'),
                ColorInfo('Pink Light', FlowItColors.pinkLight, '#EF7E6F'),
                ColorInfo('Coral', FlowItColors.coral, '#F6A66D'),
              ],
            ),
            
            _buildColorFamily(
              context,
              chartTheme,
              'Yellow Family',
              [
                ColorInfo('Yellow Dark', FlowItColors.yellowDark, '#F59E00'),
                ColorInfo('Yellow', FlowItColors.yellow, '#FDC61E'),
                ColorInfo('Yellow Light', FlowItColors.yellowLight, '#FFE37E'),
              ],
            ),
            
            _buildColorFamily(
              context,
              chartTheme,
              'Neutral Colors',
              [
                ColorInfo('Surface', FlowItColors.surface, '#FFFFFF'),
                ColorInfo('Surface Dark', FlowItColors.surfaceDark, '#121212'),
                ColorInfo('Separator', FlowItColors.separator, '#E0E0E0'),
                ColorInfo('Separator Dark', FlowItColors.separatorDark, '#2C2C2C'),
              ],
            ),
            
            SizedBox(height: chartTheme.dimensions.paddingLarge),
            
            // Usage examples
            _buildUsageExamples(context, chartTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildColorFamily(
    BuildContext context,
    ChartTheme chartTheme,
    String familyName,
    List<ColorInfo> colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          familyName,
          style: chartTheme.typography.titleMedium,
        ),
        SizedBox(height: chartTheme.dimensions.paddingMedium),
        
        Container(
          padding: EdgeInsets.all(chartTheme.dimensions.paddingMedium),
          decoration: BoxDecoration(
            color: chartTheme.colors.surface,
            borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
            border: Border.all(
              color: chartTheme.colors.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Wrap(
            spacing: chartTheme.dimensions.paddingMedium,
            runSpacing: chartTheme.dimensions.paddingMedium,
            children: colors.map((colorInfo) => _buildColorSwatch(
              context,
              chartTheme,
              colorInfo,
            )).toList(),
          ),
        ),
        
        SizedBox(height: chartTheme.dimensions.paddingLarge),
      ],
    );
  }

  Widget _buildColorSwatch(
    BuildContext context,
    ChartTheme chartTheme,
    ColorInfo colorInfo,
  ) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: colorInfo.isPrimary 
            ? Border.all(color: FlowItColors.primary, width: 2)
            : null,
      ),
      child: Column(
        children: [
          // Color circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colorInfo.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: chartTheme.colors.outline.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: colorInfo.isPrimary
                ? const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
          
          SizedBox(height: chartTheme.dimensions.paddingSmall),
          
          // Color name
          Text(
            colorInfo.name,
            style: chartTheme.typography.labelMedium.copyWith(
              fontWeight: colorInfo.isPrimary ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          
          // Hex code
          Text(
            colorInfo.hexCode,
            style: chartTheme.typography.labelSmall.copyWith(
              color: chartTheme.colors.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUsageExamples(BuildContext context, ChartTheme chartTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Usage Examples',
          style: chartTheme.typography.titleMedium,
        ),
        SizedBox(height: chartTheme.dimensions.paddingMedium),
        
        // Task status colors
        _buildUsageExample(
          context,
          chartTheme,
          'Task Status Colors',
          [
            UsageInfo('Completed', FlowItColors.waterGreen, Icons.check_circle),
            UsageInfo('In Progress', FlowItColors.yellowDark, Icons.timelapse),
            UsageInfo('To Do', FlowItColors.primary, Icons.radio_button_unchecked),
            UsageInfo('Cancelled', FlowItColors.pink, Icons.cancel),
          ],
        ),
        
        SizedBox(height: chartTheme.dimensions.paddingMedium),
        
        // Chart series colors
        _buildUsageExample(
          context,
          chartTheme,
          'Chart Series Colors',
          chartTheme.colors.chartSeries.take(6).map((color) {
            final index = chartTheme.colors.chartSeries.indexOf(color);
            return UsageInfo('Series ${index + 1}', color, Icons.show_chart);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUsageExample(
    BuildContext context,
    ChartTheme chartTheme,
    String title,
    List<UsageInfo> items,
  ) {
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
            title,
            style: chartTheme.typography.titleSmall,
          ),
          SizedBox(height: chartTheme.dimensions.paddingMedium),
          
          Wrap(
            spacing: chartTheme.dimensions.paddingMedium,
            runSpacing: chartTheme.dimensions.paddingSmall,
            children: items.map((item) => Container(
              padding: EdgeInsets.symmetric(
                horizontal: chartTheme.dimensions.paddingMedium,
                vertical: chartTheme.dimensions.paddingSmall,
              ),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: item.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    color: item.color,
                    size: 16,
                  ),
                  SizedBox(width: chartTheme.dimensions.paddingSmall),
                  Text(
                    item.label,
                    style: chartTheme.typography.labelMedium.copyWith(
                      color: item.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class ColorInfo {
  final String name;
  final Color color;
  final String hexCode;
  final bool isPrimary;

  const ColorInfo(this.name, this.color, this.hexCode, {this.isPrimary = false});
}

class UsageInfo {
  final String label;
  final Color color;
  final IconData icon;

  const UsageInfo(this.label, this.color, this.icon);
} 