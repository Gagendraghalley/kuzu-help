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

const roleLabel = (role: string) =>
  ({ worker: "Worker", admin: "Admin", ground_manager: "Ground manager", player: "Player" } as Record<string, string>)[role] ??
    "Customer";

// Bookings are in Bhutan time (UTC+6 all year), like AppStrings.bookingTime.
const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const hourLabel = (hour: number) => {
  const h = hour % 24;
  return `${h % 12 === 0 ? 12 : h % 12} ${h < 12 ? "am" : "pm"}`;
};
const bhutan = (ms: number) => new Date(ms + 6 * 3600 * 1000); // read with getUTC*
const dayLabel = (d: Date) => `${WEEKDAYS[d.getUTCDay()]} ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`;

/** 'Court A · Sat 4 Oct, 6 pm – 8 pm', as AppStrings._bookingNoticeTime. */
function bookingTime(data: Data): string {
  const startMs = Date.parse(str(data.starts_at) ?? "");
  const hours = typeof data.hours === "number" ? data.hours : undefined;
  const parts: string[] = [];
  const ground = str(data.ground_name)?.trim();
  if (ground) parts.push(ground);
  if (!Number.isNaN(startMs) && hours !== undefined) {
    const from = bhutan(startMs);
    const to = bhutan(startMs + hours * 3600 * 1000);
    const sameDay = dayLabel(from) === dayLabel(to) || (to.getUTCHours() === 0 && hours <= 24);
    parts.push(sameDay
      ? `${dayLabel(from)}, ${hourLabel(from.getUTCHours())} – ${hourLabel(to.getUTCHours())}`
      : `${dayLabel(from)} ${hourLabel(from.getUTCHours())} – ${dayLabel(to)} ${hourLabel(to.getUTCHours())}`);
  }
  return parts.join(" · ");
}

/** 'Nu. 1,500', as PriceUtils.nu. */
const nu = (amount: number) => `Nu. ${String(amount).replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`;
const num = (value: unknown) => (typeof value === "number" ? value : undefined);

/** A subscription's last day, 'Sun 2 Nov' (it ends at the midnight after), as AppStrings._subscriptionLastDay. */
function subscriptionLastDay(data: Data): string | undefined {
  const endMs = Date.parse(str(data.ends_at) ?? "");
  return Number.isNaN(endMs) ? undefined : dayLabel(bhutan(endMs - 1000));
}

const subscriptionNoun = (kind: unknown) =>
  kind === "paid" ? "subscription" : kind === "free" ? "free time" : "free trial";
const payNextMonth = (fee?: number) =>
  `Pay ${fee === undefined ? "" : `${nu(fee)} `}for the next month to stay listed for players.`;
const payToListAgain = (fee?: number) =>
  `Pay ${fee === undefined ? "" : `${nu(fee)} `}for the next month to list it again.`;

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
    case "venue_assigned": return `You now run ${text(data, "venue_name", "a ground")}`;
    case "booking_new":
      return data.status === "confirmed"
        ? `${text(data, "customer_name", "A customer")} booked ${text(data, "ground_name", "your ground")}`
        : `New booking request from ${text(data, "customer_name", "a customer")}`;
    case "booking_confirmed": return `${text(data, "venue_name", "The ground")} confirmed your booking`;
    case "booking_rejected": return `${text(data, "venue_name", "The ground")} can't take your booking`;
    case "booking_cancelled":
      return data.by === "customer"
        ? `${text(data, "customer_name", "A customer")} cancelled their booking`
        : `${text(data, "venue_name", "The ground")} cancelled your booking`;
    case "booking_expired": return `${text(data, "venue_name", "The ground")} didn't answer your request`;
    case "booking_completed": return `How was ${text(data, "venue_name", "the ground")}?`;
    case "venue_review_new": return `A customer rated your ground ${starsLabel(rating)}`;
    case "venue_review_updated": return `A customer changed their rating of your ground to ${starsLabel(rating)}`;
    case "subscription_updated":
      return data.kind === "paid"
        ? `Payment received for ${text(data, "venue_name", "your ground")}`
        : data.kind === "free"
        ? `More free time for ${text(data, "venue_name", "your ground")}`
        : `Free trial for ${text(data, "venue_name", "your ground")}`;
    case "subscription_ending": return `${text(data, "venue_name", "Your ground")}'s ${subscriptionNoun(data.kind)} ends soon`;
    case "subscription_ended": return `${text(data, "venue_name", "Your ground")} is hidden from players`;
    case "subscription_lapsed": return `${text(data, "venue_name", "A ground")}'s subscription ended`;
    default: return "Kuzu Help";
  }
}

export function pushBody(type: string, data: Data): string {
  const note = (str(data.note) ?? str(data.reason) ?? "").trim();
  const lastDay = subscriptionLastDay(data);
  const until = lastDay === undefined ? "" : ` until ${lastDay}`;
  const fee = num(data.fee_nu);
  switch (type) {
    case "welcome":
      return data.role === "worker"
        ? "Set up your worker profile. Our team checks it before customers can see you."
        : data.role === "player"
        ? "Find a sports ground near you, choose a free time and book it."
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
    case "venue_assigned": return "Answer its bookings, and keep its type, price and timings up to date here.";
    case "booking_new":
      return [bookingTime(data), data.status === "pending" ? "Tap to confirm or reject." : ""]
        .filter((s) => s !== "").join(" · ");
    case "booking_confirmed": return [bookingTime(data), note].filter((s) => s !== "").join(" · ");
    case "booking_rejected": return note || "Try another time or ground.";
    case "booking_cancelled": return data.by === "customer" || note === "" ? bookingTime(data) : note;
    case "booking_expired": return "The request is cancelled, so the time is free again. Try another time or ground.";
    case "booking_completed": return "Tap to leave a review.";
    case "venue_review_new":
    case "venue_review_updated": return "Tap to see your reviews.";
    case "subscription_updated": {
      const amount = num(data.amount_nu);
      return data.kind === "paid"
        ? [amount === undefined ? undefined : nu(amount), `Paid${until}.`].filter((s) => s !== undefined).join(" · ")
        : data.kind === "free"
        ? `Listed for free${until}.`
        : `Listed for free${until}. After that, ${fee === undefined ? "a monthly subscription" : `${nu(fee)} a month`} keeps it listed for players.`;
    }
    case "subscription_ending": return `${lastDay === undefined ? "" : `Last day: ${lastDay}. `}${payNextMonth(fee)}`;
    case "subscription_ended":
      return `Its ${subscriptionNoun(data.kind)} ended${lastDay === undefined ? "" : ` on ${lastDay}`}. ${payToListAgain(fee)}`;
    case "subscription_lapsed":
      return `${lastDay === undefined ? "" : `Last day: ${lastDay}. `}Players can't find it until you record a payment or give free time.`;
    default: return "";
  }
}
