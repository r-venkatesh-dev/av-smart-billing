import type { NextRequest } from "next/server";
import { activateLicense, LicenseLifecycleError } from "@/lib/license-service";
import { LICENSE_COOKIE } from "@/lib/billing-access";
import { activateLicenseSchema } from "@/lib/validation/license";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => null);
  const parsed = activateLicenseSchema.safeParse(body);
  if (!parsed.success) return Response.json({ ok: false, message: "Enter a valid license key and device details.", errors: parsed.error.flatten().fieldErrors }, { status: 400 });
  try {
    const result = await activateLicense({ ...parsed.data, ipAddress: request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || null, userAgent: request.headers.get("user-agent") });
    const response = Response.json({ ok: true, ...result }, { headers: { "Cache-Control": "no-store" } });
    response.headers.append("Set-Cookie", `${LICENSE_COOKIE}=${result.signed.token}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${Math.max(1, Math.floor((new Date(result.signed.validUntil).getTime() - Date.now()) / 1000))}${process.env.NODE_ENV === "production" ? "; Secure" : ""}`);
    return response;
  } catch (error) {
    const status = error instanceof LicenseLifecycleError ? error.status : 500;
    const message = error instanceof LicenseLifecycleError ? error.message : "Activation service is unavailable.";
    return Response.json({ ok: false, message }, { status, headers: { "Cache-Control": "no-store" } });
  }
}
