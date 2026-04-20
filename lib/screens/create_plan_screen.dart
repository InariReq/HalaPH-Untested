import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/services/plan_service.dart';
import 'package:halaph/screens/add_place_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';

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

class CreatePlanScreen extends StatefulWidget {
  final Destination? initialDestination;

  const CreatePlanScreen({super.key, this.initialDestination});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _titleController = TextEditingController(text: 'Untitled');
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  File? _bannerImage;
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _sharedWith = <String>[];
  bool _reminderEnabled = true;
  int _reminderMinutesBefore = 30;

  // Structure to hold destinations organized by day
  Map<int, List<Destination>> _itinerary = {};

  // Structure to hold times for destinations (destination_id -> time)
  final Map<String, String> _destinationTimes = {};

  // Structure to track visited destinations (destination_id -> bool)
  final Map<String, bool> _visitedDestinations = {};

  // Scroll tracking for location bar
  final ScrollController _scrollController = ScrollController();
  int _currentVisibleDay = 1;
  int _currentVisibleDestination = 0;

  // Timer for periodic location checking
  Timer? _locationCheckTimer;

  // Role structure for future implementation (commented for now)
  // Map<String, String> _userRoles = {'current_user': 'Editor'}; // 'Editor' or 'Viewer'

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now();
    _initializeItinerary();
    if (widget.initialDestination != null) {
      _itinerary[1] = [widget.initialDestination!];
      _destinationTimes[widget.initialDestination!.id] = '10:30 AM';
    }
    _loadDestinations();
    _scrollController.addListener(_onScroll);
    _startLocationChecking();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _locationCheckTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_startDate == null || _endDate == null) return;

    final days = _endDate!.difference(_startDate!).inDays + 1;
    final scrollOffset = _scrollController.offset;
    final screenHeight = MediaQuery.of(context).size.height;

    // Fixed offset - account for header spacing
    double contentStartOffset = 320; // Banner + buttons + padding
    double adjustedScrollOffset = scrollOffset - contentStartOffset;

    // If we're still in the header area
    if (adjustedScrollOffset < 0) {
      if (_currentVisibleDay != 1 || _currentVisibleDestination != 0) {
        setState(() {
          _currentVisibleDay = 1;
          _currentVisibleDestination = 0;
        });
      }
      return;
    }

    // Track by day and destination
    int currentDay = 1;
    int currentDestination = 0;
    double accumulatedHeight = 0;

    for (int day = 1; day <= days; day++) {
      final destinations = _itinerary[day] ?? [];

      // Add day header height
      accumulatedHeight += 80; // Day header height

      for (int destIndex = 0; destIndex < destinations.length; destIndex++) {
        final cardHeight =
            240; // Destination card height (160 image + 80 buttons + padding)
        final cardTop = accumulatedHeight;
        final cardBottom = accumulatedHeight + cardHeight;

        final screenCenter = adjustedScrollOffset + screenHeight * 0.5;
        if (screenCenter >= cardTop && screenCenter <= cardBottom) {
          currentDay = day;
          currentDestination = destIndex;
          break;
        }

        accumulatedHeight += cardHeight;
      }

      // Add day spacing
      if (day < days) {
        accumulatedHeight += 16; // Day card margin
      }
    }

    if (currentDay != _currentVisibleDay ||
        currentDestination != _currentVisibleDestination) {
      setState(() {
        _currentVisibleDay = currentDay;
        _currentVisibleDestination = currentDestination;
      });
    }
  }

  Future<void> _loadDestinations() async {
    // Destinations are loaded on-demand in the FutureBuilder
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _initializeItinerary();
      });
    }
  }

  void _initializeItinerary() {
    if (_startDate != null && _endDate != null) {
      final days = _endDate!.difference(_startDate!).inDays + 1;
      _itinerary = {};
      for (int i = 1; i <= days; i++) {
        _itinerary[i] = [];
      }
    }
  }

  Future<void> _pickBannerImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 400,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _bannerImage = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _addPlace(int day) async {
    final result = await Navigator.push<Destination>(
      context,
      MaterialPageRoute(
        builder: (context) => AddPlaceScreen(targetDay: day),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _itinerary[day] ??= [];
        _itinerary[day]!.add(result);
      });

      _showSnackBar('${result.name} added to Day $day');
    }
  }

  void _addFriends() {
    final controller = TextEditingController();
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
            const SizedBox(height: 8),
            const Text('Add names or emails separated by commas.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'friend1@email.com, Friend 2',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sharedWith
                  .map(
                    (recipient) => Chip(
                      label: Text(recipient),
                      onDeleted: () {
                        setState(() => _sharedWith.remove(recipient));
                        Navigator.pop(context);
                        _addFriends();
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final additions = controller.text
                      .split(',')
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .toList();
                  setState(() {
                    _sharedWith
                      ..addAll(additions)
                      ..sort();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _sharedWith.isEmpty
                            ? 'Plan stays private'
                            : 'Plan shared with ${_sharedWith.join(', ')}',
                      ),
                    ),
                  );
                },
                child: const Text('Save Sharing'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPlaceAfter(int day, int index) async {
    final result = await Navigator.push<Destination>(
      context,
      MaterialPageRoute(
        builder: (context) => AddPlaceScreen(targetDay: day),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _itinerary[day] ??= [];
        // Insert the new destination after the specified index
        _itinerary[day]!.insert(index + 1, result);
        // Set a default time for the new destination
        _destinationTimes[result.id] = '11:30 AM';
      });

      _showSnackBar('${result.name} added after position ${index + 1}');
    }
  }

  void _removeDestination(int day, int index) {
    final destination = _itinerary[day]![index];
    setState(() {
      _itinerary[day]!.removeAt(index);
      _destinationTimes.remove(destination.id);
      _visitedDestinations.remove(destination.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${destination.name} removed')),
    );
  }

  void _startLocationChecking() {
    // Check location every 30 seconds
    _locationCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkDestinationProximity();
    });
  }

  void _checkDestinationProximity() {
    // Update visited status based on current visible destination
    // In a real implementation, this would use actual GPS coordinates
    // For now, mark destinations as visited when they're the current visible one

    if (_startDate == null || _endDate == null) return;

    final days = _endDate!.difference(_startDate!).inDays + 1;

    for (int day = 1; day <= days; day++) {
      final destinations = _itinerary[day] ?? [];

      for (int destIndex = 0; destIndex < destinations.length; destIndex++) {
        final destination = destinations[destIndex];
        final isVisited = _visitedDestinations[destination.id] ?? false;
        final isCurrentVisible = day == _currentVisibleDay &&
            destIndex == _currentVisibleDestination;

        // Mark destination as visited when it's current visible one
        if (isCurrentVisible && !isVisited) {
          setState(() {
            _visitedDestinations[destination.id] = true;
          });

          _showSnackBar(
            'You arrived at ${destination.name}! Marked as visited.',
          );
          return;
        }
      }
    }
  }

  Future<void> _savePlan() async {
    // Title validation
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plan title')),
      );
      return;
    }
    if (title.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Plan title must be at least 3 characters')),
      );
      return;
    }

    // Date validation
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range')),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    // Destination validation
    bool hasDestinations = false;
    for (final dayDestinations in _itinerary.values) {
      if (dayDestinations.isNotEmpty) {
        hasDestinations = true;
        break;
      }
    }

    if (!hasDestinations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one destination')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save the plan using the service with complete itinerary data
      String? bannerImagePath;

      // Handle user-picked banner image
      if (_bannerImage != null) {
        // In a real app, you'd upload this to a server and get a URL
        // For now, create a consistent URL based on file name
        final fileName = _bannerImage!.path.split('/').last;
        final seed = '${_titleController.text.trim()}_$fileName';
        bannerImagePath = 'https://picsum.photos/seed/$seed/400/200';
      } else {
        // Generate a consistent banner image URL using fixed pattern
        final titleHash = _titleController.text.trim().hashCode.abs();
        final dateHash = _startDate!.millisecondsSinceEpoch.abs();
        final seed = 'halaph_${titleHash}_$dateHash';
        bannerImagePath = 'https://picsum.photos/seed/$seed/400/200';
      }

      // Convert itinerary map to list of destinations
      final allDestinations = <Destination>[];
      final customItinerary = <DayItinerary>[];
      for (final dayDests in _itinerary.values) {
        allDestinations.addAll(dayDests);
      }

      final dayNumbers = _itinerary.keys.toList()..sort();
      for (final dayNumber in dayNumbers) {
        final destinations = _itinerary[dayNumber] ?? const <Destination>[];
        final items = destinations.asMap().entries.map((entry) {
          final destination = entry.value;
          final time = _parseTime(_destinationTimes[destination.id] ?? '10:30 AM');
          return ItineraryItem(
            id: 'item_${dayNumber}_${entry.key}_${destination.id}',
            destination: destination,
            startTime: time,
            endTime: TimeOfDay(
              hour: (time.hour + 2) % 24,
              minute: time.minute,
            ),
            dayNumber: dayNumber,
            notes: 'Visit ${destination.name}',
          );
        }).toList();

        customItinerary.add(
          DayItinerary(
            date: _startDate!.add(Duration(days: dayNumber - 1)),
            items: items,
          ),
        );
      }

      final savedPlan = await PlanService.createPlan(
        title: _titleController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        destinations: allDestinations,
        customItinerary: customItinerary,
        bannerImage: bannerImagePath,
        sharedWith: _sharedWith,
        reminderEnabled: _reminderEnabled,
        reminderMinutesBefore: _reminderMinutesBefore,
      );

      if (!mounted) return;
      _showSnackBar('Plan "${savedPlan.title}" saved successfully!');

      context.pushReplacement('/plan-details?planId=${savedPlan.id}');
    } catch (e) {
      _showSnackBar('Failed to save plan. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectTimeForDestination(Destination destination) async {
    final currentTime = _destinationTimes[destination.id] ?? '10:30 AM';
    final hour = int.parse(currentTime.split(':')[0]);
    final minute = int.parse(currentTime.split(':')[1].split(' ')[0]);
    final isPM = currentTime.contains('PM');

    final initialTime = TimeOfDay(
      hour: isPM && hour < 12
          ? hour + 12
          : (hour == 12 && !isPM)
              ? 0
              : hour,
      minute: minute,
    );

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (!mounted) return;
    if (pickedTime != null) {
      final hourStr = pickedTime.hourOfPeriod.toString().padLeft(2, '0');
      final minuteStr = pickedTime.minute.toString().padLeft(2, '0');
      final period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
      final newTime = '$hourStr:$minuteStr $period';

      setState(() {
        _destinationTimes[destination.id] = newTime;
      });

      _showSnackBar('Time updated to $newTime');
    }
  }

  TimeOfDay _parseTime(String value) {
    final pieces = value.split(' ');
    final timePart = pieces.first.split(':');
    final rawHour = int.parse(timePart[0]);
    final minute = int.parse(timePart[1]);
    final isPm = pieces.length > 1 && pieces[1].toUpperCase() == 'PM';
    final hour = isPm
        ? (rawHour == 12 ? 12 : rawHour + 12)
        : (rawHour == 12 ? 0 : rawHour);
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _handleDrop(DestinationData data, int toDay, int toIndex) {
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

    _showSnackBar(
      data.fromDay == toDay
          ? 'Moved ${data.destination.name} to position ${toIndex + 1}'
          : 'Moved ${data.destination.name} from Day ${data.fromDay} to Day $toDay',
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Blank Plan',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePlan,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Banner Section with Editable Title
            _buildBannerSection(),

            // Action Buttons
            _buildActionButtons(),

            // Main Content - Circles and Cards aligned together
            _buildAlignedItinerarySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSection() {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[300],
      ),
      child: Stack(
        children: [
          // Banner Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _bannerImage != null
                ? Image.file(
                    _bannerImage!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultBanner();
                    },
                  )
                : _buildDefaultBanner(),
          ),

          // Overlay with Title and Date
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Editable Title
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Untitled',
                      hintStyle: TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date Range Selector
                  InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getDateRangeText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Change Banner Button
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: _pickBannerImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[400]!,
            Colors.grey[600]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          size: 50,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _addPlace(1), // Default to Day 1
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Place',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _addFriends,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Friends',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _reminderEnabled,
                  onChanged: (value) {
                    setState(() => _reminderEnabled = value);
                  },
                  title: const Text('Use phone time/day for reminders'),
                  subtitle: const Text(
                    'Reminder scheduling follows the device clock.',
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 8),
                    const Text('Notify before first stop'),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _reminderMinutesBefore,
                      items: const [15, 30, 60, 120]
                          .map(
                            (minutes) => DropdownMenuItem<int>(
                              value: minutes,
                              child: Text('$minutes min'),
                            ),
                          )
                          .toList(),
                      onChanged: _reminderEnabled
                          ? (value) {
                              if (value != null) {
                                setState(() => _reminderMinutesBefore = value);
                              }
                            }
                          : null,
                    ),
                  ],
                ),
                if (_sharedWith.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sharedWith.map((recipient) {
                        return Chip(
                          label: Text(recipient),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() => _sharedWith.remove(recipient));
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignedItinerarySection() {
    if (_startDate == null || _endDate == null) {
      return const Center(
        child: Text(
          'Please select a date range to start planning',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    final days = _endDate!.difference(_startDate!).inDays + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ...List.generate(days, (index) {
            final dayNumber = index + 1;

            return _buildAlignedDayCard(dayNumber);
          }),
        ],
      ),
    );
  }

  Widget _buildAlignedDayCard(int dayNumber) {
    final destinations = _itinerary[dayNumber] ?? [];

    return Column(
      children: [
        // Day header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Itinerary Day $dayNumber',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (_startDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(
                            _startDate!.add(Duration(days: dayNumber - 1))),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Add place button for this day
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () => _addPlace(dayNumber),
                  icon: const Icon(Icons.add, color: Colors.white),
                  iconSize: 18,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Destinations with circles aligned in same Row
        if (destinations.isEmpty)
          DragTarget<DestinationData>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              _handleDrop(details.data, dayNumber, 0);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isHovering ? Colors.blue[50] : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      isHovering ? Border.all(color: Colors.blue[300]!) : null,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          isHovering
                              ? Icons.add_circle_outline
                              : Icons.place_outlined,
                          size: 32,
                          color:
                              isHovering ? Colors.blue[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isHovering
                              ? 'Drop destination here'
                              : 'No places added yet',
                          style: TextStyle(
                            color: isHovering
                                ? Colors.blue[600]
                                : Colors.grey[500],
                            fontSize: 14,
                            fontWeight: isHovering
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        else
          Column(
            children: [
              ...destinations.asMap().entries.map((entry) {
                final index = entry.key;
                final destination = entry.value;
                return _buildAlignedDestinationItem(
                    destination, dayNumber, index);
              }),
              // Add drop target at the end of the day for inserting destinations
              DragTarget<DestinationData>(
                onWillAcceptWithDetails: (details) => true,
                onAcceptWithDetails: (details) {
                  _handleDrop(details.data, dayNumber, destinations.length);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 16),
                    height: isHovering ? 60 : 40,
                    decoration: BoxDecoration(
                      color: isHovering ? Colors.blue[50] : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isHovering
                          ? Border.all(color: Colors.blue[300]!)
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        size: 24,
                        color: isHovering ? Colors.blue[600] : Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAlignedDestinationItem(
      Destination destination, int day, int index) {
    final time = _destinationTimes[destination.id] ?? '10:30 AM';
    final isVisited = _visitedDestinations[destination.id] ?? false;
    final isLastDestination = index == (_itinerary[day]?.length ?? 0) - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle on the left with absolute positioned line
          SizedBox(
            width: 40,
            child: Stack(
              children: [
                // Background connecting line (doesn't affect positioning)
                if (!isLastDestination)
                  Positioned(
                    left: 19, // Center of 40px container (20 - 1)
                    top: 80, // Start from circle center
                    child: Container(
                      width: 2,
                      height: 240,
                      color: Colors.grey[300],
                    ),
                  ),

                // Circle (positioned normally)
                Column(
                  children: [
                    const SizedBox(height: 80), // Center of 160px image
                    Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isVisited ? Colors.orange : Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 80), // Rest of card height
                  ],
                ),
              ],
            ),
          ),

          // Card on the right with enhanced drag and drop
          Expanded(
            child: LongPressDraggable<DestinationData>(
              data: DestinationData(
                  destination: destination, fromDay: day, fromIndex: index),
              feedback: Material(
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
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(color: Colors.blue[300]!, width: 2),
                  ),
                  child: Transform.rotate(
                    angle: 0.05, // Slight rotation for drag effect
                    child: Opacity(
                      opacity: 0.9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Actual image in feedback
                          Container(
                            width: double.infinity,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              color: Colors.grey[200],
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              child: destination.imageUrl.isNotEmpty &&
                                      destination.imageUrl.startsWith('http')
                                  ? Image.network(
                                      destination.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return _buildDefaultDestinationImage(
                                            destination.category);
                                      },
                                    )
                                  : _buildDefaultDestinationImage(
                                      destination.category),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              childWhenDragging: Container(
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
              ),
              child: DragTarget<DestinationData>(
                onWillAcceptWithDetails: (details) {
                  return details.data.destination.id != destination.id;
                },
                onAcceptWithDetails: (details) {
                  _handleDrop(details.data, day, index);
                },
                onMove: (details) {
                  // Optional: Add haptic feedback or other interactions
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isHovering ? Colors.blue[50] : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: isHovering
                                ? Colors.blue.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: isHovering ? 16 : 12,
                            offset: Offset(0, isHovering ? 6 : 4),
                          ),
                        ],
                        border: isHovering
                            ? Border.all(
                                color: Colors.blue[400]!,
                                width: 3,
                              )
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image section with time overlay
                          Stack(
                            children: [
                              // Destination Image
                              Container(
                                width: double.infinity,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12)),
                                  color: Colors.grey[200],
                                ),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12)),
                                  child: destination.imageUrl.isNotEmpty &&
                                          destination.imageUrl
                                              .startsWith('http')
                                      ? Image.network(
                                          destination.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return _buildDefaultDestinationImage(
                                                destination.category);
                                          },
                                        )
                                      : _buildDefaultDestinationImage(
                                          destination.category),
                                ),
                              ),

                              // Gradient overlay
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(12)),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.7),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Time overlay
                              Positioned(
                                top: 12,
                                left: 12,
                                child: GestureDetector(
                                  onTap: () =>
                                      _selectTimeForDestination(destination),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          time,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Location info overlay
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      destination.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      destination.location,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Action buttons section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Add Place After button
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _addPlaceAfter(day, index),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side:
                                          const BorderSide(color: Colors.blue),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('+ Place After'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Delete button
                                OutlinedButton(
                                  onPressed: () =>
                                      _removeDestination(day, index),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Icon(Icons.delete, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultDestinationImage(DestinationCategory category) {
    Color startColor, endColor;
    IconData iconData;

    switch (category) {
      case DestinationCategory.park:
        startColor = const Color(0xFF81C784);
        endColor = const Color(0xFF4CAF50);
        iconData = Icons.park;
        break;
      case DestinationCategory.landmark:
        startColor = const Color(0xFF64B5F6);
        endColor = const Color(0xFF2196F3);
        iconData = Icons.location_city;
        break;
      case DestinationCategory.food:
        startColor = const Color(0xFFFFB74D);
        endColor = const Color(0xFFFF9800);
        iconData = Icons.restaurant;
        break;
      case DestinationCategory.activities:
        startColor = const Color(0xFFBA68C8);
        endColor = const Color(0xFF9C27B0);
        iconData = Icons.beach_access;
        break;
      case DestinationCategory.museum:
        startColor = const Color(0xFFF06292);
        endColor = const Color(0xFFE91E63);
        iconData = Icons.museum;
        break;
      case DestinationCategory.market:
        startColor = const Color(0xFF4DB6AC);
        endColor = const Color(0xFF009688);
        iconData = Icons.shopping_cart;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getDateRangeText() {
    if (_startDate == null || _endDate == null) {
      return 'Set date';
    }

    final startFormat = '${_startDate!.month}/${_startDate!.day}';
    final endFormat = '${_endDate!.month}/${_endDate!.day}';

    if (_startDate!.year == _endDate!.year) {
      return '$startFormat - $endFormat';
    } else {
      return '$startFormat/${_startDate!.year} - $endFormat/${_endDate!.year}';
    }
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
    return '${months[date.month - 1]} ${date.day}';
  }
}
