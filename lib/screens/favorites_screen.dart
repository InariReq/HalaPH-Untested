import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/favorites_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Destination> _favorites = <Destination>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final allDestinations = await DestinationService.searchDestinationsEnhanced();
    final favoriteIds = FavoritesService.favoriteIds.toSet();
    setState(() {
      _favorites = allDestinations
          .where((destination) => favoriteIds.contains(destination.id))
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(
                  child: Text(
                    'No favorite destinations yet',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final destination = _favorites[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: Icon(
                              Icons.favorite,
                              color: Colors.red[400],
                            ),
                          ),
                          title: Text(destination.name),
                          subtitle: Text(destination.location),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            '/explore-details?destinationId=${destination.id}&source=favorites',
                            extra: destination,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
