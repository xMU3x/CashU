# CashU — خطوات الرفع (مرة واحدة)

1. ارفع محتوى هذا المجلد على المستودع (commit عادي، بدون force).
2. افتح `.github/workflows/GITHUB_WORKFLOW.yml` في GitHub. لو محتواه لسه فيه `Flousy` أو `flutter`
   (يعني مجلد `.github` المخفي ما اترفعش):
   - اضغط القلم → حدّد كل المحتوى واحذفه → افتح `PASTE_INTO_GITHUB_WORKFLOW.yml` من جذر المستودع،
     انسخ محتواه والصقه → Commit.
3. Settings → Secrets and variables → Actions → أضف `SUPABASE_ANON_KEY` (+ اختياري KEYSTORE_*).
4. Actions → «Build CashU (Kotlin Native)» → Run workflow. الـAPK والـAAB في Artifacts باسم CashU.

ملاحظة: الـworkflow القديم (Flutter) اتشال واستُبدل بهذا. كود Flutter نفسه (lib/ …) باقي كمرجع للنقل.
