// Supabase Edge Function: send-invoice
// Emails the invoice for one month a ground paid (supabase/updates.sql,
// section 14) to the ground's manager, from your own mailbox (e.g. Gmail)
// over SMTP. The database calls it when an admin records a payment, or asks
// to send one again, with the same shared secret as send-push (from Vault).
//
// Deploy (README, 'Invoice emails'): Supabase > Edge Functions > Deploy a new
// function > Via Editor, name it send-invoice, paste this file, Deploy. Then
// in its settings turn OFF 'Enforce JWT verification' (the database proves
// who it is with the secret instead). CLI: supabase functions deploy send-invoice --no-verify-jwt
// Secrets (Edge Functions > Secrets):
//   PUSH_SECRET      already there for send-push: the same random text as the kuzu_push_secret Vault secret
//   SMTP_USER        the email invoices come from, e.g. your Gmail address
//   SMTP_PASS        for Gmail, an App Password (myaccount.google.com/apppasswords), not your password
//   SMTP_HOST        optional: smtp.gmail.com unless another provider's
//   SMTP_PORT        optional: 465 (Supabase blocks 25 and 587)
//   INVOICE_FROM     optional: the name and address shown, e.g. Kuzu Help <you@gmail.com>; else Kuzu Help <SMTP_USER>
//   INVOICE_BCC      optional: who gets a copy of every invoice (commas between several)
//   INVOICE_REPLY_TO optional: where the manager's replies go; else to SMTP_USER
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";
// @deno-types="npm:@types/nodemailer@6"
import nodemailer from "npm:nodemailer@6";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  // Trimmed: a secret pasted into the dashboard often ends with a line break.
  const secret = Deno.env.get("PUSH_SECRET")?.trim();
  if (!secret || req.headers.get("x-push-secret")?.trim() !== secret) return json({ error: "unauthorized" }, 401);

  const { period_id: periodId } = await req.json().catch(() => ({}));
  if (typeof periodId !== "string") return json({ error: "period_id is required" }, 400);

  const user = Deno.env.get("SMTP_USER")?.trim();
  const pass = Deno.env.get("SMTP_PASS")?.replace(/\s+/g, ""); // Google shows App Passwords in groups of 4
  if (!user || !pass) return json({ error: "SMTP_USER and SMTP_PASS are not set" }, 500);

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: period, error } = await db
    .from("venue_subscription_periods")
    .select("id, venue_id, kind, starts_at, ends_at, amount_nu, payment_method, payment_reference, note, invoice_number, created_at")
    .eq("id", periodId)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!period || period.kind !== "paid") return json({ sent: false, reason: "not a payment" });

  const { data: venue, error: venueError } = await db
    .from("venues")
    .select("name, town, dzongkhag, manager_id")
    .eq("id", period.venue_id)
    .maybeSingle();
  if (venueError) return json({ error: venueError.message }, 500);
  if (!venue?.manager_id) return json({ sent: false, reason: "the ground has no manager" });

  const { data: manager, error: managerError } = await db
    .from("profiles")
    .select("full_name, email")
    .eq("id", venue.manager_id)
    .maybeSingle();
  if (managerError) return json({ error: managerError.message }, 500);
  if (!manager?.email) return json({ sent: false, reason: "the manager has no email" });

  const invoice = invoiceEmail({ period, venue, manager });
  const smtp = nodemailer.createTransport({
    host: Deno.env.get("SMTP_HOST")?.trim() || "smtp.gmail.com",
    port: Number(Deno.env.get("SMTP_PORT") || 465),
    secure: true, // TLS from the start: Supabase blocks the plain ports 25 and 587
    auth: { user, pass },
  });
  try {
    await smtp.sendMail({
      from: Deno.env.get("INVOICE_FROM")?.trim() || { name: "Kuzu Help", address: user },
      to: manager.email,
      bcc: Deno.env.get("INVOICE_BCC")?.trim() || undefined,
      replyTo: Deno.env.get("INVOICE_REPLY_TO")?.trim() || undefined,
      subject: invoice.subject,
      text: invoice.text,
      html: invoice.html,
    });
  } catch (e) {
    // e.g. 535 for a wrong App Password: see the function's Logs.
    console.error("The invoice email was not sent", e);
    return json({ error: "the email was not sent", detail: String(e) }, 502);
  } finally {
    smtp.close();
  }

  await db.from("venue_subscription_periods").update({ invoice_sent_at: new Date().toISOString() }).eq("id", period.id);
  return json({ sent: true });
});

// ---------------------------------------------------------------------------
// The invoice: in Bhutan time and Ngultrum, as the app shows billing
// (AppStrings, PriceUtils).

type Period = {
  starts_at: string;
  ends_at: string;
  amount_nu: number;
  payment_method: string | null;
  payment_reference: string | null;
  note: string | null;
  invoice_number: string | null;
  created_at: string;
};
type Venue = { name: string; town: string | null; dzongkhag: string };
type Manager = { full_name: string; email: string };

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const bhutan = (ms: number) => new Date(ms + 6 * 3600 * 1000); // read with getUTC*
/** '2 Oct 2026', the Bhutan day [iso] falls on; [before] the second before it (a period's last day). */
const day = (iso: string, before = false) => {
  const d = bhutan(Date.parse(iso) - (before ? 1000 : 0));
  return `${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
};
/** 'Nu. 1,500', as PriceUtils.nu. */
const nu = (amount: number) => `Nu. ${String(amount).replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`;
const methodLabel = (method: string | null) =>
  ({ mbob_transfer: "mBoB transfer", mpay_transfer: "mPay transfer", bank_transfer: "Bank transfer", cash: "Cash" } as Record<
    string,
    string
  >)[method ?? ""] ?? "Other";
const escape = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

export function invoiceEmail({ period, venue, manager }: { period: Period; venue: Venue; manager: Manager }) {
  const number = period.invoice_number ?? "";
  const place = [venue.town, venue.dzongkhag].filter((s) => s && s.trim() !== "").join(", ");
  const dates = `${day(period.starts_at)} – ${day(period.ends_at, true)}`;
  const paidBy = [methodLabel(period.payment_method), period.payment_reference && `Journal no. ${period.payment_reference}`]
    .filter(Boolean)
    .join(" · ");
  const name = manager.full_name.trim() || manager.email;
  const subject = `Kuzu Help invoice ${number}: ${venue.name}`;

  const text = [
    `Kuzu Help: invoice ${number} (paid)`,
    ``,
    `Dear ${name},`,
    `Thank you for your payment. ${venue.name} stays listed for players until ${day(period.ends_at, true)}.`,
    ``,
    `Invoice: ${number}`,
    `Date: ${day(period.created_at)}`,
    `Billed to: ${name} (${manager.email}), ${venue.name}${place ? `, ${place}` : ""}`,
    `Ground listing on Kuzu Help, one month: ${dates}`,
    `Total paid: ${nu(period.amount_nu)}`,
    `Paid by: ${paidBy}`,
    ...(period.note ? [`Note: ${period.note}`] : []),
    ``,
    `Kuzu Help`,
  ].join("\n");

  const row = (label: string, value: string) =>
    `<tr><td style="padding:6px 0;color:#75685D">${label}</td><td style="padding:6px 0;text-align:right;color:#2B1D14">${value}</td></tr>`;
  const html = `<!doctype html>
<html><body style="margin:0;background:#F7F3EE;font-family:Helvetica,Arial,sans-serif;color:#2B1D14">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F7F3EE;padding:24px 12px">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:16px;padding:28px">
<tr><td>
  <div style="font-size:22px;font-weight:800;color:#B8540F">Kuzu Help</div>
  <div style="margin-top:18px;font-size:18px;font-weight:700">Invoice ${escape(number)}</div>
  <div style="margin-top:4px;display:inline-block;padding:3px 10px;border-radius:12px;background:#E8F5E9;color:#2E7D32;font-size:13px;font-weight:700">Paid</div>
  <p style="margin:18px 0 0;line-height:1.5">Dear ${escape(name)},<br>Thank you for your payment. <b>${escape(venue.name)}</b>
  stays listed for players until <b>${day(period.ends_at, true)}</b>.</p>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:20px;font-size:14px;border-top:1px solid #EBE3D8">
    ${row("Invoice", escape(number))}
    ${row("Date", day(period.created_at))}
    ${row("Billed to", `${escape(name)}<br>${escape(manager.email)}`)}
    ${row("Ground", `${escape(venue.name)}${place ? `<br>${escape(place)}` : ""}`)}
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:16px;font-size:14px;border-top:1px solid #EBE3D8;border-bottom:1px solid #EBE3D8">
    <tr><td style="padding:10px 0">Ground listing on Kuzu Help, one month<br><span style="color:#75685D">${dates}</span></td>
        <td style="padding:10px 0;text-align:right;white-space:nowrap">${nu(period.amount_nu)}</td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:8px;font-size:15px">
    <tr><td style="padding:6px 0;font-weight:800">Total paid</td><td style="padding:6px 0;text-align:right;font-weight:800">${nu(period.amount_nu)}</td></tr>
    ${row("Paid by", escape(paidBy))}
    ${period.note ? row("Note", escape(period.note)) : ""}
  </table>
  <p style="margin:24px 0 0;font-size:13px;color:#75685D;line-height:1.5">Keep this email as your receipt. Your billing history is in the Kuzu Help app, on your ground's Subscription page.</p>
</td></tr>
</table>
</td></tr>
</table>
</body></html>`;

  return { subject, text, html };
}
