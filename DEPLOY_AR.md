# 🏥 Surgery Department Cases - Cloudflare Pages + Supabase Setup
### (now with real doctor login via Supabase Auth)

## 1) Create the Supabase database
1. Go to https://supabase.com and sign in / sign up.
2. Create a new project.
3. Open **SQL Editor** from the left menu.
4. Paste the content of `supabase-schema.sql` (included in this folder) and click **Run** (once only).
   - This creates the `cases`, `app_config`, and `profiles` tables, and turns on Row Level Security.
5. From **Project Settings -> API** you'll find:
   - **Project URL** (this is `SUPABASE_URL`)
   - **anon / public key** (this is `SUPABASE_ANON_KEY` — safe to expose in the browser)
   - **service_role key** or **secret key** (this is `SUPABASE_SERVICE_ROLE_KEY`) — keep this private, never share it or put it in client-side code.
6. From **Authentication -> Providers**, make sure **Email** sign-in is enabled (it is by default).
7. From **Authentication -> Settings**, it's a good idea to turn **OFF** "Enable email confirmations" — doctor accounts created from the app are already marked as confirmed, so this just avoids surprises.

## 2) Put your Supabase URL + anon key into the app
Open `index.html`, find this near the top of the `<script>` section:
```js
const SUPABASE_URL = 'https://YOUR-PROJECT-REF.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR-ANON-PUBLIC-KEY';
```
Replace both with the values from step 1.5. The anon key is meant to be public (it's how every Supabase web app talks to Auth) — the real protection is the `service_role` key, which only ever lives on the server (Cloudflare Functions), never in this file.

## 3) Deploy to Cloudflare Pages
1. Create an account at https://dash.cloudflare.com if you don't have one.
2. From the sidebar: **Workers & Pages -> Create -> Pages**.
3. Choose **"Upload assets"** (direct upload) or connect a GitHub repo containing all these files.
4. If uploading manually, drag in every file and folder in this project (including the `functions` folder).

## 4) Add environment variables
Inside your Cloudflare Pages project:
1. Go to **Settings -> Environment variables**.
2. Add these for both Production and Preview:
   - `SUPABASE_URL` = your Supabase project URL
   - `SUPABASE_ANON_KEY` = the anon/public key from Supabase
   - `SUPABASE_SERVICE_ROLE_KEY` = the service_role / secret key from Supabase (keep this one secret — it's only used server-side)
3. Save, then **Redeploy** the project so the variables take effect.

## 5) Create the first doctor account (yourself, as admin)
1. Open the deployed site — you'll land on the login screen.
2. There's no account yet, so use this one-time bootstrap: open your browser's dev tools (F12) → Console, and run:
   ```js
   fetch('/api/doctors/create', {
     method: 'POST',
     headers: {'Content-Type':'application/json'},
     body: JSON.stringify({
       email: 'you@example.com',
       password: 'choose-a-strong-password',
       displayName: 'Dr. Your Name'
     })
   }).then(r=>r.json()).then(console.log);
   ```
   The very first account created this way is automatically made an **admin**. After that, this shortcut is closed — every account after the first must be created from **Settings → Doctors** by an existing admin.
3. Sign in on the login screen with that email/password.

## 6) Add the rest of the doctors
- Open **Settings** (password-protected, default `1234` — change it from Settings → Security) — as an admin you'll now see a **Doctors** section.
- Fill in name, role (Doctor/Admin), email, and a password (6+ characters), then **Create doctor account**.
- Each doctor signs in with their own email/password from the login screen — no shared login needed.

## 7) How the "who registered/edited it" tracking works
- Every time a case is saved, the app stamps who created it and who last edited it (name + date), pulled straight from the signed-in account.
- This shows in a **"Registered / Edited by"** column in the case table, and at the top of the case's edit screen.
- It's also included when exporting to Excel.

## 8) Disabling a doctor who has left
- In **Settings → Doctors**, click **🚫 Disable** next to their name.
- This blocks their login immediately (Supabase Auth rejects new sign-ins for that account) — it does **not** delete the account or touch any case they registered or edited. Their name stays attached to their past cases exactly as before.
- Click **✅ Enable** any time to restore their access.
- Admins can't disable their own account (to avoid accidentally locking everyone out).

## 9) Test the site
- Sign in, add a new case, and confirm it saves (refresh and check it's still there, and that your name shows under "Registered by").
- Edit an existing case as a different doctor and confirm "Edited by" updates while "Registered by" stays the original doctor.
- Set a "Day out" date on a case — it should disappear from the Active Cases view and appear under the Archive tab.
- Disable a test doctor account and confirm they can no longer sign in, while their existing cases are untouched.

## Data fields per case
Pt. Name, Senior, Consultant, Department, Age, Diagnosis, Day/Admission, Vitality, Feeding, Drain, Investigation, Labs, Rads, Day out, Notes, and now Registered/Edited by.

## How the lists work
- **Seniors**, **Consultants**, and **Departments** are fully customizable from the in-app Settings screen — no code changes needed, and there's no limit on how many you add.
- These lists are stored in the `app_config` table in Supabase and shared by everyone using the app.
- Cases are grouped and color-coded by department on the main screen, and each consultant gets a consistent color badge.

## Password protection vs. login
- There are now **two layers**:
  1. **Real login** (Supabase Auth) — required just to open the app at all. Each doctor has their own email/password.
  2. **The shared Settings password** (unchanged from before, default `1234`) — an extra gate specifically for opening Settings and deleting cases, on top of being logged in.
- You can keep both, or if you'd rather rely only on per-doctor login, just tell me and I can remove the extra Settings password layer.

## Font
- The whole site now uses the **Tajawal** font (works well for both Arabic and Latin text), loaded from Google Fonts.

## Security notes
- The `cases`, `app_config`, and `profiles` tables have Row Level Security enabled with no public policies. The only access path is through the Cloudflare Functions using the `service_role` key on the server — never directly from the browser.
- Every `/api/cases/*`, `/api/config/*`, and `/api/doctors/*` request is checked against a real, signed-in, non-disabled Supabase Auth session before it touches any data.
- The `service_role` key must only ever be set as a Cloudflare Pages environment variable — never paste it into `index.html` or any file that ships to the browser.
