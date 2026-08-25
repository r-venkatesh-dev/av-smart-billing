import type { ReactNode } from "react";
import { redirect } from "next/navigation";
import { connection } from "next/server";
import { AppShell } from "@/components/app-shell";
import { getBillingAccess } from "@/lib/billing-access";

export default async function BillingLayout({ children }: { children: ReactNode }) {
  await connection();
  const access = await getBillingAccess();
  if (!access) redirect("/activate?reason=session-required");
  return <AppShell mode="billing" user={{ fullName: access.displayName, role: access.role }} allowReportsExports={access.allowReportsExports}>{children}</AppShell>;
}
