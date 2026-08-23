import { createHash } from "node:crypto";
import { z } from "zod";
import { verifyLicenseGrant } from "@/lib/license-signing";
import { createAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";

const entitySchema = z.enum(["products", "customers", "invoices"]);
const recordSchema = z.object({
  localId: z.uuid(),
  updatedAt: z.iso.datetime({ offset: true }),
  payload: z.record(z.string(), z.unknown()),
});
const backupSchema = z.object({
  entity: entitySchema,
  records: z.array(recordSchema).max(250),
});

function json(message: string, status: number) {
  return new Response(JSON.stringify({ ok: false, message }), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

async function authorize(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    throw json("Mobile license authorization is required.", 401);
  }
  let grant;
  try {
    grant = await verifyLicenseGrant(authorization.slice(7), "MOBILE");
  } catch {
    throw json("The mobile license requires online validation.", 401);
  }
  const supabase = createAdminClient();
  const [license, device] = await Promise.all([
    supabase.from("licenses").select("customer_id, status, expires_at, allow_cloud_backup, customers(status), plans(status, allow_cloud_backup)").eq("id", grant.licenseId).maybeSingle(),
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
  if (!valid || !license.data?.customer_id) {
    throw json("This license or device is no longer active.", 403);
  }
  if (!license.data.allow_cloud_backup || plan?.allow_cloud_backup !== true) {
    throw json("Cloud backup is not included in this plan. Upgrade your plan to continue.", 403);
  }
  return { grant, customerId: license.data.customer_id as string, supabase };
}

function hashPayload(payload: Record<string, unknown>) {
  return createHash("sha256").update(JSON.stringify(payload)).digest("hex");
}

export async function GET(request: Request) {
  try {
    const { customerId, supabase } = await authorize(request);
    const { data, error } = await supabase
      .from("mobile_backup_runs")
      .select("entity_type, received_count, inserted_count, updated_count, unchanged_count, completed_at")
      .eq("customer_id", customerId)
      .order("completed_at", { ascending: false })
      .limit(30);
    if (error) throw new Error(error.message);
    const latest = new Map<string, unknown>();
    for (const row of data ?? []) {
      if (!latest.has(row.entity_type)) latest.set(row.entity_type, row);
    }
    return Response.json(
      { ok: true, lastBackups: Object.fromEntries(latest) },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Mobile backup status failed", error);
    return json("Cloud backup is unavailable. Please try again.", 500);
  }
}

export async function PUT(request: Request) {
  try {
    const { grant, customerId, supabase } = await authorize(request);
    const parsed = backupSchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) return json("The cloud backup payload is invalid or too large.", 400);

    const records = [...new Map(parsed.data.records.map((record) => [record.localId, record])).values()];
    const ids = records.map((record) => record.localId);
    const existing = ids.length === 0
      ? { data: [], error: null }
      : await supabase
          .from("mobile_backup_records")
          .select("local_id, content_hash")
          .eq("customer_id", customerId)
          .eq("entity_type", parsed.data.entity)
          .in("local_id", ids);
    if (existing.error) throw new Error(existing.error.message);
    const hashes = new Map((existing.data ?? []).map((row) => [row.local_id, row.content_hash]));
    const now = new Date().toISOString();
    const changed = records
      .map((record) => ({ record, hash: hashPayload(record.payload) }))
      .filter(({ record, hash }) => hashes.get(record.localId) !== hash);
    const inserted = changed.filter(({ record }) => !hashes.has(record.localId)).length;
    const updated = changed.length - inserted;

    if (changed.length > 0) {
      const { error } = await supabase.from("mobile_backup_records").upsert(
        changed.map(({ record, hash }) => ({
          customer_id: customerId,
          entity_type: parsed.data.entity,
          local_id: record.localId,
          payload: record.payload,
          content_hash: hash,
          source_license_id: grant.licenseId,
          source_device_id: grant.deviceId,
          local_updated_at: record.updatedAt,
          cloud_updated_at: now,
        })),
        { onConflict: "customer_id,entity_type,local_id" },
      );
      if (error) throw new Error(error.message);
    }

    const unchanged = records.length - changed.length;
    const { error: historyError } = await supabase.from("mobile_backup_runs").insert({
      customer_id: customerId,
      license_id: grant.licenseId,
      device_id: grant.deviceId,
      entity_type: parsed.data.entity,
      received_count: records.length,
      inserted_count: inserted,
      updated_count: updated,
      unchanged_count: unchanged,
      completed_at: now,
    });
    if (historyError) throw new Error(historyError.message);

    return Response.json(
      { ok: true, entity: parsed.data.entity, received: records.length, inserted, updated, unchanged, backedUpAt: now },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Mobile backup upload failed", error);
    return json("Unable to save this data to cloud backup.", 500);
  }
}
