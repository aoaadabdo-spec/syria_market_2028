import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../models/ad_model.dart';
import '../constants/app_constants.dart';
import 'ad_detail_screen.dart';
import '../widgets/ad_card.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String categoryTitle;

  const CategoryDetailScreen({super.key, required this.categoryTitle});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  String _selectedProvince = 'الكل';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<Map<String, dynamic>>? _subCategories;

  @override
  void initState() {
    super.initState();
    _subCategories = AppConstants.subCategories[widget.categoryTitle];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: Text('قسم: ${widget.categoryTitle}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث في هذا القسم...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          if (_subCategories != null && _subCategories!.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _subCategories!.length,
                itemBuilder: (context, index) {
                  final sub = _subCategories![index];
                  return GestureDetector(
                    onTap: () {
                      SystemSound.play(SystemSoundType.click);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CategoryDetailScreen(categoryTitle: sub['title']),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(sub['color'] as int).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(sub['color'] as int).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        sub['title'] as String,
                        style: TextStyle(
                          color: Color(sub['color'] as int),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: AppConstants.provinces.length,
              itemBuilder: (context, index) {
                final prov = AppConstants.provinces[index];
                final isSelected = prov == _selectedProvince;
                return GestureDetector(
                  onTap: () => setState(() => _selectedProvince = prov),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF005B41) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF005B41) : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      prov,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client
                  .from('ads')
                  .stream(primaryKey: ['id'])
                  .eq('status', 'approved')
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF005B41)),
                  );
                }

                final allAds = snapshot.data!
                    .map((doc) => AdModel.fromMap(doc, doc['id'] ?? ''))
                    .where((ad) {
                  bool matchesCategory = ad.category == widget.categoryTitle ||
                      ad.category.startsWith(widget.categoryTitle);
                  bool matchesProvince =
                      _selectedProvince == 'الكل' || ad.province == _selectedProvince;
                  bool matchesSearch = _searchQuery.isEmpty ||
                      ad.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      ad.description.toLowerCase().contains(_searchQuery.toLowerCase());
                  return matchesCategory && matchesProvince && matchesSearch;
                }).toList();

                if (allAds.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد إعلانات في هذا القسم حالياً',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: allAds.length,
                  itemBuilder: (context, index) {
                    final ad = allAds[index];
                    return AdCard(
                      ad: ad,
                      isSponsored: ad.isSponsored,
                      onTap: () => _openAdDetail(ad),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
