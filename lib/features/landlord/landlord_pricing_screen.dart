import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../shared/widgets/saco_landlord_ui.dart';
import '../payment/payment_config.dart';

class LandlordPricingScreen extends StatelessWidget {
  const LandlordPricingScreen({super.key, this.postId});

  final String? postId;

  static const _tiers = ['BASIC', 'LITE', 'PRO', 'ELITE'];
  static const _tierColors = [
    Color(0xFF9CA3AF),
    Color(0xFF2563EB),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];
  static const _packages = [
    null,
    PaymentCheckoutPackage.landlordLite,
    PaymentCheckoutPackage.landlordPro,
    PaymentCheckoutPackage.landlordElite,
  ];

  /// Feature rows: label + per-tier cell value.
  static const _rows = <_PricingRow>[
    _PricingRow('Giá 30 ngày', ['Miễn phí', '475.000', '975.000', '1.475.000'], bold: true),
    _PricingRow('Nhãn dán nổi bật', ['—', 'MÀU XANH', 'MÀU CAM, IN HOA', 'MÀU ĐỎ, IN HOA'], highlight: true),
    _PricingRow('Kích thước tin', ['Nhỏ', 'Vừa', 'Lớn', 'Rất lớn']),
    _PricingRow('Ưu tiên duyệt (30-60 phút)', [false, true, true, true]),
    _PricingRow('Duy trì thêm 10 ngày tin thường', [false, true, true, true]),
    _PricingRow('Bộ lọc', [false, true, true, true]),
    _PricingRow('Đẩy tin', [false, false, true, true]),
    _PricingRow('Phân tích người xem', [false, true, false, true]),
  ];

  void _checkout(BuildContext context, PaymentCheckoutPackage pkg) {
    final params = <String, String>{
      'package': pkg.label,
      'context': PaymentContext.landlord.queryValue,
    };
    if (postId != null && postId!.isNotEmpty) params['postId'] = postId!;
    context.go(Uri(path: '/payment/checkout', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacoPageHeader(
            title: 'Bảng giá VIP',
            subtitle: postId != null
                ? 'Nâng cấp tin đăng để tiếp cận nhiều người thuê hơn'
                : 'Chọn gói phù hợp — tin VIP hiển thị nổi bật trên bản đồ & danh sách',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Vuốt ngang bảng để xem đủ các gói →',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.right,
            ),
          ),
          if (kPaymentUiOnlyMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: const Text(
                  'Thanh toán demo — backend PayOS tạm bảo trì.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TierHeaderRow(
                          tiers: _tiers,
                          colors: _tierColors,
                        ),
                        ..._rows.map((row) => _FeatureRow(row: row, colors: _tierColors)),
                        _PayRow(
                          packages: _packages,
                          colors: _tierColors,
                          onPay: (pkg) => _checkout(context, pkg),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Text(
              '(*) Các tin VIP sẽ được ưu tiên kiểm duyệt trong thời gian 30–60 phút.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingRow {
  const _PricingRow(this.label, this.cells, {this.bold = false, this.highlight = false});

  final String label;
  final List<Object> cells;
  final bool bold;
  final bool highlight;
}

class _TierHeaderRow extends StatelessWidget {
  const _TierHeaderRow({required this.tiers, required this.colors});

  final List<String> tiers;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 132,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text(
              'Tính năng',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
        for (var i = 0; i < tiers.length; i++)
          SizedBox(
            width: 108,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: colors[i],
              alignment: Alignment.center,
              child: Text(
                tiers[i],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.row, required this.colors});

  final _PricingRow row;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 132,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                row.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: row.bold ? FontWeight.w700 : FontWeight.w500,
                  color: SacoColors.sacoBlue,
                  height: 1.3,
                ),
              ),
            ),
          ),
          for (var i = 0; i < row.cells.length; i++)
            SizedBox(
              width: 108,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey.shade200)),
                ),
                alignment: Alignment.center,
                child: _CellValue(value: row.cells[i], highlight: row.highlight, tierColor: colors[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _CellValue extends StatelessWidget {
  const _CellValue({
    required this.value,
    required this.highlight,
    required this.tierColor,
  });

  final Object value;
  final bool highlight;
  final Color tierColor;

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      return _CheckIcon(enabled: value as bool);
    }
    final text = value as String;
    if (text == '—') {
      return Icon(Icons.remove, size: 16, color: Colors.grey.shade400);
    }
    if (highlight) {
      return Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: tierColor,
          height: 1.2,
        ),
      );
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: text == 'Miễn phí' ? Colors.grey.shade600 : SacoColors.sacoBlue,
      ),
    );
  }
}

class _CheckIcon extends StatelessWidget {
  const _CheckIcon({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled ? const Color(0xFF22C55E) : Colors.grey.shade200,
      ),
      child: Icon(
        Icons.check,
        size: 14,
        color: enabled ? Colors.white : Colors.grey.shade400,
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.packages,
    required this.colors,
    required this.onPay,
  });

  final List<PaymentCheckoutPackage?> packages;
  final List<Color> colors;
  final ValueChanged<PaymentCheckoutPackage> onPay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 132),
          for (var i = 0; i < packages.length; i++)
            SizedBox(
              width: 108,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey.shade200)),
                ),
                child: packages[i] == null
                    ? Text(
                        'Mặc định',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      )
                    : FilledButton(
                        onPressed: () => onPay(packages[i]!),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors[i],
                          minimumSize: const Size(88, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Thanh toán',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
