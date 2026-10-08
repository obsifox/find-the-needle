# برنامه Releases

سیاست: **release به release جلو می‌رویم — هر release هم سورس، هم (در صورت آمادگی) APK.**

## v1.0.0 — فقط سورس 🔄
- ریپو خصوصی: `obsifox/find-the-needle`
- سورس کامل بازی (pak-solona) در ریپو push می‌شود
- فایل zip کامل سورس (pak-solona.zip) به‌عنوان asset به release پیوست می‌شود
- **APK ندارد** — هنوز باگ‌ها رفع نشده

## v2.0.0 — باگ‌فیکس (سورس جدا + APK جدا) ⏳
- رفع ۴ باگ: کرش 74% (Terrain3D)، کنترل لمسی کامل + layout واکنش‌گرا، حذف تنظیمات بی‌استفاده، لودینگ جدید
- Assetها: `source.zip` (سورس جدید) **و** `FindTheNeedle-v2.0.0.apk` (universal: arm64-v8a + armeabi-v7a، minSdk 26، ETC2/ASTC)
- کیفیت‌ها: low / medium / high

## بعد از v2.0.0
- هر release: سورس به‌روز + APK ساخته‌شده از همان commit
- تگ‌گذاری: `vX.Y.Z`
- APKها زیر ۲GB (محدودیت GitHub Releases asset)
