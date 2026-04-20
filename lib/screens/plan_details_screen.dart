import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/plan_service.dart';
import 'package:halaph/screens/add_place_screen.dart';

class DestinationData {
  final Destination destination;
  final int fromDay;
  final int fromIndex;

  DestinationData({
    required this.destination,
    required this.fromDay,
    required this.fromIndex,
  });
}

class PlanDetailsScreen extends StatefulWidget {
  final TravelPlan? plan;

  const PlanDetailsScreen({
    super.key,
    required this.plan,
  });

  @override
  State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen> {
  TravelPlan? _plan;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  final _titleController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  Map<int, List<Destination>> _itinerary = {};
  Map<String, String> _destinationTimes = {};

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  void _refreshPlan() {
    setState(() {
      _isLoading = true;
    });
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    // Plan is now loaded by the router, just initialize if we have it
    if (widget.plan != null) {
      // Initialize state variables with plan data
      _titleController.text = widget.plan!.title;
      _startDate = widget.plan!.startDate;
      _endDate = widget.plan!.endDate;

      // Convert itinerary back to Map<int, List<Destination>> format
      _itinerary = {};
      _destinationTimes = {};

      for (final dayItinerary in widget.plan!.itinerary) {
        final dayNumber =
            dayItinerary.date.difference(widget.plan!.startDate).inDays + 1;
        final destinations =
            dayItinerary.items.map((item) => item.destination).toList();
        _itinerary[dayNumber] = destinations;

        // Set times for each destination
        for (final item in dayItinerary.items) {
          _destinationTimes[item.destination.id] =
              _formatTimeOfDay(item.startTime);
        }
      }

      setState(() {
        _plan = widget.plan;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _savePlanChanges() async {
    if (_plan == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Validate input
      if (_titleController.text.trim().isEmpty) {
        _showError('Please enter a plan title');
        return;
      }

      if (_startDate == null || _endDate == null) {
        _showError('Please select valid dates');
        return;
      }

      // Update the plan using the service
      if (_plan == null) return;

      // Convert Map<int, List<Destination>> to List<DayItinerary>
      final dayItineraries = <DayItinerary>[];
      final sortedKeys = _itinerary.keys.toList()..sort();
      for (final dayNum in sortedKeys) {
        final destinations = _itinerary[dayNum] ?? [];
        final items = destinations
            .map((dest) => ItineraryItem(
                  id: 'item_${dayNum}_${dest.id}',
                  destination: dest,
                  startTime: const TimeOfDay(hour: 9, minute: 0),
                  endTime: const TimeOfDay(hour: 11, minute: 0),
                  dayNumber: dayNum,
                  notes: 'Visit ${dest.name}',
                ))
            .toList();

        dayItineraries.add(DayItinerary(
          date: _startDate!.add(Duration(days: dayNum - 1)),
          items: items,
        ));
      }

      // Create updated travel plan
      final updatedPlanData = TravelPlan(
        id: _plan!.id,
        title: _titleController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        participantIds: _plan!.participantIds,
        createdBy: _plan!.createdBy,
        itinerary: dayItineraries,
        isShared: _plan!.isShared,
        bannerImage: _plan!.bannerImage,
        shareCode: _plan!.shareCode,
        sharedWith: _plan!.sharedWith,
        reminderEnabled: _plan!.reminderEnabled,
        reminderMinutesBefore: _plan!.reminderMinutesBefore,
      );

      await PlanService.updatePlan(updatedPlanData);

      if (updatedPlanData.id.isNotEmpty) {
        _showSuccess('Plan updated successfully!');

        // Reload the plan from service to get the latest data including banner image
        final updatedPlan = PlanService.getPlanById(_plan!.id);
        if (updatedPlan != null) {
          setState(() {
            _plan = updatedPlan;
            _isEditing = false;
          });
        }

        // Navigate to My Plans after saving
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/my-plans');
        }
      } else {
        _showError('Failed to update plan');
      }
    } catch (e) {
      _showError('Failed to update plan');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _showPlanDeleteConfirmation();
              },
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _loadPlan(); // Reset to original data
                });
              },
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _savePlanChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildContent() {
    if (_plan == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
              const SizedBox(height: 24),
              Text(
                'Plan Not Found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The plan you\'re looking for doesn\'t exist or may have been deleted.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/my-plans'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Back to My Plans',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  _buildHeroSection(),
                  _buildActionButtons(),
                  _buildPlanMetaSection(),
                  _buildItinerarySection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: _isSaving ? null : _savePlanChanges,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          )
        else
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
          ),
        if (!_isEditing)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              _showPlanDeleteConfirmation();
            },
          ),
        if (_isEditing)
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () {
              setState(() {
                _isEditing = false;
                _loadPlan(); // Reset to original data
              });
            },
          ),
      ],
    );
  }

  String _getBannerImageUrl() {
    // Try banner image first
    if (_plan?.bannerImage != null && _plan!.bannerImage!.isNotEmpty) {
      print('DEBUG: Using banner image: ${_plan!.bannerImage}');
      return _plan!.bannerImage!;
    }
    // Fallback to destination image
    else if (_plan != null &&
        _plan!.itinerary.isNotEmpty &&
        _plan!.itinerary.first.items.isNotEmpty) {
      print(
          'DEBUG: Using destination image: ${_plan!.itinerary.first.items.first.destination.imageUrl}');
      return _plan!.itinerary.first.items.first.destination.imageUrl;
    }
    // Default fallback
    else {
      print('DEBUG: Using default fallback image');
      return 'https://picsum.photos/seed/travel/400/200';
    }
  }

  Widget _buildBannerImage() {
    final imageUrl = _getBannerImageUrl();

    // Add cache buster to force refresh when plan changes
    final cacheBuster =
        _plan?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final urlWithCache = imageUrl.contains('?')
        ? '$imageUrl&cache=$cacheBuster'
        : '$imageUrl?cache=$cacheBuster';

    return Image.network(
      urlWithCache,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      key: ValueKey('banner_${_plan?.id}_$cacheBuster'),
      cacheWidth: 800, // Optimize for mobile - smaller cache size
      cacheHeight: 400,
      semanticLabel: 'Plan banner image for ${_plan?.title ?? 'Untitled Plan'}',
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[200],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[300],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 50, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroSection() {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          _buildBannerImage(),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isEditing)
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Plan Title',
                        hintStyle: TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Text(
                      _plan?.title ?? 'Untitled Plan',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _plan?.formattedDateRange ?? 'No dates set',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isEditing ? _addLocations : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing ? Colors.blue[600] : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Add Locations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _showShareSheet,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[600],
                side: BorderSide(color: Colors.blue[200]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Share Plan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanMetaSection() {
    if (_plan == null) return const SizedBox.shrink();

    final reminder = _plan!.nextReminderDateTime;
    final now = DateTime.now();
    final reminderText = reminder == null
        ? 'Reminders disabled'
        : reminder.isBefore(now)
            ? 'Reminder time already passed on this device'
            : 'Next reminder: ${reminder.month}/${reminder.day} ${_formatTimeOfDay(TimeOfDay(hour: reminder.hour, minute: reminder.minute))}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Expanded(child: Text(reminderText)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.group, size: 18, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _plan!.sharedWith.isEmpty
                        ? 'Private plan'
                        : 'Shared with ${_plan!.sharedWith.join(', ')}',
                  ),
                ),
              ],
            ),
            if (_plan!.shareCode != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.key, size: 18, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Text('Share code: ${_plan!.shareCode}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addLocations() async {
    final result = await Navigator.push<Destination>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPlaceScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        // Add to the first day by default
        const dayNumber = 1;
        _itinerary[dayNumber] ??= [];
        _itinerary[dayNumber]!.add(result);

        // Set a default time for the new destination
        _destinationTimes[result.id] = '10:30 AM';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} added to Day 1')),
      );
    }
  }

  void _showShareSheet() {
    if (_plan == null) return;
    final controller =
        TextEditingController(text: _plan!.sharedWith.join(', '));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share Plan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'friend@email.com, Group mate',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: PlanService.buildShareMessage(_plan!),
                        ),
                      );
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Plan summary copied')),
                      );
                    },
                    child: const Text('Copy Summary'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final recipients = controller.text
                          .split(',')
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .toList();
                      final updatedPlan =
                          await PlanService.sharePlan(_plan!.id, recipients);
                      if (!mounted) return;
                      Navigator.pop(context);
                      if (updatedPlan != null) {
                        setState(() => _plan = updatedPlan);
                      }
                    },
                    child: const Text('Save Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addToPlan(Destination destination) {
    if (!_isEditing) return;

    _showTimeDateSelectionDialog(destination);
  }

  void _showTimeDateSelectionDialog(Destination destination) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${destination.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select day and time for ${destination.name}'),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _addToPlanWithDay(Destination destination, int dayNumber) {
    setState(() {
      _itinerary[dayNumber] ??= [];
      _itinerary[dayNumber]!.add(destination);
      _destinationTimes[destination.id] = '10:30 AM';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${destination.name} added to Day $dayNumber')),
    );
  }

  void _removeDestinationFromPlan(Destination destination, int dayNumber) {
    if (!_isEditing) return;

    setState(() {
      _itinerary[dayNumber]?.remove(destination);
      if (_itinerary[dayNumber]?.isEmpty == true) {
        _itinerary.remove(dayNumber);
      }
      _destinationTimes.remove(destination.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${destination.name} removed from Day $dayNumber')),
    );
  }

  void _handleDrop(DestinationData data, int toDay, int toIndex) {
    if (!_isEditing) return;

    setState(() {
      // Remove from original position
      _itinerary[data.fromDay]!.removeAt(data.fromIndex);

      // Insert at new position
      _itinerary[toDay] ??= [];
      _itinerary[toDay]!.insert(toIndex, data.destination);

      // If moving to a different day, update the day structure
      if (data.fromDay != toDay) {
        // Ensure the original day still exists
        if (_itinerary[data.fromDay]!.isEmpty) {
          _itinerary.remove(data.fromDay);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          data.fromDay == toDay
              ? 'Moved ${data.destination.name} to position ${toIndex + 1}'
              : 'Moved ${data.destination.name} from Day ${data.fromDay} to Day ${toDay}',
        ),
      ),
    );
  }

  Widget _buildItinerarySection() {
    if (_itinerary.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No itinerary items yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                if (_isEditing)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Tap "Add Friends" to get started',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: _itinerary.keys.map((dayNumber) {
        final destinations = _itinerary[dayNumber]!;
        final dayDate = _plan?.startDate.add(Duration(days: dayNumber - 1)) ??
            DateTime.now();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      'Day $dayNumber',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(dayDate),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Destinations for this day
              ...destinations.asMap().entries.map((entry) {
                final destinationIndex = entry.key;
                final destination = entry.value;
                final isLast = destinationIndex == destinations.length - 1;

                return _buildDestinationCard(
                    destination, dayNumber, destinationIndex);
              }).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDestinationCard(Destination destination, int day, int index) {
    final time = _destinationTimes[destination.id] ?? '10:30 AM';
    final dayLength = _itinerary[day]?.length ?? 0;
    final isLast = index == dayLength - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Container(
            width: 40,
            height: 200, // Add fixed height to provide bounded constraints
            child: Stack(
              children: [
                // Connecting line
                if (!isLast)
                  Positioned(
                    left: 19,
                    top: 20,
                    child: Container(
                      width: 2,
                      height: 176,
                      color: Colors.grey[300],
                    ),
                  ),

                // Circle indicator
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Destination card
          Expanded(
            child: _buildDestinationCardContent(destination, day, index, time),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCardContent(
      Destination destination, int day, int index, String time) {
    if (_isEditing) {
      return _buildEditableDestinationCard(destination, day, index, time);
    } else {
      return _buildReadOnlyDestinationCard(destination, time, day, index);
    }
  }

  Widget _buildEditableDestinationCard(
      Destination destination, int day, int index, String time) {
    return LongPressDraggable<DestinationData>(
      data: DestinationData(
          destination: destination, fromDay: day, fromIndex: index),
      feedback: _buildDragFeedback(destination),
      childWhenDragging: _buildDropPlaceholder(destination),
      child: DragTarget<DestinationData>(
        onWillAccept: (data) =>
            data != null && data.destination.id != destination.id,
        onAccept: (data) => _handleDrop(data, day, index),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isHovering ? Colors.blue[50] : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Image section with overlay and delete button
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: _buildDestinationImage(destination),
                          ),
                        ),
                        // Gradient overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Delete button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () =>
                                _removeDestinationFromPlan(destination, day),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Info section
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  destination.location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          _buildDestinationFooter(time, destination.category),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadOnlyDestinationCard(
      Destination destination, String time, int day, int index) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image section
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: _buildDestinationImage(destination),
              ),
            ),
          ),
          // Info section
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destination.location,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _addPlaceAfter(destination, day, index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.blue[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Place After',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildDestinationFooter(time, destination.category),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationImage(Destination destination) {
    if (destination.imageUrl.isNotEmpty &&
        destination.imageUrl.startsWith('http')) {
      return Image.network(
        destination.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultDestinationImage(destination.category);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[100],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
    }
    return _buildDefaultDestinationImage(destination.category);
  }

  Widget _buildDestinationFooter(String time, DestinationCategory category) {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 12,
          color: Colors.grey[500],
        ),
        const SizedBox(width: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            category.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _addPlaceAfter(Destination destination, int day, int index) {
    if (!_isEditing) return;

    setState(() {
      // Insert new destination after current one
      _itinerary[day]!.insert(index + 1, destination);

      // Set a default time for the new destination
      _destinationTimes[destination.id] = '11:00 AM';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${destination.name} added after ${destination.name}')),
    );
  }

  Widget _buildDragFeedback(Destination destination) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 12),
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: Colors.blue[300]!, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.grey[200],
            ),
            child: _buildDestinationImage(destination),
          ),
        ),
      ),
    );
  }

  Widget _buildDropPlaceholder(Destination destination) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue[200]!,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.drag_indicator,
                  color: Colors.blue[600],
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Drop here',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Move "${destination.name}"',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultDestinationImage(DestinationCategory category) {
    IconData icon;
    Color color = Colors.grey; // Default color

    switch (category) {
      case DestinationCategory.park:
        icon = Icons.park;
        color = Colors.green;
        break;
      case DestinationCategory.landmark:
        icon = Icons.location_city;
        color = Colors.teal;
        break;
      case DestinationCategory.food:
        icon = Icons.fastfood;
        color = Colors.orange;
        break;
      case DestinationCategory.activities:
        icon = Icons.sports_soccer;
        color = Colors.indigo;
        break;
      case DestinationCategory.museum:
        icon = Icons.museum;
        color = Colors.brown;
        break;
      case DestinationCategory.market:
        icon = Icons.shopping_bag;
        color = Colors.pink;
        break;
      default:
        icon = Icons.place;
        color = Colors.grey;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: color.withOpacity(0.1),
      child: Icon(
        icon,
        size: 48,
        color: color.withOpacity(0.6),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showPlanDeleteConfirmation() {
    if (_plan == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text(
            'Are you sure you want to delete "${_plan?.title ?? 'Untitled Plan'}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_plan == null) return;
              await PlanService.deletePlan(_plan!.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plan deleted successfully')),
                );
                context.go('/'); // Navigate to home
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
