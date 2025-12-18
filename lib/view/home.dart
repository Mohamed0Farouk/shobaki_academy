import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/auth/login_page.dart';
import 'package:shobaki_academy/view/enrolled_topics/enrolled_topics.dart';
import 'package:shobaki_academy/view/results/results_page.dart';
import 'package:shobaki_academy/view/settings.dart';
import 'package:shobaki_academy/view/topics/topics_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = '';
  bool inReviewParam = false;
  bool guestParam = false;

  final PageController _pageController = PageController(
    initialPage: 0,
    keepPage: true,
  );

  int _currentIndex = 0;

  /// ⭐ Prevents LateInitializationError
  List<Widget> _pages = [];
  List<BottomNavigationBarItem> _navItems = [];

  bool _loadingPages = true;

  @override
  void initState() {
    super.initState();

    final params = Get.parameters;
    inReviewParam = params['inReview'] == 'true';
    guestParam = params['guest'] == 'true';

    _init();
    _loadLocalUserName();
  }

  Future<void> _init() async {
    await _buildPagesAndItems();

    if (mounted) {
      setState(() => _loadingPages = false);
    }
  }

  Future<void> _buildPagesAndItems() async {
    final api = ApiClient();

    final res = await api.fetchData('application_manfist');
    final manifest = res.isNotEmpty ? res[0] : <String, dynamic>{};

    final bool inReviewMode = manifest['in_review'] as bool? ?? false;
    final bool useHomeworksAndExams =
        manifest['use_homeworks_and_exams'] as bool? ?? false;

    // Normal user pages
    final normalPages = <Widget>[
      TopicsPage(),
      EnrolledTopicsPage(),
      if (useHomeworksAndExams) ResultsPage(),
      SettingsPage(),
    ];

    final normalItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_filled),
        label: 'المواضيع',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bookmark_border),
        activeIcon: Icon(Icons.bookmark),
        label: 'الاشتراكات',
      ),
      if (useHomeworksAndExams)
        const BottomNavigationBarItem(
          icon: Icon(Icons.area_chart_outlined),
          activeIcon: Icon(Icons.area_chart_rounded),
          label: 'النتائج',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings_outlined),
        activeIcon: Icon(Icons.settings_rounded),
        label: 'الاعدادات',
      ),
    ];

    // Guest pages
    final guestPages = <Widget>[
      TopicsPage(guest: true),
      if (useHomeworksAndExams) ResultsPage(),
      SettingsPage(isGuest: true),
    ];

    final guestItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_filled),
        label: 'المواضيع',
      ),
      if (useHomeworksAndExams)
        const BottomNavigationBarItem(
          icon: Icon(Icons.area_chart_outlined),
          activeIcon: Icon(Icons.area_chart_rounded),
          label: 'النتائج',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings_outlined),
        activeIcon: Icon(Icons.settings_rounded),
        label: 'الاعدادات',
      ),
    ];

    // Reviewer pages
    final reviewPages = <Widget>[
      TopicsPage(inReview: inReviewMode),
      if (useHomeworksAndExams) ResultsPage(),
      SettingsPage(),
    ];

    final reviewItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_filled),
        label: 'المواضيع',
      ),
      if (useHomeworksAndExams)
        const BottomNavigationBarItem(
          icon: Icon(Icons.area_chart_outlined),
          activeIcon: Icon(Icons.area_chart_rounded),
          label: 'النتائج',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings_outlined),
        activeIcon: Icon(Icons.settings_rounded),
        label: 'الاعدادات',
      ),
    ];

    // Apply final pages
    if (inReviewMode) {
      _pages = reviewPages;
      _navItems = reviewItems;
    } else if (guestParam) {
      _pages = guestPages;
      _navItems = guestItems;
    } else {
      _pages = normalPages;
      _navItems = normalItems;
    }

    if (_currentIndex >= _pages.length) _currentIndex = 0;
  }

  Future<void> _loadLocalUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('UserData');

    if (raw != null) {
      try {
        final user = jsonDecode(raw);
        setState(() => userName = (user['name'] ?? '').toString());
      } catch (_) {}
    }
  }

  void _onTapNav(int idx) {
    setState(() => _currentIndex = idx);

    /// ⭐ Safe: PageView is now attached
    _pageController.animateToPage(
      idx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPages) {
      return Scaffold(body: Center(child: loading(context)));
    }

    //final navBarColor = Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      extendBody: true,
      appBar: guestParam ? _buildGuestAppBar(context) : null,

      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: (value) {
          setState(() => _currentIndex = value);
        },
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTapNav,
            items: _navItems,
            type: BottomNavigationBarType.fixed,
            backgroundColor: primary,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.black87,
          ),
        ),
      ),
    );
  }

  /// Guest app bar
  PreferredSizeWidget _buildGuestAppBar(BuildContext context) {
    return AppBar(
      title: const Text('طالبنا العزيز'),
      centerTitle: true,
      elevation: 0,
      flexibleSpace: Container(color: Theme.of(context).colorScheme.primary),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(55),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange, width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline),
                const SizedBox(width: 8),
                const Expanded(child: Text('سجل دخولك للوصول لكل الميزات')),
                TextButton(
                  onPressed: () {
                    loadingDilog(context);
                    AuthController().exitGuestMode().then(
                      (_) => Get.offAll(() => LoginPage()),
                    );
                  },
                  style: TextButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text(
                    'دخول',
                    style: TextStyle(color: Colors.white),
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
