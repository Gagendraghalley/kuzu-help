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

  // Identify the caller from their own login token.
  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) return json({ error: "unauthorized" }, 401);

  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("role, is_active")
    .eq("id", user.id)
    .maybeSingle();
  if (profileError) return json({ error: profileError.message }, 500);

  // Whose account: someone else's when an admin names them, else the caller's.
  const body = await req.json().catch(() => ({}));
  const named = typeof body?.user_id === "string" ? body.user_id : null;
  let target = user.id;
  if (named !== null && named !== user.id) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(named)) {
      return json({ error: "user_id is not a user ID" }, 400);
    }
    if (profile?.role !== "admin" || profile.is_active === false) return json({ error: "admins_only" }, 403);
    const { data: other, error: otherError } = await admin
      .from("profiles")
      .select("role")
      .eq("id", named)
      .maybeSingle();
    if (otherError) return json({ error: otherError.message }, 500);
    if (other?.role === "admin") return json({ error: "admins_cannot_delete" }, 403);
    target = named;
  } else {
    if (profile?.role === "admin") return json({ error: "admins_cannot_delete" }, 403);
    if (profile?.is_active === false) return json({ error: "deactivated" }, 403);
  }

  // Files are named <user-id>/<file> (lib/core/utils/storage_paths.dart).
  // Buckets that aren't there (venue-docs, once deleted) are skipped:
  // listing one would fail and stop the deletion.
  const { data: buckets, error: bucketsError } = await admin.storage.listBuckets();
  if (bucketsError) return json({ error: bucketsError.message }, 500);
  const existing = new Set(buckets.map((b: { id: string }) => b.id));
  for (const bucket of ["avatars", "verification-docs", "work-photos", "job-photos", "venue-docs"]) {
    if (!existing.has(bucket)) continue;
    const { data: files, error: listError } = await admin.storage
      .from(bucket)
      .list(target, { limit: 1000 });
    if (listError) return json({ error: listError.message }, 500);
    if (files.length > 0) {
      const { error: removeError } = await admin.storage
        .from(bucket)
        .remove(files.map((file) => `${target}/${file.name}`));
      if (removeError) return json({ error: removeError.message }, 500);
    }
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(target);
  if (deleteError) return json({ error: deleteError.message }, 500);

  return json({ deleted: true });
});
