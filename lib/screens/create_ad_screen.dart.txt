import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/ad_model.dart';
import '../constants/app_constants.dart';

class CreateAdScreen extends StatefulWidget {
  const CreateAdScreen({super.key});

  @override
  State<CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends State<CreateAdScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'سيارات';
  String _selectedProvince = 'دمشق';
  String _contactMethod = 'اتصال هاتف';
  CurrencyType _currencyType = CurrencyType.syrian;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _priceSyrianController = TextEditingController();
  final _priceUsdController = TextEditingController();

  final List<String> _pickedImagePaths = [];
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _priceSyrianController.dispose();
    _priceUsdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    SystemSound.play(SystemSoundType.click);
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _pickedImagePaths.add(pickedFile.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرفاق الصورة')),
        );
      }
    }
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    SystemSound.play(SystemSoundType.click);

    setState(() => _isUploading = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      List<String> uploadedImageUrls = [];
      final adId = DateTime.now().millisecondsSinceEpoch.toString();

      for (int i = 0; i < _pickedImagePaths.length; i++) {
        final file = File(_pickedImagePaths[i]);
        final fileName = '${adId}_$i.jpg';
        final filePath = 'ads/$fileName';

        await SupabaseService.client.storage
            .from('ad_images')
            .upload(filePath, file);

        final url = SupabaseService.client.storage
            .from('ad_images')
            .getPublicUrl(filePath);

        uploadedImageUrls.add(url);
      }

      final isJobCategory = _selectedCategory.contains('وظائف');

      final newAd = AdModel(
        id: adId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        province: _selectedProvince,
        city: _cityController.text.trim(),
        phone: _phoneController.text.trim(),
        contactMethod: _contactMethod,
        priceSyrian: isJobCategory ? null : double.tryParse(_priceSyrianController.text),
        priceUsd: isJobCategory ? null : double.tryParse(_priceUsdController.text),
        currencyType: _currencyType,
        status: 'pending',
        imageUrls: uploadedImageUrls,
        isSold: false,
        isSponsored: false,
        userId: userId,
        createdAt: DateTime.now(),
      );

      await SupabaseService.client.from('ads').insert(newAd.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال إعلانك بنجاح! سيظهر بعد موافقة الإدارة'),
            backgroundColor: Color(0xFF005B41),
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isJobCategory = _selectedCategory.contains('وظائف');

    return Scaffold(
      appBar: AppBar(
        title: const Text('نشر إعلان جديد'),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF005B41)),
                  SizedBox(height: 16),
                  Text('جاري رفع الصور وحفظ الإعلان...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'اختر القسم *',
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat['title'] as String,
                        child: Text(cat['title'] as String),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val!),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    decoration: const InputDecoration(
                      labelText: 'المحافظة *',
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.provinces
                        .where((p) => p != 'الكل')
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedProvince = val!),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'المدينة / المنطقة *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'يرجى كتابة المدينة' : null,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _contactMethod,
                    decoration: const InputDecoration(
                      labelText: 'وسيلة التواصل *',
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.contactMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) => setState(() => _contactMethod = val!),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: isJobCategory
                          ? 'المسمى الوظيفي *'
                          : 'عنوان الإعلان *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'يرجى كتابة العنوان' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'الوصف والتفاصيل *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'يرجى إدخال التفاصيل' : null,
                  ),
                  const SizedBox(height: 16),

                  if (!isJobCategory) ...[
                    const Text('عملة التسعير:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<CurrencyType>(
                            title: const Text('سوري', style: TextStyle(fontSize: 12)),
                            value: CurrencyType.syrian,
                            groupValue: _currencyType,
                            onChanged: (val) => setState(() => _currencyType = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<CurrencyType>(
                            title: const Text('دولار', style: TextStyle(fontSize: 12)),
                            value: CurrencyType.usd,
                            groupValue: _currencyType,
                            onChanged: (val) => setState(() => _currencyType = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<CurrencyType>(
                            title: const Text('معاً', style: TextStyle(fontSize: 12)),
                            value: CurrencyType.both,
                            groupValue: _currencyType,
                            onChanged: (val) => setState(() => _currencyType = val!),
                          ),
                        ),
                      ],
                    ),
                    if (_currencyType == CurrencyType.syrian || _currencyType == CurrencyType.both)
                      TextFormField(
                        controller: _priceSyrianController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'السعر بالليرة السورية',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (_currencyType == CurrencyType.usd || _currencyType == CurrencyType.both) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceUsdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'السعر بالدولار',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

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
                        const Text('إرفاق الصور',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF005B41))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('كاميرا', style: TextStyle(fontSize: 11)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text('معرض الصور', style: TextStyle(fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                        if (_pickedImagePaths.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('تم اختيار ${_pickedImagePaths.length} صورة',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pickedImagePaths.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: FileImage(File(_pickedImagePaths[index])),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _pickedImagePaths.removeAt(index)),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close,
                                              color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _submitAd,
                    child: const Text('إرسال الإعلان للمراجعة',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
