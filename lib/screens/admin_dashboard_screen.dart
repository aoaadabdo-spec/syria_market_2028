import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/supabase_service.dart';
import '../models/ad_model.dart';
import 'ad_detail_screen.dart';
import '../widgets/ad_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _activeTab = 0;

  void _showRejectDialog(AdModel ad) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الإعلان'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'اكتب سبب الرفض...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isNotEmpty) {
                try {
                  await SupabaseService.client
                      .from('ads')
                      .update({
                        'status': 'rejected',
                        'rejection_reason': reasonController.text.trim(),
                      })
                      .eq('id', ad.id);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم رفض الإعلان')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى كتابة سبب الرفض')),
                );
              }
            },
            child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _approveAd(AdModel ad) async {
    SystemSound.play(SystemSoundType.click);
    try {
      await SupabaseService.client
          .from('ads')
          .update({'status': 'approved'})
          .eq('id', ad.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الموافقة على الإعلان ونشره')),
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

  Future<void> _deleteAd(AdModel ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: const Text('هل أنت متأكد؟'),
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
      await SupabaseService.client.from('ads').delete().eq('id', ad.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الإعلان')),
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

  void _openAdDetail(AdModel ad) {
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
        title: const Text('لوحة الإدارة'),
      ),
      body: Column(
        children: [
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
                  child: const Text('الطلبات المعلقة'),
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
                  child: const Text('كل الإعلانات'),
                ),
              ),
            ],
          ),
          Expanded(
            child: _activeTab == 0
                ? _buildPendingAds()
                : _buildAllAds(),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAds() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('ads')
          .stream(primaryKey: ['id'])
          .eq('status', 'pending')
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF005B41)));
        }

        final pendingAds = snapshot.data!
            .map((doc) => AdModel.fromMap(doc, doc['id'] ?? ''))
            .toList();

        if (pendingAds.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 60, color: Color(0xFF005B41)),
                SizedBox(height: 12),
                Text('لا توجد إعلانات تنتظر الموافقة',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ad.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('القسم: ${ad.category} | ${ad.province} (${ad.city})'),
                              Text('التواصل: ${ad.contactMethod} - ${ad.phone}'),
                              const SizedBox(height: 4),
                              Text(ad.description,
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ad.imageUrls.isNotEmpty
                              ? Image.network(ad.imageUrls.first,
                                  width: 75, height: 75, fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(width: 75, height: 75, color: Colors.grey))
                              : Container(
                                  width: 75, height: 75, color: Colors.grey.shade300,
                                  child: const Icon(Icons.image, color: Colors.grey)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () => _approveAd(ad),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('موافقة', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => _showRejectDialog(ad),
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text('رفض', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                          onPressed: () => _openAdDetail(ad),
                          icon: const Icon(Icons.visibility, color: Colors.white),
                          label: const Text('عرض', style: TextStyle(color: Colors.white)),
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
    );
  }

  Widget _buildAllAds() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('ads')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF005B41)));
        }

        final allAds = snapshot.data!
            .map((doc) => AdModel.fromMap(doc, doc['id'] ?? ''))
            .toList();

        if (allAds.isEmpty) {
          return const Center(child: Text('لا توجد إعلانات'));
        }

        return ListView.builder(
          itemCount: allAds.length,
          itemBuilder: (context, index) {
            final ad = allAds[index];
            return AdCard(
              ad: ad,
              isSponsored: ad.isSponsored,
              onTap: () => _openAdDetail(ad),
              showStatus: true,
            );
          },
        );
      },
    );
  }
}