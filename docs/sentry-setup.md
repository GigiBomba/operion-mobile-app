# Sentry (Crash Reporting) — What It Is + Setup When You're Ready

> You asked what Sentry is. Short answer: a **crash-reporting dashboard** — a website that
> collects the technical details ("stack trace") whenever the app crashes on someone's phone,
> so you can see what broke and fix it, instead of only hearing "it crashed".
> The code is already wired (mobile + backend) but **does nothing until you provide a key**
> (a "DSN") — it's a deliberate no-op so nothing breaks today.

## Do you need it?
- For the family-fleet beta, it's the difference between "the app crashed on Ion's phone"
  and "the app crashed with this exact error, on this phone model, at this time, and here are
  the last 30 actions".
- The blueprint's release gate includes a "≥99.5% crash-free sessions" metric — that number
  can only be measured with crash reporting enabled.

## How to enable it (when you're ready — ~10 minutes, free tier)
1. Create a free account at **sentry.io** (or self-host Sentry on your own server — heavier;
   docs exist; the code supports any DSN URL).
2. Create a project (e.g. "operion-mobile" for the app, "operion-backend" for the server).
3. Copy each project's **DSN** (a URL like `https://xxx@yyy.ingest.sentry.io/1234`).
4. Mobile: pass it at build time — `flutter build ... --dart-define=SENTRY_DSN=<dsn>`.
5. Backend: set the env var `OPERION_SENTRY_DSN=<dsn>` and restart.
6. That's it — crashes start appearing in the dashboard. No code changes needed.

## What happens until then
- **Nothing.** Both integrations check for the DSN and skip initialization when absent
  (verified: app runs normally, tests unaffected, zero network calls).
- If you'd rather remove Sentry entirely, say so — it's a small bounded removal.

## Also see
- `docs/firebase-setup.md` — push notifications (the other Google-account-dependent service).
- `docs/implementation-status-and-production-readiness.md` — full readiness checklist.
