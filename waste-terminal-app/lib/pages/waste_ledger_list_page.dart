import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../providers/waste_ledger_provider.dart';
import '../models/waste_ledger.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_tag.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_widget.dart';
import '../utils/date_util.dart';
import '../utils/toast_util.dart';

class WasteLedgerListPage extends StatefulWidget {
  const WasteLedgerListPage({super.key});

  @override
  State<WasteLedgerListPage> createState() => _WasteLedgerListPageState();
}

class _WasteLedgerListPageState extends State<WasteLedgerListPage> {
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();

  final List<String> _ledgerTypes = ['全部', '月报', '年报'];
  String? _selectedLedgerType;

  final List<String> _generateStatuses = ['全部', '待生成', '生成中', '已生成', '生成失败'];
  String? _selectedGenerateStatus;

  final List<String> _reportStatuses = ['全部', '待上报', '上报中', '已上报', '上报失败', '无需上报'];
  String? _selectedReportStatus;

  int? _selectedYear;
  int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await context.read<WasteLedgerProvider>().loadItems(refresh: true);
  }

  Future<void> _onRefresh() async {
    try {
      await context.read<WasteLedgerProvider>().refresh();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  Future<void> _onLoading() async {
    try {
      await context.read<WasteLedgerProvider>().loadItems();
      _refreshController.loadComplete();
    } catch (e) {
      _refreshController.loadComplete();
    }
  }

  void _onSearch() {
    final provider = context.read<WasteLedgerProvider>();
    provider.setSearchParams(
      keyword: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      ledgerType: _selectedLedgerType == '全部' || _selectedLedgerType == null
          ? null
          : _selectedLedgerType == '月报'
              ? 'MONTHLY'
              : 'YEARLY',
      generateStatus: _selectedGenerateStatus == '全部' || _selectedGenerateStatus == null
          ? null
          : _generateStatuses.indexOf(_selectedGenerateStatus!) - 1,
      reportStatus: _selectedReportStatus == '全部' || _selectedReportStatus == null
          ? null
          : _reportStatuses.indexOf(_selectedReportStatus!) - 1,
      periodYear: _selectedYear,
      periodMonth: _selectedMonth,
    );
    provider.loadItems(refresh: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _selectedLedgerType = null;
      _selectedGenerateStatus = null;
      _selectedReportStatus = null;
      _selectedYear = null;
      _selectedMonth = null;
    });
    final provider = context.read<WasteLedgerProvider>();
    provider.clearSearch();
    provider.loadItems(refresh: true);
  }

  Future<void> _showGenerateDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => const _GenerateLedgerDialog(),
    ).then((result) {
      if (result == true) {
        _onRefresh();
      }
    });
  }

  void _onItemTap(WasteLedger ledger) {
    Navigator.pushNamed(
      context,
      AppRoutes.wasteLedgerDetail,
      arguments: ledger.id,
    );
  }

  StatusTag _buildGenerateStatusTag(int? status) {
    switch (status) {
      case 0:
        return StatusTag.info('待生成');
      case 1:
        return StatusTag.warning('生成中');
      case 2:
        return StatusTag.success('已生成');
      case 3:
        return StatusTag.danger('生成失败');
      default:
        return StatusTag.info('未知');
    }
  }

  StatusTag _buildReportStatusTag(int? status) {
    switch (status) {
      case 0:
        return StatusTag.info('待上报');
      case 1:
        return StatusTag.warning('上报中');
      case 2:
        return StatusTag.success('已上报');
      case 3:
        return StatusTag.danger('上报失败');
      case 4:
        return StatusTag.info('无需上报');
      default:
        return StatusTag.info('未知');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('电子台账'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showGenerateDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchArea(),
          _buildStatsArea(),
          Expanded(
            child: Consumer<WasteLedgerProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.items.isEmpty) {
                  return const LoadingWidget();
                }

                if (provider.items.isEmpty) {
                  return EmptyState(
                    message: '暂无台账数据',
                    onRefresh: _onRefresh,
                  );
                }

                return SmartRefresher(
                  controller: _refreshController,
                  enablePullDown: true,
                  enablePullUp: provider.hasMore,
                  onRefresh: _onRefresh,
                  onLoading: _onLoading,
                  child: ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: provider.items.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final ledger = provider.items[index];
                      return _buildLedgerCard(ledger);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchArea() {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索台账编号',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  ),
                  onSubmitted: (_) => _onSearch(),
                ),
              ),
              SizedBox(width: 12.w),
              ElevatedButton(
                onPressed: _onSearch,
                child: const Text('搜索'),
              ),
              SizedBox(width: 8.w),
              TextButton(
                onPressed: _clearSearch,
                child: const Text('重置'),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              _buildFilterDropdown(
                '台账类型',
                _ledgerTypes,
                _selectedLedgerType,
                (value) {
                  setState(() => _selectedLedgerType = value);
                },
              ),
              _buildFilterDropdown(
                '生成状态',
                _generateStatuses,
                _selectedGenerateStatus,
                (value) {
                  setState(() => _selectedGenerateStatus = value);
                },
              ),
              _buildFilterDropdown(
                '上报状态',
                _reportStatuses,
                _selectedReportStatus,
                (value) {
                  setState(() => _selectedReportStatus = value);
                },
              ),
              _buildYearPicker(),
              _buildMonthPicker(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    List<String> options,
    String? selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      width: 150.w,
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(label, style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
          value: selectedValue,
          isExpanded: true,
          items: options
              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14.sp))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildYearPicker() {
    final now = DateTime.now();
    final years = List.generate(5, (index) => now.year - index);

    return Container(
      width: 120.w,
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          hint: Text('年份', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
          value: _selectedYear,
          isExpanded: true,
          items: years
              .map((e) => DropdownMenuItem(value: e, child: Text('$e年', style: TextStyle(fontSize: 14.sp))))
              .toList(),
          onChanged: (value) {
            setState(() => _selectedYear = value);
          },
        ),
      ),
    );
  }

  Widget _buildMonthPicker() {
    final months = List.generate(12, (index) => index + 1);

    return Container(
      width: 120.w,
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          hint: Text('月份', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
          value: _selectedMonth,
          isExpanded: true,
          items: months
              .map((e) => DropdownMenuItem(value: e, child: Text('$e月', style: TextStyle(fontSize: 14.sp))))
              .toList(),
          onChanged: (value) {
            setState(() => _selectedMonth = value);
          },
        ),
      ),
    );
  }

  Widget _buildStatsArea() {
    return Consumer<WasteLedgerProvider>(
      builder: (context, provider, child) {
        int pendingGenerate = 0;
        int generated = 0;
        int pendingReport = 0;
        int reported = 0;

        for (var item in provider.items) {
          if (item.generateStatus == 0 || item.generateStatus == 1) {
            pendingGenerate++;
          } else if (item.generateStatus == 2) {
            generated++;
          }
          if (item.reportStatus == 0 || item.reportStatus == 1 || item.reportStatus == 3) {
            pendingReport++;
          } else if (item.reportStatus == 2) {
            reported++;
          }
        }

        return Container(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Expanded(
                child: StatCard(
                  title: '待生成',
                  value: '$pendingGenerate',
                  color: AppTheme.infoColor,
                  icon: Icons.description,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: StatCard(
                  title: '已生成',
                  value: '$generated',
                  color: AppTheme.successColor,
                  icon: Icons.check_circle,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: StatCard(
                  title: '待上报',
                  value: '$pendingReport',
                  color: AppTheme.warningColor,
                  icon: Icons.upload,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: StatCard(
                  title: '已上报',
                  value: '$reported',
                  color: AppTheme.primaryColor,
                  icon: Icons.cloud_done,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLedgerCard(WasteLedger ledger) {
    return InkWell(
      onTap: () => _onItemTap(ledger),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
                    ledger.periodText,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                _buildGenerateStatusTag(ledger.generateStatus),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Text(
                  ledger.ledgerNo ?? '',
                  style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary),
                ),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    ledger.ledgerTypeText,
                    style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('入库', '${ledger.totalInCount ?? 0}笔', '${(ledger.totalInWeight ?? 0).toStringAsFixed(2)}kg'),
                ),
                Container(width: 1, height: 40.h, color: Colors.grey.shade200),
                Expanded(
                  child: _buildInfoItem('出库', '${ledger.totalOutCount ?? 0}笔', '${(ledger.totalOutWeight ?? 0).toStringAsFixed(2)}kg'),
                ),
                Container(width: 1, height: 40.h, color: Colors.grey.shade200),
                Expanded(
                  child: _buildInfoItem('期末库存', '', '${(ledger.endInventoryWeight ?? 0).toStringAsFixed(2)}kg'),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildReportStatusTag(ledger.reportStatus),
                    SizedBox(width: 12.w),
                    if (ledger.platformLedgerNo != null)
                      Text(
                        '平台编号: ${ledger.platformLedgerNo}',
                        style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
                Text(
                  DateUtil.formatDateTime(ledger.createTime),
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.textHint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String count, String weight) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
        ),
        SizedBox(height: 4.h),
        if (count.isNotEmpty)
          Text(
            count,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        Text(
          weight,
          style: TextStyle(
            fontSize: 14.sp,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GenerateLedgerDialog extends StatefulWidget {
  const _GenerateLedgerDialog();

  @override
  State<_GenerateLedgerDialog> createState() => _GenerateLedgerDialogState();
}

class _GenerateLedgerDialogState extends State<_GenerateLedgerDialog> {
  final TextEditingController _remarkController = TextEditingController();
  String _ledgerType = 'MONTHLY';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final provider = context.read<WasteLedgerProvider>();
    final result = await provider.generateLedger(
      ledgerType: _ledgerType,
      periodYear: _selectedYear,
      periodMonth: _ledgerType == 'MONTHLY' ? _selectedMonth : null,
      remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
    );

    if (result != null && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List.generate(5, (index) => now.year - index);
    final months = List.generate(12, (index) => index + 1);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '生成台账',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            _buildTypeSelector(),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: '年份',
                    value: _selectedYear,
                    items: years,
                    onChanged: (value) {
                      setState(() => _selectedYear = value!);
                    },
                    labelBuilder: (value) => '$value年',
                  ),
                ),
                if (_ledgerType == 'MONTHLY') ...[
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildDropdown(
                      label: '月份',
                      value: _selectedMonth,
                      items: months,
                      onChanged: (value) {
                        setState(() => _selectedMonth = value!);
                      },
                      labelBuilder: (value) => '$value月',
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 20.h),
            TextField(
              controller: _remarkController,
              decoration: InputDecoration(
                labelText: '备注',
                hintText: '请输入备注（可选）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: _generate,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  '生成台账',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '台账类型',
          style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _ledgerType = 'MONTHLY'),
                child: Container(
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: _ledgerType == 'MONTHLY' ? AppTheme.primaryColor : Colors.white,
                    border: Border.all(
                      color: _ledgerType == 'MONTHLY' ? AppTheme.primaryColor : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: Text(
                      '月报',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: _ledgerType == 'MONTHLY' ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _ledgerType = 'YEARLY'),
                child: Container(
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: _ledgerType == 'YEARLY' ? AppTheme.primaryColor : Colors.white,
                    border: Border.all(
                      color: _ledgerType == 'YEARLY' ? AppTheme.primaryColor : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: Text(
                      '年报',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: _ledgerType == 'YEARLY' ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) labelBuilder,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(label, style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(labelBuilder(e), style: TextStyle(fontSize: 14.sp)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
