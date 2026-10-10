import { z } from "zod";
import { verifyLicenseGrant } from "@/lib/license-signing";
import { createAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";

const productSchema = z.object({
  id: z.uuid().optional(),
  name: z.string().trim().min(2).max(180),
  sku: z.string().trim().min(1).max(80),
  barcode: z.string().trim().max(120).default(""),
  unit: z.string().trim().min(1).max(24),
  priceInPaise: z.number().int().min(0),
  taxRateBasisPoints: z.number().int().min(0).max(10000),
  discountPercent: z.number().min(0).max(100),
  stockQuantity: z.number().min(0),
});

const customerSchema = z.object({
  id: z.uuid().optional(),
  name: z.string().trim().min(2).max(180),
  phone: z.string().trim().max(20),
  address: z.string().trim().max(1000),
  gstin: z.string().trim().max(15),
});

const saveSchema = z.discriminatedUnion("resource", [
  z.object({ resource: z.literal("product"), data: productSchema }),
  z.object({ resource: z.literal("customer"), data: customerSchema }),
]);

const statusSchema = z.object({
  resource: z.literal("product-status"),
  id: z.uuid(),
  active: z.boolean(),
});

function failure(message: string, status: number) {
  return Response.json(
    { ok: false, message },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}

async function authorize(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    throw failure("Mobile license authorization is required.", 401);
  }

  let grant;
  try {
    grant = await verifyLicenseGrant(authorization.slice(7), "MOBILE");
  } catch {
    throw failure("The mobile license requires online validation.", 401);
  }

  const supabase = createAdminClient();
  const [license, device] = await Promise.all([
    supabase
      .from("licenses")
      .select("created_by, status, expires_at, allow_online_billing, customers(status), plans(status, allow_online_billing)")
      .eq("id", grant.licenseId)
      .maybeSingle(),
    supabase
      .from("devices")
      .select("status, license_id")
      .eq("id", grant.deviceId)
      .maybeSingle(),
  ]);
  const customer = Array.isArray(license.data?.customers)
    ? license.data.customers[0]
    : license.data?.customers;
  const plan = Array.isArray(license.data?.plans)
    ? license.data.plans[0]
    : license.data?.plans;
  const valid =
    license.data?.status === "ACTIVE" &&
    new Date(license.data.expires_at) > new Date() &&
    customer?.status === "ACTIVE" &&
    plan?.status === "ACTIVE" &&
    device.data?.status === "ACTIVE" &&
    device.data.license_id === grant.licenseId;
  if (!valid || !license.data?.created_by) {
    throw failure("This license or device is no longer active.", 403);
  }
  if (!license.data.allow_online_billing || plan?.allow_online_billing !== true) {
    throw failure("Online billing is not included in this plan. Upgrade your plan to continue.", 403);
  }

  const business = await supabase
    .from("billing_businesses")
    .select("id, company_name, phone, email, address, gstin, invoice_prefix, invoice_terms, tax_type, payment_qr_path, low_stock_threshold")
    .eq("license_id", grant.licenseId)
    .eq("status", "ACTIVE")
    .maybeSingle();
  if (business.error) throw new Error(business.error.message);
  if (!business.data) {
    throw failure(
      "Online billing workspace is not ready. Validate the license and try again.",
      409,
    );
  }
  return {
    supabase,
    business: business.data,
    actorId: license.data.created_by as string,
  };
}

function productResponse(row: Record<string, unknown>) {
  return {
    id: row.id,
    name: row.name,
    sku: row.sku,
    barcode: row.barcode ?? "",
    unit: row.unit,
    priceInPaise: Number(row.price_in_paise),
    taxRateBasisPoints: Number(row.tax_rate_basis_points),
    discountPercent: Number(row.discount_percent ?? 0),
    stockQuantity: Number(row.stock_quantity),
    active: row.status === "ACTIVE",
  };
}

function customerResponse(row: Record<string, unknown>) {
  return {
    id: row.id,
    name: row.name,
    phone: row.phone ?? "",
    address: row.address ?? "",
    gstin: row.gstin ?? "",
  };
}

export async function GET(request: Request) {
  try {
    const { supabase, business } = await authorize(request);
    const url = new URL(request.url);
    const resource = url.searchParams.get("resource") ?? "status";
    if (resource === "status") {
      return Response.json(
        {
          ok: true,
          business: {
            id: business.id,
            companyName: business.company_name,
            lowStockThreshold: Number(business.low_stock_threshold),
          },
        },
        { headers: { "Cache-Control": "no-store" } },
      );
    }
    if (resource === "products") {
      const query = url.searchParams.get("query")?.trim() ?? "";
      let products = supabase
        .from("billing_products")
        .select(
          "id, name, sku, barcode, unit, price_in_paise, tax_rate_basis_points, discount_percent, stock_quantity, status",
        )
        .eq("business_id", business.id)
        .order("status", { ascending: false })
        .order("name");
      if (query) {
        const safeQuery = query.replaceAll(/[%,()]/g, " ").trim();
        if (safeQuery) {
          products = products.or(
            `name.ilike.%${safeQuery}%,sku.ilike.%${safeQuery}%,barcode.ilike.%${safeQuery}%`,
          );
        }
      }
      const result = await products;
      if (result.error) throw new Error(result.error.message);
      return Response.json(
        { ok: true, products: (result.data ?? []).map(productResponse) },
        { headers: { "Cache-Control": "no-store" } },
      );
    }
    if (resource === "customers") {
      const result = await supabase
        .from("billing_customers")
        .select("id, name, phone, address, gstin")
        .eq("business_id", business.id)
        .eq("status", "ACTIVE")
        .order("name");
      if (result.error) throw new Error(result.error.message);
      return Response.json(
        { ok: true, customers: (result.data ?? []).map(customerResponse) },
        { headers: { "Cache-Control": "no-store" } },
      );
    }
    if (resource === "invoices") {
      const result = await supabase
        .from("billing_invoices")
        .select("id, invoice_number, customer_name, issued_at, total_in_paise, status")
        .eq("business_id", business.id)
        .order("issued_at", { ascending: false })
        .limit(100);
      if (result.error) throw new Error(result.error.message);
      return Response.json(
        {
          ok: true,
          invoices: (result.data ?? []).map((row) => ({
            id: row.id,
            invoiceNumber: row.invoice_number,
            customerName: row.customer_name ?? "Walk-in Customer",
            issuedAt: row.issued_at,
            totalInPaise: Number(row.total_in_paise),
            status: row.status,
          })),
        },
        { headers: { "Cache-Control": "no-store" } },
      );
    }
    if (resource === "invoice") {
      const invoiceId = url.searchParams.get("id");
      if (!invoiceId) return failure("Invoice ID is required.", 400);
      const [invoiceRes, itemsRes] = await Promise.all([
        supabase
          .from("billing_invoices")
          .select("*")
          .eq("id", invoiceId)
          .eq("business_id", business.id)
          .maybeSingle(),
        supabase
          .from("billing_invoice_items")
          .select("*")
          .eq("invoice_id", invoiceId),
      ]);
      if (invoiceRes.error) throw new Error(invoiceRes.error.message);
      if (!invoiceRes.data) return failure("Invoice not found.", 404);
      return Response.json(
        {
          ok: true,
          invoice: {
            ...invoiceRes.data,
            invoice_number: invoiceRes.data.invoice_number,
            customer_name: invoiceRes.data.customer_name ?? "Walk-in Customer",
            customer_phone: invoiceRes.data.customer_phone ?? "",
            customer_address: invoiceRes.data.customer_address ?? "",
            customer_gstin: invoiceRes.data.customer_gstin ?? "",
            total_in_paise: Number(invoiceRes.data.total_in_paise),
            subtotal_in_paise: Number(invoiceRes.data.subtotal_in_paise),
            discount_in_paise: Number(invoiceRes.data.discount_in_paise ?? 0),
            tax_in_paise: Number(invoiceRes.data.tax_in_paise ?? 0),
          },
          items: (itemsRes.data ?? []).map((item) => ({
            id: item.id,
            product_id: item.product_id,
            product_name: item.description,
            sku: item.sku,
            unit: item.unit,
            quantity: Number(item.quantity),
            unit_price_in_paise: Number(item.unit_price_in_paise),
            tax_rate_basis_points: Number(item.tax_rate_basis_points),
            discount_in_paise: Number(item.discount_in_paise ?? 0),
            taxable_in_paise: Number(item.taxable_in_paise),
            tax_in_paise: Number(item.line_tax_in_paise ?? 0),
            subtotal_in_paise: Number(item.line_subtotal_in_paise ?? 0),
            total_in_paise: Number(item.taxable_in_paise) + Number(item.line_tax_in_paise ?? 0),
          })),
          business: {
            id: business.id,
            company_name: business.company_name,
            phone: business.phone ?? "",
            email: business.email ?? "",
            address: business.address ?? "",
            gstin: business.gstin ?? "",
            invoice_prefix: business.invoice_prefix ?? "INV",
            invoice_terms: business.invoice_terms ?? "",
            payment_qr_path: business.payment_qr_path ?? "",
          },
        },
        { headers: { "Cache-Control": "no-store" } },
      );
    }
    return failure("Unsupported online billing resource.", 400);
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Mobile online billing read failed", error);
    return failure("Online billing is unavailable. Please try again.", 500);
  }
}

export async function PUT(request: Request) {
  try {
    const { supabase, business, actorId } = await authorize(request);
    const parsed = saveSchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) return failure("Review the entered details.", 400);

    if (parsed.data.resource === "product") {
      const value = parsed.data.data;
      const product = {
        business_id: business.id,
        name: value.name,
        sku: value.sku.toUpperCase(),
        barcode: value.barcode || null,
        unit: value.unit,
        price_in_paise: value.priceInPaise,
        tax_rate_basis_points: value.taxRateBasisPoints,
        discount_percent: value.discountPercent,
        stock_quantity: value.stockQuantity,
      };
      if (!value.id) {
        const saved = await supabase
          .from("billing_products")
          .insert({ ...product, status: "ACTIVE" })
          .select("id")
          .single();
        if (saved.error) {
          if (saved.error.code === "23505") {
            return failure("This SKU or barcode is already used.", 409);
          }
          throw new Error(saved.error.message);
        }
        if (value.stockQuantity > 0) {
          const movement = await supabase.from("billing_stock_movements").insert({
            business_id: business.id,
            product_id: saved.data.id,
            movement_type: "OPENING",
            quantity_change: value.stockQuantity,
            quantity_after: value.stockQuantity,
            reference_type: "PRODUCT",
            reference_id: saved.data.id,
            notes: "Opening stock from mobile Online Mode",
            created_by: actorId,
          });
          if (movement.error) throw new Error(movement.error.message);
        }
      } else {
        const previous = await supabase
          .from("billing_products")
          .select("stock_quantity")
          .eq("id", value.id)
          .eq("business_id", business.id)
          .maybeSingle();
        if (previous.error) throw new Error(previous.error.message);
        if (!previous.data) return failure("Product not found.", 404);
        const saved = await supabase
          .from("billing_products")
          .update(product)
          .eq("id", value.id)
          .eq("business_id", business.id);
        if (saved.error) {
          if (saved.error.code === "23505") {
            return failure("This SKU or barcode is already used.", 409);
          }
          throw new Error(saved.error.message);
        }
        const stockChange = value.stockQuantity - Number(previous.data.stock_quantity);
        if (stockChange !== 0) {
          const movement = await supabase.from("billing_stock_movements").insert({
            business_id: business.id,
            product_id: value.id,
            movement_type: "ADJUSTMENT",
            quantity_change: stockChange,
            quantity_after: value.stockQuantity,
            reference_type: "PRODUCT",
            reference_id: value.id,
            notes: "Stock changed from mobile Online Mode",
            created_by: actorId,
          });
          if (movement.error) throw new Error(movement.error.message);
        }
      }
      return Response.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
    }

    const value = parsed.data.data;
    const customer = {
      business_id: business.id,
      name: value.name,
      phone: value.phone,
      address: value.address,
      gstin: value.gstin || null,
      status: "ACTIVE",
    };
    const saved = value.id
      ? await supabase
          .from("billing_customers")
          .update(customer)
          .eq("id", value.id)
          .eq("business_id", business.id)
      : await supabase.from("billing_customers").insert(customer);
    if (saved.error) throw new Error(saved.error.message);
    return Response.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Mobile online billing save failed", error);
    return failure("Unable to save this online data. Please try again.", 500);
  }
}

export async function PATCH(request: Request) {
  try {
    const { supabase, business } = await authorize(request);
    const parsed = statusSchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) return failure("The product status is invalid.", 400);
    const updated = await supabase
      .from("billing_products")
      .update({ status: parsed.data.active ? "ACTIVE" : "INACTIVE" })
      .eq("id", parsed.data.id)
      .eq("business_id", business.id)
      .select("id")
      .maybeSingle();
    if (updated.error) throw new Error(updated.error.message);
    if (!updated.data) return failure("Product not found.", 404);
    return Response.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Mobile online product status failed", error);
    return failure("Unable to update this product. Please try again.", 500);
  }
}

export async function DELETE(request: Request) {
  try {
    const { supabase, business } = await authorize(request);
    const url = new URL(request.url);
    const resource = url.searchParams.get("resource");
    const id = z.uuid().safeParse(url.searchParams.get("id"));
    if (!id.success || !["product", "customer"].includes(resource ?? "")) {
      return failure("The delete request is invalid.", 400);
    }

    if (resource === "product") {
      const removed = await supabase.rpc("delete_billing_product", {
        p_business_id: business.id,
        p_product_id: id.data,
      });
      if (removed.error) throw new Error(removed.error.message);
      return Response.json(
        { ok: true, mode: removed.data === "deleted" ? "deleted" : "inactive" },
        { headers: { "Cache-Control": "no-store" } },
      );
    }

    const used = await supabase
      .from("billing_invoices")
      .select("id", { count: "exact", head: true })
      .eq("business_id", business.id)
      .eq("customer_id", id.data);
    if (used.error) throw new Error(used.error.message);
    const removed = (used.count ?? 0) > 0
      ? await supabase
          .from("billing_customers")
          .update({ status: "INACTIVE" })
          .eq("id", id.data)
          .eq("business_id", business.id)
      : await supabase
          .from("billing_customers")
          .delete()
          .eq("id", id.data)
          .eq("business_id", business.id);
    if (removed.error) throw new Error(removed.error.message);
    return Response.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Mobile online billing delete failed", error);
    return failure("Unable to delete this online data. Please try again.", 500);
  }
}

const posSaleSchema = z.object({
  customerId: z.string().uuid().nullable().optional(),
  walkInName: z.string().trim().default("Walk-in Customer"),
  walkInPhone: z.string().trim().default(""),
  paymentMethod: z.enum(["CASH", "UPI", "UPI_QR", "CARD", "BANK_TRANSFER", "OTHER", "CREDIT"]),
  amountReceivedInRupees: z.number().min(0).optional(),
  overallDiscountPercent: z.number().min(0).max(100).default(0),
  reference: z.string().trim().max(120).default(""),
  taxType: z.enum(["INTRA_STATE", "INTER_STATE"]).default("INTRA_STATE"),
  items: z.array(z.object({
    productId: z.string().uuid(),
    quantity: z.number().positive(),
    discountPercent: z.number().min(0).max(100).default(0),
  })).min(1),
});

export async function POST(request: Request) {
  try {
    const { supabase, business } = await authorize(request);
    const body = (await request.json().catch(() => null)) as { resource?: string; data?: unknown } | null;
    const resource = body?.resource ?? "pos-sale";
    if (resource !== "pos-sale") {
      return failure("Unsupported resource.", 400);
    }
    const parsed = posSaleSchema.safeParse(body?.data);
    if (!parsed.success) {
      return failure(parsed.error.issues[0]?.message ?? "Invalid POS sale payload.", 400);
    }
    const val = parsed.data;
    const paymentMethod = val.paymentMethod === "UPI_QR" ? "UPI" : val.paymentMethod;
    const amountReceivedInPaise = val.amountReceivedInRupees != null
      ? Math.round(val.amountReceivedInRupees * 100)
      : 0;

    const rpcResult = await supabase.rpc("create_billing_pos_sale", {
      p_business_id: business.id,
      p_customer_id: val.customerId || null,
      p_walk_in_name: val.walkInName || "Walk-in Customer",
      p_walk_in_phone: val.walkInPhone || "",
      p_items: val.items,
      p_payment_method: paymentMethod,
      p_amount_received_in_paise: amountReceivedInPaise,
      p_reference: val.reference || null,
      p_tax_type: val.taxType,
      p_overall_discount_percent: val.overallDiscountPercent,
    });

    if (rpcResult.error) {
      return failure(rpcResult.error.message, 400);
    }

    const sale = rpcResult.data as {
      invoiceId: string;
      invoiceNumber: string;
      totalInPaise: number;
      changeInPaise?: number;
    };

    return Response.json(
      {
        ok: true,
        invoiceId: sale.invoiceId,
        invoiceNumber: sale.invoiceNumber,
        totalInPaise: sale.totalInPaise,
        changeInPaise: sale.changeInPaise ?? 0,
      },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Mobile online pos sale failed", error);
    return failure("Unable to complete online sale. Please try again.", 500);
  }
}

