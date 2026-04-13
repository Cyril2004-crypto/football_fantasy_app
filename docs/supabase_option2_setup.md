# Supabase Option 2 Setup (Keep Firebase Auth)

This setup keeps Firebase Authentication in the app and writes to Supabase through a trusted Edge Function that uses the service role key.

## 1) Run SQL in Supabase

Run `supabase/sql/users_option2_setup.sql` in the Supabase SQL Editor.
Then run `supabase/sql/real_life_data_schema.sql` in the Supabase SQL Editor.

## 2) Deploy the Edge Function

Function source: `supabase/functions/sync-firebase-user/index.ts`

Deploy commands:

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase functions deploy sync-firebase-user --no-verify-jwt
```

Set required secrets for the function:

```bash
supabase secrets set FIREBASE_PROJECT_ID=<your-firebase-project-id>
supabase secrets set SERVICE_ROLE_KEY=<your-service-role-key>
```

`SUPABASE_URL` is normally available in Supabase Functions runtime. If needed, set it explicitly as a secret too.

## 3) Add Flutter runtime define

Add this key to your local defines file:

```json
{
  "SUPABASE_SYNC_FUNCTION_URL": "https://<project-ref>.functions.supabase.co/sync-firebase-user"
}
```

Then run with defines:

```bash
flutter run -d chrome --dart-define-from-file=dart_defines.local.json
```

## 4) Verify

1. Sign in/sign up in the app.
2. Check function logs in Supabase dashboard.
3. Confirm a row appears in `public.users` with `firebase_uid`.

## Notes

- The app now treats Supabase sync as best-effort and will not block Firebase login.
- Never expose `SUPABASE_SERVICE_ROLE_KEY` to the Flutter client.
