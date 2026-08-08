# Firebase Function: sendTwilioAlert

This function sends dynamic SMS alerts.

Recipients are selected from Firestore:

- Officers: `alpha_users`
  - `role == "officer"`
  - `phoneNumber`
  - `officerArea`
  - `officerTypes`
- Citizens: `alpha_alert_subscriptions`
  - `enabled == true`
  - `phone`
  - `area`
  - `alertTypes`

Fallback is used only when no matching officer/citizen exists.

## Set Twilio secrets

Do not commit Twilio credentials into source code.

```powershell
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_FROM_NUMBER
firebase functions:secrets:set TWILIO_FALLBACK_TO
```

Use:

- `TWILIO_ACCOUNT_SID`: your Twilio Account SID
- `TWILIO_AUTH_TOKEN`: your Twilio Auth Token
- `TWILIO_FROM_NUMBER`: your Twilio phone number
- `TWILIO_FALLBACK_TO`: admin/emergency fallback phone number

## Deploy

```powershell
firebase deploy --only functions:sendTwilioAlert
```

Firebase prints a URL like:

```text
https://us-central1-alpha-community-95a5c.cloudfunctions.net/sendTwilioAlert
```

Use that URL in Flutter:

```powershell
flutter build apk --debug `
  --dart-define=TWILIO_ALERT_ENDPOINT=https://us-central1-alpha-community-95a5c.cloudfunctions.net/sendTwilioAlert
```

## Trial account note

Twilio trial accounts can usually send SMS only to verified recipient numbers.
For real citizen alerts, upgrade Twilio or verify the test citizen/officer
numbers in Twilio.
