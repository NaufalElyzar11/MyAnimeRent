/// One-way latch set before the event application is constructed.
/// Legacy services check this before obtaining any Firebase instance.
abstract final class EventSafety {
  static bool _cloudDisabled = false;

  static bool get cloudDisabled => _cloudDisabled;

  static void disableCloud() => _cloudDisabled = true;

  static void requireCloudAccess() {
    if (_cloudDisabled) {
      throw StateError('Layanan cloud dinonaktifkan pada versi uji event.');
    }
  }
}
