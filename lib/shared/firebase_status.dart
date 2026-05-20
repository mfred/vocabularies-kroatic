/// Singleton-Flag, das beim App-Start vom main() gesetzt wird, je nachdem ob
/// `Firebase.initializeApp()` erfolgreich war. Auth + globale Highscores
/// werden ausgeblendet/deaktiviert, wenn Firebase nicht verfügbar ist —
/// damit die App ohne `flutterfire configure` weiter im reinen Lokal-Modus
/// läuft.
class FirebaseStatus {
  FirebaseStatus._();

  static final FirebaseStatus instance = FirebaseStatus._();

  bool _ready = false;
  String? _error;

  bool get isReady => _ready;
  String? get error => _error;

  void markReady() {
    _ready = true;
    _error = null;
  }

  void markUnavailable(String reason) {
    _ready = false;
    _error = reason;
  }
}
