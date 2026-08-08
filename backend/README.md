# Alpha Community backend

The Flutter APK must not contain provider or Twilio secrets. Run this backend on
a server and configure secrets as environment variables.

## Endpoints

```text
GET  /health
POST /assistant
POST /send-alert
```

## GenAI assistant

```text
GEN_AI_UPSTREAM_URL=<provider chat-completions compatible URL>
GEN_AI_API_KEY=<secret key>
GEN_AI_MODEL=<model name>
PORT=8080
```

Then run `node server.mjs` and launch Flutter with:

```powershell
flutter run --dart-define=GEN_AI_ENDPOINT=https://your-server.example/assistant
```

## Twilio SMS alerts

The production Firebase Function does not use one fixed officer number. It
dynamically sends alerts to:

1. Officers in `alpha_users` whose `officerArea` and `officerTypes` match the
   report
2. Citizens in `alpha_alert_subscriptions` whose `area` and `alertTypes` match
   the report
3. `TWILIO_FALLBACK_TO` only when no matching officer/citizen exists

For local `backend/server.mjs`, set:

```text
TWILIO_ACCOUNT_SID=<Twilio Account SID>
TWILIO_AUTH_TOKEN=<Twilio Auth Token>
TWILIO_FROM_NUMBER=<Twilio phone number, e.g. +1234567890>
TWILIO_TO_NUMBERS=<local test recipient numbers, e.g. +94771234567>
PORT=8080
```

Run locally:

```powershell
$env:TWILIO_ACCOUNT_SID="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$env:TWILIO_AUTH_TOKEN="your_auth_token"
$env:TWILIO_FROM_NUMBER="+1234567890"
$env:TWILIO_TO_NUMBERS="+94771234567"
node server.mjs
```

Test health:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:8080/health
```

When the backend is deployed, build Flutter with:

```powershell
flutter build apk --debug `
  --dart-define=TWILIO_ALERT_ENDPOINT=https://your-server.example/send-alert
```

For phone testing against a local PC server, use your PC LAN IP, not localhost:

```powershell
flutter build apk --debug `
  --dart-define=TWILIO_ALERT_ENDPOINT=http://192.168.1.5:8080/send-alert
```

For Firebase Functions deployment, set secrets instead:

```powershell
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_FROM_NUMBER
firebase functions:secrets:set TWILIO_FALLBACK_TO
firebase deploy --only functions:sendTwilioAlert
```

Before production, add authentication, rate limiting, moderation, request size
limits, logging controls, and provider-specific response validation.
