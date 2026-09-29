// Supabase Edge Function: delete-account
// Deletes the calling user's auth account. Linked rows are removed by the
// schema's ON DELETE CASCADE rules. Storage files should be removed here too.
//
// Deploy:  supabase functions deploy delete-account
// The service_role key is available to the function as an environment
// variable on Supabase's servers - it is NEVER shipped in the Flutter app.

import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return new Response("Unauthorized", { status: 401 });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Identify the caller from their own login token.
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return new Response("Unauthorized", { status: 401 });

  const admin = createClient(url, serviceKey);

  // TODO: delete the user's files in avatars/<id>/ and verification-docs/<id>/

  const { error: delError } = await admin.auth.admin.deleteUser(user.id);
  if (delError) return new Response(delError.message, { status: 500 });

  return new Response(JSON.stringify({ deleted: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
