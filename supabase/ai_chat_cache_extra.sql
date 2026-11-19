-- اختياري: عمود extra في كاش الدردشة عشان الردود المخزّنة ترجّع البطاقة (panel) والاقتراحات (suggestions) كمان.
-- من غيره الدالة بتشتغل عادي (الكاش يرجّع reply بس). آمن لو اتشغّل أكتر من مرة.
alter table public.ai_chat_cache add column if not exists extra jsonb;
