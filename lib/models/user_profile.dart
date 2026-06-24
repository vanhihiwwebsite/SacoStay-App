import '../core/utils/json_normalize.dart';
import '../core/utils/user_display.dart';

class UserProfile {
  UserProfile({required this.raw});

  final Map<String, dynamic> raw;

  String get id => strField(pickField(raw, 'id', ['Id', 'ID']));
  String get email => strField(pickField(raw, 'email', ['Email']));
  String get userName => strField(pickField(raw, 'userName', ['UserName', 'username']));
  String get firstName => strField(pickField(raw, 'firstName', ['FirstName']));
  String get lastName => strField(pickField(raw, 'lastName', ['LastName']));
  String get phoneNumber => strField(pickField(raw, 'phoneNumber', ['PhoneNumber']));
  List<String> get roles => listOfStrings(raw['roles'] ?? raw['Roles']);
  String? get avatar => profileAvatarFromRaw(raw);

  String get displayLabel => navProfileLabel(raw);

  bool get isAdmin => isAdminUser(raw);
  bool get isLandlord => isLandlordUser(raw);

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(raw: normalizeAuthUser(json));
  }
}

class LoginRequest {
  LoginRequest({required this.emailPhoneorUsername, required this.password});

  final String emailPhoneorUsername;
  final String password;

  Map<String, dynamic> toJson() => {
        'emailPhoneorUsername': emailPhoneorUsername,
        'password': password,
      };
}

class RegisterRequest {
  RegisterRequest({
    required this.userName,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.role,
    this.firstName,
    this.lastName,
    this.phoneNumber,
  });

  final String userName;
  final String email;
  final String password;
  final String confirmPassword;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
        'role': role,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      };
}

class LoginResponse {
  LoginResponse({required this.token, this.user});

  final String token;
  final UserProfile? user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = unwrapData(json);
    final token = strField(
      pickField(data, 'token', ['Token', 'accessToken', 'AccessToken']),
    );
    UserProfile? user;
    final userRaw = data['user'] ?? data['User'];
    if (userRaw is Map<String, dynamic>) {
      user = UserProfile.fromJson(userRaw);
    }
    return LoginResponse(token: token, user: user);
  }
}
