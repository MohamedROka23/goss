# دليل الرفع على Google Play — تطبيق GOSST

ملف الرفع الجاهز: `build\app\outputs\bundle\release\app-release.aab` (مُوقَّع بـ Upload Key)
أصول القائمة: مجلد `store_assets\`

---

## الخطوة 0 — التحضير المسبق (اختياري لكن يُنصح به)
1. **نشر قواعد Firestore**: في Firebase Console → Firestore Database → Rules → الصق محتوى `firestore.rules` → Publish. (الشرط: المستخدم لديه إمكانية الوصول إلى وحدة Firebase عبر /firebase.json)
2. **رفع الخادم على HTTPS**: نشر `server/index.js` على استضافة Node عامة بعنوان HTTPS، وضبط عنوان الخادم في التطبيق (الإعدادات → عنوان الخادم، أو تعديل القيمة الافتراضية في lib/services/api_service.dart). تتوافق play لكتُب HTTPS فقط.
3. **استضافة سياسة الخصوصية**: رفع `store_assets\privacy_policy.html` على موقع/استضافة ثابتة، وأخذ الرابط (ستُلصقه في الخطوة 3).

## الخطوة 1 — حساب المطور وإنشاء التطبيق
1. سجّل في https://play.google.com/console بتسجيل دخول Google (يمكن استخدام حساب العميل / شركة جوست).
2. ادفع رسوم التسجيل **($25)** مرة واحدة.
3. أكمل بيانات الشحن/الجغرافية في صفحة Pay.
4. اضغط **Create app**:
   - App name: `GOSST`
   - Default language: العربية (أو اختر العربية لاحقًا وستضيف الإنجليزية في القائمة)
   - App or game: App
   - Free or paid: Free
   - اضغط Create.

## الخطوة 2 — إعداد التطبيق والمفاتيح
- من القائمة الجانبية: **App content** ← App access: اختر «All functionality is accessible without restrictions».
- **App signing** (يظهر تلقائيًا عند أول رفع للـ AAB): فعّل **Play App Signing** (توقيع التطبيق بواسطة Google) — هكذا يبقى التوقيع placeholder آمن، وتُحفظ حزمة التوقيع الأصلي في Play Dashboard.
  - لاحظ: يتم تسجيل مفتاح الرفع (Upload Key) تلقائيًا من داخل الـ AAB نفسه، فلا حاجة لإصدار شهادات إضافية.
- ⚠️ **حفظ نسخة من مفتاح التوقيع**: انسخ احتياطيًا `android\app\upload-keystore.jks` + `android\key.properties` في مكان آمن (محرك أقراص خارجي/مستودع خاص). فقدان المفتاح = صعوبة تحديث التطبيق مستقبلًا.

## الخطوة 3 — القائمة داخل المتجر (Store Listing)
في **Main store listing**:
| الحقل | المحتوى |
|---|---|
| Short description | انسخ من `store_assets\store_listing.txt` (الإصدار القصير) |
| Full description | انسخ النص الكامل (عربي + إنجليزي) |
| App icon (512x512) | `store_assets\playstore_icon_512.png` |
| Feature graphic (1024x500) | `store_assets\feature_graphic_1024x500.png` |
| Phone screenshots | ارفع على الأقل 2: من `store_assets\09-role.png` و`phone-01-home.png` و`phone-02-catalog.png` و`03-about.png` و`07-contact.png` وغيرها |
| Categorization | Business (فئة) |
| Contact details | موقع: https://Info@gossts.com / بريد الدعم: Info@gossts.com |
| Privacy policy URL | رابط `privacy_policy.html` بعد استضافته |

## الخطوة 4 — استمارة الأمان (Data safety)
1. **App content** ← **Data safety** ← البدء.
2. إجابات تتبع النوع:
   - أرسل أو نتلقى بيانات المستخدم: **نعم، يرسل التطبيق بيانات** (معلومات الاتصال في الطلبات، ورمز الجهاز للإشعارات).
   - البيانات المُجمَّعة والغرض:
     - **Contact info** (الاسم، الهاتف، البريد، العنوان): يملؤها المستخدم يدويًا في نموذج الطلب — الغرض: «App functionality».
     - **Device or other IDs** (Push token): الغرض «App functionality» (إشعارات الطلبات).
   - مُجمَّعة؟ لست بحاجة لإعلان الجمع.
   - لم نشارك البيانات، ولم نبيعها، وليست جزءًا من الإعلانات.
   - **تشفير أثناء النقل**: HTTPS ✓
   - وسيلة الحذف: بطلب عبر البريد أو من فريق الإدارة (كما في سياسة الخصوصية).
   - لا موقع، لا صور، لا ميكروفون، لا أجهزة.

## الخطوة 5 — التصنيف العمري (Content rating)
1. ادخل IARC questionnaire من نفس صفحة App content.
2. أجب بصدق: لا عنف، لا محتوى جنسي، لا مخدرات، لا قمار، لا... → نتيجة متوقعة **3+ (أو 13+ للتصنيف الآمن)**. اختر 13+ إن أردت أمانًا إضافيًا.
3. أضف بريدًا للتحقق (يمكن Info@gossts.com) وأتمم.

## الخطوة 6 — الرفع (Release)
1. من القائمة: **Testing** ← **Internal testing** ← Create release.
2. ارفع الملف `app-release.aab`.
3. اكتب ملاحظات الإصدار: `Version 1.0.0 — First release`.
4. أضف نفسك (والأرقام الاختبارية للمحاكي داخل التدوين أو عبر قائمة Testers): البريد المرتبط بحساب المطور.
5. **Review release** ثم **Start rollout to Internal testing**.
6. انسخ رابط الـ opt-in وأرسله إليّ أو الثبّت على جهاز بنفس الحساب — سيتحقق Play من التوقيع والمؤهلات.

## الخطوة 7 — التحقق قبل الإنتاج
- ثبّت النسخة الاختبارية وافتحها، وأكّد: لا شاشة شكل، الإشعارات تطلب، السلة/الطلبات تعمل مع الخادم الحقيقي.
- حل أي تحذيرات تظهر في صفحة الإصدار.

## الخطوة 8 — النشر للإنتاج
1. في صفحة Internal testing: أيقونة «Promote release» → **Production**.
2. أكمل **Data safety** و**Content rating** و**App access** (إن لم تكتمل بعد) — ستمنعك Play حتى إكمالها.
3. ستراجع Google الطلب (من 1 ساعة إلى 7 أيام للإصدارات الجديدة).
4. بعد الموافقة يكون التطبيق متاحًا في المتجر عالميًا.

## إجراءات ما بعد الإصدار
- **الإصدار الجديد**: عدّل الإصدار في `pubspec.yaml` (مثال: أول تحديث ← `version: 1.0.1+2`)، ثم `flutter build appbundle --release` وارفع الملف الجديد → أيقونة للإصدارات القادمة في نفس صفحة Internal/Production.
- **مفتاح الجديد**: أثناء بناء الإصدار الثاني تأكد من وجود `key.properties` وقرص التوقيع — واحتفظ بنسخة منه.

## أسئلة قد تواجهك
- **تحذير «target SDK»**: التطبيق مبني بآخر SDK متوفر — لا حاجة لتغيير شيء.
- **التحقق «Privacy Policy»**: أضف دائمًا رابط سياسة الخصوصية في القائمة قبل الإنتاج.
- **`INSTALL_FAILED_UPDATE_INCOMPATIBLE`**: عند اختبار نسخة Release فوق نسخة Debug قديمة، احذف التطبيق أولًا.

---
مرجع الصور في المتجر: `store_assets\` (أيقونة 512، الغرافيك 1024x500، 9 لقطات شاشة، نصوص القائمة، سياسة الخصوصية).