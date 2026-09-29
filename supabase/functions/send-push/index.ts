// Supabase Edge Function: send-push
// Sends one notification (supabase/updates.sql section 5) to its user's
// phones through Firebase Cloud Messaging. The database calls it for every new
// notification (section 12), with the shared secret from Supabase Vault.
//
// Deploy (README, 'Push notifications'): Supabase > Edge Functions > Deploy a
// new function > Via Editor, name it send-push, paste this file, Deploy. Then
// in its settings turn OFF 'Enforce JWT verification' (the database proves
// who it is with the secret instead). CLI: supabase functions deploy send-push --no-verify-jwt
// Secrets (Edge Functions > Secrets):
//   PUSH_SECRET               the same random text as the kuzu_push_secret Vault secret
//   FIREBASE_SERVICE_ACCOUNT  the whole JSON file from Firebase > Project settings >
//                             Service accounts > Generate new private key
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";

type Data = Record<string, unknown>;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  const secret = Deno.env.get("PUSH_SECRET");
  if (!secret || req.headers.get("x-push-secret") !== secret) return json({ error: "unauthorized" }, 401);

  const { notification_id: notificationId } = await req.json().catch(() => ({}));
  if (typeof notificationId !== "string") return json({ error: "notification_id is required" }, 400);

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: notification, error } = await db
    .from("notifications")
    .select("id, user_id, type, data")
    .eq("id", notificationId)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!notification) return json({ sent: 0 });

  const { data: tokens, error: tokensError } = await db
    .from("push_tokens")
    .select("token")
    .eq("user_id", notification.user_id);
  if (tokensError) return json({ error: tokensError.message }, 500);
  if (!tokens?.length) return json({ sent: 0 });

  const account = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "null");
  if (!account?.project_id) return json({ error: "FIREBASE_SERVICE_ACCOUNT is not set" }, 500);
  const accessToken = await googleAccessToken(account);

  const data: Data = notification.data ?? {};
  const title = pushTitle(notification.type, data);
  const body = pushBody(notification.type, data);
  let sent = 0;
  for (const { token } of tokens) {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: body ? { title, body } : { title },
          // What the app needs to open the right screen when it's tapped
          // (AppNotification.fromPush). FCM data values must be strings.
          data: { notification_id: notification.id, type: notification.type, payload: JSON.stringify(data) },
          android: { priority: "HIGH", notification: { channel_id: "kuzu_help", tag: notification.id } },
          apns: { payload: { aps: { sound: "default" } } },
        },
      }),
    });
    if (res.ok) {
      sent++;
      continue;
    }
    const problem = await res.json().catch(() => ({}));
    // The app was uninstalled, or the phone has a new token: forget this one.
    const gone = res.status === 404 ||
      problem?.error?.details?.some((d: { errorCode?: string }) => d.errorCode === "UNREGISTERED");
    if (gone) await db.from("push_tokens").delete().eq("token", token);
    else console.error("FCM refused a push", res.status, JSON.stringify(problem));
  }
  return json({ sent });
});

// ---------------------------------------------------------------------------
// Google sign-in for Firebase Cloud Messaging, with the service account.
// A signed JWT is swapped for an access token, kept while it's valid.

type ServiceAccount = { client_email: string; private_key: string; project_id: string };
let cached: { token: string; expiresAt: number } | undefined;

export async function googleAccessToken(account: ServiceAccount): Promise<string> {
  if (cached && cached.expiresAt > Date.now() + 60_000) return cached.token;
  const assertion = await signedJwt(account);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  const reply = await res.json();
  if (!res.ok) throw new Error(`Google sign-in failed: ${JSON.stringify(reply)}`);
  cached = { token: reply.access_token, expiresAt: Date.now() + reply.expires_in * 1000 };
  return cached.token;
}

export async function signedJwt(account: ServiceAccount, now = Math.floor(Date.now() / 1000)): Promise<string> {
  const encode = (value: object) => base64url(new TextEncoder().encode(JSON.stringify(value)));
  const unsigned = `${encode({ alg: "RS256", typ: "JWT" })}.${encode({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;
  const pem = account.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  return `${unsigned}.${base64url(new Uint8Array(signature))}`;
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// ---------------------------------------------------------------------------
// What each notification says. The same words as AppStrings.notificationTitle
// and notificationBody (lib/core/strings/app_strings.dart): change both.

const str = (value: unknown) => (typeof value === "string" ? value : undefined);

function text(data: Data, key: string, fallback: string): string {
  const value = str(data[key])?.trim() ?? "";
  return value === "" ? fallback : value;
}

const starsLabel = (n: number) => (n === 1 ? "1 star" : `${n} stars`);

const roleLabel = (role: string) => (role === "worker" ? "Worker" : role === "admin" ? "Admin" : "Customer");

const reportReason = (code: string) =>
  ({
    did_not_show_up: "Did not show up",
    poor_work: "Poor quality work",
    overcharged: "Charged too much",
    rude_or_unsafe: "Rude or unsafe behaviour",
  } as Record<string, string>)[code] ?? "Something else";

export function pushTitle(type: string, data: Data): string {
  const rating = typeof data.rating === "number" ? data.rating : 0;
  switch (type) {
    case "welcome": return "Welcome to Kuzu Help!";
    case "new_user": return `${text(data, "name", "Someone")} joined as a ${roleLabel(text(data, "role", "customer")).toLowerCase()}`;
    case "worker_submitted": return `${text(data, "name", "A worker")} is waiting for approval`;
    case "worker_resubmitted": return `${text(data, "name", "A worker")} asks to be checked again`;
    case "report_new": return `New report about ${text(data, "worker_name", "a worker")}`;
    case "worker_approved": return "You're approved!";
    case "worker_rejected": return "Your profile needs changes";
    case "review_new": return `A customer rated you ${starsLabel(rating)}`;
    case "review_updated": return `A customer changed their rating to ${starsLabel(rating)}`;
    case "contact": return "A customer is getting in touch";
    case "report_updated": return `Update on your report about ${text(data, "worker_name", "a worker")}`;
    case "account_deactivated": return "Your account is deactivated";
    case "account_reactivated": return "Your account is active again";
    case "review_reply": return `${text(data, "worker_name", "The worker")} replied to your review`;
    case "job_new": return `New job request from ${text(data, "customer_name", "a customer")}`;
    case "job_accepted": return `${text(data, "worker_name", "The worker")} accepted your job request`;
    case "job_declined": return `${text(data, "worker_name", "The worker")} can't take your job`;
    case "job_cancelled": return `${text(data, "customer_name", "The customer")} cancelled their job request`;
    case "job_completed":
      return data.by === "worker"
        ? `${text(data, "worker_name", "The worker")} marked your job as done`
        : `${text(data, "customer_name", "The customer")} marked the job as done`;
    default: return "Kuzu Help";
  }
}

export function pushBody(type: string, data: Data): string {
  const note = (str(data.note) ?? str(data.reason) ?? "").trim();
  switch (type) {
    case "welcome":
      return data.role === "worker"
        ? "Set up your worker profile. Our team checks it before customers can see you."
        : "Choose a service to find trusted local workers near you.";
    case "new_user": return str(data.email) ?? "";
    case "worker_submitted": return "They sent their documents. Tap to check them.";
    case "worker_resubmitted": return "They have fixed their details. Tap to check them.";
    case "report_new": return reportReason(str(data.reason) ?? "");
    case "worker_approved": return "Customers can now find you and call you.";
    case "worker_rejected": return note || "Please fix the details below, then send them for checking again.";
    case "review_new":
    case "review_updated": return "Tap to see your reviews.";
    case "contact":
      return data.method === "whatsapp"
        ? "They tapped WhatsApp on your profile, so check your messages."
        : "They tapped Call on your profile, so expect a phone call.";
    case "report_updated":
      return data.status === "reviewed"
        ? "Our team has looked into it. Thank you for telling us."
        : data.status === "closed"
        ? "Our team has closed it. Thank you for telling us."
        : "Our team is looking into it.";
    case "account_deactivated":
      return note || "You can't use Kuzu Help with this account. If you think this is a mistake, please contact the Kuzu Help team.";
    case "account_reactivated": return "You can use Kuzu Help again.";
    case "review_reply": return "Tap to read it.";
    case "job_new": return [str(data.category), "Tap to see the job and reply."].filter((s) => s !== undefined).join(" · ");
    case "job_accepted": return note || "They'll call you on the number you gave.";
    case "job_declined": return note || "Try another worker for this job.";
    case "job_completed": return data.by === "worker" ? "How did it go? Leave a review." : "";
    default: return "";
  }
}
