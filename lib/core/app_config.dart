class AppConfig {
  /// List of owner/developer emails permitted to access developer tools (e.g. Bank SMS simulator).
  static final Set<String> developerEmails = {
    'krishnaniranjan773@gmail.com',
  };

  /// Set of developer user IDs (UIDs)
  static final Set<String> developerUserIds = {};

  /// Optional override for testing or manual developer mode toggle
  static bool developerModeOverride = false;

  /// Checks whether the given email or uid belongs to an authorized developer/owner account.
  static bool isDeveloper({String? email, String? uid}) {
    if (developerModeOverride) return true;
    if (uid != null && developerUserIds.contains(uid.trim())) return true;
    if (email == null || email.trim().isEmpty) return false;
    final normalized = email.trim().toLowerCase();
    return developerEmails.any((e) => e.toLowerCase().trim() == normalized);
  }
}
