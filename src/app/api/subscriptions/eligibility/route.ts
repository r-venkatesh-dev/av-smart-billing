import type { NextRequest } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { z } from "zod";

export const runtime = "nodejs";

const eligibilitySchema = z.object({
  phone: z.string().trim().min(5),
});

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => null);
  const parsed = eligibilitySchema.safeParse(body);
  if (!parsed.success) {
    return Response.json(
      { ok: false, message: "Enter a valid 10-digit mobile number." },
      { status: 400 },
    );
  }

  const raw = parsed.data.phone;
  const digits = raw.replace(/\D/g, "");
  if (digits.length < 10) {
    return Response.json(
      { ok: false, message: "Enter a valid 10-digit mobile number." },
      { status: 400 },
    );
  }

  const last10 = digits.slice(-10);
  const supabase = createAdminClient();

  // Check 1: Registered customers table
  const { count: customerCount, error: customerError } = await supabase
    .from("customers")
    .select("id", { count: "exact", head: true })
    .or(`phone.eq.${digits},phone.ilike.%${last10}%`);

  if (customerError) {
    console.error("Eligibility customer query failed:", customerError);
  }

  // Check 2: Completed subscription orders
  const { count: orderCount, error: orderError } = await supabase
    .from("subscription_orders")
    .select("id", { count: "exact", head: true })
    .or(`phone.eq.${digits},phone.ilike.%${last10}%`)
    .in("status", ["PAID", "PAYMENT_CAPTURED"]);

  if (orderError) {
    console.error("Eligibility subscription_orders query failed:", orderError);
  }

  const isFirstTimeCustomer = (customerCount ?? 0) === 0 && (orderCount ?? 0) === 0;

  return Response.json({
    ok: true,
    phone: last10,
    isFirstTimeCustomer,
  });
}
