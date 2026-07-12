/// Real PayOS integration via backend API.
const kPaymentUiOnlyMode = false;

enum PaymentContext { tenant, landlord }

extension PaymentContextX on PaymentContext {
  String get queryValue => name;

  static PaymentContext? fromQuery(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'tenant':
        return PaymentContext.tenant;
      case 'landlord':
        return PaymentContext.landlord;
      default:
        return null;
    }
  }
}

enum PaymentCheckoutPackage {
  tenantPremium(
    label: 'PREMIUM',
    title: 'SacoStay Premium',
    priceLabel: '80.000đ/tháng',
    amount: 80000,
    context: PaymentContext.tenant,
  ),
  landlordBasic(
    label: 'BASIC',
    title: 'VIP BASIC',
    priceLabel: '53.000đ/30 ngày',
    amount: 53000,
    context: PaymentContext.landlord,
  ),
  landlordLite(
    label: 'LITE',
    title: 'VIP LITE',
    priceLabel: '295.000đ/30 ngày',
    amount: 295000,
    context: PaymentContext.landlord,
  ),
  landlordPro(
    label: 'PRO',
    title: 'VIP PRO',
    priceLabel: '737.500đ/30 ngày',
    amount: 737500,
    context: PaymentContext.landlord,
  ),
  landlordElite(
    label: 'ELITE',
    title: 'VIP ELITE',
    priceLabel: '1.475.000đ/30 ngày',
    amount: 1475000,
    context: PaymentContext.landlord,
  );

  const PaymentCheckoutPackage({
    required this.label,
    required this.title,
    required this.priceLabel,
    required this.amount,
    required this.context,
  });

  final String label;
  final String title;
  final String priceLabel;
  final int amount;
  final PaymentContext context;

  static PaymentCheckoutPackage? fromQuery(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final key = raw.toUpperCase();
    for (final pkg in PaymentCheckoutPackage.values) {
      if (pkg.label == key) return pkg;
    }
    return null;
  }

  static PaymentCheckoutPackage? fromLabel(String label) {
    return fromQuery(label);
  }
}
