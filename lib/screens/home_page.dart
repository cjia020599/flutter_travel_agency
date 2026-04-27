import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_client.dart';
import '../api/tours_api.dart';
import '../api/cars_api.dart';
import '../api/lookups_api.dart';
import '../api/auth_api.dart';
import '../api/user_api.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'user_profile_page.dart';
import '../models/car_rental.dart';
import '../api/car_rentals_api.dart';
import '../api/tour_bookings_api.dart';
import '../api/ratings_api.dart';
import '../api/notifications_api.dart';
import 'package:intl/intl.dart';
import '../models/notification_item.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Design colors
const _navBlue = Color(0xFF1E3A5F);
const _topBarGrey = Color(0xFF2C3E50);
const _primaryBlue = Color(0xFF2563EB);
const _accentOrange = Color(0xFFEAB308);
const _saleRed = Color(0xFFDC2626);
const _hotPurple = Color(0xFF7C3AED);

/// Philippine peso for prices shown on the home experience.
const String _peso = '\u20B1';

enum _NavItem { home, tours, cars }

class TravelHomePage extends StatefulWidget {
  const TravelHomePage({super.key});

  @override
  State<TravelHomePage> createState() => _TravelHomePageState();
}

class _TravelHomePageState extends State<TravelHomePage> {
  int _searchTabIndex = 0;
  final _searchTabs = ['Tours', 'Cars'];

  _NavItem _current = _NavItem.home;
  RangeValues _priceRange = const RangeValues(50, 300);

  bool _isLoggedIn = false;
  bool _isAdmin = false;
  String? _userDisplayName;
  List<dynamic> _tours = [];
  List<dynamic> _cars = [];
  List<dynamic> _locations = [];
  List<CarRental> _rentals = [];
  final Map<String, List<dynamic>> _ratingsByKey = {};
  final Map<String, bool> _ratingsLoadingByKey = {};
  List<NotificationItem> _notifications = [];
  bool _notificationsLoading = false;
  WebSocketChannel? _notificationsChannel;
  StreamSubscription? _notificationsSub;
  Timer? _notificationsPollTimer;
  DateTime? _lastWsMessageAt;
  bool _notificationsConnecting = false;
  int _wsReconnectAttempts = 0;
  DateTimeRange _filterDateRange = DateTimeRange(
    start: DateTime.now().add(const Duration(days: 1)),
    end: DateTime.now().add(const Duration(days: 5)),
  );

  late final TextEditingController _locationQueryController;
  late final TextEditingController _filterGuestsController;
  final Set<String> _starFilters = {};
  final Set<String> _tourAvailabilityFilters = {};
  final Set<String> _carCapacityFilters = {};
  final Map<String, double> _avgRatingByKey = {};
  final Map<String, int> _ratingCountByKey = {};

  @override
  void initState() {
    super.initState();
    _locationQueryController = TextEditingController()
      ..addListener(_onSearchFiltersChanged);
    _filterGuestsController = TextEditingController(text: '2')
      ..addListener(_onSearchFiltersChanged);
    _loadData();
  }

  void _onSearchFiltersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _locationQueryController.dispose();
    _filterGuestsController.dispose();
    _disconnectNotifications();
    _notificationsPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loggedIn = await ApiClient.instance.isLoggedIn;
    Map<String, dynamic>? profile;
    if (loggedIn) {
      try {
        profile = await UserApi.getProfile();
      } catch (_) {
        profile = null;
      }
    }
    final isAdmin = await UserApi.isAdmin();
    final tours = await ToursApi.list();
    final cars = await CarsApi.list();
    final locations = await LookupsApi.locations();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _isAdmin = isAdmin;
      _tours = tours;
      _cars = cars;
      _locations = locations;
      _userDisplayName = _displayNameFromProfile(profile);
    });
    await _loadRentals();
    await _syncNotifications();
    await _refreshAggregateRatings();
  }

  Future<void> _loadRentals() async {
    if (!_isLoggedIn) {
      if (mounted) setState(() => _rentals = []);
      return;
    }
    try {
      final rentals = await CarRentalsApi.getCarRentals();
      if (mounted) setState(() => _rentals = rentals);
    } catch (e) {
      if (mounted) setState(() => _rentals = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load rentals: $e')),
      );
    }
  }

  int get _unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  String _displayNameFromProfile(Map<String, dynamic>? profile) {
    final raw = profile?['firstName'] ??
        profile?['name'] ??
        profile?['userName'] ??
        profile?['username'] ??
        profile?['email'];
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return 'User';
    return value;
  }

  List<String> _locationOptions() {
    final values = _locations
        .map((loc) => (loc is Map ? loc['name'] : loc)?.toString() ?? '')
        .where((name) => name.trim().isNotEmpty)
        .map((name) => name.trim())
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  Widget _buildLocationDropdownField({
    required String hintText,
    String? labelText,
    EdgeInsets? contentPadding,
    double borderRadius = 8,
  }) {
    final options = _locationOptions();
    return Autocomplete<String>(
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return options;
        return options.where((name) => name.toLowerCase().contains(query));
      },
      onSelected: (value) {
        _locationQueryController.text = value;
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        if (textController.text != _locationQueryController.text) {
          textController.text = _locationQueryController.text;
          textController.selection = TextSelection.collapsed(
            offset: textController.text.length,
          );
        }
        return TextField(
          controller: textController,
          focusNode: focusNode,
          onChanged: (value) {
            if (_locationQueryController.text != value) {
              _locationQueryController.text = value;
            }
          },
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            contentPadding:
                contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      },
    );
  }

  Future<void> _confirmAndLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthApi.logout();
    _loadData();
  }

  Future<void> _syncNotifications() async {
    if (!_isLoggedIn) {
      _disconnectNotifications();
      _notificationsPollTimer?.cancel();
      if (mounted) {
        setState(() {
          _notifications = [];
          _notificationsLoading = false;
        });
      }
      return;
    }

    await _fetchNotifications();
    _startNotificationsPolling();
    await _connectNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (mounted) {
      setState(() => _notificationsLoading = true);
    }
    try {
      final items = await NotificationsApi.list(page: 1, limit: 50, unreadOnly: false);
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _notifications = items;
          _notificationsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _notificationsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }
  }

  void _startNotificationsPolling() {
    _notificationsPollTimer?.cancel();
    if (!_isLoggedIn || !mounted) return;
    _notificationsPollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || !_isLoggedIn) return;
      // If WS is quiet, poll to keep UI fresh.
      final lastWs = _lastWsMessageAt;
      final tooQuiet = lastWs == null || DateTime.now().difference(lastWs) > const Duration(seconds: 30);
      if (tooQuiet) {
        await _fetchNotifications();
      }
    });
  }

  Future<void> _connectNotifications() async {
    if (_notificationsChannel != null || _notificationsConnecting) return;
    _notificationsConnecting = true;

    final token = await ApiClient.instance.getToken();
    if (token == null || token.isEmpty) {
      _notificationsConnecting = false;
      return;
    }

    final baseUri = Uri.parse(baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = baseUri.hasPort
        ? Uri(
            scheme: wsScheme,
            userInfo: baseUri.userInfo,
            host: baseUri.host,
            port: baseUri.port,
            path: '/ws/notifications',
            queryParameters: {'token': token},
          )
        : Uri(
            scheme: wsScheme,
            userInfo: baseUri.userInfo,
            host: baseUri.host,
            path: '/ws/notifications',
            queryParameters: {'token': token},
          );

    _notificationsChannel = WebSocketChannel.connect(wsUri);
    _notificationsSub = _notificationsChannel!.stream.listen(
      (message) {
        _lastWsMessageAt = DateTime.now();
        try {
          final data = jsonDecode(message.toString());
          if (data is Map<String, dynamic>) {
            _handleIncomingNotification(NotificationItem.fromJson(data));
          } else if (data is Map) {
            _handleIncomingNotification(NotificationItem.fromJson(Map<String, dynamic>.from(data)));
          }
        } catch (_) {
          // ignore malformed messages
        }
      },
      onError: (_) {
        _disconnectNotifications();
        _scheduleNotificationsReconnect();
      },
      onDone: () {
        _disconnectNotifications();
        _scheduleNotificationsReconnect();
      },
    );
    _wsReconnectAttempts = 0;
    _notificationsConnecting = false;
  }

  void _disconnectNotifications() {
    _notificationsSub?.cancel();
    _notificationsSub = null;
    _notificationsChannel?.sink.close();
    _notificationsChannel = null;
  }

  void _scheduleNotificationsReconnect() {
    if (!_isLoggedIn || !mounted) return;
    _wsReconnectAttempts = (_wsReconnectAttempts + 1).clamp(1, 8);
    final delaySeconds = 2 * _wsReconnectAttempts;
    Future.delayed(Duration(seconds: delaySeconds), () {
      if (!mounted || !_isLoggedIn || _notificationsChannel != null) return;
      _connectNotifications();
    });
  }

  void _handleIncomingNotification(NotificationItem item) {
    if (!mounted) return;
    setState(() {
      _notifications.removeWhere((n) => n.id == item.id);
      _notifications.insert(0, item);
    });
  }

  Future<void> _markNotificationRead(NotificationItem item) async {
    if (item.isRead) return;
    try {
      final updated = await NotificationsApi.markRead(item.id);
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map((n) => n.id == item.id ? updated : n)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark read: $e')),
        );
      }
    }
  }

  Future<void> _openNotificationsDialog() async {
    if (!_isLoggedIn) {
      await _promptLoginIfNeeded();
      return;
    }

    await showGeneralDialog(
      context: context,
      barrierLabel: 'Notifications',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.08),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.of(context).size;
        final panelWidth = size.width < 520 ? size.width - 32 : 360.0;
        final panelHeight = size.height < 720 ? size.height * 0.55 : 480.0;
        final rightOffset = size.width < 520 ? 16.0 : 48.0;
        const topOffset = 56.0;

        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned(
                top: topOffset,
                right: rightOffset,
                child: _buildNotificationsPanel(
                  width: panelWidth,
                  height: panelHeight,
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  String _ratingsKey(String moduleType, int moduleId) => '$moduleType:$moduleId';

  void _updateAvgRatingFromList(String moduleType, int moduleId, List<dynamic> ratings) {
    final key = _ratingsKey(moduleType, moduleId);
    if (ratings.isEmpty) {
      _avgRatingByKey.remove(key);
      _ratingCountByKey.remove(key);
      return;
    }
    final sum = ratings.fold<double>(
      0,
      (a, r) => a + (double.tryParse((r is Map ? r['stars'] : null)?.toString() ?? '0') ?? 0),
    );
    _avgRatingByKey[key] = sum / ratings.length;
    _ratingCountByKey[key] = ratings.length;
  }

  Future<void> _refreshAggregateRatings() async {
    try {
      final all = await RatingsApi.list();
      if (!mounted) return;
      final sums = <String, double>{};
      final counts = <String, int>{};
      for (final r in all) {
        if (r is! Map) continue;
        final mt = r['moduleType']?.toString();
        final mid = int.tryParse(r['moduleId']?.toString() ?? '');
        if (mt == null || mid == null) continue;
        final stars = double.tryParse(r['stars']?.toString() ?? '') ?? 0;
        final k = _ratingsKey(mt, mid);
        sums[k] = (sums[k] ?? 0) + stars;
        counts[k] = (counts[k] ?? 0) + 1;
      }
      setState(() {
        _avgRatingByKey.clear();
        _ratingCountByKey.clear();
        sums.forEach((k, sum) {
          final c = counts[k] ?? 1;
          _avgRatingByKey[k] = sum / c;
          _ratingCountByKey[k] = c;
        });
      });
    } catch (_) {}
  }

  double? _itemPrice(Map<String, dynamic> item) {
    final sale = double.tryParse(item['salePrice']?.toString() ?? '');
    final reg = double.tryParse(item['price']?.toString() ?? '');
    if (sale != null && sale > 0) return sale;
    if (reg != null && reg > 0) return reg;
    if (sale != null) return sale;
    return reg;
  }

  double? _avgRating(String moduleType, int id) => _avgRatingByKey[_ratingsKey(moduleType, id)];

  int? _ratingCount(String moduleType, int id) => _ratingCountByKey[_ratingsKey(moduleType, id)];

  int get _effectiveGuestCount {
    final raw = _filterGuestsController.text.trim();
    if (raw.isEmpty) return 1;
    final n = int.tryParse(raw);
    if (n == null || n < 1) return 1;
    return n;
  }

  bool _itemIsFeatured(Map<String, dynamic> m) =>
      m['isFeatured'] == true || m['featured'] == true;

  String _priceLabel(dynamic price, {required bool perPerson}) {
    if (price == null) return '';
    return '$_peso$price${perPerson ? ' / person' : ' / day'}';
  }

  DateTime? _tryParseDateField(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  bool _passesPrice(Map<String, dynamic> item) {
    final p = _itemPrice(item);
    if (p == null) return true;
    return p >= _priceRange.start && p <= _priceRange.end;
  }

  bool _passesLocation(Map<String, dynamic> item, {required bool isTour}) {
    final q = _locationQueryController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final title = (item['title'] ?? '').toString().toLowerCase();
    final addr = (item['realTourAddress'] ?? '').toString().toLowerCase();
    if (title.contains(q) || addr.contains(q)) return true;
    if (!isTour) return false;
    final lid = item['locationId']?.toString();
    if (lid == null) return false;
    for (final loc in _locations) {
      if (loc is Map) {
        if (loc['id']?.toString() == lid) {
          final name = (loc['name'] ?? '').toString().toLowerCase();
          if (name.contains(q)) return true;
        }
      }
    }
    return false;
  }

  bool _passesGuests(Map<String, dynamic> item, {required bool isTour}) {
    if (isTour) return true;
    final cap = int.tryParse(item['passenger']?.toString() ?? '') ?? 0;
    if (cap <= 0) return true;
    return cap >= _effectiveGuestCount;
  }

  bool _passesDateRange(Map<String, dynamic> item) {
    final from = _tryParseDateField(
      item['availableFrom'] ?? item['available_from'] ?? item['startDate'] ?? item['start_date'],
    );
    final to = _tryParseDateField(
      item['availableTo'] ?? item['available_to'] ?? item['endDate'] ?? item['end_date'],
    );
    if (from == null && to == null) return true;
    final rs = _filterDateRange.start;
    final re = _filterDateRange.end;
    final effFrom = from ?? rs.subtract(const Duration(days: 5000));
    final effTo = to ?? re.add(const Duration(days: 5000));
    return !effTo.isBefore(rs) && !effFrom.isAfter(re);
  }

  bool _passesStarFilters(String moduleType, int id) {
    if (_starFilters.isEmpty) return true;
    final avg = _avgRating(moduleType, id);
    if (avg == null) return false;
    for (final s in _starFilters) {
      if (s == '5' && avg >= 4.5) return true;
      if (s == '4' && avg >= 3.5 && avg < 4.5) return true;
      if (s == '3' && avg >= 2.5 && avg < 3.5) return true;
      if (s == '2' && avg >= 1.5 && avg < 2.5) return true;
      if (s == '1' && avg < 1.5) return true;
    }
    return false;
  }

  bool _passesPropertyFilters(Map<String, dynamic> item, {required bool isTour}) {
    if (isTour) {
      if (_tourAvailabilityFilters.isEmpty) return true;
      final a = item['availability']?.toString();
      if (_tourAvailabilityFilters.contains('always') && a == 'always') return true;
      if (_tourAvailabilityFilters.contains('fixed') && a == 'fixed') return true;
      if (_tourAvailabilityFilters.contains('open_hours') && a == 'open_hours') return true;
      return false;
    }

    if (_carCapacityFilters.isEmpty) return true;
    final pass = int.tryParse(item['passenger']?.toString() ?? '') ?? 0;
    if (_carCapacityFilters.contains('small') && pass >= 1 && pass <= 4) return true;
    if (_carCapacityFilters.contains('medium') && pass >= 5 && pass <= 7) return true;
    if (_carCapacityFilters.contains('large') && pass >= 8) return true;
    return false;
  }

  List<dynamic> get _filteredTours {
    return _tours.where((raw) {
      final t = raw as Map<String, dynamic>;
      final id = t['id'] is int ? t['id'] as int : int.tryParse(t['id']?.toString() ?? '') ?? 0;
      if (!_passesPrice(t)) return false;
      if (!_passesLocation(t, isTour: true)) return false;
      if (!_passesDateRange(t)) return false;
      if (!_passesStarFilters('tour', id)) return false;
      if (!_passesPropertyFilters(t, isTour: true)) return false;
      return true;
    }).toList();
  }

  List<dynamic> get _filteredCars {
    return _cars.where((raw) {
      final c = raw as Map<String, dynamic>;
      final id = c['id'] is int ? c['id'] as int : int.tryParse(c['id']?.toString() ?? '') ?? 0;
      if (!_passesPrice(c)) return false;
      if (!_passesLocation(c, isTour: false)) return false;
      if (!_passesGuests(c, isTour: false)) return false;
      if (!_passesDateRange(c)) return false;
      if (!_passesStarFilters('car', id)) return false;
      if (!_passesPropertyFilters(c, isTour: false)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickFilterStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDateRange.start.isBefore(today) ? today : _filterDateRange.start,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null && mounted) {
      setState(() {
        var end = _filterDateRange.end;
        if (!end.isAfter(picked)) {
          end = picked.add(const Duration(days: 1));
        }
        _filterDateRange = DateTimeRange(start: picked, end: end);
      });
    }
  }

  Future<void> _pickFilterEndDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = _filterDateRange.start.isBefore(today) ? today : _filterDateRange.start;
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDateRange.end.isBefore(start) ? start.add(const Duration(days: 1)) : _filterDateRange.end,
      firstDate: start,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null && mounted) {
      setState(() => _filterDateRange = DateTimeRange(start: start, end: picked));
    }
  }

  Widget _filterStartDateField({
    double borderRadius = 8,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    String label = 'Start date',
  }) {
    final fmt = DateFormat('MMM d, yyyy');
    return InkWell(
      onTap: _pickFilterStartDate,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
          contentPadding: contentPadding,
        ),
        child: Text(
          fmt.format(_filterDateRange.start),
          style: TextStyle(color: Colors.grey[800], fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _filterEndDateField({
    double borderRadius = 8,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    String label = 'End date',
  }) {
    final fmt = DateFormat('MMM d, yyyy');
    return InkWell(
      onTap: _pickFilterEndDate,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
          contentPadding: contentPadding,
        ),
        child: Text(
          fmt.format(_filterDateRange.end),
          style: TextStyle(color: Colors.grey[800], fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _filterGuestsTextField({
    double? width,
    double borderRadius = 8,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    String? labelText,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: _filterGuestsController,
        decoration: InputDecoration(
          labelText: labelText ?? 'Guests',
          hintText: 'Guests',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius)),
          contentPadding: contentPadding,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  void _goToSearchTab(int tabIndex) {
    setState(() {
      _searchTabIndex = tabIndex;
      _current = tabIndex == 0 ? _NavItem.tours : _NavItem.cars;
    });
  }

  String _itemImageUrl(Map<String, dynamic> item) {
    final u = item['imageUrl']?.toString().trim();
    if (u != null && u.isNotEmpty) return u;
    return 'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=600';
  }

  int _itemId(Map<String, dynamic> item) {
    final id = item['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '') ?? 0;
  }

  Future<List<dynamic>> _loadRatingsFor(String moduleType, int moduleId) async {
    final key = _ratingsKey(moduleType, moduleId);
    if (mounted) {
      setState(() {
        _ratingsLoadingByKey[key] = true;
      });
    }
    try {
      final ratings = await RatingsApi.list(moduleType: moduleType, moduleId: moduleId);
      print('DEBUG _loadRatingsFor($moduleType, $moduleId): Got ${ratings.length} ratings');
      if (mounted) {
        setState(() {
          _ratingsByKey[key] = ratings;
          _ratingsLoadingByKey[key] = false;
          _updateAvgRatingFromList(moduleType, moduleId, ratings);
        });
      }
      return ratings;
    } catch (e) {
      print('DEBUG _loadRatingsFor error: $e');
      if (mounted) {
        setState(() {
          _ratingsByKey[key] = [];
          _ratingsLoadingByKey[key] = false;
          _updateAvgRatingFromList(moduleType, moduleId, []);
        });
      }
      return [];
    }
  }

  Future<void> _promptLoginIfNeeded() async {
    if (_isLoggedIn) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        title: const Text('Sign In'),
        content: LoginDialogContent(onSuccess: _loadData),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    await _loadData();
  }

  int? _extractUserId(dynamic rating) {
    if (rating is! Map) return null;
    final user = rating['user'];
    if (user is Map && user['id'] != null) {
      return int.tryParse(user['id'].toString());
    }
    if (rating['userId'] != null) {
      return int.tryParse(rating['userId'].toString());
    }
    return null;
  }

  Future<void> _upsertRating({
    required String moduleType,
    required int moduleId,
    Map<String, dynamic>? existing,
  }) async {
    if (!_isLoggedIn) {
      await _promptLoginIfNeeded();
      if (!_isLoggedIn) return;
    }

    final starsController = TextEditingController(
      text: (existing?['stars']?.toString() ?? '5'),
    );
    final commentController = TextEditingController(
      text: existing?['comment']?.toString() ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Rating' : 'Edit Rating'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: starsController,
                decoration: const InputDecoration(
                  labelText: 'Stars (1-5)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final stars = int.tryParse(starsController.text.trim());
    if (stars == null || stars < 1 || stars > 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stars must be an integer from 1 to 5')),
        );
      }
      return;
    }

    try {
      if (existing == null) {
        final createRes = await RatingsApi.create(
          moduleType: moduleType,
          moduleId: moduleId,
          stars: stars,
          comment: commentController.text.trim(),
        );
        print('DEBUG: Rating created successfully: $createRes');
      } else {
        final ratingId = int.tryParse(existing['id'].toString());
        if (ratingId == null) {
          throw Exception('Invalid rating ID');
        }
        await RatingsApi.update(
          ratingId,
          stars: stars,
          comment: commentController.text.trim(),
        );
      }

      print('DEBUG: About to call _loadRatingsFor($moduleType, $moduleId)');
      final loadedRatings = await _loadRatingsFor(moduleType, moduleId);
      print('DEBUG: _loadRatingsFor returned ${loadedRatings.length} ratings');
      print('DEBUG: Loaded ratings: $loadedRatings');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Rating added' : 'Rating updated')),
        );
      }
    } catch (e) {
      print('DEBUG: Error in _upsertRating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rating save failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteRating({
    required String moduleType,
    required int moduleId,
    required int ratingId,
  }) async {
    if (!_isLoggedIn) {
      await _promptLoginIfNeeded();
      if (!_isLoggedIn) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rating'),
        content: const Text('Are you sure you want to delete this rating?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await RatingsApi.delete(ratingId);
      await _loadRatingsFor(moduleType, moduleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Widget _buildRatingsSection({
    required String moduleType,
    required int moduleId,
  }) {
    final key = _ratingsKey(moduleType, moduleId);
    final ratings = _ratingsByKey[key] ?? const [];
    final isLoading = _ratingsLoadingByKey[key] == true;
    final avg = ratings.isEmpty
        ? 0.0
        : ratings
                .map((r) => double.tryParse((r['stars'] ?? 0).toString()) ?? 0.0)
                .reduce((a, b) => a + b) /
            ratings.length;
    final currentUserId = int.tryParse((_clientCurrentUserIdCached ?? '').toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ratings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(width: 8),
            if (ratings.isNotEmpty)
              Text(
                '${avg.toStringAsFixed(1)} / 5 (${ratings.length})',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _upsertRating(moduleType: moduleType, moduleId: moduleId),
              icon: const Icon(Icons.rate_review, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          )
        else if (ratings.isEmpty)
          Text('No ratings yet.', style: TextStyle(color: Colors.grey[600]))
        else
          ...ratings.map((r) {
            final ratingId = int.tryParse((r['id'] ?? '').toString());
            final stars = (r['stars'] ?? '').toString();
            final comment = (r['comment'] ?? '').toString();
            final userName = (r['username'] ?? r['userName'] ?? (
                    (r['user'] is Map && r['user']['name'] != null)
                        ? r['user']['name']
                        : ((r['user'] is Map && r['user']['email'] != null)
                            ? r['user']['email']
                            : 'User')))
                .toString();
            final ownerId = _extractUserId(r);
            final isOwner = currentUserId != null && ownerId != null && ownerId == currentUserId;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('$stars ★  •  $userName'),
                subtitle: Text(comment.isEmpty ? 'No comment' : comment),
                trailing: isOwner && ratingId != null
                    ? Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _upsertRating(
                              moduleType: moduleType,
                              moduleId: moduleId,
                              existing: Map<String, dynamic>.from(r),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _deleteRating(
                              moduleType: moduleType,
                              moduleId: moduleId,
                              ratingId: ratingId,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          }),
      ],
    );
  }

  String? _clientCurrentUserIdCached;

  Future<void> _cacheCurrentUserId() async {
    _clientCurrentUserIdCached = await ApiClient.instance.currentUserId;
    if (mounted) setState(() {});
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _showCarDetailsDialog(Map<String, dynamic> car) async {
    final carId = _itemId(car);
    if (carId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid car ID')),
      );
      return;
    }

    final title = car['title']?.toString() ?? 'Car';
    final price = car['salePrice'] ?? car['price'];
    final priceStr = price != null ? '$_peso${price.toString()} / day' : '';
    final imageUrl = _itemImageUrl(car);
    final passengers = car['passenger']?.toString() ?? '-';
    final gear = car['gearShift']?.toString() ?? '-';
    final carDesc = car['description']?.toString().trim();

    final startController = TextEditingController(text: DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 1))));
    final endController = TextEditingController(text: DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 5))));
    final buyerNameController = TextEditingController();
    final buyerEmailController = TextEditingController(text: 'test@example.com');
    final buyerPhoneController = TextEditingController(text: '+1234567890');

    await _loadRatingsFor('car', carId);
    await _cacheCurrentUserId();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Car Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.directions_car, size: 80, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Price
                  Text(
                    priceStr,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  // Details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.people, 'Passengers', passengers),
                          const SizedBox(height: 8),
                          _infoRow(Icons.speed, 'Gear Shift', gear),
                          if (carDesc != null && carDesc.isNotEmpty) ...[
                            const Divider(height: 24),
                            Text(carDesc, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Pickers (compact style)
                  Text('Rental Dates:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startController,
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            hintText: 'Select start date',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 20),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 1)),
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  startController.text = DateFormat('MMM dd, yyyy').format(picked);
                                  setDialogState(() {});
                                }
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endController,
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            hintText: 'Select end date',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 20),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 5)),
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  endController.text = DateFormat('MMM dd, yyyy').format(picked);
                                  setDialogState(() {});
                                }
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRatingsSection(moduleType: 'car', moduleId: carId),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final startDate = DateFormat('MMM dd, yyyy').parse(startController.text);
                  final endDate = DateFormat('MMM dd, yyyy').parse(endController.text);
                  
                  final CreateRentalRequest request = CreateRentalRequest(
                    carId: carId,
                    startDate: startDate,
                    endDate: endDate,
                    buyerName: buyerNameController.text.trim(),
                    buyerEmail: buyerEmailController.text.trim(),
                    buyerPhone: buyerPhoneController.text.trim(),
                  );

                  final success = await CarRentalsApi.rentCar(request);
                  Navigator.pop(context);
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$title rented successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _loadRentals();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to rent car')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Rent Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMyRentals() async {
    if (_rentals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rentals found')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Car Rentals'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _rentals.length,
            itemBuilder: (context, index) {
              final rental = _rentals[index];
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      rental.carImageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.directions_car, size: 60),
                    ),
                  ),
                  title: Text(rental.carTitle),
                  subtitle: Text('${DateFormat('MMM dd, yyyy').format(rental.startDate)} - ${DateFormat('MMM dd, yyyy').format(rental.endDate)}'),
                  trailing: rental.status != 'cancelled'
                      ? IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Cancel'),
                                content: const Text('Are you sure you want to cancel this car rental booking? This action cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Cancel Booking'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              final success = await CarRentalsApi.cancelRental(rental.id);
                              if (success && mounted) {
                                Navigator.pop(context);
                                await _loadRentals();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Rental cancelled')),
                                );
                              }
                            }
                          },
                        )
                      : const Text('Cancelled', style: TextStyle(color: Colors.grey)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTourDetailsDialog(Map<String, dynamic> tour) async {
    final tourId = _itemId(tour);
    if (tourId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid tour ID')),
      );
      return;
    }

    final title = tour['title']?.toString() ?? 'Tour';
    final price = tour['salePrice'] ?? tour['price'];
    final priceStr = price != null ? '$_peso${price.toString()} / person' : '';
    final imageUrl = _itemImageUrl(tour);
    final tourDesc = tour['description']?.toString().trim();

    final startController = TextEditingController(text: DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 1))));
    final endController = TextEditingController(text: DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 5))));
    final buyerNameController = TextEditingController(text: 'John Doe');
    final buyerEmailController = TextEditingController(text: 'test@example.com');
    final buyerPhoneController = TextEditingController(text: '+1234567890');

    await _loadRatingsFor('tour', tourId);
    await _cacheCurrentUserId();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.travel_explore, size: 80, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    priceStr,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryBlue),
                  ),
                  if (tourDesc != null && tourDesc.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(tourDesc, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  ],
                  const SizedBox(height: 16),
                  Text('Tour Dates:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startController,
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 1)),
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) startController.text = DateFormat('MMM dd, yyyy').format(picked);
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endController,
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 5)),
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) endController.text = DateFormat('MMM dd, yyyy').format(picked);
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRatingsSection(moduleType: 'tour', moduleId: tourId),
                  const SizedBox(height: 24),
                  Text('Buyer Information:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: buyerNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: buyerEmailController,
                    decoration:  InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
    TextField(
                    controller: buyerPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final startDate = DateFormat('MMM dd, yyyy').parse(startController.text);
                  final endDate = DateFormat('MMM dd, yyyy').parse(endController.text);
                  final request = CreateTourBookingRequest(
                    tourId: tourId,
                    startDate: startDate,
                    endDate: endDate,
                    buyerName: buyerNameController.text.trim(),
                    buyerEmail: buyerEmailController.text.trim(),
                    buyerPhone: buyerPhoneController.text.trim(),
                  );
                  final success = await TourBookingsApi.buyTour(request);
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('$title booked!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking failed')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white),
              child: const Text('Book Now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildTopBar(),
          _buildNavBar(),
          ..._buildPageSlivers(),
        ],
      ),
      floatingActionButton: null,
    );
  }

  List<Widget> _buildPageSlivers() {
    switch (_current) {
      case _NavItem.home:
        return [
          SliverToBoxAdapter(child: _buildHero()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildSectionTitle('Featured', 'Hand-picked tours and cars.')),
          SliverToBoxAdapter(child: _buildFeaturedPackages()),
          SliverToBoxAdapter(child: _buildSectionTitle('Our Tour Packages', 'Browse available tours.')),
          SliverToBoxAdapter(child: _buildTourPackages()),
          SliverToBoxAdapter(child: _buildSectionTitle('Our Cars', 'Browse available cars.')),
          SliverToBoxAdapter(child: _buildCarPackages()),
          SliverToBoxAdapter(child: _buildFooter()),
        ];
      case _NavItem.tours:
        return [
          SliverToBoxAdapter(child: _buildSearchListPage(title: 'Search for tour', itemLabel: 'tours', items: _filteredTours, isTour: true)),
          SliverToBoxAdapter(child: _buildFooter()),
        ];
      case _NavItem.cars:
        return [
          SliverToBoxAdapter(child: _buildSearchListPage(title: 'Search for car', itemLabel: 'cars', items: _filteredCars, isTour: false)),
          SliverToBoxAdapter(child: _buildFooter()),
        ];
    }
  }

  Widget _buildTopBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: _topBarGrey,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 10),
        child: LayoutBuilder(
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (_isLoggedIn) ...[
                      _buildNotificationBell(),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserProfilePage()));
                          _loadData();
                        },
                        child: Text(
                          'Hi ${_userDisplayName ?? 'User'}',
                          style: TextStyle(color: Colors.grey[300], fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _confirmAndLogout();
                        },
                        child: Text('Logout', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () async {
showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                              title: const Text('Sign In'),
                              content: LoginDialogContent(onSuccess: _loadData),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text('Sign In', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () async {
await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                              title: const Text('Register'),
                              content: const RegisterDialogContent(),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          );
                          _loadData();
                        },
                        child: Text('Register', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dropdown(String value, List<String> options) {
    return DropdownButton<String>(
      value: value,
      dropdownColor: _topBarGrey,
      underline: const SizedBox(),
      style: TextStyle(color: Colors.grey[300], fontSize: 13),
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (_) {},
    );
  }

  Widget _buildNotificationBell() {
    final unread = _unreadNotificationsCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: _openNotificationsDialog,
          tooltip: 'Notifications',
        ),
        if (unread > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _saleRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationsPanel({
    required double width,
    required double height,
    required VoidCallback onClose,
  }) {
    const panelRadius = 16.0;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: height),
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(panelRadius),
          color: _navBlue,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: const BoxDecoration(color: _navBlue),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Notifications',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_notificationsLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close, color: Colors.white),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: 18,
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: _navBlue),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(panelRadius)),
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    child: _notifications.isEmpty
                        ? Center(child: Text(_notificationsLoading ? 'Loading...' : 'No notifications yet.'))
                        : ListView.separated(
                            itemCount: _notifications.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final n = _notifications[index];
                              final time = DateFormat('MMM dd, yyyy  HH:mm').format(n.createdAt.toLocal());
                              return Material(
                                color: n.isRead ? Colors.transparent : const Color(0xFFFFF7ED),
                                child: ListTile(
                                  leading: Icon(
                                    n.isRead ? Icons.notifications_none : Icons.notifications_active,
                                    color: _navBlue,
                                  ),
                                  title: Text(
                                    n.title,
                                    style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(n.message),
                                      const SizedBox(height: 6),
                                      Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  ),
                                  trailing: n.isRead
                                      ? null
                                      : TextButton(
                                          onPressed: () => _markNotificationRead(n),
                                          child: const Text('Mark read'),
                                        ),
                                  onTap: () => _markNotificationRead(n),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: _navBlue,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
        child: Row(
          children: [
            _buildLogo(),
            const SizedBox(width: 48),
            _NavLink(
              label: 'Home',
              isActive: _current == _NavItem.home,
              onTap: () => setState(() => _current = _NavItem.home),
            ),
            _NavLink(
              label: 'Tours',
              isActive: _current == _NavItem.tours,
              onTap: () => setState(() {
                _current = _NavItem.tours;
                _searchTabIndex = 0;
              }),
            ),
            _NavLink(
              label: 'Cars',
              isActive: _current == _NavItem.cars,
              onTap: () => setState(() {
                _current = _NavItem.cars;
                _searchTabIndex = 1;
              }),
            ),
            const Spacer(),
            // IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 125,
      height: 125,
      child:  Center(child: ClipOval(child: Image.network('https://res.cloudinary.com/das4hjjvf/image/upload/v1773481328/logo_transparent_bg_dfoqlw.webp', fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.grey[400]))),
                  ),
    );
  }

  Widget _buildHero() {
    return Stack(
      children: [
        Container(
          height: 520,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E3A5F).withOpacity(0.7),
                const Color(0xFF0F172A),
              ],
            ),
          ),
          child: Image.network(
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1200',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(),
          ),
        ),
        Container(
          height: 520,
          width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54])),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 100, 48, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hi there!', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w300)),
              const SizedBox(height: 8),
              const Text("Let's explore the world together!", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500)),
              const SizedBox(height: 75),
              _buildSearchWidget(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(_searchTabs.length, (i) {
                  final isActive = i == _searchTabIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _searchTabIndex = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: isActive ? _primaryBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _searchTabs[i],
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey[700],
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: _buildLocationDropdownField(
                        hintText: 'Where are you going?',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Expanded(child: _filterStartDateField()),
                          const SizedBox(width: 8),
                          Expanded(child: _filterEndDateField()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _filterGuestsTextField(width: 120),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _goToSearchTab(_searchTabIndex),
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLocationDropdownField(
                      hintText: 'Where are you going?',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _filterStartDateField()),
                        const SizedBox(width: 8),
                        Expanded(child: _filterEndDateField()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _filterGuestsTextField()),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _goToSearchTab(_searchTabIndex),
                          icon: const Icon(Icons.search, size: 20),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 20, 48, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _navBlue)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    Widget card({
      required Color color,
      required String title,
      required String desc,
      required IconData icon,
      required VoidCallback onTap,
      required EdgeInsets margin,
    }) {
      return Expanded(
        child: Padding(
          padding: margin,
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 16),
                        Icon(icon, color: Colors.white54, size: 40),
                      ],
                    ),
                    const Positioned(bottom: 0, right: 0, child: Icon(Icons.arrow_forward, color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card(
            color: _navBlue,
            title: 'Tours',
            desc: 'Browse guided trips and tour packages.',
            icon: Icons.travel_explore,
            margin: const EdgeInsets.only(right: 8),
            onTap: () => setState(() {
              _current = _NavItem.tours;
              _searchTabIndex = 0;
            }),
          ),
          card(
            color: Colors.orange[700]!,
            title: 'Cars',
            desc: 'Find a rental car for your journey.',
            icon: Icons.directions_car,
            margin: const EdgeInsets.only(left: 8),
            onTap: () => setState(() {
              _current = _NavItem.cars;
              _searchTabIndex = 1;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingPlaces() {
    if (_tours.isEmpty) {
      return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    }
    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 48),
        itemCount: _tours.length,
        itemBuilder: (context, i) {
          final t = _tours[i] as Map<String, dynamic>;
          final title = t['title']?.toString() ?? 'Tour';
          final price = t['salePrice'] ?? t['price'];
          final priceStr = _priceLabel(price, perPerson: true);
          final featured = _itemIsFeatured(t);
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network('https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=400', fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.grey[400]))),
                      if (featured) Positioned(top: 12, left: 12, child: _tag('FEATURED', _saleRed)),
                      Positioned(bottom: 12, left: 12, right: 12, child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(priceStr, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)));
  }

  Widget _buildTopDestinations() {
    if (_locations.isEmpty) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.8,
        children: _locations.map<Widget>((loc) {
          final name = (loc is Map ? loc['name'] : loc.toString()) ?? 'Destination';
          return Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network('https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=400', fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.grey[400])),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]))),
                  Positioned(bottom: 16, left: 16, right: 16, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), Text('Explore', style: TextStyle(color: Colors.white70, fontSize: 12))]), const Icon(Icons.arrow_forward, color: Colors.white)])),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard({
    String? saleTag,
    String title = 'Travel with us',
    String desc = 'Lorem ipsum dolor sit amet.',
    String price = '${_peso}150 / person',
    String? moduleType,
    int? moduleId,
    String? buttonLabel,
    String? imageUrl,
    VoidCallback? onTap,
  }) {
    final img = imageUrl?.trim();
    final resolvedImage = (img != null && img.isNotEmpty)
        ? img
        : 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400';
    final Widget ratingSummary;
    if (moduleType == null || moduleId == null) {
      ratingSummary = Text('No ratings yet', style: TextStyle(color: Colors.grey[600], fontSize: 13));
    } else {
      final avg = _avgRating(moduleType, moduleId);
      final cnt = _ratingCount(moduleType, moduleId);
      if (avg == null || cnt == null || cnt == 0) {
        ratingSummary = Text('No ratings yet', style: TextStyle(color: Colors.grey[600], fontSize: 13));
      } else {
        ratingSummary = Row(
          children: [
            Icon(Icons.star, size: 16, color: Colors.amber[700]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${avg.toStringAsFixed(1)} / 5 ($cnt)',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }
    }
    final card = Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: Image.network(resolvedImage, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                ),
              ),
              if (saleTag != null) Positioned(top: 12, left: 12, child: _tag(saleTag, saleTag == 'HOT' ? _hotPurple : _saleRed)),
              Positioned(bottom: 12, right: 12, child: CircleAvatar(backgroundColor: _primaryBlue, child: const Icon(Icons.check, color: Colors.white, size: 20))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ratingSummary),
                  const SizedBox(width: 8),
                  Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (buttonLabel != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onTap ?? () {},
                    child: Text(buttonLabel),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: card,
        ),
      );
    }
    return card;
  }

  Widget _buildFeaturedPackages() {
    final entries = <({bool isTour, Map<String, dynamic> m})>[];
    for (final t in _tours) {
      final m = t as Map<String, dynamic>;
      if (_itemIsFeatured(m)) entries.add((isTour: true, m: m));
    }
    for (final c in _cars) {
      final m = c as Map<String, dynamic>;
      if (_itemIsFeatured(m)) entries.add((isTour: false, m: m));
    }
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(48, 0, 48, 24),
        child: Text(
          'No featured tours or cars yet.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.3,
        children: entries.map<Widget>((e) {
          final title = e.m['title']?.toString() ?? (e.isTour ? 'Tour' : 'Car');
          final price = e.m['salePrice'] ?? e.m['price'];
          final priceStr = _priceLabel(price, perPerson: e.isTour);
          final descExtra = e.m['description']?.toString().trim();
          final typeLine = e.isTour ? 'Tour package' : '${e.m['passenger'] ?? '-'} passengers · ${e.m['gearShift'] ?? '-'}';
          final desc = (descExtra != null && descExtra.isNotEmpty) ? (e.isTour ? descExtra : '$typeLine\n$descExtra') : typeLine;
          final id = e.m['id'] is int ? e.m['id'] as int : int.tryParse(e.m['id']?.toString() ?? '') ?? 0;
          return _buildCard(
            saleTag: 'FEATURED',
            title: title,
            price: priceStr.isEmpty ? '—' : priceStr,
            desc: desc,
            moduleType: e.isTour ? 'tour' : 'car',
            moduleId: id,
            buttonLabel: 'View Details',
            imageUrl: _itemImageUrl(e.m),
            onTap: () => e.isTour ? _showTourDetailsDialog(e.m) : _showCarDetailsDialog(e.m),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTourPackages() {
    if (_tours.isEmpty) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.3,
        children: _tours.map<Widget>((t) {
          final m = t as Map<String, dynamic>;
          final title = m['title']?.toString() ?? 'Tour';
          final price = m['salePrice'] ?? m['price'];
          final priceStr = _priceLabel(price, perPerson: true);
          final desc = m['description']?.toString().trim();
          final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '') ?? 0;
          return _buildCard(
            title: title,
            price: priceStr.isEmpty ? '—' : priceStr,
            desc: (desc != null && desc.isNotEmpty) ? desc : 'Tour package',
            moduleType: 'tour',
            moduleId: id,
            buttonLabel: 'View Details',
            imageUrl: _itemImageUrl(m),
            onTap: () => _showTourDetailsDialog(m),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCarPackages() {
    if (_cars.isEmpty) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.3,
        children: _cars.map<Widget>((c) {
          final m = c as Map<String, dynamic>;
          final title = m['title']?.toString() ?? 'Car';
          final price = m['salePrice'] ?? m['price'];
          final priceStr = _priceLabel(price, perPerson: false);
          final descExtra = m['description']?.toString().trim();
          final line = '${m['passenger'] ?? '-'} passengers · ${m['gearShift'] ?? '-'}';
          final desc = (descExtra != null && descExtra.isNotEmpty) ? '$line\n$descExtra' : line;
          final id = m['id'] is int ? m['id'] as int : int.tryParse(m['id']?.toString() ?? '') ?? 0;
          return _buildCard(
            title: title,
            price: priceStr.isEmpty ? '—' : priceStr,
            desc: desc,
            moduleType: 'car',
            moduleId: id,
            buttonLabel: 'View Details',
            imageUrl: _itemImageUrl(m),
            onTap: () => _showCarDetailsDialog(m),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPopularPackages() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1,
        children: List.generate(8, (i) {
          return _buildCard(title: '${7 - (i % 3)} Days In Switzerland', price: '${_peso}70 / person', buttonLabel: null);
        }),
      ),
    );
  }

  Widget _buildBankEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.4,
        children: List.generate(6, (i) {
          return _buildCard(saleTag: 'HOT', title: 'Amazing Event in Paris', desc: 'Lorem ipsum dolor sit amet.', price: '${_peso}120', buttonLabel: null);
        }),
      ),
    );
  }

  Widget _buildNews() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.2,
        children: List.generate(6, (_) {
          return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(height: 180, width: double.infinity, color: Colors.grey[300], child: Image.network('https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=400', fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Adventure Trip (Tour)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('22 March 2026', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () {}, child: const Text('Read More')),
                  ]),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchListPage({required String title, required String itemLabel, required List<dynamic> items, required bool isTour}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero banner with title
        Stack(
          children: [
            SizedBox(
              height: 260,
              width: double.infinity,
              child: Image.network(
                'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?w=1200',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(color: Colors.green[200]),
              ),
            ),
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 48,
              bottom: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find the best $itemLabel for your next trip.',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Search row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final locationField = _buildLocationDropdownField(
                labelText: 'Location',
                hintText: 'Where are you going?',
                borderRadius: 4,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              );
              final dateFieldsRow = Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _filterStartDateField(
                      borderRadius: 4,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _filterEndDateField(
                      borderRadius: 4,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              );
              final guestsField = _filterGuestsTextField(
                borderRadius: 4,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              );
              final searchBtn = SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                  child: const Text('Search'),
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(flex: 3, child: locationField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: dateFieldsRow),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: guestsField),
                    const SizedBox(width: 12),
                    searchBtn,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  locationField,
                  const SizedBox(height: 12),
                  dateFieldsRow,
                  const SizedBox(height: 12),
                  guestsField,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: searchBtn),
                ],
              );
            },
          ),
        ),
        // Filter + results
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 16, 48, 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 260, child: _buildHotelFilterCard(isTour: isTour)),
              const SizedBox(width: 24),
              Expanded(child: _buildResultList(itemLabel: itemLabel, items: items, isTour: isTour)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterCheckboxRow(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: onChanged, activeColor: _primaryBlue),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Widget _buildHotelFilterCard({required bool isTour}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter by', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navBlue)),
          const SizedBox(height: 16),
          const Text('Filter Price', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          RangeSlider(
            values: RangeValues(
              _priceRange.start.clamp(0, 2000),
              _priceRange.end.clamp(0, 2000),
            ),
            min: 0,
            max: 2000,
            labels: RangeLabels('$_peso${_priceRange.start.round()}', '$_peso${_priceRange.end.round()}'),
            activeColor: _primaryBlue,
            onChanged: (values) {
              setState(() => _priceRange = values);
            },
          ),
          const SizedBox(height: 4),
          Text('Price: $_peso${_priceRange.start.round()} - $_peso${_priceRange.end.round()}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          const Divider(height: 32),
          const Text('Star rating', style: TextStyle(fontWeight: FontWeight.w600)),
          Text('Filter by average star rating (1–5)', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(height: 8),
          _filterCheckboxRow('5 star', _starFilters.contains('5'), (v) {
            setState(() {
              if (v == true) {
                _starFilters.add('5');
              } else {
                _starFilters.remove('5');
              }
            });
          }),
          _filterCheckboxRow('4 star', _starFilters.contains('4'), (v) {
            setState(() {
              if (v == true) {
                _starFilters.add('4');
              } else {
                _starFilters.remove('4');
              }
            });
          }),
          _filterCheckboxRow('3 star', _starFilters.contains('3'), (v) {
            setState(() {
              if (v == true) {
                _starFilters.add('3');
              } else {
                _starFilters.remove('3');
              }
            });
          }),
          _filterCheckboxRow('2 star', _starFilters.contains('2'), (v) {
            setState(() {
              if (v == true) {
                _starFilters.add('2');
              } else {
                _starFilters.remove('2');
              }
            });
          }),
          _filterCheckboxRow('1 star', _starFilters.contains('1'), (v) {
            setState(() {
              if (v == true) {
                _starFilters.add('1');
              } else {
                _starFilters.remove('1');
              }
            });
          }),
          const Divider(height: 32),
          if (isTour) ...[
            const Text('Tour availability', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Filter tours by availability type', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            const SizedBox(height: 8),
            _filterCheckboxRow('Always open', _tourAvailabilityFilters.contains('always'), (v) {
              setState(() {
                if (v == true) {
                  _tourAvailabilityFilters.add('always');
                } else {
                  _tourAvailabilityFilters.remove('always');
                }
              });
            }),
            _filterCheckboxRow('Fixed dates', _tourAvailabilityFilters.contains('fixed'), (v) {
              setState(() {
                if (v == true) {
                  _tourAvailabilityFilters.add('fixed');
                } else {
                  _tourAvailabilityFilters.remove('fixed');
                }
              });
            }),
            _filterCheckboxRow('Open hours', _tourAvailabilityFilters.contains('open_hours'), (v) {
              setState(() {
                if (v == true) {
                  _tourAvailabilityFilters.add('open_hours');
                } else {
                  _tourAvailabilityFilters.remove('open_hours');
                }
              });
            }),
          ] else ...[
            const Text('Passenger capacity', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Filter cars by their passenger capacity', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            const SizedBox(height: 8),
            _filterCheckboxRow('Small (1-4)', _carCapacityFilters.contains('small'), (v) {
              setState(() {
                if (v == true) {
                  _carCapacityFilters.add('small');
                } else {
                  _carCapacityFilters.remove('small');
                }
              });
            }),
            _filterCheckboxRow('Medium (5-7)', _carCapacityFilters.contains('medium'), (v) {
              setState(() {
                if (v == true) {
                  _carCapacityFilters.add('medium');
                } else {
                  _carCapacityFilters.remove('medium');
                }
              });
            }),
            _filterCheckboxRow('Large (8+)', _carCapacityFilters.contains('large'), (v) {
              setState(() {
                if (v == true) {
                  _carCapacityFilters.add('large');
                } else {
                  _carCapacityFilters.remove('large');
                }
              });
            }),
          ]
        ],
      ),
    );
  }

  Widget _buildResultList({required String itemLabel, required List<dynamic> items, required bool isTour}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${items.length} $itemLabel found',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _navBlue),
            ),
          ],
        ),
        const SizedBox(height: 12),
        items.isEmpty
            ? const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No items found.')))
            : GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: List.generate(items.length, (index) => InkWell(
                  onTap: () => isTour ? _showTourDetailsDialog(items[index] as Map<String, dynamic>) : _showCarDetailsDialog(items[index] as Map<String, dynamic>),
                  child: _buildResultCard(items[index] as Map<String, dynamic>, isTour),
                )),
              ),
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item, bool isTour) {
    final title = item['title']?.toString() ?? 'Item';
    final price = item['salePrice'] ?? item['price'];
    final priceStr = _priceLabel(price, perPerson: isTour);
    final featured = _itemIsFeatured(item);
    final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '') ?? 0;
    final mt = isTour ? 'tour' : 'car';
    final avg = _avgRating(mt, id);
    final cnt = _ratingCount(mt, id);
    final ratingLine = (avg != null && cnt != null && cnt > 0)
        ? '${avg.toStringAsFixed(1)} / 5 ($cnt)'
        : 'No ratings yet';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Image.network(
                    _itemImageUrl(item),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: Colors.grey[300]),
                  ),
                ),
              ),
              if (featured)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _saleRed, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Featured', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  if (isTour)
                    Text('Tour', style: TextStyle(color: Colors.grey[600], fontSize: 12))
                  else
                    Text('${item['passenger'] ?? '-'} passengers · ${item['gearShift'] ?? '-'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(ratingLine, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  const SizedBox(height: 8),
                  Text(
                    priceStr.isEmpty ? '—' : 'from $priceStr',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowYourCityBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(48, 48, 48, 0),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      decoration: BoxDecoration(color: _accentOrange.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Know your city?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 8), Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut elit tellus', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14))]),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _navBlue, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Learn More')),
        ],
      ),
    );
  }

  Widget _buildRatings() {
    final guides = [('Irvin Deo', 'Sample Rating'), ('Jane Smith', 'Sample Rating'), ('John Doe', 'Sample Rating')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: guides.map((e) {
          final (name, role) = e;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 2))]),
              child: Column(children: [
                CircleAvatar(radius: 48, backgroundColor: Colors.grey[300], child: Text(name[0], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(role, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 8),
                Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit.', style: TextStyle(color: Colors.grey[500], fontSize: 12), textAlign: TextAlign.center),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNewsletter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 48, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      color: Colors.grey[200],
      child: Row(
        children: [
          Icon(Icons.mail_outline, size: 32, color: _navBlue),
          const SizedBox(width: 16),
          const Text('Join Our Newsletter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navBlue)),
          const SizedBox(width: 32),
          Expanded(child: TextField(decoration: InputDecoration(hintText: 'Enter your email', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)))),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: _navBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Subscribe')),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: _navBlue,
      padding: const EdgeInsets.fromLTRB(48, 48, 48, 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 16),
                    Text('Tours and car rentals for your next trip.', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                    const SizedBox(height: 16),
                    Text('Copyright © 2026 Company Name, All Rights Reserved.', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Contact Information', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text('+1 (800) 283 0000', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                  Text('info@domain.com', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                  Text('123 Street, City, Country', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white12),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _accentOrange : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}


