export const publicBusiness = {
  brandName: "AV Smartbilling",
  legalName: process.env.NEXT_PUBLIC_BUSINESS_LEGAL_NAME?.trim() || "AV Smartbilling",
  supportEmail: process.env.NEXT_PUBLIC_SUPPORT_EMAIL?.trim() || "r.venkatesh.dev@gmail.com",
  supportPhone: process.env.NEXT_PUBLIC_SUPPORT_PHONE?.trim() || "",
  address: process.env.NEXT_PUBLIC_BUSINESS_ADDRESS?.trim() || "",
  website: "https://av-smart-billing.vercel.app",
  policyEffectiveDate: "23 August 2026",
};

