# GOSST — Global Outsourcing Services & Trading

تطبيق شركة توريدات ولوجستيات بشاشتين منفصلتين: **العميل** (تصفح خدمات، كتالوج عروض أسعار، طلب عروض، متابعة الطلبات) و**الأدمن** (لوحة تحكم كاملة: طلبات، تتبع، عملاء، عروض أسعار، شراء، ربح، مصاريف، فريق).

- يعمل كليًا على **Firebase Firestore + Auth** (بدون سيرفر محلي).
- عربي / إنجليزي (RTL/LTR)، وضع ليلي / نهاري، وإشعارات push.

## البنية الأساسية (core)

| الملف | محتواه |
|---|---|
| **lib/main.dart** | نقطة البداية: تهيئة Firebase وFCM، ربط `AppProvider` و`AdminProvider`، بناء `GossApp` (الثيم، اللغة، قفل تكبير الخط حتى 1.3) وبدء `SplashScreen` |
| **lib/screens/splash_screen.dart** | شاشة البداية: لوغو GOSST المتحرك (46 إطار) ثم الانتقال لاختيار الدور بعد 2.2 ثانية |
| **lib/screens/role_screen.dart** | اختيار الدور: "الدخول كعميل" (CustomerShell) أو "تسجيل دخول الإدارة" (AdminShell) |
| **lib/app/theme.dart** | ألوان GOSST + ثيم فاتح/ليلي كامل + امتدادات `context.headingColor/bodyColor/mutedColor` |
| **lib/app/service_data.dart** | بيانات الخدمات اللوجستية الخمس الثابتة (عناوين EN/AR، وصف، نقاط مميزة، صورة) |
| **lib/models/models.dart** | كلاس البيانات: Product، CartItem، CustomerRequest/RequestItem، Purchase، Expense، AdminUser، ProductCategory، PriceUpdateNotification + `RequestStatus` (المراحل من جديد حتى مؤكد/مرفوض) + `AdminRole`/`AdminPerms` |
| **lib/providers/app_provider.dart** | حالة العميل: لغة/ثيم، منتجات وفئات، السلة (أضف/عدّل/امسح)، إرسال الطلبات، طلباتي، دخول الأدمن وصلاحياته، الأشعارات |
| **lib/providers/admin_provider.dart** | حالة الأدمن: جلب الطلبات/المشتريات/المصاريف، تغيير الحالة (مع قفل بعد قرار العميل)، إدارة الفريق والإشعارات |

## طبقة الخدمات (lib/services)

| الملف | محتواه |
|---|---|
| **backend.dart** | واجهة `GossBackend` (العمليات المجردة) + إعدادات التوافق |
| **backend_manager.dart** | اختيار الباك-أند: دائمًا `FirestoreBackend` + هوية العميل (Firebase anonymous UID أو UUID محفوظ) |
| **firestore_backend.dart** | تنفيذ Firestore الكامل: منتجات، طلبات (+قبول/رفض التسليم وقفل الحالات النهائية)، مشتريات، مصاريف، عروض، إشعارات أسعار، مصادقة وتسجيل الأدمن |
| **http_backend.dart** / **api_service.dart** | تنفيذ HTTP قديم لباك-أند محلي (غير مستخدم حاليًا) |
| **export_service.dart** | تصدير PDF/Excel منسّق (رأس GOSST، جدول كحلي بـ zebra وحدود، عرض أعمدة تلقائي) |
| **fcm_service.dart** | إشعارات FCM + الإشعارات المحلية (تسجيل التوكن، معالجة الرسائل في المقدمة والخلفية) |
| **translation_service.dart** | ترجمة مجانية عربي→إنجليزي (Google Translate) لحقول المنتج |

## شاشات العميل (lib/screens/customer)

| الملف | محتواه |
|---|---|
| **customer_shell.dart** | هيكل العميل: AppBar + 6 تبويبات + دروور + جرس إشعارات + بطاقة السلة |
| **home_screen.dart** | الرئيسية: سلايدر، شبكة 10 خدمات، نبذة عن الشركة، خطوات العمل، القيم، فوتر |
| **about_screen.dart** | من نحن: القصة + المهمة/الرؤية + بطاقات الاعتمادات |
| **logistics_screen.dart** | قائمة الخدمات الخمس اللوجستية (رقم 01–05 + نقاط مميزة) |
| **supplies_screen.dart** | التوريدات: قطاعات (فنادق/مطاعم/شركات) + شيبس تصنيفات |
| **catalog_screen.dart** | الكتالوج + البحث + السلة (كميات بـ +/−، مسح، كتابة 0) + نموذج البيانات وإرسال الطلب |
| **service_detail_screen.dart** | تفاصيل خدمة: صورة hero + وصف + نقاط + زر "اطلب عرض سعر شحن" |
| **my_orders_screen.dart** | طلباتي: خط زمني للمراحل + وعد التسليم (48 ساعة) + أزرار قبول/رفض التسليم |
| **contact_screen.dart** | تواصل معنا: كروت تليفون/واتساب/إيميل/عنوان |
| **notifications_screen.dart** | تنبيهات تحديث الأسعار (المنتج + السعر القديم/الجديد) |
| **settings_screen.dart** | الإعدادات: وضع ليل/نهار، اللغة، حالة الاتصال، رقم الإصدار |

## شاشات الأدمن (lib/screens/admin)

| الملف | محتواه |
|---|---|
| **admin_shell.dart** | هيكل الأدمن: AppBar + جرس إشعارات بعدّاد + تغيير كلمة المرور + خروج |
| **admin_login_screen.dart** | تسجيل دخول/تسجيل حساب أدمن (كود التسجيل `GOSST@admin`) |
| **admin_dashboard.dart** | التبويبات الثمانية مصفاة حسب صلاحيات الحساب |
| **admin_requests_tab.dart** | الطلبات: بطاقات + قائمة الحالة + زرار "قبول الطلب" + قفل الحالة بعد قرار العميل + تصدير |
| **admin_tracking_tab.dart** | التتبع: فلترة التاريخ/البحث + خط زمني لحظي لكل طلب |
| **admin_customers_tab.dart** | العملاء: تجميع الطلبات لكل عميل + من/إلى تاريخ + إجمالي فواتير + ربح متوقع |
| **admin_quotes_tab.dart** | عروض الأسعار: إضافة/تعديل/حذف منتجات + ترجمة تلقائية |
| **admin_purchases_tab.dart** | المشتريات: تسجيل (مورد/منتج/كمية/تكلفة) + سجل + تصدير |
| **admin_profit_tab.dart** | حاسبة الربح: منتجات × كميات − مصاريف إضافية → ربح صافي + هامش % |
| **admin_expenses_tab.dart** | المصاريف: إضافة/تعديل/حذف + بحث + إجمالي + تصدير |
| **admin_team_tab.dart** | الفريق: إضافة عضو (دور/صلاحيات) + تعديل + حذف (المالك محمي) |
| **admin_notifications_screen.dart** | مراجعة الطلبات الجديدة + سجل تحديثات الأسعار المرسلة |

## المكوّنات المشتركة (lib/widgets/widgets.dart)

`GossButton`، `SectionTitle`، `PageHero`، `ProductCard`، `ExportButtons` (PDF/Excel)، `RequestStatusChip`، `RequestStatusTimeline`، `VersionBadge`، `AnimatedLogo`، `AdminMenusSlider` ودالة `requestStatusColor()`.

## البناء والإصدار

- بناء الـ APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
- بناء الـ AAB (لـ Google Play): `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
- الاختبارات: `flutter test` (571 اختبارًا)
- الفحص الساكن: `flutter analyze`