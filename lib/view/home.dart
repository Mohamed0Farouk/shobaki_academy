import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/services/api.dart';
import 'package:shobaki_academy/services/locale_db.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/view/auth/login_page.dart';
import 'package:shobaki_academy/view/books.dart';
import 'package:shobaki_academy/view/enrolled_topics/enrolled_topics.dart';
import 'package:shobaki_academy/view/results/results_page.dart';
import 'package:shobaki_academy/view/settings.dart';
import 'package:shobaki_academy/view/topics/topics_page.dart';

class _SidebarItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  _SidebarItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = '';
  bool inReviewParam = false;
  bool guestParam = false;
  Map<String, dynamic>? _user;

  final PageController _pageController = PageController(
    initialPage: 0,
    keepPage: true,
  );

  int _currentIndex = 0;
  bool _sidebarCollapsed = false;

  /// ⭐ Prevents LateInitializationError
  List<Widget> _pages = [];
  List<BottomNavigationBarItem> _navItems = [];
  List<_SidebarItem> _sidebarItems = [];

  bool _loadingPages = true;

  @override
  void initState() {
    super.initState();

    final localDb = Get.find<LocalDB>();
    final prefs = localDb.sharedPref!;

    final raw = prefs.getString('UserData');
    if (raw != null) {
      try {
        _user = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _user = null;
      }
    }

    guestParam = _user?['email'] == 'guest@example.com';
    inReviewParam = _user?['email'] == AuthController.reviewerEmailPrefix;

    _init();
    _loadLocalUserName();
    //_checkFirstLaunch(); // 👈 HERE
  }

  Future<void> showFirstLaunchDialog({bool dismissible = true}) {
    return Get.dialog(
      AlertDialog(
        title: const Text('ارشادات الاستخدام'),
        content: const Text(
          'Welcome to the app!\n\nHere you can explain features, rules, or anything important.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Got it')),
        ],
      ),
      barrierDismissible: dismissible,
    );
  }

  // Future<void> _checkFirstLaunch() async {
  //   final localDb = Get.find<LocalDB>();
  //   final prefs = localDb.sharedPref!;

  //   const key = 'first_launch_done';

  //   final isFirstLaunch = !(prefs.getBool(key) ?? false);

  //   print(isFirstLaunch ? 'first launch' : 'not first launch');

  //   print('added');
  //   if (isFirstLaunch) {
  //     // Wait until UI is ready
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       showFirstLaunchDialog();
  //     });

  //     await prefs.setBool(key, true);
  //   }
  // }

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

    bool inReviewMode = manifest['in_review'] as bool? ?? false;
    inReviewMode = inReviewMode || inReviewParam;
    final bool useHomeworksAndExams =
        manifest['use_homeworks_and_exams'] as bool? ?? false;

    // Normal user pages
    final normalPages = <Widget>[
      TopicsPage(),
      BooksPage(),
      EnrolledTopicsPage(),
      if (useHomeworksAndExams) ResultsPage(),
      SettingsPage(),
    ];

    final normalItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_rounded),
        label: 'المحتويات',
      ),
      BottomNavigationBarItem(
        label: 'الملازم',
        icon: Icon(Icons.bookmarks_outlined),
        activeIcon: Icon(Icons.bookmarks_rounded),
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
        icon: Icon(Icons.person_outline_rounded),
        activeIcon: Icon(Icons.person_rounded),
        label: 'الملف الشخصي',
      ),
    ];

    final normalSidebarItems = <_SidebarItem>[
      _SidebarItem(
        label: 'المحتويات',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _SidebarItem(
        label: 'الملازم',
        icon: Icons.bookmarks_outlined,
        activeIcon: Icons.bookmarks_rounded,
      ),
      _SidebarItem(
        label: 'الاشتراكات',
        icon: Icons.bookmark_border,
        activeIcon: Icons.bookmark,
      ),
      if (useHomeworksAndExams)
        _SidebarItem(
          label: 'النتائج',
          icon: Icons.area_chart_outlined,
          activeIcon: Icons.area_chart_rounded,
        ),
      _SidebarItem(
        label: 'الملف الشخصي',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    // Guest pages
    final guestPages = <Widget>[
      TopicsPage(guest: true),
      BooksPage(),
      if (useHomeworksAndExams) ResultsPage(),
      SettingsPage(isGuest: true),
    ];

    final guestItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_rounded),
        label: 'المحتويات',
      ),
      const BottomNavigationBarItem(
        label: 'الملازم',
        icon: Icon(Icons.bookmarks_outlined),
        activeIcon: Icon(Icons.bookmarks_rounded),
      ),
      if (useHomeworksAndExams)
        const BottomNavigationBarItem(
          icon: Icon(Icons.area_chart_outlined),
          activeIcon: Icon(Icons.area_chart_rounded),
          label: 'النتائج',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline_rounded),
        activeIcon: Icon(Icons.person_rounded),
        label: 'الملف الشخصي',
      ),
    ];

    final guestSidebarItems = <_SidebarItem>[
      _SidebarItem(
        label: 'المحتويات',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _SidebarItem(
        label: 'الملازم',
        icon: Icons.bookmarks_outlined,
        activeIcon: Icons.bookmarks_rounded,
      ),
      if (useHomeworksAndExams)
        _SidebarItem(
          label: 'النتائج',
          icon: Icons.area_chart_outlined,
          activeIcon: Icons.area_chart_rounded,
        ),
      _SidebarItem(
        label: 'الملف الشخصي',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    // Reviewer pages
    final reviewPages = <Widget>[
      TopicsPage(inReview: inReviewMode),
      BooksPage(),
      if (useHomeworksAndExams) ResultsPage(),
      SettingsPage(),
    ];

    final reviewItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_rounded),
        label: 'المحتويات',
      ),
      BottomNavigationBarItem(
        label: 'الملازم',
        icon: Icon(Icons.bookmarks_outlined),
        activeIcon: Icon(Icons.bookmarks_rounded),
      ),
      if (useHomeworksAndExams)
        const BottomNavigationBarItem(
          icon: Icon(Icons.area_chart_outlined),
          activeIcon: Icon(Icons.area_chart_rounded),
          label: 'النتائج',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline_rounded),
        activeIcon: Icon(Icons.person_rounded),
        label: 'الملف الشخصي',
      ),
    ];

    final reviewSidebarItems = <_SidebarItem>[
      _SidebarItem(
        label: 'المحتويات',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _SidebarItem(
        label: 'الملازم',
        icon: Icons.bookmarks_outlined,
        activeIcon: Icons.bookmarks_rounded,
      ),
      if (useHomeworksAndExams)
        _SidebarItem(
          label: 'النتائج',
          icon: Icons.area_chart_outlined,
          activeIcon: Icons.area_chart_rounded,
        ),
      _SidebarItem(
        label: 'الملف الشخصي',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    // Apply final pages
    if (inReviewMode) {
      _pages = reviewPages;
      _navItems = reviewItems;
      _sidebarItems = reviewSidebarItems;
    } else if (guestParam) {
      _pages = guestPages;
      _navItems = guestItems;
      _sidebarItems = guestSidebarItems;
    } else {
      _pages = normalPages;
      _navItems = normalItems;
      _sidebarItems = normalSidebarItems;
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

    final primary = Theme.of(context).colorScheme.primary;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      return Scaffold(
        extendBody: false,
        //backgroundColor: Colors.transparent,
        body: Row(
          children: [
            _buildModernSidebar(context, primary),
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _pages,
                  onPageChanged: (value) {
                    setState(() => _currentIndex = value);
                  },
                ),
              ),
            ),
          ],
        ),
      );
    } else {
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
  }

  Widget _buildModernSidebar(BuildContext context, Color primary) {
    final sidebarWidth = _sidebarCollapsed ? 75.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      width: sidebarWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Container(
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 8),
                spreadRadius: 4,
              ),
              BoxShadow(
                color: primary.withOpacity(0.15),
                blurRadius: 50,
                offset: const Offset(0, 16),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            children: [
              // Modern header
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 12,
                ),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  crossFadeState: _sidebarCollapsed
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          _buildModernCollapseButton(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Al-Shobaki Academy',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName.isNotEmpty ? userName : 'مستخدم',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  secondChild: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildModernCollapseButton(),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Divider(color: Colors.white.withOpacity(0.1), height: 1),
              ),
              // Navigation items with smooth scrolling
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _sidebarItems.length,
                  itemBuilder: (context, index) {
                    final item = _sidebarItems[index];
                    final isActive = _currentIndex == index;

                    return _buildModernNavItem(
                      context,
                      item,
                      isActive,
                      index,
                      primary,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Divider(color: Colors.white.withOpacity(0.1), height: 1),
              ),
              // Guest annotation integrated in footer
              if (guestParam)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 400),
                    crossFadeState: _sidebarCollapsed
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: _buildGuestFooter(context),
                    secondChild: Tooltip(
                      message: 'أنت في الوضع الضيف',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Colors.orange,
                          size: 18,
                        ),
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

  Widget _buildGuestFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.orange, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'سجل دخولك للوصول لكل الميزات',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              onPressed: () {
                loadingDilog(context);
                AuthController().exitGuestMode().then(
                  (_) => Get.offAll(() => LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                'دخول الآن',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCollapseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _sidebarCollapsed = !_sidebarCollapsed);
        },
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedRotation(
            turns: _sidebarCollapsed ? 0.5 : 0,
            duration: const Duration(milliseconds: 400),
            child: Icon(Icons.chevron_left, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavItem(
    BuildContext context,
    _SidebarItem item,
    bool isActive,
    int index,
    Color primary,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Tooltip(
        message: _sidebarCollapsed ? item.label : '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onTapNav(index),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: _sidebarCollapsed ? 8 : 12,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(0.18) : null,
                borderRadius: BorderRadius.circular(16),
                border: isActive
                    ? Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.2,
                      )
                    : null,
              ),
              child: _sidebarCollapsed
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            duration: const Duration(milliseconds: 300),
                            scale: isActive ? 1.15 : 1.0,
                            child: Icon(
                              isActive ? item.activeIcon : item.icon,
                              color: isActive ? Colors.white : Colors.white70,
                              size: 20,
                            ),
                          ),
                          if (isActive)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Container(
                                width: 5,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        AnimatedScale(
                          duration: const Duration(milliseconds: 300),
                          scale: isActive ? 1.15 : 1.0,
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive ? Colors.white : Colors.white70,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            width: 5,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
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
                Expanded(
                  child: Text(
                    'قم بانشاء حساب او سجل الدخول للوصول لكل الميزات ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    loadingDilog(context);
                    AuthController().exitGuestMode().then(
                      (_) => Get.offAll(() => LoginPage()),
                    );
                  },
                  style: TextButton.styleFrom(backgroundColor: Colors.orange),
                  child: Text(
                    'دخول',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium!.copyWith(color: Colors.white),
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
