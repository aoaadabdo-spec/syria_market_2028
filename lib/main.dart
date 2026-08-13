import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase Init Error: $e");
  }

  runApp(const SyriaMarketApp());
}

// معرف المستخدم الحالي وهل هو مدير (للتجربة والتحكم بالصلاحيات)
const String currentUserId = 'u1';
const bool isCurrentAdmin = true;

// ---------------- 1. التطبيق الرئيسي ----------------
class SyriaMarketApp extends StatelessWidget {
  const SyriaMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سوق سوريا الشامل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        primaryColor: const Color(0xFF005B41),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

// ---------------- 2. نموذج بيانات الإعلان ونموذج المشرف ----------------
enum CurrencyType { syrian, usd, both }

class AdModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String province;
  final String city;
  final String phone;
  final String contactMethod; // اتصال هاتف - واتساب - تليجرام
  final String priceSyrian;
  final String priceUSD;
  final CurrencyType currencyType;
  String
  status; // 'pending' (قيد الانتظار), 'approved' (مقبول), 'rejected' (مرفوض)
  String? rejectionReason; // سبب الرفض
  List<String> imageUrls; // قوائم الصور المرافقة (روابط فايربيس السحابية)
  List<String> videoUrls; // قوائم الفيديوهات (روابط فايربيس السحابية)
  bool isSold; // حالة البيع
  bool isSponsored; // إعلان ممول وثابت في الأعلى 🌟
  String ownerId; // معرف صاحب المنشور
  DateTime createdAt;

  AdModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.province,
    required this.city,
    required this.phone,
    required this.contactMethod,
    this.priceSyrian = '',
    this.priceUSD = '',
    required this.currencyType,
    this.status = 'pending',
    this.rejectionReason,
    required this.imageUrls,
    this.videoUrls = const [],
    this.isSold = false,
    this.isSponsored = false,
    this.ownerId = 'u1',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // تحويل البيانات إلى خريطة لرفعها إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'province': province,
      'city': city,
      'phone': phone,
      'contactMethod': contactMethod,
      'priceSyrian': priceSyrian,
      'priceUSD': priceUSD,
      'currencyType': currencyType.index,
      'status': status,
      'rejectionReason': rejectionReason,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'isSold': isSold,
      'isSponsored': isSponsored,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // إنشاء نموذج من وثيقة Firestore
  factory AdModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AdModel(
      id: map['id'] ?? documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      province: map['province'] ?? '',
      city: map['city'] ?? '',
      phone: map['phone'] ?? '',
      contactMethod: map['contactMethod'] ?? '',
      priceSyrian: map['priceSyrian'] ?? '',
      priceUSD: map['priceUSD'] ?? '',
      currencyType: CurrencyType.values[map['currencyType'] ?? 0],
      status: map['status'] ?? 'pending',
      rejectionReason: map['rejectionReason'],
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      videoUrls: List<String>.from(map['videoUrls'] ?? []),
      isSold: map['isSold'] ?? false,
      isSponsored: map['isSponsored'] ?? false,
      ownerId: map['ownerId'] ?? 'u1',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class SupervisorModel {
  final String id;
  final String name;
  bool canApprovePosts;
  bool canRejectPosts;

  SupervisorModel({
    required this.id,
    required this.name,
    this.canApprovePosts = true,
    this.canRejectPosts = true,
  });
}

// قائمة المشرفين المحلية
List<SupervisorModel> globalSupervisors = [
  SupervisorModel(
    id: 's1',
    name: 'المشرف أحمد',
    canApprovePosts: true,
    canRejectPosts: true,
  ),
  SupervisorModel(
    id: 's2',
    name: 'المشرف خالد',
    canApprovePosts: true,
    canRejectPosts: false,
  ),
];

// ---------------- 3. الصفحة الرئيسية ----------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedProvince = 'الكل 🌐';

  final List<String> provinces = [
    'الكل 🌐',
    'دمشق (العاصمة)',
    'ريف دمشق',
    'حلب',
    'حمص',
    'حماة',
    'اللاذقية',
    'طرطوس',
    'إدلب',
    'دير الزور',
    'الرقة',
    'الحسكة',
    'درعا',
    'السويداء',
    'القنيطرة',
  ];

  void _navigateToCategory(String categoryName) {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: CategoryDetailScreen(categoryTitle: categoryName),
        ),
      ),
    );
  }

  void _navigateToRealEstateMarket() {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const Directionality(
          textDirection: TextDirection.rtl,
          child: RealEstateMarketScreen(),
        ),
      ),
    );
  }

  void _navigateToElectronicsMarket() {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const Directionality(
          textDirection: TextDirection.rtl,
          child: ElectronicsMarketScreen(),
        ),
      ),
    );
  }

  void _navigateToBirdsMarket() {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const Directionality(
          textDirection: TextDirection.rtl,
          child: BirdsMarketScreen(),
        ),
      ),
    );
  }

  void _navigateToSelectCategoryForAd() {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: SelectCategoryScreen(
            provincesList: provinces.where((p) => p != 'الكل 🌐').toList(),
          ),
        ),
      ),
    );
  }

  void _navigateToAdminVerification() {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const Directionality(
          textDirection: TextDirection.rtl,
          child: AdminVerificationScreen(),
        ),
      ),
    );
  }

  void _openPostDetail(AdModel ad) {
    SystemSound.play(SystemSoundType.click);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: PostDetailScreen(ad: ad),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.network(
              'https://picsum.photos/150/150?random=logo',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.store, color: Colors.white),
            ),
          ),
        ),
        title: const Text('سوق سوريا الشامل'),
        backgroundColor: const Color(0xFF005B41),
        centerTitle: true,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ads')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              int pendingCount = snapshot.hasData
                  ? snapshot.data!.docs.length
                  : 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.admin_panel_settings),
                    tooltip: 'لوحة الإشراف والإدارة',
                    onPressed: _navigateToAdminVerification,
                  ),
                  if (pendingCount > 0)
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
                          '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
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
                itemCount: provinces.length,
                itemBuilder: (context, index) {
                  final prov = provinces[index];
                  final isSelected = prov == selectedProvince;
                  return GestureDetector(
                    onTap: () {
                      SystemSound.play(SystemSoundType.click);
                      setState(() => selectedProvince = prov);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF9800)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF9800)
                              : Colors.white54,
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
                    children: [
                      CategoryCard(
                        title: 'سيارات',
                        icon: Icons.directions_car,
                        color: Colors.orange,
                        onTap: () => _navigateToCategory('سيارات'),
                      ),
                      CategoryCard(
                        title: 'عقارات',
                        icon: Icons.home,
                        color: Colors.blue,
                        onTap: _navigateToRealEstateMarket,
                      ),
                      CategoryCard(
                        title: 'إلكترونيات',
                        icon: Icons.smartphone,
                        color: Colors.indigo,
                        onTap: _navigateToElectronicsMarket,
                      ),
                      CategoryCard(
                        title: 'أدوات منزلية',
                        icon: Icons.chair,
                        color: Colors.purple,
                        onTap: () => _navigateToCategory('أدوات منزلية'),
                      ),
                      CategoryCard(
                        title: 'الطيور والحيوانات',
                        icon: Icons.flutter_dash,
                        color: Colors.amber.shade800,
                        onTap: _navigateToBirdsMarket,
                      ),
                      CategoryCard(
                        title: 'إعلانات تجارية',
                        icon: Icons.campaign,
                        color: Colors.deepOrange,
                        onTap: () => _navigateToCategory('إعلانات تجارية'),
                      ),
                      CategoryCard(
                        title: 'سوق المستعمل',
                        icon: Icons.autorenew,
                        color: Colors.teal,
                        onTap: () => _navigateToCategory('سوق المستعمل'),
                      ),
                      CategoryCard(
                        title: 'وظائف وعمال',
                        icon: Icons.work,
                        color: Colors.blueGrey,
                        onTap: () => _navigateToCategory('وظائف وعمال'),
                      ),
                    ],
                  ),
                ),

                // جلب الإعلانات الحقيقية من فايربيس (Firestore Stream)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ads')
                      .where('status', isEqualTo: 'approved')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF005B41),
                        ),
                      );
                    }

                    final allAds = snapshot.data!.docs.map((doc) {
                      return AdModel.fromMap(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      );
                    }).toList();

                    final sponsoredAds = allAds.where((ad) {
                      bool matchesProvince =
                          selectedProvince == 'الكل 🌐' ||
                          ad.province == selectedProvince;
                      return ad.isSponsored && matchesProvince;
                    }).toList();

                    final approvedAds = allAds.where((ad) {
                      bool matchesProvince =
                          selectedProvince == 'الكل 🌐' ||
                          ad.province == selectedProvince;
                      return !ad.isSponsored && matchesProvince;
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // قسم الإعلانات الممولة الثابتة
                        if (sponsoredAds.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
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
                                  'إعلانات ممولة ومثبتة برعاية السوق 🌟',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sponsoredAds.length,
                            itemBuilder: (context, index) {
                              final ad = sponsoredAds[index];
                              return _buildAdCard(ad, isSponsoredCard: true);
                            },
                          ),
                          const Divider(),
                        ],

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'الإعلانات المنشورة العادية ($selectedProvince)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF005B41),
                            ),
                          ),
                        ),
                        approvedAds.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(
                                  child: Text(
                                    'لا توجد إعلانات عادية موافق عليها حالياً في هذه المحافظة 📭',
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: approvedAds.length,
                                itemBuilder: (context, index) {
                                  final ad = approvedAds[index];
                                  return _buildAdCard(
                                    ad,
                                    isSponsoredCard: false,
                                  );
                                },
                              ),
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

  Widget _buildAdCard(AdModel ad, {required bool isSponsoredCard}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isSponsoredCard ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSponsoredCard
            ? const BorderSide(color: Color(0xFFFF9800), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _openPostDetail(ad),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isSponsoredCard) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ممول 🌟',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            ad.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ad.province} - ${ad.city}\nالقسم: ${ad.category}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (!ad.category.contains('وظائف'))
                      Text(
                        ad.currencyType == CurrencyType.syrian
                            ? ad.priceSyrian
                            : ad.currencyType == CurrencyType.usd
                            ? ad.priceUSD
                            : '${ad.priceSyrian} / ${ad.priceUSD}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      isSponsoredCard
                          ? 'إعلان ممول ثابت لاختيار مشاهدة التفاصيل 👈'
                          : 'اضغط لمشاهدة التفاصيل الكاملة 👈',
                      style: TextStyle(
                        color: isSponsoredCard
                            ? const Color(0xFFFF9800)
                            : const Color(0xFF005B41),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      ad.imageUrls.isNotEmpty
                          ? ad.imageUrls.first
                          : 'https://picsum.photos/200/200',
                      width: 95,
                      height: 95,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 95,
                        height: 95,
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  if (ad.isSold)
                    Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Text(
                          'تم البيع 🏷️',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 4. صفحة عرض المنشور المفصل ----------------
class PostDetailScreen extends StatefulWidget {
  final AdModel ad;
  const PostDetailScreen({super.key, required this.ad});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  int _selectedImageIndex = 0;
  late AdModel ad;

  @override
  void initState() {
    super.initState();
    ad = widget.ad;
  }

  // تحديث حالة الإعلان في فايربيس (تعديل الختم أو التمويل)
  Future<void> _updateAdInFirestore(
    Map<String, dynamic> updateData,
    String successMessage,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('ads')
          .doc(ad.id)
          .update(updateData);
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء التحديث: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canManageAd = (ad.ownerId == currentUserId) || isCurrentAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(ad.title),
        backgroundColor: const Color(0xFF005B41),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              SystemSound.play(SystemSoundType.click);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ رابط المنشور بنجاح! 📋')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: ad.imageUrls.isNotEmpty
                      ? Image.network(
                          ad.imageUrls[_selectedImageIndex],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey.shade300,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.image,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                ),
                if (ad.isSold)
                  Transform.rotate(
                    angle: -0.2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'تم البيع 🔴 SOLD',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            if (ad.imageUrls.length > 1)
              Container(
                height: 70,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.black12,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: ad.imageUrls.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => setState(() => _selectedImageIndex = index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedImageIndex == index
                                ? const Color(0xFFFF9800)
                                : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            ad.imageUrls[index],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ad.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (canManageAd)
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ad.isSponsored
                                    ? Colors.amber.shade800
                                    : Colors.blueGrey,
                              ),
                              onPressed: () {
                                SystemSound.play(SystemSoundType.click);
                                setState(() {
                                  ad.isSponsored = !ad.isSponsored;
                                });
                                _updateAdInFirestore(
                                  {'isSponsored': ad.isSponsored},
                                  ad.isSponsored
                                      ? 'تم جعل الإعلان ممولاً وثابتاً في أعلى الصفحة الرئيسية 🌟'
                                      : 'تم إلغاء تمويل الإعلان وجعله عادياً 🔄',
                                );
                              },
                              icon: const Icon(Icons.star, color: Colors.white),
                              label: Text(
                                ad.isSponsored
                                    ? 'إلغاء التمويل'
                                    : 'تمويل وتثبيت 🌟',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ad.isSold
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              onPressed: () {
                                SystemSound.play(SystemSoundType.click);
                                setState(() {
                                  ad.isSold = !ad.isSold;
                                });
                                _updateAdInFirestore(
                                  {'isSold': ad.isSold},
                                  ad.isSold
                                      ? 'تم وضع ختم "تم البيع" الكبير على الإعلان 🏷️'
                                      : 'تمت إعادة فتح الإعلان 🔄',
                                );
                              },
                              icon: Icon(
                                ad.isSold ? Icons.undo : Icons.sell,
                                color: Colors.white,
                              ),
                              label: Text(
                                ad.isSold ? 'إلغاء الختم' : 'ختم تم البيع 🏷️',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (!ad.category.contains('وظائف'))
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_money, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'السعر المطلوب: ${ad.currencyType == CurrencyType.syrian
                                ? ad.priceSyrian
                                : ad.currencyType == CurrencyType.usd
                                ? ad.priceUSD
                                : "${ad.priceSyrian} / ${ad.priceUSD}"}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Text(
                    'تفاصيل ومعلومات المنشور الكاملة:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF005B41),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.category,
                      color: Color(0xFF005B41),
                    ),
                    title: const Text('القسم'),
                    subtitle: Text(ad.category),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.location_on,
                      color: Color(0xFF005B41),
                    ),
                    title: const Text('الموقع والمحافظة'),
                    subtitle: Text('${ad.province} - ${ad.city}'),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.description,
                      color: Color(0xFF005B41),
                    ),
                    title: const Text('الوصف والمواصفات الكاملة'),
                    subtitle: Text(
                      ad.description,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),

                  if (ad.videoUrls.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'مقاطع الفيديو المرفقة 🎥:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.play_circle_fill,
                            color: Color(0xFFFF9800),
                            size: 30,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'يوجد فيديو استعراضي متاح لهذا المنشور',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Text(
                    'طرق التواصل مع الناشر:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF005B41),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طريقة التواصل: ${ad.contactMethod}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الرقم: ${ad.phone}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005B41),
                          ),
                          onPressed: () {
                            SystemSound.play(SystemSoundType.click);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('جاري الاتصال بـ ${ad.phone}...'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text(
                            'اتصال 📞',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 5. شاشة التحقق الأمني للإدارة ----------------
class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  final String adminEmail = "aoaadabdo@gmail.com";
  final String adminPhone = "0992486464";

  String verificationChannel = 'email';
  String? generatedOtp;
  final TextEditingController otpController = TextEditingController();
  bool codeSent = false;
  bool isLoading = false;

  void sendVerificationCode() async {
    SystemSound.play(SystemSoundType.click);
    setState(() => isLoading = true);

    final random = Random();
    generatedOtp = (100000 + random.nextInt(900000)).toString();

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      isLoading = false;
      codeSent = true;
    });

    String destination = verificationChannel == 'phone'
        ? adminPhone
        : adminEmail;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إرسال رمز التحقق السري بنجاح إلى: $destination 📨'),
        backgroundColor: const Color(0xFF005B41),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void verifyCode() {
    SystemSound.play(SystemSoundType.click);
    if (otpController.text.trim() == generatedOtp) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Directionality(
            textDirection: TextDirection.rtl,
            child: AdminDashboardScreen(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'رمز التحقق غير صحيح، يرجى التأكد من الرسالة الواردة ❌',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق الأمني الآمن للإدارة 🔐'),
        backgroundColor: const Color(0xFF005B41),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 75,
              color: Color(0xFF005B41),
            ),
            const SizedBox(height: 16),
            const Text(
              'منطقة حماية خاصة بالمدير\nاختر وسيلة استلام الرمز السري:',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (!codeSent) ...[
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'رسالة SMS',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        adminPhone,
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: 'phone',
                      groupValue: verificationChannel,
                      onChanged: (val) =>
                          setState(() => verificationChannel = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'البريد الإلكتروني',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        adminEmail,
                        style: const TextStyle(
                          fontSize: 11,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      value: 'email',
                      groupValue: verificationChannel,
                      onChanged: (val) =>
                          setState(() => verificationChannel = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF005B41),
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005B41),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: sendVerificationCode,
                      child: const Text(
                        'إرسال الرمز السري 🚀',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ] else ...[
              Text(
                'تم إرسال رمز التحقق إلى بريدك أو هاتفك الخاص.\nيرجى تفقد رسائلك وإدخال الرمز هنا:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  labelText: 'أدخل الرمز المكون من 6 أرقام',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: verifyCode,
                child: const Text(
                  'تأكيد والدخول للوحة الإدارة ✅',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    codeSent = false;
                    otpController.clear();
                  });
                },
                child: const Text(
                  'إعادة إرسال الرمز 🔄',
                  style: TextStyle(color: Color(0xFF005B41)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------- 6. باقي أقسام السوق ----------------
class RealEstateMarketScreen extends StatelessWidget {
  const RealEstateMarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> subCategories = [
      {'title': 'عقارات للإيجار 🏠', 'color': Colors.blue},
      {'title': 'عقارات للبيع والشراء 🔑', 'color': Colors.green},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('قسم العقارات 🏢'),
        backgroundColor: const Color(0xFF005B41),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subCategories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final cat = subCategories[index];
          return InkWell(
            onTap: () {
              SystemSound.play(SystemSoundType.click);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: CategoryDetailScreen(categoryTitle: cat['title']),
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (cat['color'] as Color).withOpacity(0.4),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_work, color: cat['color'], size: 40),
                  const SizedBox(height: 8),
                  Text(
                    cat['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ElectronicsMarketScreen extends StatelessWidget {
  const ElectronicsMarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> subCategories = [
      {'title': 'هواتف وموبايلات 📱', 'color': Colors.indigo},
      {'title': 'لابتوبات وكمبيوتر 💻', 'color': Colors.teal},
      {'title': 'إلكترونيات منوعة 🔌', 'color': Colors.deepOrange},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('قسم الإلكترونيات ⚡'),
        backgroundColor: const Color(0xFF005B41),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subCategories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final cat = subCategories[index];
          return InkWell(
            onTap: () {
              SystemSound.play(SystemSoundType.click);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: CategoryDetailScreen(categoryTitle: cat['title']),
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (cat['color'] as Color).withOpacity(0.4),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices, color: cat['color'], size: 40),
                  const SizedBox(height: 8),
                  Text(
                    cat['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class BirdsMarketScreen extends StatelessWidget {
  const BirdsMarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> subCategories = [
      {'title': 'طيور الكنار 🐥', 'color': Colors.amber},
      {'title': 'طيور الحسون 🎵', 'color': Colors.orange},
      {'title': 'طيور الحمام 🕊️', 'color': Colors.blueGrey},
      {'title': 'الحيوانات الأليفة 🐶', 'color': Colors.deepPurple},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('سوق الطيور والحيوانات 🦜'),
        backgroundColor: const Color(0xFF005B41),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subCategories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final cat = subCategories[index];
          return InkWell(
            onTap: () {
              SystemSound.play(SystemSoundType.click);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: CategoryDetailScreen(categoryTitle: cat['title']),
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (cat['color'] as Color).withOpacity(0.4),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, color: cat['color'], size: 40),
                  const SizedBox(height: 8),
                  Text(
                    cat['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  final String categoryTitle;
  const CategoryDetailScreen({super.key, required this.categoryTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('قسم: $categoryTitle'),
        backgroundColor: const Color(0xFF005B41),
      ),
      body: Center(
        child: Text(
          'أهلاً بك في قسم ($categoryTitle)\nيمكنك نشر واستعراض كافة إعلانات القسم بنجاح ✅!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF005B41),
          ),
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 7. اختيار قسم المنشور ----------------
class SelectCategoryScreen extends StatelessWidget {
  final List<String> provincesList;

  const SelectCategoryScreen({super.key, required this.provincesList});

  final List<Map<String, dynamic>> categoryList = const [
    {'title': 'سيارات', 'icon': Icons.directions_car, 'color': Colors.orange},
    {
      'title': 'عقارات - للإيجار',
      'icon': Icons.home_work,
      'color': Colors.blue,
    },
    {
      'title': 'عقارات - للبيع والشراء',
      'icon': Icons.vpn_key,
      'color': Colors.green,
    },
    {
      'title': 'إلكترونيات - هواتف وموبايلات',
      'icon': Icons.smartphone,
      'color': Colors.indigo,
    },
    {
      'title': 'إلكترونيات - لابتوبات وكمبيوتر',
      'icon': Icons.laptop,
      'color': Colors.teal,
    },
    {
      'title': 'إلكترونيات - منوعة',
      'icon': Icons.devices_other,
      'color': Colors.deepOrange,
    },
    {'title': 'أدوات منزلية', 'icon': Icons.chair, 'color': Colors.purple},
    {'title': 'طيور الكنار', 'icon': Icons.flutter_dash, 'color': Colors.amber},
    {'title': 'طيور الحسون', 'icon': Icons.music_note, 'color': Colors.orange},
    {
      'title': 'طيور الحمام',
      'icon': Icons.bedroom_baby,
      'color': Colors.blueGrey,
    },
    {
      'title': 'الحيوانات الأليفة',
      'icon': Icons.pets,
      'color': Colors.deepPurple,
    },
    {'title': 'إعلانات تجارية', 'icon': Icons.campaign, 'color': Colors.red},
    {'title': 'سوق المستعمل', 'icon': Icons.autorenew, 'color': Colors.teal},
    {'title': 'وظائف وعمال', 'icon': Icons.work, 'color': Colors.blueGrey},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الخطوة 1: اختر قسم الإعلان'),
        backgroundColor: const Color(0xFF005B41),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'حدد القسم المناسب لبضاعتك للانتقال لاستمارة النشر المخصصة:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF005B41),
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categoryList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemBuilder: (context, index) {
              final cat = categoryList[index];
              return InkWell(
                onTap: () {
                  SystemSound.play(SystemSoundType.click);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: CreateAdScreen(
                          provincesList: provincesList,
                          selectedCategory: cat['title'],
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (cat['color'] as Color).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat['icon'], color: cat['color'], size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------- 8. استمارة إضافة إعلان مع رفع الصور والفيديو الفعلي لـ Firebase ----------------
class CreateAdScreen extends StatefulWidget {
  final List<String> provincesList;
  final String selectedCategory;

  const CreateAdScreen({
    super.key,
    required this.provincesList,
    required this.selectedCategory,
  });

  @override
  State<CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends State<CreateAdScreen> {
  final _formKey = GlobalKey<FormState>();

  late String selectedProvince;
  String city = '';
  String contactMethod = 'اتصال هاتف 📞';
  String phone = '';
  String title = '';
  String description = '';
  bool isSponsored = false;

  final List<String> _pickedImagePaths = [];
  String? selectedVideoSource;
  bool isUploading = false; // مؤشر التحميل أثناء الرفع للسحابة

  CurrencyType currencyType = CurrencyType.syrian;
  String priceSyrian = '';
  String priceUSD = '';

  @override
  void initState() {
    super.initState();
    selectedProvince = widget.provincesList.first;
  }

  Future<void> _handleMediaAction(String mediaType, ImageSource source) async {
    SystemSound.play(SystemSoundType.click);
    final picker = ImagePicker();

    if (mediaType == 'photo') {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _pickedImagePaths.add(pickedFile.path);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرفاق الصورة بنجاح 📸')),
        );
      }
    } else if (mediaType == 'video') {
      final pickedFile = await picker.pickVideo(source: source);
      if (pickedFile != null) {
        setState(() {
          selectedVideoSource = pickedFile.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرفاق الفيديو بنجاح 🎥')),
        );
      }
    }
  }

  // دالة لرفع الصور والفيديوهات إلى Firebase Storage وجلب روابطها الحقيقية
  Future<void> _submitAdToFirebase() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    SystemSound.play(SystemSoundType.click);

    setState(() => isUploading = true);

    try {
      List<String> uploadedImageUrls = [];
      List<String> uploadedVideoUrls = [];
      String adId = DateTime.now().millisecondsSinceEpoch.toString();

      // 1. رفع الصور الحقيقية إلى Firebase Storage
      for (int i = 0; i < _pickedImagePaths.length; i++) {
        File file = File(_pickedImagePaths[i]);
        String filePath = 'ads_images/${adId}_$i.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(filePath);
        UploadTask uploadTask = ref.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedImageUrls.add(downloadUrl);
      }

      // إذا لم يتم اختيار صور، نضع صورة افتراضية
      if (uploadedImageUrls.isEmpty) {
        uploadedImageUrls.add('https://picsum.photos/600/400?random=$adId');
      }

      // 2. رفع الفيديو الحقيقي إلى Firebase Storage (إن وجد)
      if (selectedVideoSource != null) {
        File videoFile = File(selectedVideoSource!);
        String videoPath = 'ads_videos/${adId}.mp4';
        Reference videoRef = FirebaseStorage.instance.ref().child(videoPath);
        UploadTask videoUploadTask = videoRef.putFile(videoFile);
        TaskSnapshot videoSnapshot = await videoUploadTask;
        String videoDownloadUrl = await videoSnapshot.ref.getDownloadURL();
        uploadedVideoUrls.add(videoDownloadUrl);
      }

      // 3. إنشاء كائن الإعلان
      final newAd = AdModel(
        id: adId,
        title: title,
        description: description,
        category: widget.selectedCategory,
        province: selectedProvince,
        city: city,
        phone: phone,
        contactMethod: contactMethod,
        priceSyrian: widget.selectedCategory.contains('وظائف')
            ? ''
            : priceSyrian,
        priceUSD: widget.selectedCategory.contains('وظائف') ? '' : priceUSD,
        currencyType: currencyType,
        status: 'pending',
        imageUrls: uploadedImageUrls,
        videoUrls: uploadedVideoUrls,
        isSold: false,
        isSponsored: isSponsored,
        ownerId: currentUserId,
      );

      // 4. حفظ الإعلان في قاعدة بيانات Cloud Firestore
      await FirebaseFirestore.instance
          .collection('ads')
          .doc(adId)
          .set(newAd.toMap());

      setState(() => isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تنبيه الإدارة: تم إرسال إعلانك بنجاح إلى السحابة قيد المراجعة والانتظار 🚀',
          ),
          backgroundColor: Color(0xFF005B41),
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء رفع الإعلان: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isJobCategory = widget.selectedCategory.contains('وظائف');

    return Scaffold(
      appBar: AppBar(
        title: Text('الخطوة 2: استمارة (${widget.selectedCategory})'),
        backgroundColor: const Color(0xFF005B41),
      ),
      body: isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF005B41)),
                  SizedBox(height: 16),
                  Text(
                    'جاري رفع الصور والفيديو وحفظ الإعلان بالسحابة... ⏳',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005B41).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF005B41)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.category, color: Color(0xFF005B41)),
                        const SizedBox(width: 8),
                        Text(
                          'القسم المختار: ${widget.selectedCategory}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF005B41),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedProvince,
                    decoration: const InputDecoration(
                      labelText: 'اختر المحافظة (إجباري) *',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.provincesList
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) => setState(() => selectedProvince = val!),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'المدينة / المنطقة التفصيلية *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'يرجى كتابة اسم المدينة أو المنطقة'
                        : null,
                    onSaved: (val) => city = val!.trim(),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: contactMethod,
                    decoration: const InputDecoration(
                      labelText: 'وسيلة التواصل المفضلة *',
                      border: OutlineInputBorder(),
                    ),
                    items: ['اتصال هاتف 📞', 'واتساب 💬', 'تليجرام ✈️']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) => setState(() => contactMethod = val!),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف للتواصل *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'يرجى إدخال رقم الهاتف'
                        : null,
                    onSaved: (val) => phone = val!.trim(),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    decoration: InputDecoration(
                      labelText: isJobCategory
                          ? 'المسمى الوظيفي / الشاغر المطلوب *'
                          : widget.selectedCategory.contains('عقارات')
                          ? 'عنوان العرض (مثال: شقة 3 غرف للمبيعات) *'
                          : 'اسم البضاعة / عنوان الإعلان *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'يرجى كتابة هذا الحقل'
                        : null,
                    onSaved: (val) => title = val!.trim(),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'مواصفات وتفاصيل البضاعة الكاملة *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'يرجى إدخال التفاصيل'
                        : null,
                    onSaved: (val) => description = val!.trim(),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text(
                      'طلب إعلان ممول وثابت في أعلى الصفحة الرئيسية 🌟',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'يظهر دائماً في أعلى الشاشة بشكل بارز ولا يختفي مع الإعلانات العادية',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: isSponsored,
                    activeColor: const Color(0xFFFF9800),
                    onChanged: (val) => setState(() => isSponsored = val),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إرفاق الصور والفيديو من الهاتف 📸🎥',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF005B41),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _handleMediaAction(
                                  'photo',
                                  ImageSource.camera,
                                ),
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text(
                                  'كاميرا الهاتف',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _handleMediaAction(
                                  'photo',
                                  ImageSource.gallery,
                                ),
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text(
                                  'استديو الصور',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _handleMediaAction(
                                  'video',
                                  ImageSource.camera,
                                ),
                                icon: const Icon(Icons.videocam, size: 18),
                                label: const Text(
                                  'تصوير فيديو',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _handleMediaAction(
                                  'video',
                                  ImageSource.gallery,
                                ),
                                icon: const Icon(
                                  Icons.video_collection,
                                  size: 18,
                                ),
                                label: const Text(
                                  'فيديو من المعرض',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_pickedImagePaths.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'تم اختيار (${_pickedImagePaths.length}) صورة بنجاح ✅',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!isJobCategory) ...[
                    const Text(
                      'اختر عملة التسعير:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<CurrencyType>(
                            title: const Text(
                              'سوري',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: CurrencyType.syrian,
                            groupValue: currencyType,
                            onChanged: (val) =>
                                setState(() => currencyType = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<CurrencyType>(
                            title: const Text(
                              'دولار',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: CurrencyType.usd,
                            groupValue: currencyType,
                            onChanged: (val) =>
                                setState(() => currencyType = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<CurrencyType>(
                            title: const Text(
                              'معاً',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: CurrencyType.both,
                            groupValue: currencyType,
                            onChanged: (val) =>
                                setState(() => currencyType = val!),
                          ),
                        ),
                      ],
                    ),
                    if (currencyType == CurrencyType.syrian ||
                        currencyType == CurrencyType.both)
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'السعر بالليرة السورية',
                          border: OutlineInputBorder(),
                        ),
                        onSaved: (val) => priceSyrian = val ?? '',
                      ),
                    const SizedBox(height: 8),
                    if (currencyType == CurrencyType.usd ||
                        currencyType == CurrencyType.both)
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'السعر بالدولار (دولار)',
                          border: OutlineInputBorder(),
                        ),
                        onSaved: (val) => priceUSD = val ?? '',
                      ),
                  ],

                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _submitAdToFirebase,
                    child: const Text(
                      'إرسال الإعلان للطلب والموافقة 🚀',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------------- 9. لوحة تحكم المشرفين والإدارة (تحديث حقيقي عبر Firebase) ----------------
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int activeTab = 0;

  void _showRejectDialog(AdModel ad) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال سبب الرفض'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الرفض للتنبيه...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('ads')
                    .doc(ad.id)
                    .update({
                      'status': 'rejected',
                      'rejectionReason': reasonController.text.trim(),
                    });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم رفض المنشور وإشعار المستخدم بنجاح! ❌'),
                  ),
                );
              }
            },
            child: const Text(
              'تأكيد الرفض',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة والمشرفين 🛡️'),
        backgroundColor: const Color(0xFF005B41),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ads')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int pendingCount = snapshot.hasData
                        ? snapshot.data!.docs.length
                        : 0;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeTab == 0
                            ? const Color(0xFFFF9800)
                            : Colors.grey,
                      ),
                      onPressed: () => setState(() => activeTab = 0),
                      child: Text('طلبات النشر المعلقة ($pendingCount)'),
                    );
                  },
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeTab == 1
                        ? const Color(0xFFFF9800)
                        : Colors.grey,
                  ),
                  onPressed: () => setState(() => activeTab = 1),
                  child: const Text('إدارة المشرفين والصلاحيات'),
                ),
              ),
            ],
          ),
          Expanded(
            child: activeTab == 0
                ? StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('ads')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF005B41),
                          ),
                        );
                      }

                      final pendingAds = snapshot.data!.docs.map((doc) {
                        return AdModel.fromMap(
                          doc.data() as Map<String, dynamic>,
                          doc.id,
                        );
                      }).toList();

                      if (pendingAds.isEmpty) {
                        return const Center(
                          child: Text(
                            'لا توجد إعلانات تنتظر الموافقة حالياً 🎉',
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: pendingAds.length,
                        itemBuilder: (context, index) {
                          final ad = pendingAds[index];
                          return Card(
                            margin: const EdgeInsets.all(10),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (ad.isSponsored)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          left: 6,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'ممول 🌟',
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: Text(
                                                    ad.title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'القسم: ${ad.category} | المحافظة: ${ad.province} (${ad.city})',
                                            ),
                                            Text(
                                              'التواصل: ${ad.contactMethod} - ${ad.phone}',
                                            ),
                                            Text('التفاصيل: ${ad.description}'),
                                          ],
                                        ),
                                      ),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: ad.imageUrls.isNotEmpty
                                            ? Image.network(
                                                ad.imageUrls.first,
                                                width: 75,
                                                height: 75,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      width: 75,
                                                      height: 75,
                                                      color: Colors.grey,
                                                    ),
                                              )
                                            : Container(
                                                width: 75,
                                                height: 75,
                                                color: Colors.grey,
                                              ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('ads')
                                              .doc(ad.id)
                                              .update({'status': 'approved'});
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'تمت الموافقة على المنشور ونشره للجميع بالسوق! ✅',
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'موافقة ونشر',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () => _showRejectDialog(ad),
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'رفض المنشور',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: globalSupervisors.length,
                    itemBuilder: (context, index) {
                      final sup = globalSupervisors[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ExpansionTile(
                          title: Text(
                            sup.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'تعديل صلاحيات قبول ورفض المنشورات',
                          ),
                          children: [
                            SwitchListTile(
                              title: const Text(
                                'صلاحية الموافقة على المنشورات',
                              ),
                              value: sup.canApprovePosts,
                              onChanged: (val) =>
                                  setState(() => sup.canApprovePosts = val),
                            ),
                            SwitchListTile(
                              title: const Text('صلاحية رفض المنشورات'),
                              value: sup.canRejectPosts,
                              onChanged: (val) =>
                                  setState(() => sup.canRejectPosts = val),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
