import "server-only";

import { cache } from "react";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const ADMIN_ROLES = ["OWNER", "ADMIN", "SUPPORT", "VIEWER"] as const;
export type AdminRole = (typeof ADMIN_ROLES)[number];

export const ADMIN_WRITE_ROLES = {
  profiles: ["OWNER"],
  customers: ["OWNER", "ADMIN", "SUPPORT"],
  plans: ["OWNER", "ADMIN"],
  licenses: ["OWNER", "ADMIN"],
  devices: ["OWNER", "ADMIN", "SUPPORT"],
} as const satisfies Record<string, readonly AdminRole[]>;

export interface AdminProfile {
  id: string;
  email: string;
  fullName: string;
  role: AdminRole;
}

export class AuthorizationError extends Error {
  constructor(public readonly status: 401 | 403, message: string) {
    super(message);
    this.name = "AuthorizationError";
  }
}

export const getCurrentAdmin = cache(async (): Promise<AdminProfile | null> => {
  const supabase = await createSupabaseServerClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();
  const user = userData.user;

  if (userError || !user) return null;

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, full_name, role, status")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError || !profile || profile.status !== "ACTIVE") return null;
  if (!ADMIN_ROLES.includes(profile.role as AdminRole)) return null;

  return {
    id: profile.id,
    email: user.email ?? "",
    fullName: profile.full_name,
    role: profile.role as AdminRole,
  };
});

export async function requireAdminRole(
  allowedRoles: readonly AdminRole[] = ADMIN_ROLES,
): Promise<AdminProfile> {
  const profile = await getCurrentAdmin();
  if (!profile) throw new AuthorizationError(401, "Authentication required");
  if (!allowedRoles.includes(profile.role)) throw new AuthorizationError(403, "Insufficient permissions");
  return profile;
}
