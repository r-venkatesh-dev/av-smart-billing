import type { ReactNode } from "react";
import { redirect } from "next/navigation";
import { connection } from "next/server";
import { AppShell } from "@/components/app-shell";
import { getCurrentAdmin } from "@/lib/auth/authorization";

export default async function AdminLayout({ children }: { children: ReactNode }) {
  await connection();
  const profile = await getCurrentAdmin();
  if (!profile) redirect("/login?reason=not-authorized");
  return <AppShell mode="admin" user={{ fullName: profile.fullName, role: profile.role }}>{children}</AppShell>;
}
