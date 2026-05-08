import 'dart:convert';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shobaki_academy/controller/auth_controller.dart';
import 'package:shobaki_academy/extentions.dart';
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
  late final NotchBottomBarController _notchBottomBarController;
  int _currentIndex = 0;
  bool _sidebarCollapsed = false;

  /// ⭐ Prevents LateInitializationError
  List<Widget> _pages = [];
  List<BottomBarItem> _navItems = [];
  List<_SidebarItem> _sidebarItems = [];

  bool _loadingPages = true;

  @override
  void initState() {
    super.initState();

    final localDb = Get.find<LocalDB>();
    final prefs = localDb.sharedPref!;
    _notchBottomBarController = NotchBottomBarController(index: _currentIndex);

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

    final normalItems = <BottomBarItem>[
      BottomBarItem(
        activeItem: Icon(
          Icons.home_rounded,
          color: Theme.of(context).primaryColor,
        ),
        inActiveItem: Icon(Icons.home_outlined),
      ),
      BottomBarItem(
        inActiveItem: Icon(Icons.bookmarks_outlined),
        activeItem: Icon(
          Icons.bookmarks_rounded,
          color: Theme.of(context).primaryColor,
        ),
      ),
      BottomBarItem(
        activeItem: Icon(Icons.bookmark, color: Theme.of(context).primaryColor),
        inActiveItem: Icon(Icons.bookmark_border),
      ),
      if (useHomeworksAndExams)
        BottomBarItem(
          activeItem: Icon(
            Icons.area_chart_rounded,
            color: Theme.of(context).primaryColor,
          ),
          inActiveItem: Icon(Icons.area_chart_outlined),
        ),
      BottomBarItem(
        activeItem: Icon(
          Icons.person_rounded,
          color: Theme.of(context).primaryColor,
        ),
        inActiveItem: Icon(Icons.person_outline_rounded),
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

    final guestItems = <BottomBarItem>[
      BottomBarItem(
        activeItem: Icon(
          Icons.home_rounded,
          color: Theme.of(context).primaryColor,
        ),
        inActiveItem: Icon(Icons.home_outlined),
      ),
      BottomBarItem(
        inActiveItem: Icon(Icons.bookmarks_outlined),
        activeItem: Icon(
          Icons.bookmarks_rounded,
          color: Theme.of(context).primaryColor,
        ),
      ),
      if (useHomeworksAndExams)
        BottomBarItem(
          activeItem: Icon(
            Icons.area_chart_rounded,
            color: Theme.of(context).primaryColor,
          ),
          inActiveItem: Icon(Icons.area_chart_outlined),
        ),
      BottomBarItem(
        activeItem: Icon(
          Icons.person_rounded,
          color: Theme.of(context).primaryColor,
        ),
        inActiveItem: Icon(Icons.person_outline_rounded),
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

    final reviewItems = <BottomBarItem>[
      BottomBarItem(
        activeItem: Icon(
          Icons.home_rounded,
          color: Theme.of(context).primaryColor,
        ),
        inActiveItem: Icon(Icons.home_outlined),
      ),
      BottomBarItem(
        inActiveItem: Icon(Icons.bookmarks_outlined),
        activeItem: Icon(
          Icons.bookmarks_rounded,
          color: Theme.of(context).primaryColor,
        ),
      ),
      if (useHomeworksAndExams)
        BottomBarItem(
          activeItem: Icon(
            Icons.area_chart_rounded,
            color: Theme.of(context).primaryColor,
          ),
          inActiveItem: Icon(Icons.area_chart_outlined),
        ),
      BottomBarItem(
        activeItem: Icon(
          Icons.person_rounded,
          color: Theme.of(context).primaryColor,
        ),
        inActiveItem: Icon(Icons.person_outline_rounded),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final width = MediaQuery.of(context).size.width;
      if (width >= 600 && width < 1400) {
        setState(() => _sidebarCollapsed = true);
      }
      if (width >= 600 && width < 1200) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    if (isDesktop || isTablet) {
      return Scaffold(
        extendBody: false,
        body: Row(
          children: [
            Center(
              child: _buildModernSidebar(context, primary, isTablet: isTablet),
            ),
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
        bottomNavigationBar: bottomNavBar(context),
      );
    }
  }

  Widget _buildModernSidebar(
    BuildContext context,
    Color primary, {
    bool isTablet = false,
  }) {
    final double collapsedW = isTablet ? 90.0 : 95.0;
    final double expandedW = isTablet ? 200.0 : 260.0;
    final sidebarWidth = _sidebarCollapsed ? collapsedW : expandedW;

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
                color: primary.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: primary.withValues(alpha: 0.08),
                blurRadius: 35,
                offset: const Offset(0, 12),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                              color: Colors.white.withValues(alpha: 0.15),
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
                            color: Colors.white.withValues(alpha: 0.15),
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
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.1),
                  height: 1,
                ),
              ),
              // Navigation items with smooth scrolling
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.1),
                  height: 1,
                ),
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
                          color: Colors.orange.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.5),
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
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.orange, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ' سجل الدخول للوصول لكل الميزات',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
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
                color: isActive ? Colors.white.withValues(alpha: 0.18) : null,
                borderRadius: BorderRadius.circular(16),
                border: isActive
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
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
      elevation: 0,
      flexibleSpace: Container(color: Theme.of(context).colorScheme.primary),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(25),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange, width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'قم بانشاء حساب او سجل الدخول للوصول لكل الميزات ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
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

  AnimatedNotchBottomBar bottomNavBar(BuildContext context) {
    return AnimatedNotchBottomBar(
      notchBottomBarController: _notchBottomBarController,
      bottomBarItems: _navItems,
      onTap: (value) {
        final oldPage = _pageController.page!.toInt();

        if (oldPage > value) {
          _pageController.animateToPage(
            value,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeIn,
          );
        } else {
          _pageController.animateToPage(
            value,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
          _notchBottomBarController.index = value;
        }
      },
      kIconSize: 24.0,
      kBottomRadius: 28.0,
      notchColor: Colors.black87,

      showLabel: false,
      textOverflow: TextOverflow.visible,
      maxLine: 1,
      color: Theme.of(context).colorScheme.primary,
      removeMargins: false,
      bottomBarWidth: context.screenW,
      showShadow: true,
      durationInMilliSeconds: 400,
      itemLabelStyle: Theme.of(context).textTheme.bodySmall,
      elevation: 1,
    );
  }
}
