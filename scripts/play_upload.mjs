#!/usr/bin/env node
// Uploads an Android App Bundle to Google Play and puts it on a track, with
// the Google Play Developer API and a service account (README, 'One-command
// release'). scripts/release.sh runs it; nothing to install (Node 18+).
//
//   node scripts/play_upload.mjs --aab <file.aab> --package bt.kuzuhelp.app \
//     --key <service-account.json> [--track production] [--status draft]
//
// --status draft:     the release waits in Play Console for you to roll it out.
// --status completed: it goes to Google's review and rolls out once approved.

import { readFileSync } from "node:fs";
import { createSign } from "node:crypto";
import { parseArgs } from "node:util";

const { values: args } = parseArgs({
  options: {
    aab: { type: "string" },
    package: { type: "string" },
    key: { type: "string" },
    track: { type: "string", default: "production" },
    status: { type: "string", default: "draft" },
  },
});

function fail(message) {
  console.error(`✗ Google Play: ${message}`);
  process.exit(1);
}

if (!args.aab || !args.package || !args.key) fail("--aab, --package and --key are needed");
if (!["draft", "completed"].includes(args.status)) fail("--status is draft or completed");

let account;
try {
  account = JSON.parse(readFileSync(args.key, "utf8"));
} catch (e) {
  fail(`can't read the service account key ${args.key}: ${e.message}`);
}
if (!account.client_email || !account.private_key) fail(`${args.key} isn't a service account key (JSON)`);

// PLAY_API_BASE is only for trying this against a test server.
const api = process.env.PLAY_API_BASE ?? "https://androidpublisher.googleapis.com";
const app = `${api}/androidpublisher/v3/applications/${args.package}`;

/** Signs in as the service account: a signed JWT swapped for an access token. */
async function accessToken() {
  const tokenUri = account.token_uri ?? "https://oauth2.googleapis.com/token";
  const now = Math.floor(Date.now() / 1000);
  const part = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const unsigned = `${part({ alg: "RS256", typ: "JWT" })}.${part({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  })}`;
  const signature = createSign("RSA-SHA256").update(unsigned).sign(account.private_key).toString("base64url");
  const res = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${unsigned}.${signature}` }),
  });
  const reply = await res.json().catch(() => ({}));
  if (!res.ok) fail(`signing in as ${account.client_email} failed: ${reply.error_description ?? reply.error ?? res.status}`);
  return reply.access_token;
}

const token = await accessToken();

/** A Google Play API call; throws with Google's message when it's refused. */
async function call(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, ...(body === undefined ? {} : { "Content-Type": "application/json" }) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = {};
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    // Not JSON: the text says what went wrong.
  }
  if (!res.ok) throw new Error(json.error?.message ?? (text || `HTTP ${res.status}`));
  return json;
}

// Every change goes into an 'edit', committed at the end: all of it or none.
const edit = (await call("POST", `${app}/edits`, {}).catch((e) => fail(e.message))).id;
try {
  const bundle = readFileSync(args.aab);
  console.log(`  Uploading ${args.aab} (${(bundle.length / 1e6).toFixed(1)} MB)…`);
  // A resumable upload: Google says where to send the file, then it's sent there.
  const start = await fetch(
    `${api}/upload/androidpublisher/v3/applications/${args.package}/edits/${edit}/bundles?uploadType=resumable`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "X-Upload-Content-Type": "application/octet-stream",
        "X-Upload-Content-Length": String(bundle.length),
      },
    },
  );
  const session = start.headers.get("location");
  if (!start.ok || !session) throw new Error(`the upload didn't start: ${(await start.text()) || start.status}`);
  const put = await fetch(session, {
    method: "PUT",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/octet-stream" },
    body: bundle,
  });
  const uploaded = await put.json().catch(() => ({}));
  if (!put.ok) throw new Error(uploaded.error?.message ?? `the upload failed: ${put.status}`);
  const versionCode = uploaded.versionCode;
  console.log(`  Uploaded version code ${versionCode}.`);

  await call("PUT", `${app}/edits/${edit}/tracks/${args.track}`, {
    track: args.track,
    releases: [{ versionCodes: [String(versionCode)], status: args.status }],
  });

  try {
    await call("POST", `${app}/edits/${edit}:commit`);
  } catch (e) {
    // Apps with managed publishing (or some first releases) must be sent
    // for review from Play Console: commit anyway, and say so.
    if (!e.message.includes("changesNotSentForReview")) throw e;
    await call("POST", `${app}/edits/${edit}:commit?changesNotSentForReview=true`);
    console.log("  Note: Google Play won't send this for review automatically. In Play Console, open");
    console.log("  Publishing overview and tap 'Send changes for review'.");
  }
  console.log(`✓ Google Play: version code ${versionCode} is on the ${args.track} track (${args.status}).`);
} catch (e) {
  await call("DELETE", `${app}/edits/${edit}`).catch(() => {}); // nothing half done is left behind
  fail(e.message);
}
