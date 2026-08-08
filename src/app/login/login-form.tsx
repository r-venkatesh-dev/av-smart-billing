"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { ArrowRight, LoaderCircle } from "lucide-react";
import { login, type LoginState } from "@/app/login/actions";

const initialState: LoginState = {};

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button disabled={pending} className="focus-ring flex h-12 w-full items-center justify-center gap-3 rounded-xl bg-[#5b4df5] text-[11px] font-bold uppercase tracking-[.12em] text-white transition hover:bg-[#4b3ee2] disabled:cursor-wait disabled:opacity-70">
      {pending ? <LoaderCircle className="animate-spin" size={17} /> : <ArrowRight size={17} />}
      {pending ? "Signing in…" : "Sign in securely"}
    </button>
  );
}

export function LoginForm({ redirectTo }: { redirectTo?: string }) {
  const [state, action] = useActionState(login, initialState);

  return (
    <form action={action} className="space-y-5">
      <input type="hidden" name="redirectTo" value={redirectTo ?? ""} />
      <label className="block">
        <span className="mb-2 block text-sm font-semibold text-[#344054]">Email address</span>
        <input name="email" type="email" autoComplete="email" required aria-invalid={Boolean(state.fields?.email)} aria-describedby="email-error" className="focus-ring h-12 w-full rounded-xl border border-[#d9dde7] px-4 text-sm" />
        {state.fields?.email ? <span id="email-error" className="mt-1.5 block text-xs text-rose-600">{state.fields.email[0]}</span> : null}
      </label>
      <label className="block">
        <span className="mb-2 flex items-center justify-between text-sm font-semibold text-[#344054]">Password</span>
        <input name="password" type="password" autoComplete="current-password" required aria-invalid={Boolean(state.fields?.password)} aria-describedby="password-error" className="focus-ring h-12 w-full rounded-xl border border-[#d9dde7] px-4 text-sm" />
        {state.fields?.password ? <span id="password-error" className="mt-1.5 block text-xs text-rose-600">{state.fields.password[0]}</span> : null}
      </label>
      {state.message ? <p role="alert" className="rounded-xl bg-rose-50 px-3 py-2.5 text-sm text-rose-700">{state.message}</p> : null}
      <SubmitButton />
    </form>
  );
}
