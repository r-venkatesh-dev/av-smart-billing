"use client";

import { useEffect } from "react";

export function digitsOnly(value: string): string {
  return value.replace(/\D/g, "").slice(0, 10);
}

export function formatLicenseKey(value: string): string {
  const characters = value.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 16);
  return characters.match(/.{1,4}/g)?.join("-") ?? "";
}

function isPhoneInput(input: HTMLInputElement): boolean {
  return input.type === "tel" || ["phone", "walkInPhone", "posWalkInPhone"].includes(input.name);
}

function configureInput(input: HTMLInputElement) {
  if (isPhoneInput(input)) {
    input.type = "tel";
    input.inputMode = "numeric";
    input.maxLength = 10;
    input.pattern = "[0-9]{10}";
    input.title = "Enter exactly 10 digits.";
  }
  if (input.name === "licenseKey") {
    input.maxLength = 19;
    input.pattern = "[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}";
    input.title = "Enter a license key in ABCD-EFGH-JKLM-NPQR format.";
  }
}

export function GlobalInputRules() {
  useEffect(() => {
    const handleInput = (event: Event) => {
      if (!(event.target instanceof HTMLInputElement)) return;
      configureInput(event.target);
      if (isPhoneInput(event.target)) event.target.value = digitsOnly(event.target.value);
      if (event.target.name === "licenseKey") event.target.value = formatLicenseKey(event.target.value);
    };
    document.addEventListener("input", handleInput, true);
    return () => {
      document.removeEventListener("input", handleInput, true);
    };
  }, []);

  return null;
}
