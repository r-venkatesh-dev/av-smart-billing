"use server";

import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { loginSchema, safeRedirectPath } from "@/lib/validation/auth";

export interface LoginState {
  message?: string;
  fields?: { email?: string[]; password?: string[] };
}

export async function login(_state: LoginState, formData: FormData): Promise<LoginState> {
  const parsed = loginSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
    redirectTo: formData.get("redirectTo") || undefined,
  });

  if (!parsed.success) {
    const fields = parsed.error.flatten().fieldErrors;
    return { fields: { email: fields.email, password: fields.password } };
  }

  try {
    const supabase = await createSupabaseServerClient();
    const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
      email: parsed.data.email,
      password: parsed.data.password,
    });

    if (signInError || !signInData.user) return { message: "The email or password is incorrect." };

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("status")
      .eq("id", signInData.user.id)
      .maybeSingle();

    if (profileError || profile?.status !== "ACTIVE") {
      await supabase.auth.signOut();
      return { message: "This account is not authorized to access the control center." };
    }
  } catch {
    return { message: "Authentication is not configured or is temporarily unavailable." };
  }

  redirect(safeRedirectPath(parsed.data.redirectTo));
}

export async function logout() {
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  redirect("/login");
}
