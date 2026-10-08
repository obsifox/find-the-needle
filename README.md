# Find The Needle (Haystack Incremental)

بازی اضافه‌شونده (Incremental) ساخته‌شده با **Godot 4.7.2-stable / Forward Plus** — نسخه موبایل Android.

ریپو **خصوصی** است و پیشرفت پروژه release به release اینجا منتشر می‌شود.

## 📦 Releases

| Release | محتوا | وضعیت |
|---|---|---|
| **v1.0.0** | فقط سورس (pak-solona.zip کامل + کد در ریپو) | 🔄 در حال انتشار |
| **v2.0.0** | سورس جدید (باگ‌فیکس) جدا + APK جدا | ⏳ بعدی |

هر release از این به بعد شامل: سورس به‌روز + (در صورت آماده بودن) APK ساخته‌شده از همان سورس.

## 🎮 مشخصات بازی

- نام اصلی: **Haystack Incremental** (v0.1.0) — خروجی: FIND THE NEEDLE
- موتور: Godot 4.7.2 Forward Plus
- بیلد دمو: V33
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
| کنترل لمسی | ✅ لایه `scripts/ui/touch_controls.gd` (استیک + دکمه‌ها) |
| برش دکمه‌ها در صفحه گوشی | ✅ stretch mode `canvas_items` + sensor landscape |
| تنظیمات بی‌استفاده (Resolution/Fullscreen/V-Sync/Renderer/کیبورد) | ✅ مخفی در موبایل (`options_panel.gd`) |
