import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_theme.dart';
import '../../view_models/launcher_view_model.dart';
import 'app_card_item.dart';

class AppsDashboardView extends StatelessWidget {
  const AppsDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LauncherViewModel>();
    final apps = vm.filteredApps;

    return Column(
      children: [
        // Filter & Search Toolbar (Tier 3)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              // Search Field
              SizedBox(
                width: 280,
                height: 32,
                child: TextField(
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search suite applications...',
                    prefixIcon: const Icon(Icons.search, size: 15),
                    suffixIcon: vm.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () => vm.setSearchQuery(''),
                          )
                        : null,
                  ),
                  onChanged: vm.setSearchQuery,
                ),
              ),
              const SizedBox(width: 12),

              // Category Filter Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: vm.availableCategories.map((cat) {
                      final isSelected = (vm.selectedCategory ?? 'All') == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cat, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (_) => vm.setSelectedCategory(cat == 'All' ? null : cat),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          selectedColor: AppTheme.primaryAccent.withValues(alpha: 0.25),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryAccent : AppTheme.border,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Toggle to show unreleased / private tools for developer testing
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Developer View',
                    style: TextStyle(
                      fontSize: 11,
                      color: vm.showUnreleased ? AppTheme.primaryAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: vm.showUnreleased,
                    onChanged: (_) => vm.toggleShowUnreleased(),
                    activeThumbColor: AppTheme.primaryAccent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(width: 8),

              IconButton(
                tooltip: 'Check GitHub Releases',
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: vm.isLoading ? null : vm.loadApps,
              ),
            ],
          ),
        ),

        // Primary Grid View (Tier 4)
        Expanded(
          child: vm.isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Discovering public tools on GitHub...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                )
              : apps.isEmpty
                  ? _buildEmptyState(context, vm)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Responsive 2-column or 3-column layout
                        final crossAxisCount = constraints.maxWidth > 1100
                            ? 3
                            : constraints.maxWidth > 750
                                ? 2
                                : 1;

                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: 210,
                          ),
                          itemCount: apps.length,
                          itemBuilder: (context, index) {
                            final app = apps[index];
                            return AppCardItem(
                              app: app,
                              onInstallOrUpdate: () => vm.installOrUpdate(app),
                              onLaunch: () => vm.launch(app),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, LauncherViewModel vm) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.radar,
                size: 56,
                color: AppTheme.primaryAccent.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Public Tools Found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                vm.showUnreleased
                    ? 'No apps matched your search filters.'
                    : 'The Launcher only shows tools with published releases in public repositories under GitHub (Tom-McGuire). As you make repositories public and tag releases (v*), they will automatically appear here!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: vm.loadApps,
                    icon: const Icon(Icons.refresh, size: 15),
                    label: const Text('Refresh Discovery'),
                  ),
                  if (!vm.showUnreleased)
                    OutlinedButton.icon(
                      onPressed: vm.toggleShowUnreleased,
                      icon: const Icon(Icons.developer_mode, size: 15),
                      label: const Text('Show All Suite Catalog'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
