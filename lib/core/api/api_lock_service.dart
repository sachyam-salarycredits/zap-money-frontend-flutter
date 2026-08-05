import 'dart:async';

/// Mirrors RN `APILockService.js` — mutex while guest/refresh token runs.
class ApiLockService {
  bool _locked = false;
  String? _lockToken;
  Completer<void>? _waitCompleter;

  void lock(String lockToken) {
    _lockToken = lockToken;
    _locked = true;
  }

  bool isLocked({String? requestLockToken}) {
    if (requestLockToken != null && requestLockToken == _lockToken) {
      return false;
    }
    return _locked;
  }

  void releaseLock(String lockToken) {
    if (lockToken == _lockToken) {
      _locked = false;
      if (_waitCompleter != null && !_waitCompleter!.isCompleted) {
        _waitCompleter!.complete();
      }
      _waitCompleter = null;
    }
  }

  Future<void> waitTillUnlocked() async {
    if (!_locked) return;
    _waitCompleter ??= Completer<void>();
    await _waitCompleter!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _locked = false;
      },
    );
  }
}
