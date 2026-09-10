import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../widgets/widgets.dart';
import 'catalog_screen.dart';

class SuppliesScreen extends StatelessWidget {
  const SuppliesScreen({super.key});

  static const _groups = [
    {
      'e': 'Hotels',
      'a': 'فنادق',
      'cats': ['vegetables', 'fruits', 'general', 'office', 'hotel', 'appliances'],
    },
    {
      'e': 'Restaurants',
      'a': 'مطاعم',
      'cats': ['vegetables', 'fruits', 'general', 'restaurant', 'appliances'],
    },
    {
      'e': 'General Companies',
      'a': 'شركات عام',
      'cats': ['vegetables', 'fruits', 'general', 'office', 'hotel', 'appliances'],
    },
  ];

  static const _icons = [Icons.hotel, Icons.restaurant_menu, Icons.business_center];

  static const _chipNames = {
    'vegetables': ['Vegetables', 'خضار'],
    'fruits': ['Fruits', 'فاكهة'],
    'general': ['General', 'عام'],
    'office': ['Office Supplies', 'أدوات مكتبية'],
    'hotel': ['Hotel Supplies', 'أدوات فندقية'],
    'restaurant': ['Restaurant Supplies', 'لوازم المطاعم'],
    'appliances': ['Appliances', 'أجهزة'],
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return SingleChildScrollView(
      child: Column(
        children: [
          PageHero(
            title: en ? 'Supplies & Trade' : 'التوريدات والتجارة',
            subtitle: en
                ? 'Complete supplies for hotels, restaurants, and companies.'
                : 'توريدات متكاملة للفنادق والمطاعم والشركات',
            isArabic: !en,
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  en
                      ? 'Choose your sector below, then the category you need.'
                      : 'اختر القطاع بالأسفل، ثم التصنيف الذي تحتاجه.',
                  style: TextStyle(color: context.mutedColor, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _groups.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: GossColors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_icons[i], color: GossColors.blue, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    en ? (_groups[i]['e']! as String) : (_groups[i]['a']! as String),
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.headingColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (_groups[i]['cats']! as List<String>).map((id) {
                                final pair = _chipNames[id]!;
                                return ActionChip(
                                  label: Text(en ? pair[0] : pair[1]),
                                  backgroundColor: GossColors.blue.withValues(alpha: 0.1),
                                  side: BorderSide(color: GossColors.blue.withValues(alpha: 0.3)),
                                  labelStyle: TextStyle(fontWeight: FontWeight.w600, color: context.headingColor),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CatalogScreen(initialCategory: id, showBack: true),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}