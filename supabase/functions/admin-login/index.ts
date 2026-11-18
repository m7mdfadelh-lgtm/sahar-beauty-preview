const allowedOrigin = "https://m7mdfadelh-lgtm.github.io";
const corsHeaders = {
  "Access-Control-Allow-Origin": allowedOrigin,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
  "Vary": "Origin",
};

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  if (origin && origin !== allowedOrigin) {
    return new Response("Forbidden", { status: 403, headers: { "Cache-Control": "no-store" } });
  }
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405, headers: corsHeaders });

  const usernameExpected = Deno.env.get("ADMIN_LOGIN_USERNAME") ?? "";
  const email = Deno.env.get("ADMIN_LOGIN_EMAIL") ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const publishableKey = Deno.env.get("PUBLIC_API_KEY") ?? "";
  if (!usernameExpected || !email || !supabaseUrl || !publishableKey) {
    return Response.json({ error: "Admin login is not configured" }, { status: 503, headers: corsHeaders });
  }

  let body: { action?: string; username?: string; password?: string };
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "Invalid request" }, { status: 400, headers: corsHeaders });
  }

  if (typeof body.username !== "string" || body.username.trim().toLowerCase() !== usernameExpected.trim().toLowerCase()) {
    return Response.json({ error: "Invalid credentials" }, { status: 401, headers: corsHeaders });
  }

  if (body.action === "setup") {
    const redirect = new URL("https://m7mdfadelh-lgtm.github.io/sahar-beauty-preview/admin.html");
    const endpoint = new URL("/auth/v1/otp", supabaseUrl);
    endpoint.searchParams.set("redirect_to", redirect.toString());
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "apikey": publishableKey, "Content-Type": "application/json" },
      body: JSON.stringify({ email, create_user: true }),
    });
    if (!response.ok) {
      return Response.json({ error: "Could not send setup link" }, { status: response.status === 429 ? 429 : 502, headers: corsHeaders });
    }
    return Response.json({ sent: true }, { headers: corsHeaders });
  }

  if (body.action !== "login" || typeof body.password !== "string" || body.password.length < 1 || body.password.length > 256) {
    return Response.json({ error: "Invalid request" }, { status: 400, headers: corsHeaders });
  }

  const response = await fetch(new URL("/auth/v1/token?grant_type=password", supabaseUrl), {
    method: "POST",
    headers: { "apikey": publishableKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password: body.password }),
  });
  if (!response.ok) {
    return Response.json({ error: "Invalid credentials" }, { status: response.status === 429 ? 429 : 401, headers: corsHeaders });
  }
  const session = await response.json();
  return Response.json({ access_token: session.access_token, refresh_token: session.refresh_token }, { headers: corsHeaders });
});
