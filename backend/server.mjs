import http from 'node:http';

const port = Number(process.env.PORT ?? 8080);
const upstream = process.env.GEN_AI_UPSTREAM_URL;
const apiKey = process.env.GEN_AI_API_KEY;
const model = process.env.GEN_AI_MODEL;
const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
const twilioFromNumber = process.env.TWILIO_FROM_NUMBER;
const twilioToNumbers = (process.env.TWILIO_TO_NUMBERS ?? '')
  .split(',')
  .map((number) => number.trim())
  .filter(Boolean);

async function readJson(request) {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  if (chunks.length === 0) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { 'Content-Type': 'application/json' });
  response.end(JSON.stringify(payload));
}

function twilioReady() {
  return Boolean(
    twilioAccountSid &&
      twilioAuthToken &&
      twilioFromNumber &&
      twilioToNumbers.length,
  );
}

function alertMessage(payload) {
  const type = String(payload.type ?? 'Community alert');
  const area = String(payload.area ?? 'Unknown area');
  const message = String(payload.message ?? 'Citizen safety report');
  const contact = String(payload.contactNumber ?? 'Not provided');
  const lat = payload.latitude;
  const lng = payload.longitude;
  const locationText =
    typeof lat === 'number' && typeof lng === 'number'
      ? ` Location: ${lat.toFixed(5)}, ${lng.toFixed(5)}.`
      : '';
  return `Alpha Community ${type} in ${area}: ${message}. Citizen contact: ${contact}.${locationText}`;
}

async function sendTwilioSms(to, body) {
  const endpoint = `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`;
  const params = new URLSearchParams({
    From: twilioFromNumber,
    To: to,
    Body: body,
  });
  const credentials = Buffer.from(
    `${twilioAccountSid}:${twilioAuthToken}`,
  ).toString('base64');
  const result = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params,
  });
  const text = await result.text();
  if (!result.ok) {
    throw new Error(`Twilio ${result.status}: ${text}`);
  }
  return JSON.parse(text);
}

const server = http.createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/health') {
    sendJson(response, 200, {
      ok: true,
      assistantConfigured: Boolean(upstream && apiKey && model),
      twilioConfigured: twilioReady(),
    });
    return;
  }

  if (request.method === 'POST' && request.url === '/assistant') {
    if (!upstream || !apiKey || !model) {
      sendJson(response, 503, {
        answer: 'Online assistant backend is not configured.',
      });
      return;
    }

    const { message } = await readJson(request);
    const upstreamResponse = await fetch(upstream, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [
          {
            role: 'system',
            content:
              'You are the Alfa Citizen safety assistant. Give concise general safety guidance, state uncertainty, never invent live alerts, and direct emergencies to local authorities.',
          },
          { role: 'user', content: String(message ?? '') },
        ],
      }),
    });

    const result = await upstreamResponse.json();
    const answer = result?.choices?.[0]?.message?.content;
    sendJson(response, answer ? 200 : 502, {
      answer: answer ?? 'Assistant provider error.',
    });
    return;
  }

  if (request.method === 'POST' && request.url === '/send-alert') {
    if (!twilioReady()) {
      sendJson(response, 503, {
        ok: false,
        error:
          'Twilio backend is not configured. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER, and TWILIO_TO_NUMBERS.',
      });
      return;
    }

    try {
      const payload = await readJson(request);
      const body = alertMessage(payload);
      const results = [];
      for (const to of twilioToNumbers) {
        const sms = await sendTwilioSms(to, body);
        results.push({ to, sid: sms.sid, status: sms.status });
      }
      sendJson(response, 200, { ok: true, sent: results });
    } catch (error) {
      sendJson(response, 502, {
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
    return;
  }

  response.writeHead(404).end();
});

server.listen(port, () => {
  console.log(`Alpha Community backend listening on ${port}`);
});
