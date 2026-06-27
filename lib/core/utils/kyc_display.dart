import '../../models/kyc.dart';
import 'json_normalize.dart';

KycStatus normalizeKycStatus(dynamic raw) {
  if (raw is! Map) {
    return const KycStatus(status: KycApiStatus.notSubmitted);
  }
  final o = Map<String, dynamic>.from(raw);
  final statusRaw = strField(pickField(o, 'status', ['Status']));
  final status = _parseStatus(statusRaw);
  return KycStatus(
    status: status,
    adminNote: strField(pickField(o, 'adminNote', ['AdminNote'])).isEmpty
        ? null
        : strField(pickField(o, 'adminNote', ['AdminNote'])),
    submittedAt: strField(pickField(o, 'submittedAt', ['SubmittedAt'])).isEmpty
        ? null
        : strField(pickField(o, 'submittedAt', ['SubmittedAt'])),
  );
}

KycApiStatus _parseStatus(String raw) {
  switch (raw) {
    case 'Pending':
      return KycApiStatus.pending;
    case 'Approved':
      return KycApiStatus.approved;
    case 'Rejected':
      return KycApiStatus.rejected;
    case 'NeedReupload':
      return KycApiStatus.needReupload;
    default:
      return KycApiStatus.notSubmitted;
  }
}

String kycStatusLabel(KycApiStatus status) {
  switch (status) {
    case KycApiStatus.approved:
      return 'Đã xác thực danh tính';
    case KycApiStatus.pending:
      return 'Đang chờ duyệt';
    case KycApiStatus.rejected:
    case KycApiStatus.needReupload:
      return 'Cần xác thực lại';
    default:
      return 'Chưa xác thực danh tính';
  }
}
