# باگ‌های شناخته‌شده — هدف رفع: v2.0.0

> گزارش کرش از دستگاه واقعی کاربر:
> **FIND THE NEEDLE — crash در `OPENING THE STAND (74%)`**
> GPU: Mali-G615 MC6 (ARM) | Vulkan 1.3.247 | forward_plus | Android 36 (HyperOS)

---

## باگ ۱ — کرش/قفل در OPENING THE STAND (74%) — خرابی Terrain3D روی موبایل

**علامت:** لودینگ روی 74% گیر می‌کند / اپ کرش می‌کند، هرگز بارگذاری کامل نمی‌شود.

**ریشه:** ادان **Terrain3D** روی بعضی GPUهای موبایل (Mali-G615 + Vulkan 1.3.247، forward_plus)
در حین initialize شدن خراب می‌شود. render thread روی AUTO است.

**راه‌حل برنامه‌ریزی‌شده:**
- جایگزینی Terrain3D با terrain سازگار با همه دستگاه‌ها (GridMap یا Mesh-based terrain بومی گودوت)
- یا fallback به رندرر mobile برای Android و حذف وابستگی Terrain3D از مسیر لود
- معیار پذیرش: لود کامل از 0 تا 100% روی Mali-G615 بدون کرش

## باگ ۲ — دکمه‌های لمسی ناقص + layout غیر واکنش‌گرا

**علامت:** کنترل‌های لمسی فقط داخل خود بازی (in-game) وجود دارند؛ منوها با موس طراحی شده‌اند
و روی صفحه‌های بلند/مختلف گوشی دکمه‌ها بریده می‌شوند.

**راه‌حل برنامه‌ریزی‌شده:**
- پیاده‌سازی دکمه‌های لمسی برای همه منوها (mapping کلیدهای کیبورد+ماوس → تاچ)
- stretch mode `canvas_items` + anchorهای صحیح + رعایت safe-area (نچ/ناوبار)
- معیار پذیرش: همه دیالوگ‌ها و منوها با یک انگشت قابل استفاده، بدون برش در 16:9 تا 21:9

## باگ ۳ — تنظیمات بی‌استفاده در نسخه موبایل

**علامت:** گزینه‌های زیر روی موبایل کار نمی‌کنند ولی در منو دیده می‌شوند:
Resolution، Fullscreen، V-Sync، Renderer، کلیدبایدهای کیبورد (keyboard bindings)

**راه‌حل برنامه‌ریزی‌شده:** حذف/مخفی‌سازی این گزینه‌ها در build موبایل؛ نگه‌داشتن فقط
تنظیمات مؤثر (صدا، کیفیت گرافیک low/medium/high، زبان).

## باگ ۴ — لودینگ قدیمی: بعد از پایان لود اپ بسته می‌شد

**علامت:** در نسخه قدیمی، بعد از کامل شدن لود، اپ کرش/بسته می‌شد.

**راه‌حل برنامه‌ریزی‌شده:** بازنویسی صحنه لودینگ؛ حذف فراخوانی‌های ممنوع در اندروید
(مثل `get_tree().quit()` ناخواسته)؛ انتقال init سنگین به thread جدا با پراگرس واقعی.

---

## سابقه رمزگشایی (مرجع)

۶۰۹ فایل `.gdc` (بایت‌کد GDSC v101: magic `GDSC` + zstd token buffer، identifierها
XOR `0xB6`) به گزارش متنی کلیدهای کیبورد/ماوس رمزگشایی شده بود — خروجی در
پیام ذخیره‌شده تلگرام (message_id=76).


---

## v2.0.0  — باگ ۱: ریشه واقعی پیدا شد (به‌روزرسانی تحقیق)

جایگزینی Terrain3D مشکل را حل نکرد: روی دستگاه کاربر، بیلد v2.0.0 دوباره در
**۷۱ تا ۷۴٪ — همان پنجره `OPENING THE STAND`** بسته می‌شد. یعنی مقصر اصلی
Terrain3D نبود.

**ریشه واقعی:** «پاف دودِ» selling stand (`HaySellingStand._build_puff`) اولین
مشِ کل مسیر لود است که شیدر `smoke_column.gdshader` را کامپایل می‌کند و آن شیدر
یک `instance uniform` داشت. کامپایل اولین pipeline دارای instance uniform روی
درایور Vulkan موبایل (Mali-G615 / Android 36) دستگاه، device loss و بسته شدن
برنامه می‌دهد. به همین دلیل هم کرش در هر دو بیلد v1 و v2 دقیقاً همان‌جا بود.

**فیکس اعمال‌شده (commit فعلی):**
1. همه‌ی `instance uniform`ها از شیدرهای پروژه حذف شدند (۸ شیدر: smoke_column،
   stand_surface، silo_readout، radar_beam، radar_ring، machine_lamp،
   flow_road، pulp_slurry) → uniform معمولی.
2. تغییرات per-machine حالا از طریق نسخه‌ی مخصوص هر دستگاه از متریال
   (`HayCompressor.drive_instance` جدید) اعمال می‌شود — خروجی بصری یکسان.
3. رادار (`needle_radar.gd`) هم به همان مسیر منتقل شد.
4. ردپای لود (breadcrumb): هر زیرمرحله‌ی ساخت استند با `CrashReport.note_doing`
   ثبت می‌شود؛ اگر باز هم کرشی رخ دهد، دیالوگ گزارش کرش دقیقاً می‌گوید آخرین
   زیرمرحله چه بوده.

**معیار پذیرش:** لود کامل 0→100% روی Mali-G615 (دستگاه کاربر) بدون کرش.

---

## v2.1.0  — تحقیق نهایی: فیکس قبلی به هدف اشتباهی خورده بود 🔬

کاربر گزارش داد که APK بازسازی‌شده‌ی versionCode 3 (بدون instance uniform) **باز هم
در ۷۱٪ کرش می‌کند**. بررسی عمیق‌تر سه اشتباه در تحلیل قبلی را نشان داد:

1. **پاف دود در زمان لود نامرئی است.** `HaySellingStand._build_puff` گره را با
   `visible = false` می‌سازد و فقط هنگام اولین فروش (`_puff_burst`) دیده می‌شود.
   یعنی `smoke_column.gdshader` در پنجره‌ی ۷۱–۷۴٪ اصلاً کامپایل نمی‌شد و حذف
   instance uniform آن نمی‌توانست این کرش را رفع کند. (Godot برای گره‌های
   نامرئی pipeline کامپایل نمی‌کند.)
2. **راستی‌آزمایی قبلی headless بود.** در حالت headless هیچ pipeline واقعی GPU
   کامپایل نمی‌شود، پس «تأیید لود بدون خطا» درباره‌ی کرش درایور Mali بی‌معناست.
3. **APK نسخه v2.0.0 حدود ۳۰۰ اَست گمشده داشت** (موسیقی، صدای کندن/خرمن،
   آیکون‌های منو، مدل‌های flora مثل bale/windrow، robotic_arm و…) چون سورس‌های
   خام آن‌ها هرگز به ریپو نرسیده بود و کش import هم ناقص بود. کش از pck بازی
   اصلی (pak-solona) بازسازی شد + ۹ فایل `.import` خراب (`valid=false`) تعمیر شد.

**فیکس ساختاری v2.1.0 (دفاع در عمق — بدون فرض قطعی روی یک مقصر واحد):**

1. **ساخت استیج‌شده‌ی استند روی موبایل** (`staged_build`): هر زیرمرحله‌ی ساخت
   استند (belt/payout/skin/dress/ledger/price_board/till/coins/coin_pool/sack/
   kick/sale_fx) با یک فریم رندر جدا اعمال می‌شود و breadcrumb اختصاصی خودش را
   می‌نویسد. اگر درایور روی یک pipeline خاص بمیرد، دیالوگ گزارش کرش دقیقاً
   زیرمرحله‌ی رندرشده را نام می‌برد (مثلاً `standbuild:skin`)، نه آخرین
   زیرمرحله‌ی هم‌فریم.
2. **FX تنبل (lean_fx):** لایه‌های ذرات پرداخت (PayoutCoins/Sparks/Motes)، پاف
   دود، گرد kicks و ذرات SaleFx در مسیر لود **اصلاً ساخته نمی‌شوند** — همه
   تزئینی‌اند تا اولین فروش؛ الان در اولین استفاده بعد از لودینگ ساخته می‌شوند
   (breadcrumb های `fxfirst:*`). پنجره‌ی ۷۱–۷۴٪ فقط چیزهایی کامپایل می‌کند که
   خودِ استند از آن‌ها ساخته شده.
3. **MSAA 4x روی موبایل خاموش** (`msaa_3d.mobile=0`) و **occlusion culling روی
   موبایل خاموش** (`use_occlusion_culling.mobile=false`) — هم مصرف حافظه‌ی
   فریم‌بافر و هم دو لبه‌ی شناخته‌شده‌ی درایورهای Mali حذف می‌شود.
4. **حالت امن بعد از کرش** (`CrashReport.safe_load`): اگر اجرای قبلی روی صفحه‌ی
   لودینگ مرده باشد، اجرای بعدی خودبه‌خود همان مسیر استیج‌شده و lean را می‌رود.
5. **راستی‌آزمایی دوگانه:** لود کامل headless هم با مسیر دسکتاپ و هم با مسیر
   استیج‌شده‌ی موبایل صفر خطا (اسکریپت + منبع).

**معیار پذیرش (تکرار):** لود کامل 0→100% روی Mali-G615 بدون کرش. اگر باز هم
کرشی رخ دهد، دیالوگ گزارش کرش این بار «last action» دقیقی دارد که مرحله‌ی
قاتل را نام می‌برد و اصلاح بعدی هدفمند خواهد بود.

---

## v2.2.0 — مقصر نهایی با breadcrumb نام برده شد: `standbuild:belt` 🎯

کاربر APK versionCode 4 (v2.1.0) را نصب کرد و باز هم کرش — اما این بار گزارش
کرشِ v2.1.0 دقیق بود:

```
last step     OPENING THE STAND (74%)
last action   standbuild:belt (0 s before the end)
pile          small
```

چون v2.1.0 هر زیرمرحله را در یک فریم رندر جدا می‌ساخت و هر کدام breadcrumb
خودش را می‌نوشت، معنی گزارش این است: فریمِ بعد از ساخت کمربندِ استند — یعنی
**اولین draw واقعی کمربند** — درایور را کشت. مرور شد که چه چیزهایی تا آن لحظه
با موفقیت رسم شده بود (زمین، حصار، landing zone همه MultiMesh با
StandardMaterial3D؛ پشته‌ی hay شیدر سفارشی روی MeshInstance؛ مدل استند glTF)
و در فریم کمربند دقیقاً دو «اولین» جدید رخ می‌داد:

1. **اولین کامپایل pipeline شیدر `conveyor_surface.gdshader`** در کل لود —
   fragment آن سه چیز پرریسک برای کامپایلر موبایل دارد: `fwidth` داخل بلوک
   شرطی، الگوی tread با فرکانس بسیار بالا (`pow(abs(sin(p*251.3)), vec2)`)، و
   نرمال دست‌سازِ محاسبه‌شده با تفاضل مرکزی.
2. **اولین MultiMesh با شیدر سفارشی** (پایه‌های کمربند/Feet با frame material)
   — همه‌ی MultiMeshهای قبلی لود StandardMaterial3D داشتند.

**فیکس v2.2.0 (بدون تغییر در مسیر دسکتاپ):**

1. **شیدر جفتی موبایل** — `assets/conveyor_surface_mobile.gdshader`: نام‌های
   uniform یکسان (همه‌ی `set_shader_parameter`ها بدون تغییر کار می‌کنند)،
   vertex همان اسکرول `TIME*speed`، fragment ساده (تکسچرها + tint + بازemap
   roughness + AO + نرمال‌مپ). از `ConveyorKit._pbr` روی
   `Cfg.is_mobile or CrashReport.safe_load` انتخاب می‌شود.
2. **ساخت کمربند به بعد از لودینگ منتقل شد** — در مسیر استیج‌شده، کمربند از
   `build_staged_steps` حذف شد و `world` بعد از `Loading.hide_screen()` آن را
   با `build_belt_staged()` می‌سازد: هر بخش (node/materials/deck/noses/
   supports/records) یک فریم رندر جدا + breadcrumb اختصاصی. اگر درایور باز هم
   روی یکی از این drawها بمیرد، گزارش کرش **بخش دقیق** را نام می‌برد.
3. **پایه‌های کمربند روی مسیر استیج‌شده StandardMaterial3D گرفتند**
   (`ConveyorKit.frame_material_standard`) — ترکیب MultiMesh + شیدر سفارشی
   دیگر در کل بازی در زمان لود روی موبایل رخ نمی‌دهد.
4. **هشدار ۲ فریمی**: در مسیر استیج‌شده، کمربند مدل (~۵ فریم بعد از بسته شدن
   لودینگ) با کمربند واقعی جایگزین می‌شود — در عمل نامرئی است.
5. ابزار تست: `--mobilesim` (مسیر کامل موبایل روی هر دستگاه) +
   `scripts/dev/mobile_sim_check.gd` (انتخاب شیدر + کامپایل اسکریپت‌ها).

راستی‌آزمایی headless: لود کامل استیج‌شده با `--stagedload --mobilesim` به
player می‌رسد، صفر خطای اسکریپت، و خروجی
`[stand] belt built staged: deck=true rails=true noses=true supports=true`.
کامپایل واقعی pipeline روی GPU مقصد فقط با نصب روی دستگاه کاربر اثبات می‌شود —
اما این بار اگر کرشی برگردد، گزارش کرش بخشِ قاتل (مثلاً `belt:supports`) را
نام می‌برد.

**معیار پذیرش (نهایی و بلامنازع):** لود کامل 0→100% روی Mali-G615 بدون کرش.

### پیوست — کمبودهای شناخته‌شده‌ی غیرمرتبط با کرش (موروثی از v2.1.0)

- ~۱۲ SFX بیلد (place/demolish/confirm/denied/…) در ریپو فقط `.import` دارند و
  سورس `.ogg` آن‌ها از قبل گم شده؛ در زمان اجرا فقط بی‌صدا می‌شوند (بدون کرش).
- `woodgas_plant_optimized.tscn` در ریپو نیست؛ `gas_plant.gd` نبودن مدل را
  با `_model == null` مدیریت می‌کند.

---

## v2.3.0 — درایور Vulkan کنار گذاشته شد؛ موبایل روی OpenGL ES 3 🎯🔧

### سرنخ تازه: `stand:truck`

گزارش کرش v2.2.0: همان ۷۴٪ / `OPENING THE STAND` ولی `last action =
stand:truck`. مقایسه‌ی دو گزارش:

| | v2.1.0 | v2.2.0 |
|---|---|---|
| last action | `standbuild:belt` | `stand:truck` |
| مدت اجرا | ۲۳ ثانیه | ۲۵ ثانیه |
| آخرین مرحله | OPENING THE STAND (74%) | OPENING THE STAND (74%) |

یعنی فیکس v2.2.0 کار کرد — کل زنجیره‌ی standbuild (payout/skin/dress/
ledger/price_board/till/coins/coin_pool/sack/kick/sale_fx) بدون کرش رد شد و
لود تا ساخت کامیون پیش رفت؛ حالا اولین ریسورس‌های GPU کامیون (آپلود مدل
کامپایل‌شده، بافرهای اسکین، متریال‌های skin) درایور را کشت. دو کرش روی دو شیء
متفاوت = مشکل **شیء** نیست؛ **درایور Vulkan Mali-G615** در برابر
pipeline/resource تازه حین لود ناپایدار است.

### خطای گزارش: renderer اشتباه بود

`crash_report.gd` برای خط renderer مقدار پایه‌ی
`rendering/renderer/rendering_method` را می‌خواند؛ override موبایل
(`.mobile="mobile"`) اعمال نمی‌شد. پس گوشی هر دو بار روی renderer **mobile**
(ولکان) بود، نه forward_plus. نتیجه: هر دو renderer ولکان روی این گوشی
کرش داده‌اند — ولکان روی این درایور تمام.

### فیکس‌ها

1. **`rendering_method.mobile = "gl_compatibility"`** — موبایل روی OpenGL
   ES 3 می‌رود: درایور Mali-GLES قدیمی‌ترین و پایدارترین استک این GPU است و
   هیچ اشتراکی با مسیر ولکانِ کرش‌دهنده ندارد. دسکتاپ forward_plus می‌ماند.
   افت‌های شناخته‌شده (صرفاً بصری): FogVolume حصار رندر نمی‌شود (ولومتریک
   فاگ اصلاً در mobile renderer هم نبود)، حداکثر نور per-instance محدودتر.
2. **کامیون هم استیج‌شده ساخت** — `DeliveryTruck.staged_build` +
   `build_staged_steps()` (model در `_ready`، بقیه بعد از لودینگ یک فریم در
   میان): `truck:model/skin/measure/hull/bed/stack/place/done`. مصرف‌کنندگان
   (`PropManager.truck`، `DeliveryDirector.truck`) همگی null-safe شده‌اند و
   بعد از ساخت کامل وصل می‌شوند؛ قرارداد نیمه‌تمام در save باعث `snap_parked`
   بعد از ساخت می‌شود (همان قاعده‌ی مسیر inline).
3. **breadcrumb برای اولین drawهای واقعی کامیون**: `truck:arrive` و
   `truck:roll`.
4. **گزارش کرش درست شد**: خط renderer حالا
   `RenderingServer.get_current_rendering_method()` است + `renderer_project`
   برای مقایسه + نسخه‌ی apk در خط build (`V33 demo v2.3.0 build 6`).
5. **شیدر آسمان روی GLES3 تعمیر شد**: اندیس‌گذاری داینامیک
   `moon_textures[moon_hit.id]` در `sky_atmosphere.gdshader` کل شیدر آسمان
   را روی OpenGL می‌کشت (GLSL ES 3 اندیس غیرثابت در آرایه‌ی sampler را
   ممنوع می‌کند) → سه شاخه با اندیس ثابت. بدون این فیکس، آسمان روی موبایل
   ساده/خراب بود.

### راستی‌آزمایی

- import headless: OK
- `mobile_sim_check.gd` (شامل کامپایل delivery_truck/delivery_director/
  crash_report/cfg): PASS (mobile)
- لود استیج‌شده‌ی کامل headless `--stagedload --mobilesim`: exit 0،
  `[stand] belt built staged: ...` و `[world] truck built staged: model=true
  hull=true bed=true parked=false`
- **لود کامل زیر renderer واقعی OpenGL (llvmpipe, GL 4.5 Compatibility)**:
  صفر خطای کامپایل شیدر (خطای یک‌باره‌ی `shader type fog` = FogVolume حصار
  است که در compat پشتیبانی نمی‌شود و عمداً نادیده گرفته می‌شود)، کمربند و
  کامیون کامل، خروجی تمیز.

**معیار پذیرش (دست‌نخورده):** لود کامل ۰→۱۰۰٪ روی Mali-G615 بدون کرش. اگر
کرشی برگردد، گزارش کرش این بار renderer واقعی (`gl_compatibility`)، نسخه‌ی
apk و زیرگام قاتل (مثلاً `truck:skin`) را با هم نام می‌برد.

---

## v2.4.0 — گزارش جدید: صفحه سیاه و کرش در ~۱ ثانیه + لاگی که هیچ‌وقت زنده نمی‌ماند 📋

گزارش کاربر از v2.3.0 (بیلد OpenGL): «صفحه سیاه می‌شود و بعد از ۱ ثانیه از
بازی پرت می‌شویم بیرون». یعنی کرش حالا خیلی زودتر از پنجره ۷۱–۷۴٪ رخ می‌دهد —
احتمالاً همان ثانیه‌های اول بوت (اسپلش/منو)، جایی که تا امروز هیچ
breadcrumb‌ای نمی‌نوشتیم.

**چرا هنوز کور هستیم؟** دو علت که هر دو در v2.4.0 رفع شدند:

1. **فایل‌لاگ موتور هرگز روشن نبود.** در project.godot کلید ساختگی
   `debug/file_logging/max_log_files=20` بود — گودوت چنین کلیدی ندارد؛ کلید
   درست `debug/settings/file_logging/enable_file_logging` است که هیچ‌وقت set
   نشده بود. نتیجه: `user://logs/godot.log` هرگز ساخته نمی‌شد و
   `crash_report` چیزی برای نقل قول نداشت («No log survived this crash»).
2. **هر چه نوشته می‌شد در حافظه خصوصی اپ بود** — از فایل‌منیجر گوشی دیده
   نمی‌شود و کاربر نمی‌توانست آن را بردارد و بفرستد.

### فیکس v2.4.0 — سیستم لاگ ماندگار و قابل‌ارسال

1. **فایل‌لاگ موتور واقعاً روشن شد** — `user://logs/godot.log` با ۱۰ نسخه
   گردشی. حالا SCRIPT ERRORها، خطاهای کامپایل شیدر و خروجی‌های خود بازی
   برای اجرای بعدی باقی می‌مانند.
2. **autoload جدید `GameLog`** (اولین autoload پروژه):
   - لاگ الحاقی با flush بعد از هر خط: `user://gamelog.log` (چرخش در ۳MB).
   - **آینه در حافظه اشتراکی** — اولین مسیر قابل‌نوشتن، هر بار اجرا دوباره
     پروب می‌شود:
     * `/storage/emulated/0/.gamelog/` (خواسته‌ی کاربر؛ با مجوز
       «Allow management of all files» فعال می‌شود)
     * `/storage/emulated/0/Android/media/com.obsifox.findtheneedle/gamelog/`
       (بدون هیچ مجوزی همیشه نوشتنی است و در همه فایل‌منیجرها دیده می‌شود)
     * `/storage/emulated/0/Android/data/com.obsifox.findtheneedle/files/gamelog/`
   - سربرگ بوت: build، GPU، درایور، renderer واقعی، حافظه، مسیر لاگ.
   - چرخه حیات: PAUSE/RESUME/FOCUS/CLOSE و مهر NOTIFICATION_CRASH.
   - فایل README.txt داخل پوشه (فارسی/انگلیسی) که می‌گوید کدام فایل را بفرستد.
3. **breadcrumbها حالا در فایل قابل‌ارسال هم می‌روند** — `note_stage` و
   `note_doing` در crash_report علاوه بر sentinel، خط زمان‌دار در GameLog
   می‌نویسند؛ منو/world هم نقطه شروع خودشان را لاگ می‌کنند.
4. **گزارش کرش به‌صورت فایل** — `recover()` گزارش ساخته‌شده را به
   `crash_report_<زمان>.txt` در پوشه آینه می‌نویسد؛ حتی اگر دیالوگ داخل بازی
   باز نشود، فایل روی دستگاه است.
5. **لاگ موتور اجرای قبلی** در `engine_prev.log` کپی می‌شود — برای کرش‌های
   سخت (بدون دیالوگ) ردپای خطاها همان‌جاست.
6. مجوزهای `MANAGE_EXTERNAL_STORAGE` + `WRITE_EXTERNAL_STORAGE` به manifest
   اضافه شد تا مسیر دلخواه کاربر (`.gamelog` در روت) هم با یک تیک دستی فعال
   شود (بدون تیک، مسیر Android/media کار می‌کند).

**معیار پذیرش لاگ:** بعد از کرش، کاربر بتواند بدون root از فایل‌منیجر
gamelog.txt (+ engine_prev.log / crash_report_*.txt) را بردارد و بفرستد، و
آخرین خط‌های آن دقیقاً بگوید بازی کجا بود.
