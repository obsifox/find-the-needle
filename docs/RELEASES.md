# برنامه Releases

سیاست: **release به release جلو می‌رویم — هر release هم سورس، هم (در صورت آمادگی) APK.**

## v1.0.0 — فقط سورس 🔄
- ریپو خصوصی: `obsifox/find-the-needle`
- سورس کامل بازی (pak-solona) در ریپو push می‌شود
- فایل zip کامل سورس (pak-solona.zip) به‌عنوان asset به release پیوست می‌شود
- **APK ندارد** — هنوز باگ‌ها رفع نشده

## v2.0.0 — باگ‌فیکس (سورس + APK در یک ریلیز) ✅
- رفع ۴ باگ: کرش 74% (Terrain3D)، کنترل لمسی کامل + layout واکنش‌گرا، حذف تنظیمات بی‌استفاده، لودینگ جدید
- Assetها:
  - `FindTheNeedle-v2.0.0-universal.apk` (~616MB — universal: arm64-v8a + armeabi-v7a، minSdk 26، فقط ETC2/ASTC، signed)
  - `find-the-needle-v2.0.0-source.zip` (سورس کامل قابل‌بیلد: + سورس تکسچرهای بازسازی‌شده + export_presets.cfg)
- سورس تکسچرها از کش ctex بازسازی شد (BCn decode) تا پروژه از صفر قابل import مجدد باشد
- کتابخانه Terrain3D (arm64 + arm32) داخل APK گنجانده شد

## بعد از v2.0.0
- هر release: سورس به‌روز + APK ساخته‌شده از همان commit
- تگ‌گذاری: `vX.Y.Z`
- APKها زیر ۲GB (محدودیت GitHub Releases asset)

---

## v2.0.0 — به‌روزرسانی (نسخه‌ی APK: versionCode 3) 🔁

ریشه‌ی واقعی کرش ۷۱–۷۴٪ پیدا و رفع شد (جزئیات فنی در `docs/BUGS.md`):
حذف کامل `instance uniform` از شیدرها + مسیر جدید per-machine برای متریال‌ها.

- `FindTheNeedle-v2.0.0-universal.apk` بازساخته شد (versionCode 3):
  - universal — arm64-v8a + armeabi-v7a
  - minSdk 24 (پیش‌فرض قالب گودوت؛ دستگاه هدف Android 36 پشتیبانی می‌شود)، targetSdk 36
  - بافت‌ها: ETC2/ASTC، کیفیت‌های low/medium/high داخل بازی
- `find-the-needle-v2.0.0-source.zip` بازساخته شد — این بار **کامل و قابل‌بیلد
  به‌تنهایی**: سورس‌ها + کش‌های `.godot/imported` (باینری GLB/صوت/تکسچر) +
  فایل‌های `.import` تعمیرشده.
- ⚠️ **امضای APK عوض شده** (کلید قبلی در دسترس نیست): قبل از نصب، نسخه‌ی قبلی
  را حذف (uninstall) کنید.
- اگر باز هم کرشی رخ دهد: بعد از اجرای بعدی بازی، دیالوگ گزارش کرش دقیقاً
  آخرین زیرمرحله‌ی لود (مثلاً `standbuild:kick`) را نشان می‌دهد.

---

## v2.1.0 — فیکس عمیق کرش موبایل + تکمیل اَست‌ها (versionCode 4) ✅

گزارش کاربر: APK versionCode 3 باز هم در ~۷۱٪ کرش می‌کرد. تحلیل جدید (جزئیات در
`docs/BUGS.md`): پاف دود در زمان لود نامرئی است، پس فیکس قبلی pipeline اشتباهی
را هدف گرفته بود. این ریلیز «دفاع در عمق» است:

- ساخت استند روی موبایل: هر زیرمرحله یک فریم رندر جدا + breadcrumb اختصاصی
- تمام FX ذره‌ای استند (سکه/جرقه/موتی/دود/kick dust/SaleFx) از مسیر لود حذف و
  به اولین استفاده منتقل شدند
- MSAA 4x و occlusion culling روی موبایل خاموش شدند (پروفایل `*.mobile`)
- حالت امن خودکار بعد از هر کرش لودینگ
- **تکمیل ~۳۰۰ اَست گمشده** (موسیقی، SFX، آیکون‌ها، flora، مدل‌ها) از کش pck
  بازی اصلی + تعمیر ۹ فایل `.import` خراب
- source zip این بار کش کامل `.godot/imported` (بازسازی‌شده) دارد و به‌تنهایی
  قابل‌بیلد است

Asset ها:
- `FindTheNeedle-v2.1.0-universal.apk` (versionCode 4 — universal: arm64-v8a +
  armeabi-v7a، ETC2/ASTC، low/medium/high داخل بازی)
- `find-the-needle-v2.1.0-source.zip`

⚠️ **امضای APK دوباره عوض شده** (کلید قبلی در دسترس نیست): قبل از نصب، نسخه‌ی
قبلی را uninstall کنید.

---

## v2.2.0 — فیکس هدفمند کمربند استند؛ مقصر از breadcrumb فهمیده شد (versionCode 5) ✅

گزارش کرش کاربر از APK v2.1.0 دقیقاً نام برد: `standbuild:belt`. یعنی اولین
draw کمربند استند درایور Mali را می‌کشت (تحلیل کامل در `docs/BUGS.md`). این
ریلیز سه دفاع مستقل دارد:

1. شیدر جفتی ساده‌ی موبایل برای همه‌ی متریال‌های conveyor (uniformها یکسان؛
   بدون fwidth/tread/nرمال دست‌ساز)
2. ساخت کامل کمربند به بعد از بسته شدن لودینگ منتقل شد — هر بخش یک فریم +
   breadcrumb اختصاصی (`belt:node/materials/deck/noses/supports/records`)
3. پایه‌های کمربند روی موبایل StandardMaterial3D (ترکیب MultiMesh + شیدر
   سفارشی از مسیر لود حذف شد)

- دسکتاپ: مسیر قبلی دست‌نخورده (کمربند داخل `_build_all`، شیدر کامل)
- راستی‌آزمایی: لود کامل استیج‌شده‌ی headless با `--stagedload --mobilesim` —
  صفر خطا + کمربند کامل بعد از لودینگ

Asset ها:
- `FindTheNeedle-v2.2.0-universal.apk` (versionCode 5 — universal: arm64-v8a +
  armeabi-v7a، ETC2/ASTC، targetSdk 36، کیفیت‌های low/medium/high)
- `find-the-needle-v2.2.0-source.zip`

⚠️ **امضای APK دوباره عوض شده** (کلید قبلی در دسترس نیست): قبل از نصب، نسخه‌ی
قبلی را uninstall کنید — ذخیره‌های داخل بازی با حذف برنامه پاک می‌شوند.
اگر باز هم کرش داد: دیالوگ گزارش کرش این بار باید «last action» مثل
`belt:deck` یا `standbuild:skin` را نشان دهد — عکس/متن آن را بفرستید.
