import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../providers/inventory_provider.dart';
import '../providers/app_provider.dart';
import '../services/inventory_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_tag.dart';
import '../widgets/empty_state.dart';
import '../utils/date_util.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();
  final InventoryService _inventoryService = InventoryService();

  List<String> _categories = [];
  String? _selectedCategory;
  bool _showOfflineIndicator = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCategories();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<InventoryProvider>();
    await Future.wait([
      provider.loadStatistics(),
      provider.loadItems(refresh: true),
    ]);
    final appProvider = context.read<AppProvider>();
    if (mounted) {
      setState(() {
        _showOfflineIndicator = !appProvider.isOnline;
      });
    }
  }

  Future<void> _loadCategories() async {
    final categories = await _inventoryService.getWasteCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
      });
    }
  }

  Future<void> _onRefresh() async {
    try {
      final provider = context.read<InventoryProvider>();
      await provider.refresh(forceRefresh: true);
      await provider.loadStatistics();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  Future<void> _onLoading() async {
    try {
      await context.read<InventoryProvider>().loadItems();
      _refreshController.loadComplete();
    } catch (e) {
      _refreshController.loadComplete();
    }
  }

  void _onSearch() {
    final provider = context.read<InventoryProvider>();
    provider.setSearchParams(
      keyword: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      wasteCategory: _selectedCategory,
    );
    provider.loadItems(refresh: true);
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
    });
    final provider = context.read<InventoryProvider>();
    provider.setSearchParams(
      keyword: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      wasteCategory: category,
    );
    provider.loadItems(refresh: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _selectedCategory = null;
    });
    final provider = context.read<InventoryProvider>();
    provider.clearSearch();
    provider.loadItems(refresh: true);
  }

  StatusTag _buildWarnStatusTag(int? warnStatus) {
    switch (warnStatus) {
      case 2:
        return StatusTag.danger('已超期');
      case 1:
        return StatusTag.warning('近超期');
      case 3:
        return StatusTag.danger('超量');
      default:
        return StatusTag.success('正常');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('库存监控'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ToastUtil.showInfo('正在同步...');
              await context.read<InventoryProvider>().syncData();
              await _loadCategories();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOfflineIndicator(),
          Expanded(
            child: SmartRefresher(
              controller: _refreshController,
              onRefresh: _onRefresh,
              onLoading: _onLoading,
              enablePullUp: true,
              header: WaterDropHeader(
                waterDropColor: AppTheme.primaryColor,
              ),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildStatBar()),
                  SliverToBoxAdapter(child: _buildSearchBar()),
                  _buildInventoryList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    if (!_showOfflineIndicator) return const SizedBox.shrink();
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        if (appProvider.isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _showOfflineIndicator = false);
          });
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          color: AppTheme.warningColor.withOpacity(0.15),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 16.r, color: AppTheme.warningColor),
              SizedBox(width: 8.w),
              Text(
                '离线模式 - 显示本地缓存数据',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.warningColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBar() {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final stats = provider.statistics;
        final totalWeight = (stats?['total_weight'] as num?)?.toDouble() ?? 0.0;
        final containerCount = stats?['container_count'] as int? ?? 0;
        final nearExpiryCount = stats?['near_expiry_count'] as int? ?? 0;
        final overdueCount = stats?['overdue_count'] as int? ?? 0;

        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard.primary(
                      title: '总库存量',
                      value: totalWeight.toStringAsFixed(1),
                      unit: 'kg',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: StatCard.success(
                      title: '容器数量',
                      value: '$containerCount',
                      unit: '个',
                      icon: Icons.inventory_outlined,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: StatCard.warning(
                      title: '近超期',
                      value: '$nearExpiryCount',
                      unit: '项',
                      icon: Icons.warning_amber_outlined,
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.warning);
                      },
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: StatCard.danger(
                      title: '已超期',
                      value: '$overdueCount',
                      unit: '项',
                      icon: Icons.error_outline,
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.warning);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _onSearch(),
                  style: AppTextStyle.body,
                  decoration: InputDecoration(
                    hintText: '搜索废物代码/名称',
                    prefixIcon: Icon(Icons.search, size: 20.r),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 20.r),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch();
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              SizedBox(
                height: 44.h,
                child: CommonButton(
                  text: '搜索',
                  onPressed: _onSearch,
                  size: ButtonSize.small,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 36.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryChip(null, '全部'),
                  ..._categories.map((c) => _buildCategoryChip(c, c)).toList(),
                ],
              ),
            ),
          if (_selectedCategory != null || _searchController.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _clearSearch,
                  child: Text('清除筛选', style: TextStyle(fontSize: 13.sp)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 13.sp)),
        selected: isSelected,
        onSelected: (_) => _onCategoryChanged(value),
        selectedColor: AppTheme.primaryColor.withOpacity(0.15),
        backgroundColor: AppTheme.bgCard,
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
        ),
      ),
    );
  }

  Widget _buildInventoryList() {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.items.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.items.isEmpty) {
          return SliverFillRemaining(
            child: EmptyState(
              message: '暂无库存数据',
              icon: Icons.inventory_2_outlined,
              buttonText: '刷新',
              onButtonPressed: () => provider.refresh(),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = provider.items[index];
                return _buildInventoryItem(item);
              },
              childCount: provider.items.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    final wasteCode = item['waste_code'] as String? ?? '';
    final wasteName = item['waste_name'] as String? ?? '未知危废';
    final weight = (item['weight'] as num?)?.toDouble() ?? 0.0;
    final storageDays = item['storage_days'] as int? ?? 0;
    final storageLocation = item['storage_location'] as String? ?? '';
    final warnStatus = item['warn_status'] as int?;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.containerDetail,
          arguments: item,
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    wasteName,
                    style: AppTextStyle.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildWarnStatusTag(warnStatus),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                _buildInfoItem(Icons.code, wasteCode),
                SizedBox(width: 16.w),
                _buildInfoItem(Icons.scale, '${weight.toStringAsFixed(2)} kg'),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                _buildInfoItem(Icons.schedule, '存储$storageDays天'),
                if (storageLocation.isNotEmpty) ...[
                  SizedBox(width: 16.w),
                  _buildInfoItem(Icons.location_on_outlined, storageLocation),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.r, color: AppTheme.textSecondary),
        SizedBox(width: 4.w),
        Text(
          text,
          style: AppTextStyle.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
