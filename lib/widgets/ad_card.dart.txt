import 'package:flutter/material.dart';
import '../models/ad_model.dart';

class AdCard extends StatelessWidget {
  final AdModel ad;
  final bool isSponsored;
  final VoidCallback onTap;
  final bool showStatus;

  const AdCard({
    super.key,
    required this.ad,
    this.isSponsored = false,
    required this.onTap,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isSponsored ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSponsored
            ? const BorderSide(color: Color(0xFFFF9800), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
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
                        if (isSponsored) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('ممول',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            ad.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ad.province} - ${ad.city}\nالقسم: ${ad.category}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    if (!ad.category.contains('وظائف'))
                      Text(
                        ad.priceDisplay,
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    const SizedBox(height: 6),
                    if (showStatus)
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
                      )
                    else
                      Text(
                        'اضغط لمشاهدة التفاصيل',
                        style: TextStyle(
                            color: isSponsored
                                ? const Color(0xFFFF9800)
                                : const Color(0xFF005B41),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
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
                    child: ad.imageUrls.isNotEmpty
                        ? Image.network(
                            ad.imageUrls.first,
                            width: 95,
                            height: 95,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 95,
                              height: 95,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image, color: Colors.grey, size: 40),
                            ),
                          )
                        : Container(
                            width: 95,
                            height: 95,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image, color: Colors.grey, size: 40),
                          ),
                  ),
                  if (ad.isSold)
                    Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Text(
                          'تم البيع',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
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
