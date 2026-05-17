import 'package:flutter/material.dart';

/// Statische Mapping HR-Text → Material-Icon für den Bild-Joker.
///
/// Schlüssel werden vor dem Lookup lowercased. Datei kann frei ergänzt
/// werden, ohne Migration oder Datenrepo-Bump.
class VocabIcons {
  const VocabIcons._();

  static const Map<String, IconData> _map = {
    // Farben
    'crveno': Icons.brightness_1,
    'plavo': Icons.brightness_1,
    'zeleno': Icons.brightness_1,
    'žuto': Icons.brightness_1,
    'crno': Icons.brightness_1,
    'bijelo': Icons.brightness_1,
    // Konkrete Substantive
    'auto': Icons.directions_car,
    'autobus': Icons.directions_bus,
    'vlak': Icons.directions_train,
    'avion': Icons.flight,
    'brod': Icons.directions_boat,
    'bicikl': Icons.directions_bike,
    'taksi': Icons.local_taxi,
    'cesta': Icons.add_road,
    'most': Icons.water,
    'knjiga': Icons.book,
    'vrata': Icons.door_front_door,
    'prozor': Icons.window,
    'kuća': Icons.house,
    'stan': Icons.apartment,
    'škola': Icons.school,
    'bolnica': Icons.local_hospital,
    'banka': Icons.account_balance,
    'pošta': Icons.markunread_mailbox,
    'trgovina': Icons.store,
    'restoran': Icons.restaurant,
    'kavana': Icons.local_cafe,
    'hotel': Icons.hotel,
    // Möbel
    'stol': Icons.table_restaurant,
    'stolica': Icons.chair,
    'krevet': Icons.bed,
    // Tiere
    'pas': Icons.pets,
    'mačka': Icons.pets,
    'ptica': Icons.flutter_dash,
    'riba': Icons.set_meal,
    // Essen & Trinken
    'kruh': Icons.bakery_dining,
    'voda': Icons.water_drop,
    'kava': Icons.coffee,
    'čaj': Icons.emoji_food_beverage,
    'mlijeko': Icons.local_drink,
    'pivo': Icons.sports_bar,
    'vino': Icons.wine_bar,
    'jaje': Icons.egg,
    'sir': Icons.lunch_dining,
    'meso': Icons.kebab_dining,
    'voće': Icons.apple,
    'jabuka': Icons.apple,
    'banana': Icons.lunch_dining,
    // Kleidung
    'cipele': Icons.snowshoeing,
    'majica': Icons.checkroom,
    'hlače': Icons.checkroom,
    'jakna': Icons.checkroom,
    'haljina': Icons.checkroom,
    // Natur & Wetter
    'sunce': Icons.wb_sunny,
    'kiša': Icons.cloud,
    'snijeg': Icons.ac_unit,
    'vjetar': Icons.air,
    'oblak': Icons.cloud_queue,
    'more': Icons.waves,
    'plaža': Icons.beach_access,
    'planina': Icons.terrain,
    'drvo': Icons.park,
    'cvijet': Icons.local_florist,
    // Zeit
    'sat': Icons.schedule,
    'dan': Icons.today,
    'noć': Icons.nightlight_round,
    // Schule / Büro
    'olovka': Icons.edit,
    'papir': Icons.description,
    'računalo': Icons.computer,
    'mobitel': Icons.phone_iphone,
    'telefon': Icons.phone,
    // Familie
    'majka': Icons.face_3,
    'otac': Icons.face_6,
    'dijete': Icons.child_care,
    'beba': Icons.child_friendly,
  };

  /// Liefert ein Icon, falls für den HR-Text ein Mapping existiert.
  /// Lookup ist case-insensitive auf der Eingabe.
  static IconData? lookup(String hrText) {
    final key = hrText.trim().toLowerCase();
    return _map[key];
  }

  static bool has(String hrText) => lookup(hrText) != null;

  /// Anzahl der Mappings (für Tests / Statistik).
  static int get size => _map.length;
}
