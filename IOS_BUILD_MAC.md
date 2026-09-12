# إصدار iOS — خطوات التنفيذ على الماك (GOSST)

> كل ما يخص المشروع جاهز: أيقونات iOS مولّدة، وملف
> `ios/Runner/GoogleService-Info.plist` موجود (تطبيق iOS أُضيف لمشروع Firebase
> `gosst-9c2c6` بالمعرّف `com.gosst.goss`)، والنهدف iOS 15.

## على الماك — مرة واحدة فقط
1. ثبّت Xcode من App Store (آخر نسخة) ثم:
   - `sudo xcodebuild -license accept`
   - `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
2. ثبّت CocoaPods:
   - `sudo gem install cocoapods`
3. من مجلد المشروع:
   - `flutter doctor -v`   ← تأكد أن Xcode وCocoaPods خاليان من ✗
   - `flutter pub get`
   - إن لم يظهر `ios/Podfile` تلقائياً: `flutter create --platforms=ios .` ثم `cd ios && pod install`

## التوقيع (مرة واحدة)
4. افتح `ios/Runner.xcworkspace` بـ Xcode.
5. في هدف **Runner → Signing & Capabilities**: اختر حسابك (Team) — سيُنشئ الـProvisioning تلقائياً.
6. أضف Capabilities: **Push Notifications** + **Background Modes (Remote notifications)**.
7. إشعارات iOS تحتاج **APNs Key**:
   - في Apple Developer → Keys → أنشئ مفتاحاً يسمح بـ *Apple Push Notifications service (APNs)*.
   - في Firebase Console → Project settings → Cloud Messaging → ارفع `APNs Key` (Key ID + Team ID).
   - (بدون هذه الخطوة يعمل التطبيق لكن لا تصل إشعارات الدفع على iOS.)

## البناء
8. تجربة على المحاكي:
   - `flutter emulators --launch apple_ios_simulator`
   - `flutter run`
9. بناء نقطي للجهاز (توقيع تلقائي بحسابك):
   - `flutter build ios --release --no-codesign`   ← تحقق تجريبي بدون توقيع نهائي
   - `flutter build ipa`                            ← بناء حقيقي بالتوقيع
10. الرفع لـ **TestFlight**:
    - افتح Xcode → Window → Organizer → Archives → **Distribute App** (اختر TestFlight).
    - أو من سطر الأوامر: `xcrun altool --upload-app -f build/ios/ipa/*.ipa --type ios --apiKey ... --apiIssuer ...`

## إعدادات App Store Connect (من المتصفح)
- بيانات المتجر: انسخ النصوص من `store_assets/store_listing.txt`.
- سياسة الخصوصية: استضف `store_assets/privacy_policy.html` وألصق الرابط.
- بيانات الخصوصية العامة (App Privacy) أكّدها حسب محتوى السياسة.
- نوع الدفع/الاقتصاد: لا توجد عمليات شراء داخلية.

## ملاحظات
- النمط سحابي بالكامل (Firebase/Cloud)، لا يحتاج خادماً محلياً بإطلاق.
- دخول الأدمن `info@gossts.com / 123456` يعمل على iOS كما في Android.
- هوية العميل: Anonymous Auth (مفعّل من قبل على `gosst-9c2c6`).