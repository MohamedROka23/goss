import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../widgets/widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;
    final isWide = MediaQuery.sizeOf(context).width >= 560;

    return SingleChildScrollView(
      child: Column(
        children: [
          PageHero(
            title: en ? 'About Us' : 'من نحن',
            subtitle: en
                ? 'Your trusted partner in global supply chains, logistics, and premium supply solutions.'
                : 'شريكك الموثوق في سلاسل الإمداد العالمية والخدمات اللوجستية وحلول التوريد المتميزة.',
            isArabic: !en,
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(title: en ? 'Our Story' : 'قصتنا', isArabic: !en),
                const SizedBox(height: 8),
                const _StoryTexts(),
                const SizedBox(height: 24),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _card(
                          context,
                          icon: Icons.flag,
                          title: en ? 'Our Mission' : 'مهمتنا',
                          body: en
                              ? 'To deliver seamless, secure, and highly efficient supply chain and trading solutions that empower our clients\' operations and drive sustainable growth.'
                              : 'تقديم حلول سلسة وآمنة وعالية الكفاءة لسلسلة الإمداد والتجارة، مما يعزز عمليات عملائنا ويدفع عجلة النمو المستدام.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _card(
                          context,
                          icon: Icons.visibility,
                          title: en ? 'Our Vision' : 'رؤيتنا',
                          body: en
                              ? 'To be the region\'s leading and most trusted global logistics and outsourcing partner, setting new standards in service excellence.'
                              : 'أن نكون الشريك الرائد والأكثر ثقة عالمياً في مجال اللوجستيات والتعهيد في الشرق الأوسط وما وراءه، مع إرساء معايير جديدة في التميز الخدمي.',
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _card(
                        context,
                        icon: Icons.flag,
                        title: en ? 'Our Mission' : 'مهمتنا',
                        body: en
                            ? 'To deliver seamless, secure, and highly efficient supply chain and trading solutions that empower our clients\' operations and drive sustainable growth.'
                            : 'تقديم حلول سلسة وآمنة وعالية الكفاءة لسلسلة الإمداد والتجارة، مما يعزز عمليات عملائنا ويدفع عجلة النمو المستدام.',
                      ),
                      const SizedBox(height: 12),
                      _card(
                        context,
                        icon: Icons.visibility,
                        title: en ? 'Our Vision' : 'رؤيتنا',
                        body: en
                            ? 'To be the region\'s leading and most trusted global logistics and outsourcing partner, setting new standards in service excellence.'
                            : 'أن نكون الشريك الرائد والأكثر ثقة عالمياً في مجال اللوجستيات والتعهيد في الشرق الأوسط وما وراءه، مع إرساء معايير جديدة في التميز الخدمي.',
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                SectionTitle(
                  title: en ? 'Official Registrations & Accreditations' : 'التسجيلات والاعتمادات الرسمية',
                  isArabic: !en,
                ),
                const SizedBox(height: 12),
                _accreditation(context, Icons.verified, en ? 'Certified Suppliers' : 'موردون معتمدون',
                    en
                        ? 'Officially registered and accredited to supply high-quality materials to corporate, industrial, and hospitality sectors.'
                        : 'مسجلون ومعتمدون رسمياً لتوريد مواد عالية الجودة لقطاعات الشركات والصناعة والضيافة.',
                    image: 'assets/images/hero_warehouse.jpg'),
                const SizedBox(height: 12),
                _accreditation(context, Icons.local_shipping, en ? 'Certified Logistics Providers' : 'مزودو خدمات لوجستية معتمدون',
                    en
                        ? 'Fully accredited logistics operators ensuring safe, flexible, and standards-compliant global shipping.'
                        : 'مشغلون لوجستيون معتمدون بالكامل لضمان شحن عالمي آمن ومرن ومطابق للمعايير.',
                    image: 'assets/images/fleet.jpg'),
                const SizedBox(height: 12),
                _accreditation(context, Icons.gavel, en ? 'Licensed Customs Brokers' : 'مخلصون جمركيون معتمدون',
                    en
                        ? 'Officially licensed brokers specializing in fast port clearance, regulatory compliance, and smooth handling of standard import/export documentation.'
                        : 'مخلصون مرخصون رسمياً متخصصون في التخليص السريع من الموانئ، والامتثال التنظيمي، ومعالجة وثائق الاستيراد والتصدير القياسية بسلاسة.',
                    image: 'assets/images/port.jpg'),
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Image.asset('assets/logo.png', width: 48, height: 48),
                      const SizedBox(height: 8),
                      const VersionBadge(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required IconData icon, required String title, required String body}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: GossColors.red, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.headingColor),
            ),
            const SizedBox(height: 6),
            Text(body, style: TextStyle(color: context.mutedColor, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _accreditation(BuildContext context, IconData icon, String title, String body, {String? image}) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Image.asset(image, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: GossColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: GossColors.red, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.headingColor)),
                      const SizedBox(height: 4),
                      Text(body, style: TextStyle(color: context.mutedColor, height: 1.5)),
                    ],
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

class _StoryTexts extends StatelessWidget {
  const _StoryTexts();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final ar = app.isArabic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ar
              ? 'تعتبر الشركة العالمية لخدمات التعهيد والتجارة (Gosst) شركة رائدة مقرها الرئيسي في الإسكندرية، مصر. نحن نقف في طليعة سلسلة الإمداد العالمية، ونقدم تميزاً لا مثيل له عبر الخدمات اللوجستية متعددة الوسائط، الشحن، وتوريدات الشركات عالية المستوى.'
              : 'Global Outsourcing Services & Trading (Gosst) is a leading company headquartered in Alexandria, Egypt. We stand at the forefront of the global supply chain, delivering unparalleled excellence across multimodal logistics, shipping, and premium corporate supplies.',
          style: TextStyle(color: context.mutedColor, fontSize: 15, height: 1.7),
        ),
        const SizedBox(height: 12),
        Text(
          ar
              ? 'بدافع من الابتكار والالتزام بالموثوقية المطلقة، نحن نستفيد من أساطيلنا الضخمة وشبكات التخزين الاستراتيجية لضمان سير عملياتك بسلاسة تامة. تسد خبرتنا الفجوة بين التحديات اللوجستية المعقدة والحلول المتكاملة للشركات في جميع أنحاء العالم.'
              : 'Driven by innovation and a commitment to absolute reliability, we leverage our vast fleets and strategic warehousing networks to ensure your operations run with complete smoothness. Our expertise bridges the gap between complex logistics challenges and integrated corporate solutions worldwide.',
          style: TextStyle(color: context.mutedColor, fontSize: 15, height: 1.7),
        ),
      ],
    );
  }
}