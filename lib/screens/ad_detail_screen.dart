import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ad_model.dart';
import '../services/supabase_service.dart';

class AdDetailScreen extends StatefulWidget {
  final AdModel ad;

  const AdDetailScreen({super.key, required this.ad});

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  int _selectedImageIndex = 0;
  late AdModel _ad;
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  bool _isOwner = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _ad = widget.ad;
    _checkOwnerAndAdmin();
    _checkFavorite();
  }

  void _checkOwnerAndAdmin() async {
    final userId = SupabaseService.currentUserId;
    final admin = await SupabaseService.isAdmin();
    if (mounted) {
      setState(() {
        _isOwner = _ad.userId == userId;
        _isAdmin = admin;
      });
    }
  }

  void _checkFavorite() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _isLoadingFavorite = false);
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('ad_id', _ad.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFavorite = response != null;
          _isLoadingFavorite = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    SystemSound.play(SystemSoundType.click);

    try {
      if (_isFavorite) {
        await SupabaseService.client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('ad_id', _ad.id);
        if (mounted) setState(() => _isFavorite = false);
      } else {
        await SupabaseService.client.from('favorites').insert({
          'user_id': userId,
          'ad_id': _ad.id,
        });
        if (mounted) setState(() => _isFavorite = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateAd(Map<String, dynamic> updateData, String successMessage) async {
    try {
      await SupabaseService.client
          .from('ads')
          .update(updateData)
          .eq('id', _ad.id);

      setState(() {
        if (updateData.containsKey('is_sold')) _ad = AdModel(
          id: _ad.id,
          title: _ad.title,
          description: _ad.description,
          category: _ad.category,
          province: _ad.province,
          city: _ad.city,
          phone: _ad.phone,
          contactMethod: _ad.contactMethod,
          priceSyrian: _ad.priceSyrian,
          priceUsd: _ad.priceUsd,
          currencyType: _ad.currencyType,
          status: _ad.status,
          rejectionReason: _ad.rejectionReason,
          imageUrls: _ad.imageUrls,
          isSold: updateData['is_sold'] ?? _ad.isSold,
          isSponsored: updateData.containsKey('is_sponsored')
              ? updateData['is_sponsored']
              : _ad.isSponsored,
          userId: _ad.userId,
          createdAt: _ad.createdAt,
        );
        if (updateData.containsKey('is_sponsored')) {
          _ad = AdModel(
            id: _ad.id,
            title: _ad.title,
            description: _ad.description,
            category: _ad.category,
            province: _ad.province,
            city: _ad.city,
            phone: _ad.phone,
            contactMethod: _ad.contactMethod,
            priceSyrian: _ad.priceSyrian,
            priceUsd: _ad.priceUsd,
            currencyType: _ad.currencyType,
            status: _ad.status,
            rejectionReason: _ad.rejectionReason,
            imageUrls: _ad.imageUrls,
            isSold: _ad.isSold,
            isSponsored: updateData['is_sponsored'],
            userId: _ad.userId,
            createdAt: _ad.createdAt,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAd() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: const Text('هل أنت متأكد من حذف هذا الإعلان؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.client.from('ads').delete().eq('id', _ad.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الإعلان بنجاح')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _makePhoneCall() async {
    SystemSound.play(SystemSoundType.click);
    final phone = _ad.phone;
    final contactMethod = _ad.contactMethod;

    if (contactMethod.contains('واتساب')) {
      final whatsappPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      final url = 'https://wa.me/$whatsappPhone';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: Colors.red),
          );
        }
      }
    } else if (contactMethod.contains('تليجرام')) {
      final url = 'https://t.me/${phone.replaceAll(RegExp(r'[^\d]'), '')}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح تليجرام'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      final url = 'tel:$phone';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر إجراء الاتصال'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _shareAd() async {
    SystemSound.play(SystemSoundType.click);
    final text = 'سوق سوريا الشامل\n\n'
        '${_ad.title}\n'
        '${_ad.province} - ${_ad.city}\n'
        '${_ad.priceDisplay}\n\n'
        'التواصل: ${_ad.phone} (${_ad.contactMethod})';

    await Share.share(text, subject: _ad.title);
  }

  @override
  Widget build(BuildContext context) {
    final bool canManageAd = _isOwner || _isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(_ad.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_isLoadingFavorite)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : Colors.white,
              ),
              tooltip: 'إضافة للمفضلة',
              onPressed: _toggleFavorite,
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة',
            onPressed: _shareAd,
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
                  child: _ad.imageUrls.isNotEmpty
                      ? Image.network(
                          _ad.imageUrls[_selectedImageIndex],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image_not_supported,
                                size: 60, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image, size: 60, color: Colors.grey),
                        ),
                ),
                if (_ad.isSold)
                  Transform.rotate(
                    angle: -0.2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))
                        ],
                      ),
                      child: const Text(
                        'تم البيع',
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
            if (_ad.imageUrls.length > 1)
              Container(
                height: 70,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.black12,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _ad.imageUrls.length,
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
                          child: Image.network(_ad.imageUrls[index],
                              width: 60, height: 60, fit: BoxFit.cover),
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
                          _ad.title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (canManageAd)
                        Row(
                          children: [
                            if (_isAdmin) ...[
                              IconButton(
                                tooltip: _ad.isSponsored ? 'إلغاء التمويل' : 'تمويل',
                                icon: Icon(
                                  Icons.star,
                                  color: _ad.isSponsored ? Colors.amber : Colors.grey,
                                ),
                                onPressed: () {
                                  SystemSound.play(SystemSoundType.click);
                                  _updateAd(
                                    {'is_sponsored': !_ad.isSponsored},
                                    _ad.isSponsored
                                        ? 'تم إلغاء تمويل الإعلان'
                                        : 'تم جعل الإعلان ممولاً ومثبتاً',
                                  );
                                },
                              ),
                            ],
                            IconButton(
                              tooltip: _ad.isSold ? 'إلغاء ختم البيع' : 'ختم تم البيع',
                              icon: Icon(
                                Icons.sell,
                                color: _ad.isSold ? Colors.green : Colors.red,
                              ),
                              onPressed: () {
                                SystemSound.play(SystemSoundType.click);
                                _updateAd(
                                  {'is_sold': !_ad.isSold},
                                  _ad.isSold
                                      ? 'تمت إعادة فتح الإعلان'
                                      : 'تم وضع ختم "تم البيع"',
                                );
                              },
                            ),
                            if (_isOwner)
                              IconButton(
                                tooltip: 'حذف الإعلان',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: _deleteAd,
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!_ad.category.contains('وظائف'))
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
                            'السعر: ${_ad.priceDisplay}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('تفاصيل المنشور:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF005B41))),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.category, color: Color(0xFF005B41)),
                    title: const Text('القسم'),
                    subtitle: Text(_ad.category),
                  ),
                  ListTile(
                    leading: const Icon(Icons.location_on, color: Color(0xFF005B41)),
                    title: const Text('الموقع'),
                    subtitle: Text('${_ad.province} - ${_ad.city}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description, color: Color(0xFF005B41)),
                    title: const Text('الوصف'),
                    subtitle: Text(_ad.description,
                        style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                  const SizedBox(height: 20),
                  const Text('التواصل مع الناشر:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF005B41))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الطريقة: ${_ad.contactMethod}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('الرقم: ${_ad.phone}',
                                style: const TextStyle(fontSize: 15, color: Colors.grey)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _makePhoneCall,
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text('تواصل', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
