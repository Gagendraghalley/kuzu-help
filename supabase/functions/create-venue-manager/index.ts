// Supabase Edge Function: create-venue-manager
// Admins only: the account of the person who runs a sports venue
// (supabase/updates.sql, section 13). Makes a Kuzu Help account for the email,
// already confirmed, or finds the one that uses it, and returns its ID. The
// app then gives it the venue with set_venue_manager, which also checks the
// account may manage one (not an admin's or a worker's, not deactivated).
// The manager logs in with the email and 'Forgot password?': a code arrives
// by email, and they choose their password (A5).
//
// Deploy (README): Supabase > Edge Functions > Deploy a new function > Via
// Editor, name it create-venue-manager, paste this file, Deploy. Or with the
// Supabase CLI: supabase functions deploy create-venue-manager
// The service_role key is available to the function as an environment
// variable on Supabase's servers - it is NEVER shipped in the Flutter app.
//
// Body: { email, full_name, phone? }   phone: +975XXXXXXXX
// Reply: { user_id, created }          created: false when the account existed

import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "unauthorized" }, 401);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Only an active admin, identified from their own login token.
  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) return json({ error: "unauthorized" }, 401);
  const { data: caller, error: callerError } = await admin
    .from("profiles")
    .select("role, is_active")
    .eq("id", user.id)
    .maybeSingle();
  if (callerError) return json({ error: callerError.message }, 500);
  if (caller?.role !== "admin" || caller.is_active === false) return json({ error: "admins_only" }, 403);

  const body = await req.json().catch(() => ({}));
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
  const phone = typeof body.phone === "string" && /^\+[0-9]{8,15}$/.test(body.phone) ? body.phone : null;
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || fullName === "") {
    return json({ error: "email and full_name are required" }, 400);
  }

  // An account already uses the email: that one. ilike matches '_' in an
  // email as any letter, so compare exactly after.
  const { data: matches, error: findError } = await admin
    .from("profiles")
    .select("id, email, phone")
    .ilike("email", email);
  if (findError) return json({ error: findError.message }, 500);
  const existing = matches?.find((p) => (p.email ?? "").toLowerCase() === email);
  if (existing) {
    // A sign-up whose code was never entered: confirm it, so 'Forgot
    // password?' works for them.
    await admin.auth.admin.updateUserById(existing.id, { email_confirm: true });
    if (phone && !existing.phone) await admin.from("profiles").update({ phone }).eq("id", existing.id);
    return json({ user_id: existing.id, created: false });
  }

  // A new account, confirmed already. The database makes its profile
  // (schema.sql, section 3) as a customer; set_venue_manager changes that.
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (createError || !created.user) return json({ error: createError?.message ?? "not created" }, 500);
  if (phone) {
    const { error: phoneError } = await admin.from("profiles").update({ phone }).eq("id", created.user.id);
    if (phoneError) return json({ error: phoneError.message }, 500);
  }
  return json({ user_id: created.user.id, created: true });
});
