const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const twilio = require("twilio");

admin.initializeApp();

const twilioSid = defineSecret("TWILIO_ACCOUNT_SID");
const twilioToken = defineSecret("TWILIO_AUTH_TOKEN");
const twilioFrom = defineSecret("TWILIO_FROM_NUMBER");
const twilioFallbackTo = defineSecret("TWILIO_FALLBACK_TO");

exports.sendTwilioAlert = onRequest(
  {
    cors: true,
    secrets: [twilioSid, twilioToken, twilioFrom, twilioFallbackTo],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ ok: false, error: "Use POST" });
      return;
    }

    try {
      const body = req.body || {};
      const alert = normalizeAlert(body);
      const recipients = await resolveRecipients(alert);
      const fallback = normalizePhone(twilioFallbackTo.value());
      const finalRecipients = recipients.length > 0 ? recipients : [fallback];
      const uniqueRecipients = [...new Set(finalRecipients.filter(Boolean))];

      if (uniqueRecipients.length === 0) {
        res.status(400).json({
          ok: false,
          error: "No officer, citizen, or fallback phone number found.",
        });
        return;
      }

      const client = twilio(twilioSid.value(), twilioToken.value());
      const message = formatMessage(alert);
      const sent = [];

      for (const to of uniqueRecipients) {
        const sms = await client.messages.create({
          body: message,
          from: twilioFrom.value(),
          to,
        });
        sent.push({ to, sid: sms.sid, status: sms.status });
      }

      res.status(200).json({
        ok: true,
        area: alert.area,
        type: alert.typeName,
        recipients: uniqueRecipients.length,
        sent,
      });
    } catch (error) {
      res.status(500).json({
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  },
);

function normalizeAlert(body) {
  const label = String(body.type || body.typeLabel || "Community report");
  const typeName = String(body.typeName || body.type || "other")
    .trim()
    .replace(/\s+/g, "")
    .replace(/[^A-Za-z0-9_]/g, "");
  return {
    reportId: String(body.reportId || ""),
    typeLabel: label,
    typeName: typeName || "other",
    area: String(body.area || body.district || "Unknown area"),
    message: String(body.message || "Citizen safety report"),
    contactNumber: String(body.contactNumber || "Not provided"),
    latitude: numberOrNull(body.latitude),
    longitude: numberOrNull(body.longitude),
    createdAt: String(body.createdAt || new Date().toISOString()),
  };
}

async function resolveRecipients(alert) {
  const db = admin.firestore();
  const [officerSnapshot, citizenSnapshot] = await Promise.all([
    db.collection("alpha_users").where("role", "==", "officer").get(),
    db
      .collection("alpha_alert_subscriptions")
      .where("enabled", "==", true)
      .get(),
  ]);

  const officerPhones = officerSnapshot.docs
    .map((doc) => doc.data())
    .filter((data) => officerMatches(data, alert))
    .map((data) => normalizePhone(data.phoneNumber || data.phone));

  const citizenPhones = citizenSnapshot.docs
    .map((doc) => doc.data())
    .filter((data) => citizenMatches(data, alert))
    .map((data) => normalizePhone(data.phone));

  return [...officerPhones, ...citizenPhones].filter(Boolean);
}

function officerMatches(data, alert) {
  const area = String(data.officerArea || "All areas").toLowerCase();
  const alertArea = alert.area.toLowerCase();
  const areaOk =
    area === "all areas" ||
    area === "all" ||
    alertArea.includes(area) ||
    area.includes(alertArea);

  const types = Array.isArray(data.officerTypes) ? data.officerTypes : [];
  const typeOk = types.length === 0 || types.includes(alert.typeName);
  return areaOk && typeOk;
}

function citizenMatches(data, alert) {
  const area = String(data.area || "All areas").toLowerCase();
  const alertArea = alert.area.toLowerCase();
  const areaOk =
    area === "all areas" ||
    area === "all" ||
    alertArea.includes(area) ||
    area.includes(alertArea);

  const types = Array.isArray(data.alertTypes) ? data.alertTypes : [];
  const typeOk = types.length === 0 || types.includes(alert.typeName);
  return areaOk && typeOk;
}

function formatMessage(alert) {
  const location =
    alert.latitude !== null && alert.longitude !== null
      ? ` Location: ${alert.latitude.toFixed(5)}, ${alert.longitude.toFixed(5)}.`
      : "";
  return [
    `Alpha Community Alert`,
    `Type: ${alert.typeLabel}`,
    `Area: ${alert.area}`,
    `Message: ${alert.message}`,
    `Citizen contact: ${alert.contactNumber}`,
    location.trim(),
  ]
    .filter(Boolean)
    .join("\n");
}

function numberOrNull(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizePhone(value) {
  const phone = String(value || "").trim();
  if (!phone) return "";
  return phone.startsWith("+") ? phone : `+${phone}`;
}
