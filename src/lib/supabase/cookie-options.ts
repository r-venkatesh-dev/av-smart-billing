import type { CookieOptionsWithName } from "@supabase/ssr";

export const authCookieOptions: CookieOptionsWithName = {
  httpOnly: true,
  sameSite: "lax",
  secure: process.env.NODE_ENV === "production",
  path: "/",
};
