# Find The Needle (Haystack Incremental)

بازی اضافه‌شونده (Incremental) ساخته‌شده با **Godot 4.7.2-stable** — چهار نسخه جدا از یک سورس: **Android / PC Full / PC Light / Web**.

ریپو **خصوصی** است و پیشرفت پروژه release به release اینجا منتشر می‌شود.

## 📦 Releases

| Release | محتوا | وضعیت |
|---|---|---|
| **v1.0.0** | فقط سورس (pak-solona.zip کامل + کد در ریپو) | ✅ |
| **v3.0.1** | APK موبایل (V37) + سورس | ✅ |
| **v3.1.0** | APK + PC Full + PC Light + Web + سورس (V38 — فیکس ریشه‌ای دارایی‌ها) | 🔄 در حال انتشار |

## 💻 نسخه‌ها و حداقل سیستم

| نسخه | رندرر | حداقل سیستم |
|---|---|---|
| **Android** (`FindTheNeedle-v3.1.0-universal.apk`) | Vulkan Mobile | گوشی با Vulkan 1.1+ (arm64/armv7) |
| **PC Full** (`win64-full`) | Forward+ (Vulkan) + سقوط خودکار به OpenGL | طبق جدول قدیمی: i5-8400 / 8GB / GTX 1050 Ti (Vulkan 1.3)؛ اگر Vulkan نباشد خودکار به Light می‌افتد |
| **PC Light** (`win64-light`) | OpenGL 3.3 | **i5 نسل ۳ / 4GB RAM / گرافیک اینتل (HD 2500/4000)** — هر GPU با OpenGL 3.3 |
| **Web Light** (`web-light`) | WebGL2 | هر مرورگر دسکتاپ با WebGL2 (بدون نصب) |

- نسخه **Light** تکسچرها را تا ۱۰۲۴px محدود و کیفیت پیش‌فرض LOW می‌کند (حجم نصف) — برای سیستم‌های ضعیف همین را اجرا کنید.
- نسخه **Web**: پوشه را با `python -m http.server` (یا هر هاست استاتیک) اجرا کنید و `index.html` را باز کنید.
- در بازی: **Options → Display → Quality preset** (POTATO تا ULTRA) + انتخاب Renderer.

## 🎮 مشخصات بازی

- نام اصلی: **Haystack Incremental** (v0.1.0) — خروجی: FIND THE NEEDLE
- موتور: Godot 4.7.2 (Forward+ / Mobile / Compatibility — بسته به نسخه)
- بیلد دمو: V38 (v3.1.0 build 11)
- زبان: GDScript (بعد از رمزگشایی ۶۰۹ فایل .gdc)

## 🐛 باگ‌های شناخته‌شده (هدف رفع در v2.0.0)

1. **کرش/قفل در OPENING THE STAND (74%)** — Terrain3D روی برخی گوشی‌ها (Mali-G615/Vulkan) در لود خراب می‌شود؛ نیاز به جایگزینی با terrain سازگار با همه دستگاه‌ها
2. **نبود دکمه‌های لمسی** — کنترل لمسی فقط در بازی داخلی پیاده شده؛ layout واکنش‌گرا برای همه گوشی‌ها لازم است (برش خوردن دکمه‌ها)
3. **تنظیمات بی‌استفاده** — گزینه‌های Resolution / Fullscreen / V-Sync / Renderer / کلیدبایدها باید از منوی موبایل حذف شوند
4. **لودینگ قدیمی** — در نسخه قدیمی بعد از پایان لود، اپ بسته می‌شد؛ لودینگ بازنویسی می‌شود

جزئیات کامل: `docs/BUGS.md`

## 🗂 ساختار

```
project.godot          ← پروژه Godot
addons/                ← پلاگین‌ها (Terrain3D و …)
autoload/  scripts/    ← کد بازی
demo/                  ← داده دمو
locale/                ← ترجمه‌ها (.po)
docs/                  ← مستندات باگ‌ها و ریلیزها
```

## 📱 Mobile build status (v2.0.0 work)

| باگ | وضعیت |
|---|---|
| کرش/قفل لود روی موبایل (Terrain3D / Mali-G615) | ✅ رفع شد — زمین native جایگزین شد (`yard_terrain.gd`) |
| لودینگ بلوکه‌شده | ✅ لود مرحله‌ای اجباری روی موبایل (`world.gd`) |
| بسته شدن اپ بعد از لود | ✅ `loading.gd` دیگر هرگز روی موبایل quit نمی‌کند |
| کنترل لمسی | ✅ لایه `scripts/ui/touch_controls.gd` — بازطراحی V39: ۹ دکمه دایره‌ای دیزاین‌شده (menu/run/jump/dig/build/use/e/q/tech) |
| برش دکمه‌ها در صفحه گوشی | ✅ layout نرمال‌شده (0..1) + safe-area (نچ/ناوبار) + re-layout هنگام چرخش/تغییر سایز — از 16:9 تا 21:9 |
| دکمه‌های مرده (E/MENU/TECH/BUILD/Q/هات‌بار روی لمس) | ✅ فیکس شد — tap ها الان `InputEventAction` واقعی می‌فرستند (`Input.parse_input_event`) |
| ویرایش HUD | ✅ نگه‌داشتن طولانی MENU (۰.۷ ثانیه) → حالت ویرایش: درگ = جابجایی، تپ = سایز S/M/L، RESET/DONE — ذخیره در `user://hud_layout.cfg` |
| تنظیمات بی‌استفاده (Resolution/Fullscreen/V-Sync/Renderer/کیبورد) | ✅ مخفی در موبایل (`options_panel.gd`) |
