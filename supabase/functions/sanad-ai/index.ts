const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (status: number, data: unknown) =>
  new Response(JSON.stringify(data), { status, headers });

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (request.method !== 'POST') return reply(405, { error: 'method_not_allowed' });
  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return reply(401, { error: 'unauthorized' });
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_ANON_KEY');
  const serverKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const groqKey = Deno.env.get('GROQ_API_KEY');
  if (!url || !key || !serverKey) return reply(503, { error: 'service_not_configured' });
  let requestId: string | null = null;
  let userId: string | null = null;
  let finalized = false;
  let streamOwnsReservation = false;
  const quota = async (action: string, success = false) => {
    const response = await fetch(`${url}/rest/v1/rpc/sanad_ai_quota`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: serverKey, Authorization: `Bearer ${serverKey}` },
      body: JSON.stringify({ p_user_id: userId, p_action: action, p_request_id: requestId, p_success: success }),
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) throw new Error('quota_unavailable');
    return await response.json();
  };
  try {
    // Validate the session with Auth; never trust a user ID supplied by the app.
    const auth = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: authorization, apikey: key },
      signal: AbortSignal.timeout(10000),
    });
    if (!auth.ok) return reply(auth.status >= 500 ? 503 : 401, { error: 'authentication_failed' });
    const user = await auth.json();
    if (!user.id || user.is_anonymous === true) return reply(401, { error: 'unauthorized' });
    userId = user.id;
    const profile = await fetch(`${url}/rest/v1/profiles?select=is_blocked&id=eq.${encodeURIComponent(user.id)}`, {
      headers: { Authorization: authorization, apikey: key },
      signal: AbortSignal.timeout(10000),
    });
    if (!profile.ok) return reply(503, { error: 'account_check_failed' });
    const profiles = await profile.json();
    if (profiles.some((item: { is_blocked?: boolean }) => item.is_blocked === true)) return reply(403, { error: 'account_blocked' });

    // Bound the request body before parsing it, including chunked requests.
    const reader = request.body?.getReader();
    if (!reader) return reply(400, { error: 'invalid_request' });
    const decoder = new TextDecoder();
    let body = '', bytes = 0;
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      bytes += chunk.value.byteLength;
      if (bytes > 65536) {
        await reader.cancel();
        return reply(413, { error: 'request_too_large' });
      }
      body += decoder.decode(chunk.value, { stream: true });
    }
    body += decoder.decode();
    let payload;
    try { payload = JSON.parse(body); }
    catch { return reply(400, { error: 'invalid_request' }); }
    if (payload?.action === 'usage') return reply(200, { usage: await quota('usage') });
    if (!groqKey) return reply(503, { error: 'service_not_configured' });
    const messages = payload?.messages;
    if (!Array.isArray(messages) || !messages.length || messages.length > 11) return reply(400, { error: 'invalid_messages' });
    let length = 0;
    let imageCount = 0;
    for (const message of messages) {
      if (!message || !['user', 'assistant'].includes(message.role) || typeof message.content !== 'string' || !message.content.trim() || message.content.length > 8000) return reply(400, { error: 'invalid_messages' });
      if (message.image_path !== undefined) {
        const expectedPath = new RegExp(`^${userId}/[0-9]+\\.(jpg|png|webp)$`);
        if (message.role !== 'user' || typeof message.image_path !== 'string' || !expectedPath.test(message.image_path)) return reply(400, { error: 'invalid_image' });
        imageCount++;
      }
      length += message.content.length;
    }
    if (length > 32000 || messages.at(-1).role !== 'user' || imageCount > 3) return reply(400, { error: 'invalid_messages' });
    const modelMessages = await Promise.all(messages.map(async (message: { role: string; content: string; image_path?: string }) => {
      if (!message.image_path) return { role: message.role, content: message.content };
      const encodedPath = message.image_path.split('/').map(encodeURIComponent).join('/');
      const signed = await fetch(`${url}/storage/v1/object/sign/sanad-ai-chat-images/${encodedPath}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: serverKey, Authorization: `Bearer ${serverKey}` },
        body: JSON.stringify({ expiresIn: 300 }),
        signal: AbortSignal.timeout(10000),
      });
      if (!signed.ok) throw new Error('image_unavailable');
      const signedData = await signed.json();
      if (typeof signedData.signedURL !== 'string') throw new Error('image_unavailable');
      const imageUrl = signedData.signedURL.startsWith('http')
        ? signedData.signedURL
        : `${url}/storage/v1${signedData.signedURL}`;
      return {
        role: message.role,
        content: [
          { type: 'text', text: message.content },
          { type: 'image_url', image_url: { url: imageUrl } },
        ],
      };
    }));
    const reserved = await quota('reserve');
    if (!reserved.accepted) return reply(429, { error: reserved.used >= 50 ? 'daily_limit' : 'requests_busy', usage: reserved });
    requestId = reserved.request_id;
    const systemPrompt = [
      'أنت مساعد ذكي لتطبيق سند التعليمي، تساعد الطلاب بأسلوب ودود وباللغة العربية.',
      'يُمنع منعاً باتاً استخدام الجداول أو تنسيق Markdown للجداول في أي إجابة، مهما كان السؤال.',
      'عند عرض مقارنة أو بيانات متعددة، استخدم عناوين قصيرة وقوائم نقطية أو مرقمة بدلاً من الجدول.',
      'عند حل معادلة، اعرض خطوات الحل بالتسلسل من اليسار إلى اليمين، واجعل كل معادلة في سطر مستقل بصيغة رياضية معزولة بين $$...$$. اشرح الخطوات بالعربية في أسطر منفصلة، ولا تخلط النص العربي داخل المعادلة.',
    ].join(' ');
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${groqKey}` },
      body: JSON.stringify({
        model: imageCount > 0 ? 'qwen/qwen3.8-27b' : 'openai/gpt-oss-120b',
        messages: [{ role: 'system', content: systemPrompt }, ...modelMessages],
        temperature: 0.7,
        max_tokens: 1024,
        stream: true,
      }),
      signal: AbortSignal.timeout(60000),
    });
    if (!response.ok) return reply(response.status === 429 ? 429 : 502, { error: 'provider_unavailable' });
    if (!response.body) return reply(502, { error: 'empty_response' });

    // Keep the reservation alive while tokens stream, then charge only after
    // the provider completes successfully and the database confirms it.
    streamOwnsReservation = true;
    const encoder = new TextEncoder();
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        void (async () => {
          let completedSuccessfully = false;
          let generatedText = '';
          let pending = '';
          const emit = (event: unknown) => controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
          try {
            const reader = response.body!.getReader();
            const decoder = new TextDecoder();
            let providerDone = false;
            while (!providerDone) {
              const chunk = await reader.read();
              if (chunk.done) break;
              pending += decoder.decode(chunk.value, { stream: true });
              const lines = pending.split(/\r?\n/);
              pending = lines.pop() ?? '';
              for (const line of lines) {
                if (!line.startsWith('data:')) continue;
                const data = line.slice(5).trim();
                if (data === '[DONE]') { providerDone = true; break; }
                try {
                  const event = JSON.parse(data);
                  const delta = event.choices?.[0]?.delta?.content;
                  if (typeof delta === 'string' && delta.length) {
                    generatedText += delta;
                    emit({ delta });
                  }
                } catch { /* Ignore malformed or non-content provider events. */ }
              }
            }
            if (!generatedText.trim()) {
              emit({ error: 'empty_response' });
            } else {
              const usage = await quota('finish', true);
              if (usage.accepted) {
                completedSuccessfully = true;
                finalized = true;
                emit({ usage });
              } else {
                emit({ error: 'reservation_expired' });
              }
            }
          } catch {
            emit({ error: 'service_unavailable' });
          } finally {
            if (!completedSuccessfully) {
              try { await quota('finish', false); } catch { /* Reservation expires automatically. */ }
            }
            controller.close();
          }
        })();
      },
      cancel() {
        // The reservation expires automatically if a client disconnects mid-stream.
      },
    });
    return new Response(stream, {
      status: 200,
      headers: {
        ...headers,
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache, no-transform',
        'X-Accel-Buffering': 'no',
      },
    });
  } catch {
    // Do not expose provider responses, tokens or raw exceptions to the app.
    return reply(503, { error: 'service_unavailable' });
  } finally {
    if (requestId && !finalized && !streamOwnsReservation) {
      try { await quota('finish', false); }
      catch { /* An abandoned reservation expires after 120 seconds. */ }
    }
  }
});
