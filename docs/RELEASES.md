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

---

## v2.3.0 — ولکان تمام شد؛ موبایل رفت روی OpenGL (versionCode 6) ✅

گزارش کرش دوم از APK v2.2.0: همان `OPENING THE STAND (74%)` ولی این بار
`last action = stand:truck`. یعنی فیکس کمربند جواب داده (کل زنجیره‌ی
standbuild تا آخر رفت) و حالا اولین ریسورس‌های GPU کامیون تحویل، درایور Mali
را کشته — همان الگوی قبلی، روی شیء بعدی. دو کرش، دو شیء متفاوت، یک نتیجه:
**درایور Vulkan این Mali-G615 در برابر pipeline/resource های جدید حین لود
ناپایدار است.**

نکته‌ی مهم تشخیصی: خط `renderer forward_plus` در هر دو گزارش **اشتباه**
بود — `crash_report.gd` مقدار پایه‌ی project.godot را می‌خواند، نه override
موبایل را؛ گوشی در واقع روی renderer «mobile» (ولکان) بود. یعنی هر دو
renderer ولکان (forward_plus و mobile) روی این گوشی کرش داده‌اند.

فیکس‌های v2.3.0:

1. **موبایل به `gl_compatibility` (OpenGL ES 3) منتقل شد**
   (`rendering_method.mobile`) — GLES3 از درایور کاملاً متفاوت و قدیمی‌ترِ
   Mali استفاده می‌کند؛ مسیر ولکان که دو بار کشنده از آب درآمد به‌کلی کنار
   گذاشته شد. دسکتاپ همچنان forward_plus.
2. **کامیون تحویل هم مثل کمربند به بعد از لودینگ منتقل شد** —
   `world._build_truck_staged()`: هر زیرگام یک فریم رندر + breadcrumb
   اختصاصی (`truck:model/skin/measure/hull/bed/stack/place/done`). دسکتاپ
   مسیر inline قبلی.
3. **breadcrumb برای اولین drawهای واقعی کامیون** (`truck:arrive`,
   `truck:roll`) — اگر درایور روزی روی drawهای کامیون بمیرد، گزارش دقیقاً
   می‌گوید کجا.
4. **گزارش کرش حالا renderer واقعی را نشان می‌دهد**
   (`RenderingServer.get_current_rendering_method()`) + شماره‌ی نسخه در خط
   build (`V33 demo v2.3.0 build 6`) — دیگر هیچ‌وقت معلوم نیست «کدام apk
   کرش کرده» نیست.
5. **فیکس شیدر آسمان برای GLES3** — `moon_textures[moon_hit.id]` در
   `sky_atmosphere.gdshader` شیدر آسمان را روی OpenGL می‌کشت (سامپلر آرایه
   با اندیس غیرثابت در GLSL ES 3 ممنوع است)؛ به سه شاخه‌ی اندیس ثابت شکسته
   شد.

راستی‌آزمایی: علاوه بر لود headless، این بار **لود کامل زیر renderer واقعی
OpenGL** (llvmpipe) هم اجرا شد: صفر خطای کامپایل شیدر، کمربند و کامیون کامل،
خروجی `[world] truck built staged: model=true hull=true bed=true`.

Asset ها:
- `FindTheNeedle-v2.3.0-universal.apk` (versionCode 6 — universal: arm64-v8a +
  armeabi-v7a، ETC2/ASTC، targetSdk 36، کیفیت‌های low/medium/high)
- `find-the-needle-v2.3.0-source.zip`

⚠️ **نکته‌ی نصب:** امضای v2.3.0 با v2.2.0 یکی است (نصب روی آن بدون حذف
انجام می‌شود). اگر از v2.1.0 یا قدیمی‌تر می‌آیید، اول uninstall کنید.
اگر باز هم کرش داد: خط `renderer` گزارش حالا باید `gl_compatibility` را
نشان دهد و `last action` زیرگام دقیق (مثلاً `truck:skin`) را — عکس/متن آن
را بفرستید.

---

## v2.4.0 — سیستم لاگ قابل‌ارسال؛ کرشِ صفحه سیاه دیگر نامرئی نیست (versionCode 7) ✅

گزارش کاربر از v2.3.0: صفحه سیاه و خروج در ~۱ ثانیه. تا امروز اگر کرش در
ثانیه‌های اول (بوت/منو) رخ می‌داد هیچ ردی باقی نمی‌ماند: فایل‌لاگ موتور
روشن نبود (کلید اشتباه در project.godot) و فایل‌های داخل حافظه خصوصی اپ
از فایل‌منیجر قابل دسترس نبودند. این ریلیز خودِ «چشم» را می‌سازد — جزئیات
فنی در `docs/BUGS.md`:

1. فایل‌لاگ گودوت واقعاً روشن شد (`user://logs/godot.log`، ۱۰ نسخه گردشی)
2. autoload جدید `GameLog`: لاگ ماندگار + آینه در حافظه اشتراکی
3. breadcrumbهای لودینگ (stages/standbuild/truck) حالا در فایل قابل‌ارسال هم می‌روند
4. گزارش کرش به‌صورت `crash_report_*.txt` در پوشه لاگ ذخیره می‌شود
5. مجوزهای MANAGE/WRITE_EXTERNAL_STORAGE برای مسیر `/sdcard/.gamelog`

### کجا لاگ را ببینیم؟

- مسیر پیش‌فرض (بدون هیچ مجوزی): `Android/media/com.obsifox.findtheneedle/gamelog/`
- مسیر دلخواه کاربر: `/sdcard/.gamelog/` — بعد از یک‌بار فعال کردن
  Settings → Apps → Find The Needle → Permissions → Files and media →
  «Allow management of all files» (اجرای بعدی خودکار همان‌جا می‌نویسد)
- فایل‌های مهم: `gamelog.txt` (اصلی)، `engine_prev.log` (لاگ اجرای قبل)،
  `crash_report_*.txt` (گزارش کرش)

اگر کرش برگشت: فقط جدیدترین فایل‌های این پوشه را بفرستید — آخرین خط‌ها
دقیقاً می‌گویند بازی کجا بود (منو؟ لودینگ؟ کدام زیرگام؟).

Asset ها:
- `FindTheNeedle-v2.4.0-universal.apk` (versionCode 7 — universal: arm64-v8a +
  armeabi-v7a، ETC2/ASTC، targetSdk 36، کیفیت‌های low/medium/high)
- `find-the-needle-v2.4.0-source.zip`

⚠️ **نکته‌ی نصب:** امضای این بیلد با همه‌ی بیلدهای قبلی فرق دارد (کلید قبلی
در دسترس نبود) — اول uninstall کنید بعد نصب. ذخیره‌های داخل بازی پاک می‌شوند.

---

## v2.5.0 — رفع کرش بوتِ صفحه‌سیاه + لاگ ضدگلوله (versionCode 8) ✅

لاگ واقعی v2.4.0 از گوشی آنالیز شد (`gamelog.txt` — اولین لاگی که واقعاً
از کرش surviving شد). سه سرنخ در همان بوت‌بنر بود:

1. **`gpu` و `api` خالی بودند** — موقع نوشتن بنر، درایور هنوز بالا نیامده بود
2. **`memory -0.0 GB`** — خواندن حافظه خراب بود (⇒ علامت سؤال، نه کرش)
3. **بعد از بنر هیچ خطی نیامد** — اپ قبل از اولین فریمِ رندر شده مُرد

### ریشه‌یابی: رندر روی thread جداگانه روی GL اندروید

`driver/threads/thread_model.template=2` (رندر روی thread جدا) از پروژه‌ی
دسکتاپِ اصلی به ارث رسیده بود و در **تمام بیلدهای اکسپورت** فعال است. بیلد
v2.3.0 با llvmpipe روی دسکتاپ تست شده بود — یعنی با تنظیم پیش‌فرض موتور،
نه با این override. پس اندروید از همیشه یک کانفیگ تست‌نشده را اجرا می‌کرد:
**OpenGL ES روی worker thread** (انتقال EGL context) — و Mali-G615 دقیقاً
در همین نقطه، قبل از اولین فریم، اپ را می‌کُشت.

- **فیکس:** `driver/threads/thread_model.mobile=1` — اندروید حالا
  تک‌thread رندر می‌کند (همان کانفیگی که واقعاً تست شده بود). دسکتاپ
  دست‌نخورده ماند.
- **فیکس لاگ v2.4.0:** کلیدهای فایل‌لاگ هنوز مسیر اشتباه داشتند
  (`debug/settings/file_logging/...` به‌جای `debug/file_logging/...`) ⇒
  `engine_prev.log` هرگز ساخته نمی‌شد. حالا درست شد.

### لاگ جدید چه چیزهایی می‌گوید؟

- `cpu/gpu/memory` در بنر بوت درست شد (fallback به مدل گوشی + گارد حافظه)
- خط جدید **`boot2`**: بعد از اولین فریم رندر‌شده می‌آید —
  «FIRST FRAME DRAWN» یعنی پایپ‌لاین رندر زنده است؛ نبودِ آن بعد از بنر
  یعنی مرگ داخل driver init (دقیقاً همان چیزی که v2.4.0 را مبهم می‌کرد)
- breadcrumbهای منو: `menu_root: building UI` / `background: building
  hay field` / `background: built` / `menu_root: ready` با مُهر زمانی
- اگر بعد از نصب این نسخه باز هم کرش کرد: `gamelog.txt` + `engine_prev.log`
  (این‌بار واقعاً وجود دارد) را از پوشه لاگ بفرستید

### Asset ها

- `FindTheNeedle-v2.5.0-universal.apk` (versionCode 8 — universal:
  arm64-v8a + armeabi-v7a، ETC2/ASTC، targetSdk 36، کیفیت‌های low/medium/high)
- `find-the-needle-v2.5.0-source.zip`

⚠️ **نکته‌ی نصب:** کلید امضا دوباره از دست رفته و بازسازی شده — اول
uninstall، بعد نصب. (از v2.4.0 به بعد همین شرط بوده.)

---

## v3.0.0 — بازسازی موبایل (versionCode 9) 🔄

لاگ V35 حکم قطعی را داد: منو کامل ساخته شد، ولی `gpu` هنوز خالی و `boot2`
هرگز نیامد — یعنی حتی با تک-thread، **مسیر OpenGL این درایور حتی یک فریم هم
نکشید**. سه بیلد GL (v2.3.0/2.4.0/2.5.0) هر سه دقیقاً همان‌جا مردند. در
مقابل، دو بیلد Vulkan (v2.1.0 و v2.2.0) روی همین گوشی ~۲۵ ثانیه رندر کرد
(منو + لودینگ تا ۷۴٪) و فقط روی منابع سنگین stand/truck مُرد.

**نتیجه:** OpenGL روی این گوشی مرده؛ Vulkan تنها استکی است که تا حالا پیکسل
کشیده. پس ساختار دسکتاپی کنار گذاشته شد و بازی برای موبایل بازسازی شد:

1. **رندرر موبایل → Vulkan `mobile`** (`rendering_method.mobile="mobile"`) —
   همان کانفیگی که ۲۵ ثانیه روی گوشی رندر کرد. دسکتاپ (forward_plus) دست‌نخورده
2. **منوی موبایل → پلیت ۲D** — بک‌دراپ سه‌بعدی هِی (HDR 2k + شیدرهای strand/flare)
   نمایشگاه دسکتاپ است؛ اولین فریمی که باید روی گوشی کشیده می‌شد و همان‌جا
   می‌مرد. روی موبایل همیشه پلیت ۲D — فریم اول ساده، و بالا بردن کیفیت در
   تنظیمات دیگر بک‌دراپ سنگین را برنمی‌گرداند
3. **ریست یک‌باره‌ی کیفیت روی موبایل → POTATO** — همه افکت‌ها خاموش،
   render_scale ۰٫۷۲، کوچک‌ترین آپلود تکسچر (همان عامل ۷۴٪). یک بار اعمال
   می‌شود؛ انتخاب بعدی کاربر می‌ماند
4. **سطر Render Thread هم دسکتاپی شد** — روی موبایل مخفی (نوشتن override.cfg
   روی اندروید بی‌اثر است)
5. بقیه مسیرها دست‌نخورده: Terrain3D (در Vulkan تا ۷۴٪ زنده بود)، staged
   truck/stand با breadcrumb، سیستم لاگ v2.4.0/v2.5.0

### Asset ها

- `FindTheNeedle-v3.0.0-universal.apk` (versionCode 9 — universal:
  arm64-v8a + armeabi-v7a، ETC2/ASTC، targetSdk 36)
- `find-the-needle-v3.0.0-source.zip`

اگر باز کرش کرد: لاگ این‌بار می‌گوید کجا — «FIRST FRAME DRAWN» یعنی رندر
زنده است و مشکل بعد از منو است؛ breadcrumbهای standbuild/truck زیرگام دقیق
را نشان می‌دهند؛ `engine_prev.log` (الان واقعاً ساخته می‌شود) متن خطای
درایور را دارد.

⚠️ **نصب:** اول uninstall (کلید امضا از v2.4.0 به بعد عوض شده).
