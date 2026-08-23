import { z } from "zod";

const publicSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(20),
});

const serverSchema = publicSchema.extend({
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(20),
  LICENSE_SIGNING_PRIVATE_KEY: z.string().min(32),
  LICENSE_SIGNING_KEY_ID: z.string().min(1).default("v1"),
  LICENSE_ISSUER: z.url(),
  LICENSE_KEY_ENCRYPTION_KEY: z.string().regex(/^[a-fA-F0-9]{64}$/, "LICENSE_KEY_ENCRYPTION_KEY must be a 32-byte hexadecimal key."),
});

export type PublicEnv = z.infer<typeof publicSchema>;
export type ServerEnv = z.infer<typeof serverSchema>;

export function getPublicEnv(): PublicEnv {
  return publicSchema.parse({
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  });
}

export function getServerEnv(): ServerEnv {
  return serverSchema.parse({
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
    LICENSE_SIGNING_PRIVATE_KEY: process.env.LICENSE_SIGNING_PRIVATE_KEY,
    LICENSE_SIGNING_KEY_ID: process.env.LICENSE_SIGNING_KEY_ID,
    LICENSE_ISSUER: process.env.LICENSE_ISSUER,
    LICENSE_KEY_ENCRYPTION_KEY: process.env.LICENSE_KEY_ENCRYPTION_KEY,
  });
}
