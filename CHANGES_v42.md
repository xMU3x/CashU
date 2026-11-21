# CashU v42 — التعديلات عن v40

ملفات اتغيّرت (باقي الملفات مطابق لـ v40):
- lib/ui/ai_assistant.dart            ← صفحة «حسّاب» كاملة (بدل الـ bottom sheet) + بطاقات + chips + تراجع + حفظ المحادثات + 👍/👎
- lib/pages/more_pages.dart           ← «اكتب اللي صرفته» بتحليل AI + الحساب من النص + عنوان صفحة «حسّاب»
- lib/pages/tools.dart                ← «Flow AI» → «حسّاب»
- lib/pages/home.dart                 ← «فلو» → «حسّاب»
- lib/sms/groq_ai.dart  (سطر 40)     ← المهلة 4 → 10 ثواني
- lib/sms/sms_tracker.dart (سطر 921) ← المهلة 3 → 11 ثانية
- supabase/functions/ai-chat/index.ts ← الدالة الجديدة (مبنية على المنشورة)
- supabase/ai_feedback.sql            ← جدول التقييمات + RLS (جديد)
- supabase/ai_chat_cache_extra.sql    ← عمود extra اختياري للكاش (جديد)
