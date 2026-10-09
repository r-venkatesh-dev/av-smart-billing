import type { NextRequest } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRenewalSessionToken } from "@/lib/renewal-token";
import { z } from "zod";

export const runtime = "nodejs";

const schema = z.object({
  deviceId: z.string().uuid(),
  deviceFingerprint: z.string().trim().min(10).max(512),
});

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => null);
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    return Response.json({ ok: false, message: "Invalid device session." }, { status: 400 });
  }

  const supabase = createAdminClient();
  const { data: device, error } = await supabase
    .from("devices")
    .select("license_id, status")
    .eq("id", parsed.data.deviceId)
    .maybeSingle();

  if (error || !device || !device.license_id) {
    return Response.json({ ok: false, message: "No active license found for this device." }, { status: 404 });
  }

  // Generate encrypted, opaque token valid for 1 hour
  const token = createRenewalSessionToken(device.license_id, 3600);

  const issuer = process.env.NEXT_PUBLIC_APP_URL || "https://av-smart-billing.vercel.app";
  const renewalUrl = `${issuer}/renew?token=${encodeURIComponent(token)}`;

  return Response.json({
    ok: true,
    token,
    renewalUrl,
  }, { headers: { "Cache-Control": "no-store" } });
}
