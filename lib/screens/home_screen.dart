import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/ad_model.dart';
import '../constants/app_constants.dart';
import 'category_detail_screen.dart';
import 'ad_detail_screen.dart';
import 'create_ad_screen.dart';
import 'admin_dashboard_screen.dart';
import 'profile_screen.dart';
import '../widgets/ad_card.dart';
import '../widgets/category_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedProvince = 'الكل';
  bool _isAdmin = false;
  StreamSubscription? _pendingSub;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _listenToPendingAds();
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    super.dispose();
  }

  void _checkAdmin() async {
    final admin = await SupabaseService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  int _pendingCount = 0;

  void _listenToPendingAds() {
    _pendingSub = SupabaseService.client
        .from('ads')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .listen((data) {
      if (mounted) setState(() => _pendingCount = data.length);
    });
  }

  void _navigateToCategory(String categoryName) {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(categoryTitle: categoryName),
      ),
    );
  }

  void _navigateToSelectCategoryForAd() {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateAdScreen(),
      ),
    );
  }

  void _navigateToAdmin() {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminDashboardScreen(),
      ),
    );
  }

  void _navigateToProfile() {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _openPostDetail(AdModel ad) {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdDetailScreen(ad: ad),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سوق سوريا الشامل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'حسابي وإعلاناتي',
            onPressed: _navigateToProfile,
          ),
          if (_isAdmin)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  tooltip: 'لوحة الإدارة',
                  onPressed: _navigateToAdmin,
                ),
                if (_pendingCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF005B41),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: AppConstants.provinces.length,
                itemBuilder: (context, index) {
                  final prov = AppConstants.provinces[index];
                  final isSelected = prov == _selectedProvince;
                  return GestureDetector(
                    onTap: () {
                      SystemSound.play(SystemSoundType.click);
                      setState(() => _selectedProvince = prov);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF9800) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF9800) : Colors.white54,
                        ),
                      ),
                      child: Text(
                        prov,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.3,
                    children: AppConstants.categories.map((cat) {
                      return CategoryCard(
                        title: cat['title'] as String,
                        iconData: _getIconData(cat['icon'] as String),
                        color: Color(cat['color'] as int),
                        onTap: () => _navigateToCategory(cat['title'] as String),
                      );
                    }).toList(),
                  ),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client
                      .from('ads')
                      .stream(primaryKey: ['id'])
                      .eq('status', 'approved')
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: Color(0xFF005B41)),
                        ),
                      );
                    }

                    if (snapshot.hasData && snapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'لا توجد إعلانات منشورة حالياً\nكن أول من ينشر إعلاناً!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    final allAds = snapshot.data!
                        .map((doc) => AdModel.fromMap(doc, doc['id'] ?? ''))
                        .where((ad) {
                      return _selectedProvince == 'الكل' || ad.province == _selectedProvince;
                    }).toList();

                    final sponsoredAds = allAds.where((ad) => ad.isSponsored).toList();
                    final regularAds = allAds.where((ad) => !ad.isSponsored).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sponsoredAds.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade700),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'إعلانات ممولة ومثبتة',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...sponsoredAds.map((ad) => AdCard(
                                ad: ad,
                                isSponsored: true,
                                onTap: () => _openPostDetail(ad),
                              )),
                          const Divider(),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'الإعلانات المنشورة ($_selectedProvince)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF005B41),
                            ),
                          ),
                        ),
                        if (regularAds.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                'لا توجد إعلانات في هذه المحافظة حالياً',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ...regularAds.map((ad) => AdCard(
                                ad: ad,
                                isSponsored: false,
                                onTap: () => _openPostDetail(ad),
                              )),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF9800),
        onPressed: _navigateToSelectCategoryForAd,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'نشر إعلان جديد',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  IconData _getIconData(String name) {
    const icons = {
      'directions_car': Icons.directions_car,
      'home': Icons.home,
      'smartphone': Icons.smartphone,
      'chair': Icons.chair,
      'pets': Icons.pets,
      'campaign': Icons.campaign,
      'autorenew': Icons.autorenew,
      'work': Icons.work,
      'home_work': Icons.home_work,
      'vpn_key': Icons.vpn_key,
      'laptop': Icons.laptop,
      'devices': Icons.devices,
      'flutter_dash': Icons.flutter_dash,
      'music_note': Icons.music_note,
      'bedroom_baby': Icons.bedroom_baby,
    };
    return icons[name] ?? Icons.category;
  }
}
