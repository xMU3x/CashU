-- ترحيل werd_sync -> cash_sync داخل "نفس" قاعدة البيانات (آمن ويمكن إعادة تشغيله).
-- ملاحظة: إن كانت بياناتك القديمة في مشروع Supabase آخر فهذا الملف لا يكفي — راجع README (قسم الترحيل بين المشاريع).

-- 1) أنشئ الجدول الجديد (شغّل supabase/schema.sql أولًا)

-- 2) انسخ الصفوف دون فقد: عند التعارض يفوز الأحدث (ts)
do $$
begin
  if to_regclass('public.werd_sync') is not null then
    insert into public.cash_sync (user_id, key, value, ts, updated_at)
    select user_id, key, value, ts, updated_at from public.werd_sync
    on conflict (user_id, key) do update
      set value = excluded.value, ts = excluded.ts, updated_at = excluded.updated_at
      where excluded.ts > public.cash_sync.ts;
  end if;
end $$;

-- 3) تحقق قبل أي حذف (يجب أن يكون missing = 0)
-- select (select count(*) from public.werd_sync) as old_rows,
--        (select count(*) from public.cash_sync) as new_rows,
--        (select count(*) from public.werd_sync o left join public.cash_sync n using (user_id, key) where n.user_id is null) as missing;

-- 4) بعد التأكد أن التطبيق يستخدم cash_sync فقط: أرشِف القديم (لا تحذفه)
-- alter table public.werd_sync rename to werd_sync_archive;

-- ===== الرجوع (Rollback) =====
-- alter table public.werd_sync_archive rename to werd_sync;            -- إن أرشفته
-- لا تحذف صفوف cash_sync للتراجع: قد تحتوي تعديلات أحدث من التطبيق. الجدول القديم لم يُمَس، فيكفي إرجاع التطبيق/الإعدادات إليه.
