import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../config/app_theme.dart';
import '../providers/carbon_footprint_provider.dart';
import '../utils/toast_util.dart';
import '../widgets/empty_state.dart';

class CarbonFootprintCalcPage extends StatefulWidget {
  const CarbonFootprintCalcPage({super.key});

  @override
  State<CarbonFootprintCalcPage> createState() => _CarbonFootprintCalcPageState();
}

class _CarbonFootprintCalcPageState extends State<CarbonFootprintCalcPage> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _wasteNameController = TextEditingController();
  final TextEditingController _wasteCodeController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _transferOrderNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarbonFootprintProvider>().init();
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _distanceController.dispose();
    _wasteNameController.dispose();
    _wasteCodeController.dispose();
    _remarkController.dispose();
    _transferOrderNoController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final provider = context.read<CarbonFootprintProvider>();
    final weight = double.tryParse(_weightController.text) ?? 0;
    final distance = double.tryParse(_distanceController.text) ?? 0;

    if (weight > 0 && distance > 0 && provider.selectedWasteCategory != null) {
      provider.calculatePreview(weight: weight, transportDistance: distance);
    } else {
      provider.clearCalculation();
    }
  }

  Future<void> _showWasteCategoryPicker() async {
    final provider = context.read<CarbonFootprintProvider>();
    final categories = provider.wasteCategories;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              Text(
                '选择危废类别',
                style: AppTextStyle.title,
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (ctx, index) {
                    final category = categories[index];
                    final categoryName = provider.getWasteCategoryName(category);
                    final isSelected =
                        provider.selectedWasteCategory == category;
                    return ListTile(
                      title: Text('$category - $categoryName'),
                      trailing: isSelected
                          ? Icon(Icons.check_circle,
                              color: AppTheme.primaryColor)
                          : const Icon(Icons.radio_button_unchecked),
                      onTap: () {
                        provider.setSelectedWasteCategory(category);
                        _onInputChanged();
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showTransportModePicker() async {
    final provider = context.read<CarbonFootprintProvider>();
    final modes = provider.transportModes;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '选择运输方式',
                style: AppTextStyle.title,
              ),
              SizedBox(height: 12.h),
              ...modes.map((mode) {
                final modeName = provider.getTransportModeName(mode);
                final isSelected = provider.selectedTransportMode == mode;
                return ListTile(
                  title: Text(modeName),
                  trailing: isSelected
                      ? Icon(Icons.check_circle,
                          color: AppTheme.primaryColor)
                      : const Icon(Icons.radio_button_unchecked),
                  onTap: () {
                    provider.setSelectedTransportMode(mode);
                    _onInputChanged();
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDisposalMethodPicker() async {
    final provider = context.read<CarbonFootprintProvider>();
    final methods = provider.disposalMethods;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '选择处置方式',
                style: AppTextStyle.title,
              ),
              SizedBox(height: 12.h),
              ...methods.map((method) {
                final methodName = provider.getDisposalMethodName(method);
                final isSelected = provider.selectedDisposalMethod == method;
                return ListTile(
                  title: Text(methodName),
                  trailing: isSelected
                      ? Icon(Icons.check_circle,
                          color: AppTheme.primaryColor)
                      : const Icon(Icons.radio_button_unchecked),
                  onTap: () {
                    provider.setSelectedDisposalMethod(method);
                    _onInputChanged();
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveRecord() async {
    final provider = context.read<CarbonFootprintProvider>();
    final weight = double.tryParse(_weightController.text);
    final distance = double.tryParse(_distanceController.text);

    if (provider.selectedWasteCategory == null) {
      ToastUtil.show('请选择危废类别');
      return;
    }
    if (weight == null || weight <= 0) {
      ToastUtil.show('请输入有效重量');
      return;
    }
    if (distance == null || distance <= 0) {
      ToastUtil.show('请输入有效运输距离');
      return;
    }

    final success = await provider.createRecord(
      wasteCode: _wasteCodeController.text.isNotEmpty
          ? _wasteCodeController.text
          : null,
      wasteName: _wasteNameController.text.isNotEmpty
          ? _wasteNameController.text
          : null,
      weight: weight,
      transportDistance: distance,
      transferOrderNo: _transferOrderNoController.text.isNotEmpty
          ? _transferOrderNoController.text
          : null,
      remark: _remarkController.text.isNotEmpty ? _remarkController.text : null,
    );

    if (success) {
      ToastUtil.show('计算结果已保存');
      _weightController.clear();
      _distanceController.clear();
      _wasteNameController.clear();
      _wasteCodeController.clear();
      _remarkController.clear();
      _transferOrderNoController.clear();
      provider.clearCalculation();
    } else {
      ToastUtil.show('保存失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('碳足迹计算'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.carbonFootprintReport);
            },
          ),
        ],
      ),
      body: Consumer<CarbonFootprintProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _buildResultCard(provider),
              SizedBox(height: 16.h),
              _buildWasteInfoCard(provider),
              SizedBox(height: 16.h),
              _buildTransportCard(provider),
              SizedBox(height: 16.h),
              _buildDisposalCard(provider),
              SizedBox(height: 16.h),
              _buildExtraInfoCard(),
              SizedBox(height: 24.h),
              _buildSaveButton(provider),
              SizedBox(height: 24.h),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResultCard(CarbonFootprintProvider provider) {
    final result = provider.calculationResult;
    final hasResult = result != null;

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasResult
              ? [AppTheme.primaryColor, AppTheme.secondaryColor]
              : [AppTheme.textHint, AppTheme.textSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.r16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '碳排放量估算',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              Icon(Icons.eco, size: 24.r, color: Colors.white),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            hasResult
                ? '${result.totalEmission.toStringAsFixed(2)}'
                : '--',
            style: TextStyle(
              fontSize: 48.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'kg CO₂e',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _buildResultItem(
                  '运输排放',
                  hasResult
                      ? '${result.transportEmission.toStringAsFixed(2)} kg'
                      : '--',
                  Icons.local_shipping,
                ),
              ),
              Container(
                width: 1,
                height: 40.h,
                color: Colors.white24,
              ),
              Expanded(
                child: _buildResultItem(
                  '处置排放',
                  hasResult
                      ? '${result.disposalEmission.toStringAsFixed(2)} kg'
                      : '--',
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20.r, color: Colors.white70),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildWasteInfoCard(CarbonFootprintProvider provider) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.recycling, size: 20.r, color: AppTheme.primaryColor),
              SizedBox(width: 8.w),
              Text('危废信息', style: AppTextStyle.subtitle),
            ],
          ),
          SizedBox(height: 12.h),
          _buildSelectorItem(
            label: '危废类别',
            value: provider.selectedWasteCategory != null
                ? '${provider.selectedWasteCategory} - ${provider.getWasteCategoryName(provider.selectedWasteCategory!)}'
                : '请选择',
            onTap: _showWasteCategoryPicker,
            isSelected: provider.selectedWasteCategory != null,
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _wasteCodeController,
            decoration: InputDecoration(
              labelText: '危废代码（可选）',
              hintText: '例如：HW08',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _wasteNameController,
            decoration: InputDecoration(
              labelText: '危废名称（可选）',
              hintText: '请输入危废名称',
              prefixIcon: const Icon(Icons.label),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _onInputChanged(),
            decoration: InputDecoration(
              labelText: '危废重量',
              hintText: '请输入重量',
              prefixIcon: const Icon(Icons.line_weight),
              suffixText: 'kg',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportCard(CarbonFootprintProvider provider) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, size: 20.r, color: AppTheme.infoColor),
              SizedBox(width: 8.w),
              Text('运输信息', style: AppTextStyle.subtitle),
            ],
          ),
          SizedBox(height: 12.h),
          _buildSelectorItem(
            label: '运输方式',
            value: provider.selectedTransportMode != null
                ? provider.getTransportModeName(provider.selectedTransportMode!)
                : '请选择',
            onTap: _showTransportModePicker,
            isSelected: provider.selectedTransportMode != null,
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _distanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _onInputChanged(),
            decoration: InputDecoration(
              labelText: '运输距离',
              hintText: '请输入距离',
              prefixIcon: const Icon(Icons.route),
              suffixText: 'km',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisposalCard(CarbonFootprintProvider provider) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department,
                  size: 20.r, color: AppTheme.dangerColor),
              SizedBox(width: 8.w),
              Text('处置方式', style: AppTextStyle.subtitle),
            ],
          ),
          SizedBox(height: 12.h),
          _buildSelectorItem(
            label: '处置方式',
            value: provider.selectedDisposalMethod != null
                ? provider.getDisposalMethodName(provider.selectedDisposalMethod!)
                : '请选择',
            onTap: _showDisposalMethodPicker,
            isSelected: provider.selectedDisposalMethod != null,
          ),
        ],
      ),
    );
  }

  Widget _buildExtraInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, size: 20.r, color: AppTheme.secondaryColor),
              SizedBox(width: 8.w),
              Text('附加信息（可选）', style: AppTextStyle.subtitle),
            ],
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _transferOrderNoController,
            decoration: InputDecoration(
              labelText: '关联转移联单号',
              hintText: '请输入联单号',
              prefixIcon: const Icon(Icons.receipt_long),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _remarkController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '备注',
              hintText: '请输入备注信息',
              prefixIcon: const Icon(Icons.notes),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorItem({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyle.caption,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    style: isSelected
                        ? AppTextStyle.body
                        : AppTextStyle.bodySecondary,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(CarbonFootprintProvider provider) {
    final hasResult = provider.calculationResult != null;

    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton.icon(
        onPressed: hasResult ? _saveRecord : null,
        icon: const Icon(Icons.save),
        label: const Text('保存计算结果'),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasResult ? AppTheme.primaryColor : AppTheme.textHint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
        ),
      ),
    );
  }
}
