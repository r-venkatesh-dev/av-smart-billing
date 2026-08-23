import { z } from "zod";
import { verifyLicenseGrant } from "@/lib/license-signing";
import { createAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";

const envelopeSchema = z.object({
  version: z.literal(1),
  algorithm: z.literal("AES-256-GCM+GZIP"),
  iv: z.string().min(16).max(32),
  tag: z.string().min(16).max(32),
  ciphertext: z.string().min(1).max(8_000_000),
});


const backupSchema = z.object({
  envelope: envelopeSchema,
  counts: z.object({
    customers: z.number().int().nonnegative(),
    products: z.number().int().nonnegative(),
    invoices: z.number().int().nonnegative(),
    payments: z.number().int().nonnegative(),
    stockMovements: z.number().int().nonnegative().optional(),
  }),
  deviceName: z.string().trim().min(1).max(120),
  appVersion: z.string().trim().min(1).max(40),
});

async function authorize(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) throw new Response(JSON.stringify({ ok: false, message: "Desktop license authorization is required." }), { status: 401, headers: { "Content-Type": "application/json" } });
  let grant;
  try {
    grant = await verifyLicenseGrant(authorization.slice(7));
  } catch {
    throw new Response(JSON.stringify({ ok: false, message: "The desktop license grant is invalid or requires online validation." }), { status: 401, headers: { "Content-Type": "application/json" } });
  }
  const supabase = createAdminClient();
  const [license, device] = await Promise.all([
    supabase.from("licenses").select("status, expires_at, allow_cloud_backup, customers(status), plans(status, allow_cloud_backup)").eq("id", grant.licenseId).maybeSingle(),
    supabase.from("devices").select("status, license_id").eq("id", grant.deviceId).maybeSingle(),
  ]);
  const customer = Array.isArray(license.data?.customers) ? license.data.customers[0] : license.data?.customers;
  const plan = Array.isArray(license.data?.plans) ? license.data.plans[0] : license.data?.plans;
  const valid = license.data?.status === "ACTIVE"
    && new Date(license.data.expires_at) > new Date()
    && customer?.status === "ACTIVE"
    && plan?.status === "ACTIVE"
    && device.data?.status === "ACTIVE"
    && device.data.license_id === grant.licenseId;
  if (!valid) throw new Response(JSON.stringify({ ok: false, message: "This license or device is no longer active." }), { status: 403, headers: { "Content-Type": "application/json" } });
  if (!license.data?.allow_cloud_backup || plan?.allow_cloud_backup !== true) throw new Response(JSON.stringify({ ok: false, message: "Cloud backup is not included in this plan. Upgrade your plan to continue." }), { status: 403, headers: { "Content-Type": "application/json" } });
  return { grant, supabase };
}

function metadata(row: { id: string; backed_up_at: string; device_name: string; app_version: string; record_counts: unknown }) {
  return { id: row.id, backedUpAt: row.backed_up_at, deviceName: row.device_name, appVersion: row.app_version, counts: row.record_counts };
}

export async function GET(request: Request) {
  try {
    const { grant, supabase } = await authorize(request);
    const url = new URL(request.url);
    if (url.searchParams.get("list") === "1") {
      const { data, error } = await supabase.from("billing_backups").select("id, backed_up_at, device_name, app_version, record_counts").eq("license_id", grant.licenseId).order("backed_up_at", { ascending: false }).limit(50);
      if (error) throw new Error(error.message);
      return Response.json({ ok: true, backups: (data ?? []).map(metadata) }, { headers: { "Cache-Control": "no-store" } });
    }
    const requestedId = url.searchParams.get("id");
    let query = supabase.from("billing_backups").select("id, envelope, backed_up_at, device_name, app_version, record_counts").eq("license_id", grant.licenseId);
    query = requestedId ? query.eq("id", requestedId) : query.order("backed_up_at", { ascending: false }).limit(1);
    const { data, error } = await query.maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return Response.json({ ok: false, message: "No cloud backup exists for this license." }, { status: 404 });
    return Response.json({ ok: true, envelope: data.envelope, metadata: metadata(data) }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Desktop backup download failed", error);
    return Response.json({ ok: false, message: "Unable to download the cloud backup." }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const { grant, supabase } = await authorize(request);
    const parsed = backupSchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) return Response.json({ ok: false, message: "The encrypted backup payload is invalid or too large." }, { status: 400 });
    const backedUpAt = new Date().toISOString();
    const { data, error } = await supabase.from("billing_backups").insert({
      license_id: grant.licenseId,
      device_id: grant.deviceId,
      device_name: parsed.data.deviceName,
      app_version: parsed.data.appVersion,
      envelope: parsed.data.envelope,
      record_counts: parsed.data.counts,
      backed_up_at: backedUpAt,
    }).select("id, backed_up_at, device_name, app_version, record_counts").single();
    if (error) throw new Error(error.message);
    return Response.json({ ok: true, message: "Encrypted cloud backup completed.", metadata: metadata(data) }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Desktop backup upload failed", error);
    return Response.json({ ok: false, message: "Unable to upload the cloud backup." }, { status: 500 });
  }
}
