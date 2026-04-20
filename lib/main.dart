// =============================================================================
// A complete, self-contained calendar planner featuring:
//   • Mock email/password login
//   • Material 3 design with Indigo / Deep Purple palette
//   • Custom calendar widget (no external calendar package required)
//   • Add / view / delete events with title & time
//   • Filter events: Upcoming | Past | All
//   • Light / Dark theme toggle, persisted via shared_preferences
//   • Named routes: /login -> /home -> /event-details
//   • Animated page transitions, responsive layout (mobile + tablet)
//   • NEW: In-app real-time notification toggle and alert engine!
//
// ---- Required pubspec.yaml dependencies ----
// dependencies:
//   flutter:
//     sdk: flutter
//   shared_preferences: ^2.2.2
//
// Run with:
//   flutter pub get
//   flutter run
// =============================================================================

import 'dart:async'; // Added for the Notification Timer
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// ENTRY POINT
// =============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the persisted theme preference before the app runs so the correct
  // theme is applied on the very first frame (no theme flash).
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool(ThemeController._storageKey) ?? false;
  runApp(CalendarPlannerApp(initialDarkMode: isDark));
}

// =============================================================================
// THEME CONTROLLER
// -----------------------------------------------------------------------------
// Simple ChangeNotifier-based controller that exposes the current ThemeMode
// and persists user preference through SharedPreferences.
// =============================================================================
class ThemeController extends ChangeNotifier {
  static const _storageKey = 'calendar_planner.dark_mode';

  ThemeController(bool initialDark)
    : _mode = initialDark ? ThemeMode.dark : ThemeMode.light;

  ThemeMode _mode;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey, isDark);
  }
}

// =============================================================================
// EVENT MODEL + IN-MEMORY STORE
// -----------------------------------------------------------------------------
// Event is a plain data class. EventStore uses ChangeNotifier so widgets can
// subscribe for live updates when events are added or deleted.
// =============================================================================
class Event {
  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    this.notes = '',
    this.colorSeed = 0,
    this.notifyMe = false, // NEW: User choice for notifications
    this.hasNotified = false, // NEW: Internal tracker to prevent spam
  });

  final String id;
  final String title;
  final DateTime date; // date-only (year, month, day)
  final TimeOfDay time;
  final String notes;
  final int colorSeed; // used to vary card accent colors
  final bool notifyMe;
  bool hasNotified;

  DateTime get fullDateTime =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class EventStore extends ChangeNotifier {
  final List<Event> _events = <Event>[];

  List<Event> get all => List.unmodifiable(_events);

  List<Event> forDate(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _events.where((e) => e.date == d).toList()
      ..sort((a, b) => a.fullDateTime.compareTo(b.fullDateTime));
  }

  /// Returns true if any events exist on that day (used by calendar dots).
  bool hasEvents(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _events.any((e) => e.date == d);
  }

  void add(Event event) {
    _events.add(event);
    notifyListeners();
  }

  void remove(String id) {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}

/// Filter toggle values for the home screen event list.
enum EventFilter { upcoming, past, all }

// =============================================================================
// ROOT APP WIDGET
// =============================================================================
class CalendarPlannerApp extends StatefulWidget {
  const CalendarPlannerApp({super.key, required this.initialDarkMode});
  final bool initialDarkMode;

  @override
  State<CalendarPlannerApp> createState() => _CalendarPlannerAppState();
}

class _CalendarPlannerAppState extends State<CalendarPlannerApp> {
  late final ThemeController _themeController;
  late final EventStore _eventStore;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController(widget.initialDarkMode);
    _eventStore = EventStore();

    // Seed a couple of demo events so the app doesn't look empty on first run.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _eventStore.add(
      Event(
        id: 'seed-1',
        title: 'Team Sync',
        date: today,
        time: const TimeOfDay(hour: 10, minute: 30),
        notes: 'Weekly product sync with the team.',
        colorSeed: 1,
        notifyMe: false, // Default false
      ),
    );
    _eventStore.add(
      Event(
        id: 'seed-2',
        title: 'Gym Session',
        date: today.add(const Duration(days: 1)),
        time: const TimeOfDay(hour: 18, minute: 0),
        notes: 'Leg day — do not skip!',
        colorSeed: 2,
        notifyMe: true, // Example of enabled notification
      ),
    );
  }

  // Build both light and dark Material 3 themes around an indigo / deep-purple
  // accent pair for a modern, cohesive look.
  ThemeData _buildTheme(Brightness brightness) {
    final seed = const Color(0xFF4F46E5); // indigo-600
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      secondary: const Color(0xFF7C3AED), // deep purple accent
    );
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme
          .apply(fontFamily: 'Roboto')
          .copyWith(
            displayLarge: base.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: scheme.surfaceContainerHighest.withOpacity(
          brightness == Brightness.dark ? 0.35 : 0.6,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds only when the ThemeController toggles.
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Calendar Planner',
          debugShowCheckedModeBanner: false,
          themeMode: _themeController.mode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          initialRoute: LoginScreen.routeName,
          // onGenerateRoute lets us attach custom animated page transitions
          // to every named route.
          onGenerateRoute: (settings) {
            Widget page;
            switch (settings.name) {
              case LoginScreen.routeName:
                page = LoginScreen(themeController: _themeController);
                break;
              case HomeScreen.routeName:
                page = HomeScreen(
                  themeController: _themeController,
                  eventStore: _eventStore,
                );
                break;
              case EventDetailsScreen.routeName:
                final event = settings.arguments as Event;
                page = EventDetailsScreen(
                  event: event,
                  eventStore: _eventStore,
                );
                break;
              default:
                page = LoginScreen(themeController: _themeController);
            }
            return _fadeSlideRoute(page, settings);
          },
        );
      },
    );
  }

  /// Reusable fade + slide page transition used for all routes.
  PageRouteBuilder _fadeSlideRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

// =============================================================================
// LOGIN SCREEN
// -----------------------------------------------------------------------------
// Mock authentication: any valid email + password >= 6 chars.
// Also accepts the demo shortcut: demo@demo.com / demo123.
// =============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.themeController});
  static const String routeName = '/login';
  final ThemeController themeController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'demo@demo.com');
  final _passwordCtrl = TextEditingController(text: 'demo123');
  bool _obscure = true;
  bool _loading = false;

  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    // Simulate a network delay for a nicer UX.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final maxFormWidth = isTablet ? 460.0 : double.infinity;

    return Scaffold(
      body: Stack(
        children: [
          // Decorative gradient + blurred orbs for a modern login feel.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withOpacity(0.18),
                    cs.secondary.withOpacity(0.10),
                    cs.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: _GradientOrb(
              size: 220,
              colors: [cs.primary, cs.secondary.withOpacity(0.6)],
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _GradientOrb(
              size: 260,
              colors: [cs.secondary, cs.primary.withOpacity(0.4)],
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxFormWidth),
                  child: FadeTransition(
                    opacity: _entryController,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _entryController,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Brand mark
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [cs.primary, cs.secondary],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.event_available_rounded,
                                color: cs.onPrimary,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Welcome back',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to plan your day beautifully.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: cs.onSurface.withOpacity(0.7),
                                ),
                          ),
                          const SizedBox(height: 36),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  validator: (v) {
                                    final value = (v ?? '').trim();
                                    if (value.isEmpty) return 'Email required';
                                    final emailRegex = RegExp(
                                      r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$',
                                    );
                                    if (!emailRegex.hasMatch(value)) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if ((v ?? '').length < 6) {
                                      return 'Minimum 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 56,
                                  child: FilledButton(
                                    onPressed: _loading ? null : _submit,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Sign in'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'Demo: demo@demo.com  /  demo123',
                                    style: TextStyle(
                                      color: cs.onSurface.withOpacity(0.55),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton.icon(
                              onPressed: () => widget.themeController.toggle(),
                              icon: Icon(
                                widget.themeController.isDark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                              ),
                              label: Text(
                                widget.themeController.isDark
                                    ? 'Switch to light mode'
                                    : 'Switch to dark mode',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft blurred colored orb used for login background decoration.
class _GradientOrb extends StatelessWidget {
  const _GradientOrb({required this.size, required this.colors});
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
      // Slight opacity to give a "glow" feeling without dart:ui blur.
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.02),
      ),
    );
  }
}

// =============================================================================
// HOME SCREEN (calendar + events + filter toggle)
// =============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeController,
    required this.eventStore,
  });
  static const String routeName = '/home';
  final ThemeController themeController;
  final EventStore eventStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _focusedMonth; // which month the calendar is displaying
  late DateTime _selectedDate; // currently highlighted day
  EventFilter _filter = EventFilter.all;
  Timer? _notificationTimer; // NEW: Timer for notifications

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);

    _startNotificationEngine(); // NEW: Initialize background timer
  }

  @override
  void dispose() {
    _notificationTimer?.cancel(); // NEW: Clean up timer
    super.dispose();
  }

  // =========================================================================
  // NEW: REAL-TIME NOTIFICATION ENGINE
  // =========================================================================
  void _startNotificationEngine() {
    // Checks every 10 seconds if any event matches the exact current time
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;

      final now = TimeOfDay.now();
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      // Get events for today
      final todayEvents = widget.eventStore.forDate(today);

      for (var event in todayEvents) {
        if (event.notifyMe && !event.hasNotified) {
          if (event.time.hour == now.hour && event.time.minute == now.minute) {
            event.hasNotified = true; // Mark as notified
            _showNotificationBanner(event);
          }
        }
      }
    });
  }

  void _showNotificationBanner(Event event) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        elevation: 10,
        backgroundColor: cs.primaryContainer,
        leading: Icon(
          Icons.notifications_active_rounded,
          color: cs.primary,
          size: 32,
        ),
        content: Text(
          'Reminder: ${event.title} is starting now!',
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: Text('DISMISS', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );

    // Auto dismiss after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }
  // =========================================================================

  void _goPrevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _goNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _onDaySelected(DateTime day) {
    setState(() => _selectedDate = day);
  }

  Future<void> _openAddEventSheet() async {
    final result = await showModalBottomSheet<Event>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEventSheet(selectedDate: _selectedDate),
    );
    if (result != null) {
      widget.eventStore.add(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Added "${result.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _logout() {
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  /// Applies the current filter to the full event list.
  List<Event> _filteredEvents(List<Event> events) {
    final now = DateTime.now();
    switch (_filter) {
      case EventFilter.upcoming:
        return events.where((e) => e.fullDateTime.isAfter(now)).toList()
          ..sort((a, b) => a.fullDateTime.compareTo(b.fullDateTime));
      case EventFilter.past:
        return events.where((e) => e.fullDateTime.isBefore(now)).toList()
          ..sort((a, b) => b.fullDateTime.compareTo(a.fullDateTime));
      case EventFilter.all:
        return [...events]
          ..sort((a, b) => a.fullDateTime.compareTo(b.fullDateTime));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    // Use a two-pane layout on tablets / wide screens.
    final isWide = size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Planner'),
        actions: [
          IconButton(
            tooltip: widget.themeController.isDark ? 'Light mode' : 'Dark mode',
            onPressed: () => setState(() => widget.themeController.toggle()),
            icon: Icon(
              widget.themeController.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddEventSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Event'),
      ),
      body: AnimatedBuilder(
        animation: widget.eventStore,
        builder: (context, _) {
          final eventsForDate = widget.eventStore.forDate(_selectedDate);
          final filtered = _filteredEvents(widget.eventStore.all);

          final calendarPane = _CalendarPane(
            focusedMonth: _focusedMonth,
            selectedDate: _selectedDate,
            events: widget.eventStore,
            onPrev: _goPrevMonth,
            onNext: _goNextMonth,
            onSelect: _onDaySelected,
          );

          final listPane = _EventsPane(
            selectedDate: _selectedDate,
            eventsForDate: eventsForDate,
            filteredAll: filtered,
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
            onOpenEvent: (e) => Navigator.of(
              context,
            ).pushNamed(EventDetailsScreen.routeName, arguments: e),
            onDelete: (e) => widget.eventStore.remove(e.id),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: calendarPane),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  color: cs.outlineVariant.withOpacity(0.4),
                ),
                Expanded(flex: 6, child: listPane),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [calendarPane, listPane],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Calendar pane (month header + weekday row + day grid)
// -----------------------------------------------------------------------------
class _CalendarPane extends StatelessWidget {
  const _CalendarPane({
    required this.focusedMonth,
    required this.selectedDate,
    required this.events,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final EventStore events;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // First day of displayed month.
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    // weekday: Monday=1..Sunday=7. Leading blanks before day 1.
    final leading = firstOfMonth.weekday - 1;
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: month label + prev/next controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withOpacity(0.12),
                  cs.secondary.withOpacity(0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _monthNames[focusedMonth.month - 1],
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${focusedMonth.year}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: cs.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                _RoundIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: onPrev,
                ),
                const SizedBox(width: 8),
                _RoundIconButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: onNext,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Weekday labels
          Row(
            children: _weekdayLabels
                .map(
                  (w) => Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withOpacity(0.55),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leading + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(
                focusedMonth.year,
                focusedMonth.month,
                dayNumber,
              );
              final isSelected = date == selectedDate;
              final isToday = _isSameDay(date, DateTime.now());
              final hasEvent = events.hasEvents(date);

              return _CalendarCell(
                dayNumber: dayNumber,
                isSelected: isSelected,
                isToday: isToday,
                hasEvent: hasEvent,
                onTap: () => onSelect(date),
              );
            },
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: cs.onSurface),
        ),
      ),
    );
  }
}

/// Single day cell inside the calendar grid.
class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.dayNumber,
    required this.isSelected,
    required this.isToday,
    required this.hasEvent,
    required this.onTap,
  });

  final int dayNumber;
  final bool isSelected;
  final bool isToday;
  final bool hasEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    BoxBorder? border;
    if (isSelected) {
      bg = cs.primary;
      fg = cs.onPrimary;
    } else if (isToday) {
      bg = cs.primaryContainer.withOpacity(0.5);
      fg = cs.onPrimaryContainer;
      border = Border.all(color: cs.primary, width: 1.5);
    } else {
      bg = Colors.transparent;
      fg = cs.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: border,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: fg,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (hasEvent)
                  Positioned(
                    bottom: 6,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected ? cs.onPrimary : cs.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Events pane (selected-date list + filter toggle + full filtered list)
// -----------------------------------------------------------------------------
class _EventsPane extends StatelessWidget {
  const _EventsPane({
    required this.selectedDate,
    required this.eventsForDate,
    required this.filteredAll,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenEvent,
    required this.onDelete,
  });

  final DateTime selectedDate;
  final List<Event> eventsForDate;
  final List<Event> filteredAll;
  final EventFilter filter;
  final ValueChanged<EventFilter> onFilterChanged;
  final ValueChanged<Event> onOpenEvent;
  final ValueChanged<Event> onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateLabel = _prettyDate(selectedDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selected date heading + count
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${eventsForDate.length} event${eventsForDate.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Events for the selected date
          if (eventsForDate.isEmpty)
            _EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'No events on this day',
              subtitle: 'Tap the + button to create one.',
            )
          else
            Column(
              children: [
                for (final e in eventsForDate)
                  _EventCard(
                    event: e,
                    onTap: () => onOpenEvent(e),
                    onDelete: () => onDelete(e),
                  ),
              ],
            ),
          const SizedBox(height: 28),
          // Filter toggle section
          Text(
            'All events',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SegmentedButton<EventFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: EventFilter.upcoming,
                label: Text('Upcoming'),
                icon: Icon(Icons.trending_up_rounded),
              ),
              ButtonSegment(
                value: EventFilter.past,
                label: Text('Past'),
                icon: Icon(Icons.history_rounded),
              ),
              ButtonSegment(
                value: EventFilter.all,
                label: Text('All'),
                icon: Icon(Icons.all_inclusive_rounded),
              ),
            ],
            selected: {filter},
            onSelectionChanged: (s) => onFilterChanged(s.first),
          ),
          const SizedBox(height: 14),
          if (filteredAll.isEmpty)
            _EmptyState(
              icon: Icons.inbox_rounded,
              title: _emptyFilterTitle(filter),
              subtitle: 'Create new events to see them here.',
            )
          else
            Column(
              children: [
                for (final e in filteredAll)
                  _EventCard(
                    event: e,
                    showDate: true,
                    onTap: () => onOpenEvent(e),
                    onDelete: () => onDelete(e),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _emptyFilterTitle(EventFilter f) {
    switch (f) {
      case EventFilter.upcoming:
        return 'No upcoming events';
      case EventFilter.past:
        return 'No past events';
      case EventFilter.all:
        return 'No events yet';
    }
  }

  static String _prettyDate(DateTime d) {
    const months = [
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
      'Dec',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

/// Empty placeholder used in several spots on the home screen.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: cs.onSurface.withOpacity(0.4)),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: cs.onSurface.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }
}

/// A single event card with icon, title, time, optional date, and delete menu.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onTap,
    required this.onDelete,
    this.showDate = false,
  });

  final Event event;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool showDate;

  // Accent palette cycled via colorSeed.
  static const List<List<Color>> _accents = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)], // indigo -> violet
    [Color(0xFF0EA5E9), Color(0xFF22D3EE)], // sky -> cyan
    [Color(0xFFF59E0B), Color(0xFFF97316)], // amber -> orange
    [Color(0xFF10B981), Color(0xFF22C55E)], // emerald -> green
    [Color(0xFFEC4899), Color(0xFFF43F5E)], // pink -> rose
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accents[event.colorSeed.abs() % _accents.length];
    final timeLabel = _formatTime(event.time);
    final dateLabel = _formatDate(event.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: accent.first.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Accent icon tile
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: accent),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accent.last.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      // NEW: Use notification icon if it's set to remind
                      event.notifyMe
                          ? Icons.notifications_active_rounded
                          : Icons.event_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              showDate
                                  ? '$dateLabel  •  $timeLabel'
                                  : timeLabel,
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                    onSelected: (v) {
                      if (v == 'delete') _confirmDelete(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete event?'),
        content: Text('"${event.title}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete();
  }

  static String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  static String _formatDate(DateTime d) {
    const months = [
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
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// =============================================================================
// ADD EVENT BOTTOM SHEET
// =============================================================================
class AddEventSheet extends StatefulWidget {
  const AddEventSheet({super.key, required this.selectedDate});
  final DateTime selectedDate;

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late DateTime _date;
  TimeOfDay _time = TimeOfDay.now();

  // NEW: State for notification toggle
  bool _notifyMe = false;

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final event = Event(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      date: _date,
      time: _time,
      notes: _notesCtrl.text.trim(),
      colorSeed: math.Random().nextInt(1000),
      notifyMe: _notifyMe, // NEW: pass the toggle value
    );
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag indicator
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 14),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    'New Event',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Title required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date',
                          value: _formatDate(_date),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: _time.format(context),
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // NEW: Notification Toggle UI
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Remind me at this time',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Sends an in-app alert when time arrives',
                        style: TextStyle(fontSize: 12),
                      ),
                      secondary: Icon(
                        Icons.notifications_active_rounded,
                        color: _notifyMe ? cs.primary : Colors.grey,
                      ),
                      value: _notifyMe,
                      onChanged: (val) => setState(() => _notifyMe = val),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save event'),
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
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
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// Tappable tile used for the date and time pickers inside the sheet.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EVENT DETAILS SCREEN
// =============================================================================
class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({
    super.key,
    required this.event,
    required this.eventStore,
  });
  static const String routeName = '/event-details';

  final Event event;
  final EventStore eventStore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent =
        _EventCard._accents[event.colorSeed.abs() % _EventCard._accents.length];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('Delete event?'),
                  content: Text('"${event.title}" will be removed.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                eventStore.remove(event.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hero-like accent header
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: accent,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: accent.last.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  event.notifyMe
                      ? Icons.notifications_active_rounded
                      : Icons.event_available_rounded, // NEW
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_prettyDate(event.date)} • ${_EventCard._formatTime(event.time)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DetailRow(
            icon: Icons.calendar_month_rounded,
            label: 'Date',
            value: _prettyDate(event.date),
          ),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: _EventCard._formatTime(event.time),
          ),
          // NEW: Shows Notification status
          _DetailRow(
            icon: event.notifyMe
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            label: 'Reminder',
            value: event.notifyMe ? 'Enabled for this event' : 'Disabled',
          ),
          _DetailRow(
            icon: Icons.notes_rounded,
            label: 'Notes',
            value: event.notes.isEmpty ? '—' : event.notes,
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to calendar'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }

  static String _prettyDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
