import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_destination_ids';
  static final Set<String> _favoriteIds = <String>{};

  static List<String> get favoriteIds => _favoriteIds.toList()..sort();
  static int get favoritesCount => _favoriteIds.length;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteIds
      ..clear()
      ..addAll(prefs.getStringList(_favoritesKey) ?? const []);
  }

  static bool isFavorite(String destinationId) {
    return _favoriteIds.contains(destinationId);
  }

  static Future<bool> toggleFavorite(String destinationId) async {
    if (_favoriteIds.contains(destinationId)) {
      _favoriteIds.remove(destinationId);
    } else {
      _favoriteIds.add(destinationId);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favoriteIds);
    return _favoriteIds.contains(destinationId);
  }
}
