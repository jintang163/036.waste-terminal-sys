import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../config/app_theme.dart';
import '../config/app_routes.dart';
import '../services/inventory_check_service.dart';
import '../services/inventory_service.dart';
import '../widgets/status_tag.dart';
import '../widgets/common_button.dart';
import '../widgets/empty_state.dart';
import '../utils/toast_util.dart';
import '../utils/uuid_util.dart';
import '../utils/date_util.dart';

class InventoryCheckPage extends StatefulWidget {
  const InventoryCheckPage({super.key});

  @override
  State<InventoryCheckPage> createState() => _InventoryCheckPageState();
}

class _InventoryCheckPageState extends State<InventoryCheckPage> {
  final RefreshController _refreshController = RefreshController();
  final InventoryCheckService _checkService = InventoryCheckService();
  final InventoryService _inventoryService = InventoryService();

  List<Map<String, dynamic>> _checkList = [];
  bool _isLoading = false;

  Map<String, dynamic>? _activeCheck;
  List<Map<String, dynamic>> _scannedDetails = [];
  List<Map<String, dynamic>> _inventoryItems = [];
  Set<String> _scannedCodes = {};
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadCheckList();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckList() async {
    setState(() => _isLoading = true);
    try {
      final list = await _checkService.getCheckList(page: 1, pageSize: 50);
      if (mounted) {
        setState(() {
          _checkList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    try {
      await _loadCheckList();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  Future<void> _createCheck(String checkType) async {
    try {
      final checkNo = UuidUtil.generateCheckNo();
      final check = {
        'check_no': checkNo,
        'check_name': checkType == 'full' ? '全盘' : '抽盘',
        'check_type': checkType,
        'check_date': DateTime.now().toIso8601String(),
        'status': 0,
        'operator_name': '',
      };

      final result = await _checkService.createInventoryCheck(check);
      final inventory = await _inventoryService.getAllInventory();
      setState(() {
        _activeCheck = result;
        _inventoryItems = inventory;
        _scannedDetails = [];
        _scannedCodes = {};
        _isChecking = true;
      });
      ToastUtil.showSuccess('盘点单创建成功');
    } catch (e) {
      ToastUtil.showError('创建盘点单失败');
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新建盘点'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '选择盘点类型',
                style: AppTextStyle.bodySecondary,
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: CommonButton(
                      text: '全盘',
                      type: ButtonType.primary,
                      size: ButtonSize.medium,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _createCheck('full');
                      },
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: CommonButton(
                      text: '抽盘',
                      type: ButtonType.outline,
                      size: ButtonSize.medium,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _createCheck('partial');
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

  Future<void> _scanContainer() async {
    final result = await Navigator.pushNamed(context, AppRoutes.scan);
    if (result == null) return;

    String? containerCode;
    if (result is String) {
      containerCode = result;
      if (containerCode.startsWith('WC:')) {
        final parts = containerCode.split(':');
        if (parts.length >= 2) containerCode = parts[1];
      }
    }

    if (containerCode == null || containerCode.isEmpty) return;

    if (_scannedCodes.contains(containerCode)) {
      ToastUtil.showShort('该容器已扫描');
      return;
    }

    setState(() => _scannedCodes.add(containerCode));

    final matchedInventory = _inventoryItems.where(
      (item) => item['container_code'] == containerCode,
    ).toList();

    if (matchedInventory.isNotEmpty) {
      for (var inv in matchedInventory) {
        _scannedDetails.add({
          'check_offline_id': _activeCheck?['offline_id'],
          'container_code': containerCode,
          'waste_code': inv['waste_code'],
          'waste_name': inv['waste_name'],
          'inventory_weight': inv['weight'],
          'check_weight': inv['weight'],
          'diff_weight': 0.0,
          'diff_type': 'match',
          'is_found': 1,
        });
      }
    } else {
      _scannedDetails.add({
        'check_offline_id': _activeCheck?['offline_id'],
        'container_code': containerCode,
        'inventory_weight': 0.0,
        'check_weight': 0.0,
        'diff_weight': 0.0,
        'diff_type': 'extra',
        'is_found': 1,
      });
    }

    setState(() {});
    ToastUtil.showShort('已扫描: $containerCode');
  }

  Map<String, int> _getDiffStats() {
    int matchCount = 0;
    int mismatchCount = 0;
    int extraCount = 0;
    int missingCount = 0;

    for (var detail in _scannedDetails) {
      switch (detail['diff_type']) {
        case 'match':
          matchCount++;
          break;
        case 'mismatch':
          mismatchCount++;
          break;
        case 'extra':
          extraCount++;
          break;
      }
    }

    final scannedCodeSet = _scannedCodes;
    for (var inv in _inventoryItems) {
      final code = inv['container_code'] as String?;
      if (code != null && !scannedCodeSet.contains(code)) {
        missingCount++;
      }
    }

    return {
      'match': matchCount,
      'mismatch': mismatchCount,
      'extra': extraCount,
      'missing': missingCount,
    };
  }

  double _getTotalWeightDiff() {
    double diff = 0.0;
    for (var detail in _scannedDetails) {
      diff += (detail['diff_weight'] as num?)?.toDouble() ?? 0.0;
    }
    return diff;
  }

  Future<void> _finishCheck() async {
    if (_activeCheck == null) return;

    try {
      ToastUtil.showLoading(status: '正在保存...');

      await _checkService.batchAddCheckDetails(_scannedDetails);

      final stats = _getDiffStats();
      final totalWeightDiff = _getTotalWeightDiff();

      final updateData = {
        ..._activeCheck!,
        'total_containers': _inventoryItems.length,
        'checked_containers': _scannedCodes.length,
        'missing_containers': stats['missing'] ?? 0,
        'extra_containers': stats['extra'] ?? 0,
        'diff_weight': totalWeightDiff,
        'status': 1,
        'sync_status': 0,
      };

      await _checkService.updateInventoryCheck(updateData);

      ToastUtil.dismiss();

      setState(() {
        _isChecking = false;
        _activeCheck = null;
        _scannedDetails = [];
        _inventoryItems = [];
        _scannedCodes = {};
      });

      await _loadCheckList();
      ToastUtil.showSuccess('盘点完成，已保存');
    } catch (e) {
      ToastUtil.dismiss();
      ToastUtil.showError('保存盘点结果失败');
    }
  }

  void _showDiffReport() {
    final stats = _getDiffStats();
    final totalWeightDiff = _getTotalWeightDiff();
    final totalContainers = _inventoryItems.length;
    final checkedContainers = _scannedCodes.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.w),
          constraints: BoxConstraints(maxHeight: 0.7.sh),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text('盘点差异报告', style: AppTextStyle.title),
              SizedBox(height: 16.h),
              _buildReportRow('总容器数', '$totalContainers'),
              _buildReportRow('已盘点', '$checkedContainers'),
              _buildReportRow('匹配', '${stats['match']}', color: AppTheme.successColor),
              _buildReportRow('不匹配', '${stats['mismatch']}', color: AppTheme.warningColor),
              _buildReportRow('多出', '${stats['extra']}', color: AppTheme.infoColor),
              _buildReportRow('缺失', '${stats['missing']}', color: AppTheme.dangerColor),
              Divider(height: 24.h),
              _buildReportRow('重量差异', '${totalWeightDiff.toStringAsFixed(2)} kg',
                  color: totalWeightDiff.abs() > 0.01 ? AppTheme.warningColor : AppTheme.successColor),
              SizedBox(height: 16.h),
              CommonButton(
                text: '完成盘点',
                block: true,
                onPressed: () {
                  Navigator.pop(context);
                  _finishCheck();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyle.body),
          Text(
            value,
            style: AppTextStyle.subtitle.copyWith(
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  StatusTag _getCheckStatusTag(int? status) {
    switch (status) {
      case 1:
        return StatusTag.success('已完成');
      case 2:
        return StatusTag.info('已审核');
      default:
        return StatusTag.warning('盘点中');
    }
  }

  StatusTag _getSyncStatusTag(int? syncStatus) {
    if (syncStatus == 1) {
      return StatusTag.success('已同步');
    }
    return StatusTag.warning('待同步', outlined: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isChecking ? '盘点中' : '库存盘点'),
        actions: [
          if (!_isChecking)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateDialog,
            ),
        ],
      ),
      body: _isChecking ? _buildCheckingView() : _buildCheckListView(),
    );
  }

  Widget _buildCheckListView() {
    return SmartRefresher(
      controller: _refreshController,
      onRefresh: _onRefresh,
      header: WaterDropHeader(waterDropColor: AppTheme.primaryColor),
      child: _isLoading && _checkList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _checkList.isEmpty
              ? EmptyState(
                  message: '暂无盘点记录',
                  icon: Icons.assignment_outlined,
                  buttonText: '新建盘点',
                  onButtonPressed: _showCreateDialog,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _checkList.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: CommonButton(
                          text: '新建盘点',
                          block: true,
                          prefixIcon: Icons.add_circle_outline,
                          onPressed: _showCreateDialog,
                        ),
                      );
                    }
                    return _buildCheckCard(_checkList[index - 1]);
                  },
                ),
    );
  }

  Widget _buildCheckCard(Map<String, dynamic> check) {
    final checkNo = check['check_no'] as String? ?? '';
    final checkName = check['check_name'] as String? ?? '';
    final checkType = check['check_type'] as String? ?? '';
    final checkDate = check['check_date'] as String?;
    final status = check['status'] as int?;
    final syncStatus = check['sync_status'] as int?;
    final totalContainers = check['total_containers'] as int? ?? 0;
    final checkedContainers = check['checked_containers'] as int? ?? 0;
    final missingContainers = check['missing_containers'] as int? ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.inventoryCheckDetail,
          arguments: check,
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
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
                Text(checkName, style: AppTextStyle.subtitle),
                _getCheckStatusTag(status),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Text(checkNo, style: AppTextStyle.caption),
                SizedBox(width: 12.w),
                _getSyncStatusTag(syncStatus),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                _buildStatItem('容器', '$totalContainers'),
                SizedBox(width: 16.w),
                _buildStatItem('已盘', '$checkedContainers'),
                SizedBox(width: 16.w),
                _buildStatItem('缺失', '$missingContainers'),
                SizedBox(width: 16.w),
                if (checkDate != null)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.access_time, size: 14.r, color: AppTheme.textHint),
                        SizedBox(width: 4.w),
                        Text(
                          DateUtil.formatString(checkDate, DateUtil.formatDateOnly) ?? '',
                          style: AppTextStyle.small,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyle.caption),
        SizedBox(width: 4.w),
        Text(value, style: AppTextStyle.body.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCheckingView() {
    final stats = _getDiffStats();
    final progress = _inventoryItems.isEmpty ? 0.0 : _scannedCodes.length / _inventoryItems.length;

    return Column(
      children: [
        _buildCheckProgress(progress),
        _buildCheckActions(),
        _buildScanSummary(stats),
        Expanded(child: _buildScanResultList()),
      ],
    );
  }

  Widget _buildCheckProgress(double progress) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      color: AppTheme.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '盘点进度',
                style: AppTextStyle.subtitle,
              ),
              Text(
                '${(_scannedCodes.length)}/${_inventoryItems.length}',
                style: AppTextStyle.bodySecondary,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8.h,
              backgroundColor: AppTheme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            child: CommonButton(
              text: '扫描容器',
              prefixIcon: Icons.qr_code_scanner,
              onPressed: _scanContainer,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: CommonButton(
              text: '差异报告',
              type: ButtonType.outline,
              prefixIcon: Icons.assessment_outlined,
              onPressed: _scannedDetails.isEmpty ? null : _showDiffReport,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanSummary(Map<String, int> stats) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          _buildSummaryChip('匹配', stats['match'] ?? 0, AppTheme.successColor),
          SizedBox(width: 12.w),
          _buildSummaryChip('不匹配', stats['mismatch'] ?? 0, AppTheme.warningColor),
          SizedBox(width: 12.w),
          _buildSummaryChip('多出', stats['extra'] ?? 0, AppTheme.infoColor),
          SizedBox(width: 12.w),
          _buildSummaryChip('缺失', stats['missing'] ?? 0, AppTheme.dangerColor),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(fontSize: 11.sp, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanResultList() {
    if (_scannedDetails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 64.r, color: AppTheme.textHint),
            SizedBox(height: 16.h),
            Text('请扫描容器条码开始盘点', style: AppTextStyle.bodySecondary),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: _scannedDetails.length,
      itemBuilder: (context, index) {
        final detail = _scannedDetails[index];
        return _buildScanResultItem(detail);
      },
    );
  }

  Widget _buildScanResultItem(Map<String, dynamic> detail) {
    final diffType = detail['diff_type'] as String? ?? 'match';
    final containerCode = detail['container_code'] as String? ?? '';
    final wasteName = detail['waste_name'] as String? ?? '未知';

    Color typeColor;
    String typeText;
    switch (diffType) {
      case 'mismatch':
        typeColor = AppTheme.warningColor;
        typeText = '不匹配';
        break;
      case 'extra':
        typeColor = AppTheme.infoColor;
        typeText = '多出';
        break;
      default:
        typeColor = AppTheme.successColor;
        typeText = '匹配';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: typeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        containerCode,
                        style: AppTextStyle.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusTag(
                      text: typeText,
                      type: diffType == 'match'
                          ? StatusType.success
                          : diffType == 'mismatch'
                              ? StatusType.warning
                              : StatusType.info,
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(wasteName, style: AppTextStyle.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
