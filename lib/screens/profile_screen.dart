import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/ad_model.dart';
import 'ad_detail_screen.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _activeTab = 0;
  String _userName = '';
  String _userEmail = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await SupabaseService.client
            .from('profiles')
            .select('name')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _userName = response?['name'] ?? 'مستخدم';
            _userEmail = user.email ?? '';
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _userName = 'مستخدم';
            _userEmail = user.email ?? '';
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await SupabaseService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  void _openAdDetail(AdModel ad) {
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
        title: const Text('حسابي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF005B41)))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF005B41),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Color(0xFF005B41)),
                      ),
                      const SizedBox(height: 10),
                      Text(_userName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_userEmail,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeTab == 0
                              ? const Color(0xFFFF9800)
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () => setState(() => _activeTab = 0),
                        child: const Text('إعلاناتي'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeTab == 1
                              ? const Color(0xFFFF9800)
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () => setState(() => _activeTab = 1),
                        child: const Text('المفضلة'),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: _activeTab == 0 ? _buildMyAds() : _buildFavorites(),
                ),
              ],
            ),
    );
  }

  Widget _buildMyAds() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const Center(child: Text('سجل الدخول'));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('ads')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF005B41)));
        }

        final myAds = snapshot.data!
            .map((doc) => AdModel.fromMap(doc, doc['id'] ?? ''))
            .toList();

        if (myAds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.post_add, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('لم تنشر أي إعلان بعد',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: myAds.length,
          itemBuilder: (context, index) {
            final ad = myAds[index];
            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ad.imageUrls.isNotEmpty
                      ? Image.network(ad.imageUrls.first,
                          width: 60, height: 60, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(width: 60, height: 60, color: Colors.grey))
                      : Container(
                          width: 60, height: 60, color: Colors.grey.shade300,
                          child: const Icon(Icons.image, color: Colors.grey)),
                ),
                title: Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.category, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ad.isApproved
                            ? Colors.green.shade100
                            : ad.isPending
                                ? Colors.orange.shade100
                                : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ad.isApproved
                            ? 'منشور'
                            : ad.isPending
                                ? 'قيد المراجعة'
                                : 'مرفوض',
                        style: TextStyle(
                          fontSize: 11,
                          color: ad.isApproved
                              ? Colors.green.shade800
                              : ad.isPending
                                  ? Colors.orange.shade800
                                  : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => _openAdDetail(ad),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFavorites() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return const Center(child: Text('سجل الدخول'));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('favorites')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF005B41)));
        }

        final favoriteAdIds = snapshot.data!.map((doc) => doc['ad_id'] as String).toList();

        if (favoriteAdIds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('لا توجد إعلانات في المفضلة',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.client
              .from('ads')
              .stream(primaryKey: ['id'])
              .inFilter('id', favoriteAdIds)
              .eq('status', 'approved'),
          builder: (context, adSnapshot) {
            if (!adSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF005B41)));
            }

            final favAds = adSnapshot.data!
                .map((doc) => AdModel.fromMap(doc, doc['id'] ?? ''))
                .toList();

            if (favAds.isEmpty) {
              return const Center(child: Text('الإعلانات المفضلة لم تعد متوفرة'));
            }

            return ListView.builder(
              itemCount: favAds.length,
              itemBuilder: (context, index) {
                final ad = favAds[index];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ad.imageUrls.isNotEmpty
                          ? Image.network(ad.imageUrls.first,
                              width: 60, height: 60, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(width: 60, height: 60, color: Colors.grey))
                          : Container(
                              width: 60, height: 60, color: Colors.grey.shade300,
                              child: const Icon(Icons.image, color: Colors.grey)),
                    ),
                    title: Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${ad.province} - ${ad.city}'),
                    onTap: () => _openAdDetail(ad),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
