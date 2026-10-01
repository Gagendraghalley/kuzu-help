// Supabase Edge Function: delete-account
// D1 'Delete account'. Deletes the calling user's files (their <id>/ folder
// in each bucket), then their auth account. Linked rows (profile, worker
// profile, services, documents, reviews, reports, notifications, work photos,
// saved workers, job requests, ground bookings, venue reviews) are removed by
// the ON DELETE CASCADE rules. A venue manager's venues stay, without a
// manager, and so do the cover photos they uploaded (venue-photos is left
// alone): they belong to the venue. venue-docs, for trade licences from the
// first version of sports grounds, is cleaned only while it still exists.
// Refused for admins (so there is always one) and for deactivated users
// (so they can't sign up again to get round the block).
//
// Deploy (README, step 4): Supabase > Edge Functions > Deploy a new function
// > Via Editor, name it delete-account, paste this file, Deploy. Or with the
// Supabase CLI: supabase functions deploy delete-account
// The service_role key is available to the function as an environment
// variable on Supabase's servers - it is NEVER shipped in the Flutter app.

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
  if (profile?.role === "admin") return json({ error: "admins_cannot_delete" }, 403);
  if (profile?.is_active === false) return json({ error: "deactivated" }, 403);

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
      .list(user.id, { limit: 1000 });
    if (listError) return json({ error: listError.message }, 500);
    if (files.length > 0) {
      const { error: removeError } = await admin.storage
        .from(bucket)
        .remove(files.map((file) => `${user.id}/${file.name}`));
      if (removeError) return json({ error: removeError.message }, 500);
    }
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return json({ error: deleteError.message }, 500);

  return json({ deleted: true });
});
