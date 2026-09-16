import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../widgets/widgets.dart';
import 'service_detail_screen.dart';
import 'catalog_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _heroSection(context),
          _servicesSection(context),
          _aboutSection(context),
          _processSection(context),
          _valuesSection(context),
          _footer(context),
        ],
      ),
    );
  }

  Widget _heroSection(BuildContext context) {
    return _HeroCarousel(en: _en(context));
  }

  Widget _servicesSection(BuildContext context) {
    final en = _en(context);
    final services = [
      ['Fresh Vegetables', 'الخضروات الطازجة'],
      ['Fresh Fruits', 'الفاكهة الطازجة'],
      ['Hotels & Hospitality Supplies', 'مستلزمات الفنادق والضيافة'],
      ['Office Supplies', 'الأدوات المكتبية'],
      ['Packaging & Wrapping Materials', 'مواد التعبئة والتغليف'],
      ['Road Freight', 'الشحن البري'],
      ['Sea Freight', 'الشحن البحري'],
      ['Customs Clearance', 'التخليص الجمركي'],
      ['Smart Warehousing & Distribution Centres', 'التخزين الذكي ومراكز التوزيع'],
      ['Major Projects & Heavy Equipment', 'المشروعات الكبرى والمعدات الثقيلة'],
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      color: context.sectionColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: en ? 'Our Main Services' : '\u062e\u062f\u0645\u0627\u062a\u0646\u0627 \u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629', isArabic: !en),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              mainAxisExtent: 96,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: services.length,
            itemBuilder: (ctx, i) {
              const supplyIds = ['vegetables', 'fruits', 'hotel', 'office', 'packaging'];
              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    if (i < 5) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CatalogScreen(
                            initialCategory: supplyIds[i],
                            showBack: true,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ServiceDetailScreen(index: i - 5)),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      en ? services[i][0] : services[i][1],
                      style: TextStyle(fontWeight: FontWeight.w700, color: ctx.headingColor, fontSize: 14),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _aboutSection(BuildContext context) {
    final en = _en(context);
    return Container(
      padding: const EdgeInsets.all(24),
      color: context.altSectionColor,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: en ? 'About Gosst Co.' : '\u0639\u0646 \u0634\u0631\u0643\u0629 \u062c\u0648\u0633\u062a', isArabic: !en),
          const SizedBox(height: 8),
          Text(
            en
                ? 'Gosst is a leading supply management and logistics company, delivering flexible, cost-effective solutions designed for corporate sectors and broad commercial trade. We operate under strict official registrations across three main sectors: general supplies, multimodal logistics, and customs clearance, ensuring absolute compliance and reliability for our clients.'
                : 'جوست هي شركة رائدة في إدارة التوريدات والخدمات اللوجستية، تقدم حلولاً مرنة وفعالة من حيث التكلفة مصممة لقطاعات الشركات والتجارة الواسعة. نحن نعمل بموجب تسجيلات رسمية صارمة عبر ثلاثة قطاعات رئيسية: التوريدات العامة، والخدمات اللوجستية متعددة الوسائط، والتخليص الجمركي، مما يضمن الامتثال المطلق والموثوقية لعملائنا.',
            style: TextStyle(color: context.mutedColor, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 3
                      : constraints.maxWidth >= 380
                          ? 2
                          : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 124,
                children: [
                  _infoCard(context, en ? 'Officially Approved Suppliers' : 'موردون معتمدون رسمياً'),
                  _infoCard(context, en ? 'Certified Logistics Providers' : 'مزودو خدمات لوجستية معتمدون'),
                  _infoCard(context, en ? 'Licensed Customs Brokers' : 'مستخلصون جمركيون معتمدون'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _processSection(BuildContext context) {
    final en = _en(context);
    final items = [
      ['Sourcing & Procurement', 'التوريد والمشتريات',
        'Identifying and securing high-quality materials and products.',
        'تحديد وتأمين المواد والمنتجات عالية الجودة.'],
      ['Quality Inspection', 'فحص الجودة',
        'Rigorous quality checks to ensure compliance with standards.',
        'فحوصات الجودة الصارمة لضمان الامتثال للمعايير.'],
      ['Warehousing', 'التخزين',
        'Secure storage and inventory management in modern facilities.',
        'التخزين الآمن وإدارة المخزون في منشآت حديثة.'],
      ['Road Transport & Delivery', 'النقل البري والتسليم',
        'Efficient and reliable distribution to your designated locations.',
        'توزيع فعال وموثوق إلى المواقع المحددة الخاصة بك.'],
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      color: context.sectionColor,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: en ? 'Our Working Process' : '\u0622\u0644\u064a\u0629 \u0627\u0644\u0639\u0645\u0644', isArabic: !en),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (ctx, cons) {
              const gap = 12.0;
              final fullW = cons.maxWidth;
              final cols = fullW >= 760 ? 4 : fullW >= 520 ? 3 : fullW >= 380 ? 2 : 1;
              final cardW = (fullW - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: cardW,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                en ? item[0] : item[1],
                                style: TextStyle(fontWeight: FontWeight.w700, color: ctx.headingColor),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                en ? item[2] : item[3],
                                style: TextStyle(color: ctx.mutedColor, fontSize: 13),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
    );
  }

  Widget _valuesSection(BuildContext context) {
    final en = _en(context);
    final values = [
      ['Total Transparency', 'الشفافية التامة',
        'Clear pricing and honest communication at every step of our partnership.',
        'تسعير واضح وتواصل صادق في كل خطوة من شراكتنا.'],
      ['Strict Punctuality', 'الالتزام الصارم بالمواعيد',
        'Unwavering commitment to delivery schedules and operational deadlines.',
        'التزام لا يتزعزع بجداول التسليم والمواعيد النهائية للعمليات.'],
      ['Uncompromising Quality', 'جودة لا تقبل المساومة',
        'Rigorous vetting of all supplies to ensure they meet exact corporate standards.',
        'تدقيق صارم لجميع التوريدات لضمان تلبيتها لمعايير الشركات الدقيقة.'],
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      color: context.altSectionColor,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: en ? 'Core Values' : 'القيم الأساسية', isArabic: !en),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (ctx, cons) {
              const gap = 12.0;
              final fullW = cons.maxWidth;
              final cols = fullW >= 760 ? 3 : fullW >= 420 ? 2 : 1;
              final cardW = (fullW - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in values)
                    SizedBox(
                      width: cardW,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                en ? item[0] : item[1],
                                style: TextStyle(fontWeight: FontWeight.w700, color: ctx.headingColor, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                en ? item[2] : item[3],
                                style: TextStyle(color: ctx.mutedColor, fontSize: 13),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
    );
  }

  Widget _infoCard(BuildContext context, String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.headingColor),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final en = _en(context);
    final columns = <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/logo.png', width: 60, height: 60, fit: BoxFit.contain),
          const SizedBox(height: 8),
          Text(
            en
                ? 'Delivering logistics excellence and premium supplies for your business needs.'
                : 'تقديم التميز اللوجستي والتوريدات المتميزة لاحتياجات عملك.',
            style: const TextStyle(color: Color(0xFFD7DEEA), fontSize: 13),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(en ? 'Quick Links' : 'روابط سريعة',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(en ? 'Home' : 'الرئيسية', style: const TextStyle(color: Color(0xFFC9D3E0))),
          Text(en ? 'About Us' : 'من نحن', style: const TextStyle(color: Color(0xFFC9D3E0))),
          Text(en ? 'Working Process' : 'آلية العمل', style: const TextStyle(color: Color(0xFFC9D3E0))),
          Text(en ? 'Contact' : 'تواصل معنا', style: const TextStyle(color: Color(0xFFC9D3E0))),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(en ? 'Core Services' : 'الخدمات الأساسية',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(en ? 'General Supplies' : 'التوريدات العامة', style: const TextStyle(color: Color(0xFFC9D3E0))),
          Text(en ? 'Road Transport & Goods Distribution' : 'النقل البري وتوزيع البضائع', style: const TextStyle(color: Color(0xFFC9D3E0))),
          Text(en ? 'Cold & Dry Storage' : 'التخزين المبرد والجاف', style: const TextStyle(color: Color(0xFFC9D3E0))),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(en ? 'Contact' : 'تواصل معنا',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(en ? 'Alexandria, Egypt' : '\u0627\u0644\u0625\u0633\u0643\u0646\u062f\u0631\u064a\u0629\u060c \u0645\u0635\u0631', style: const TextStyle(color: Color(0xFFC9D3E0))),
          const Text('+20 10 11428818', style: TextStyle(color: Color(0xFFC9D3E0))),
          const Text('info@gossts.com', style: TextStyle(color: Color(0xFFC9D3E0))),
        ],
      ),
    ];

    return Container(
      color: GossColors.navy,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 24) / (constraints.maxWidth < 700 ? 2 : 4);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: columns
                    .map((c) => SizedBox(width: itemWidth, child: c))
                    .toList(),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                en ? '© 2026 Gosst Company. All rights reserved.' : '© 2026 شركة جوست. جميع الحقوق محفوظة.',
                style: const TextStyle(color: Color(0xFFC9D3E0), fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _en(BuildContext context) {
    final app = context.watch<AppProvider>();
    return !app.isArabic;
  }
}

class _HeroCarousel extends StatefulWidget {
  final bool en;
  const _HeroCarousel({required this.en});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _controller = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_page + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<Map<String, Object>> get _slides => [
        {
          'image': 'assets/images/hero_warehouse.jpg',
          'badge_e': 'GOSST LOGISTICS & TRADE',
          'badge_a': 'جوست للوجستيات والتجارة',
          'title_e': 'General Supplies & Trade',
          'title_a': 'التوريدات العامة والتجارة',
          'sub_e': 'Providing premium supplies for corporate sectors and the Hotels, Restaurants, and Catering industry.',
          'sub_a': 'نوفر توريدات ممتازة لقطاعات الشركات وقطاع الفنادق والمطاعم والتموين.',
        },
        {
          'image': 'assets/images/hero_trucks.jpg',
          'badge_e': 'ROAD FREIGHT & DISTRIBUTION',
          'badge_a': 'النقل البري وتوزيع البضائع',
          'title_e': 'Integrated Logistics Services',
          'title_a': 'خدمات لوجستية متكاملة',
          'sub_e': 'Guaranteeing your shipments arrive safely and on time.',
          'sub_a': 'نضمن توصيل شحنتك بأمان وفي الوقت المحدد.',
        },
        {
          'image': 'assets/images/hero_ships.jpg',
          'badge_e': 'STORAGE & SUPPLY CHAIN SOLUTIONS',
          'badge_a': 'حلول التخزين وسلاسل الإمداد',
          'title_e': 'Secure Storage & Distribution',
          'title_a': 'تخزين وتوزيع آمن',
          'sub_e': 'Secure, scalable storage solutions designed for all types of commercial goods.',
          'sub_a': 'حلول تخزين آمنة وقابلة للتطوير مصممة لجميع أنواع البضائع التجارية.',
        },
      ];

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.35).clamp(300.0, 430.0);
    return SizedBox(
      height: heroHeight,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _startAutoPlay();
            },
            itemBuilder: (ctx, i) {
              final s = _slides[i];
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(s['image']! as String),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        GossColors.navy.withValues(alpha: 0.9),
                        GossColors.navy.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: GossColors.red,
                        child: Text(
                          widget.en ? s['badge_e']! as String : s['badge_a']! as String,
                          style: const TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.en ? s['title_e']! as String : s['title_a']! as String,
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.en ? s['sub_e']! as String : s['sub_a']! as String,
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i ? GossColors.red : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
