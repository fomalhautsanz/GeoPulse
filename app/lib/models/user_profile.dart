/// What someone does in the GeoPulse network. Shown on Sign Up and Profile.
///
/// An "enhanced enum": each value carries the text shown to people.
enum UserRole {
  resident('Resident'),
  barangayDrrm('Barangay DRRM'),
  official('Official'),
  responder('Responder');

  const UserRole(this.label);

  final String label;
}

/// The signed-in person.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.phone,
    required this.role,
    required this.barangay,
  });

  final String name;
  final String phone; // or email, whatever they signed up with
  final UserRole role;
  final String barangay; // barangay or site name
}
