import '../models/user_profile.dart';
import 'mock_data.dart';

/// The single door screens use for accounts, like `status_repository.dart`
/// is for device data. Today every login succeeds with the sample user;
/// later, replace the function bodies with real API calls and keep the
/// same signatures.

UserProfile? _currentUser;

/// Who is logged in, or null if nobody is.
UserProfile? get currentUser => _currentUser;

Future<UserProfile> logIn({required String phoneOrEmail, required String password}) async {
  await Future<void>.delayed(const Duration(milliseconds: 600)); // fake network
  return _currentUser = mockUser;
}

Future<UserProfile> signUp({
  required String name,
  required String phone,
  required UserRole role,
  required String barangay,
  required String password,
}) async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  return _currentUser = UserProfile(name: name, phone: phone, role: role, barangay: barangay);
}

Future<void> logOut() async {
  _currentUser = null;
}
