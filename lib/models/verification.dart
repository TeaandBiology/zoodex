/// Whether a visit's presence at the zoo was confirmed by GPS.
///
/// - [verified]   — GPS placed the user inside the zoo's radius that day.
/// - [unverified] — logged, but not (yet) confirmed by GPS (e.g. from memory,
///   a flaky fix, or a different location). Can still be upgraded to verified
///   later the same day.
/// - [skipped]    — location services off / permission denied / no coordinates
///   set for the zoo, so verification couldn't run.
enum VerificationStatus { verified, unverified, skipped }

String verificationToString(VerificationStatus v) {
  switch (v) {
    case VerificationStatus.verified:
      return 'verified';
    case VerificationStatus.skipped:
      return 'skipped';
    case VerificationStatus.unverified:
      return 'unverified';
  }
}

VerificationStatus verificationFromString(String? s) {
  switch (s) {
    case 'verified':
      return VerificationStatus.verified;
    case 'skipped':
      return VerificationStatus.skipped;
    default:
      return VerificationStatus.unverified;
  }
}

class VerificationResult {
  final VerificationStatus status;

  /// The zoo GPS placed the user at, when [status] is [VerificationStatus.verified].
  final String? detectedZooId;

  const VerificationResult(this.status, {this.detectedZooId});
}
