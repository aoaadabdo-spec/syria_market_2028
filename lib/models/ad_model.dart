import 'package:flutter/material.dart';

enum CurrencyType { syrian, usd, both }

extension CurrencyTypeExtension on CurrencyType {
  String get label {
    switch (this) {
      case CurrencyType.syrian:
        return 'syrian';
      case CurrencyType.usd:
        return 'usd';
      case CurrencyType.both:
        return 'both';
    }
  }

  static CurrencyType fromString(String? value) {
    switch (value) {
      case 'usd':
        return CurrencyType.usd;
      case 'both':
        return CurrencyType.both;
      default:
        return CurrencyType.syrian;
    }
  }
}

class AdModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String province;
  final String city;
  final String phone;
  final String contactMethod;
  final double? priceSyrian;
  final double? priceUsd;
  final CurrencyType currencyType;
  final String status;
  final String? rejectionReason;
  final List<String> imageUrls;
  final bool isSold;
  final bool isSponsored;
  final String userId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AdModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.province,
    required this.city,
    required this.phone,
    required this.contactMethod,
    this.priceSyrian,
    this.priceUsd,
    required this.currencyType,
    this.status = 'pending',
    this.rejectionReason,
    this.imageUrls = const [],
    this.isSold = false,
    this.isSponsored = false,
    required this.userId,
    required this.createdAt,
    this.updatedAt,
  });

  factory AdModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AdModel(
      id: map['id'] ?? documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      province: map['province'] ?? '',
      city: map['city'] ?? '',
      phone: map['phone'] ?? '',
      contactMethod: map['contact_method'] ?? '',
      priceSyrian: map['price_syrian'] != null
          ? double.tryParse(map['price_syrian'].toString())
          : null,
      priceUsd: map['price_usd'] != null
          ? double.tryParse(map['price_usd'].toString())
          : null,
      currencyType: CurrencyTypeExtension.fromString(map['currency_type']),
      status: map['status'] ?? 'pending',
      rejectionReason: map['rejection_reason'],
      imageUrls: List<String>.from(map['image_urls'] ?? []),
      isSold: map['is_sold'] ?? false,
      isSponsored: map['is_sponsored'] ?? false,
      userId: map['user_id'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'province': province,
      'city': city,
      'phone': phone,
      'contact_method': contactMethod,
      'price_syrian': priceSyrian,
      'price_usd': priceUsd,
      'currency_type': currencyType.label,
      'status': status,
      'rejection_reason': rejectionReason,
      'image_urls': imageUrls,
      'is_sold': isSold,
      'is_sponsored': isSponsored,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get priceDisplay {
    if (category.contains('وظائف')) return 'غير محدد';
    switch (currencyType) {
      case CurrencyType.syrian:
        return priceSyrian != null ? '${priceSyrian!.toStringAsFixed(0)} ل.س' : '';
      case CurrencyType.usd:
        return priceUsd != null ? '${priceUsd!.toStringAsFixed(0)} \$' : '';
      case CurrencyType.both:
        final syr = priceSyrian != null ? '${priceSyrian!.toStringAsFixed(0)} ل.س' : '';
        final usd = priceUsd != null ? '${priceUsd!.toStringAsFixed(0)} \$' : '';
        return '$syr / $usd';
    }
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
