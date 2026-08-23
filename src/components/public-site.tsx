import type { ReactNode } from "react";
import Link from "next/link";
import { LockKeyhole } from "lucide-react";
import { BrandLogo } from "@/components/brand-logo";
import { publicBusiness } from "@/lib/public-business";

const primaryLinks = [
  { href: "/", label: "Home" },
  { href: "/products", label: "Products" },
  { href: "/plans", label: "Plans" },
  { href: "/about", label: "About" },
  { href: "/contact", label: "Contact" },
];

const policyLinks = [
  { href: "/privacy", label: "Privacy" },
  { href: "/terms", label: "Terms" },
  { href: "/refund-policy", label: "Refunds" },
];

export function PublicHeader() {
  return (
    <header className="border-b border-[#dfe3e1] bg-white">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-4 px-4 py-3 sm:flex-nowrap sm:px-5">
        <Link
          href="/"
          className="focus-ring flex shrink-0 items-center gap-2.5"
        >
          <BrandLogo size={36} />
          <span>
            <strong className="block text-sm leading-4">AV Smartbilling</strong>
            <small className="text-[9px] font-semibold uppercase tracking-[.14em] text-[#6d716f]">
              Simple business billing
            </small>
          </span>
        </Link>
        <nav
          aria-label="Public navigation"
          className="order-3 mt-2 flex w-full items-center gap-5 overflow-x-auto border-t border-[#edf0ef] pt-2 text-xs font-semibold text-[#475467] sm:order-none sm:ml-auto sm:mt-0 sm:w-auto sm:border-0 sm:pt-0"
        >
          {primaryLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="focus-ring shrink-0 py-1 hover:text-[#057c73]"
            >
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="ml-auto flex shrink-0 items-center gap-2 sm:ml-2">
          <Link
            href="/login"
            className="focus-ring hidden items-center gap-1.5 px-2 py-2 text-[11px] font-semibold text-[#6d716f] md:flex"
          >
            <LockKeyhole size={14} />
            Admin
          </Link>
          <Link
            href="/subscribe"
            className="focus-ring bg-[#057c73] px-3.5 py-2.5 text-[10px] font-bold uppercase tracking-[.08em] text-white"
          >
            Get key
          </Link>
        </div>
      </div>
    </header>
  );
}

export function PublicFooter() {
  return (
    <footer className="fixed inset-x-0 bottom-0 z-30 border-t border-[#dfe3e1] bg-white shadow-[0_-4px_18px_rgba(38,39,42,0.06)]">
      <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-3 text-[11px] text-[#6d716f] sm:px-5 md:flex-row md:items-center md:justify-between">
        <div>
          <strong className="text-[#26272a]">{publicBusiness.legalName}</strong>
          <span className="ml-2">
            © 2026 · Billing software and Android app
          </span>
        </div>
        <nav
          aria-label="Legal information"
          className="flex flex-wrap gap-x-4 gap-y-1.5"
        >
          {policyLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="hover:text-[#057c73]"
            >
              {link.label}
            </Link>
          ))}
          <Link href="/contact" className="hover:text-[#057c73]">
            Support
          </Link>
          <Link href="/login" className="hover:text-[#057c73]">
            Admin login
          </Link>
        </nav>
      </div>
    </footer>
  );
}

export function PublicSite({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-[#f7f8f7] pb-28 md:pb-16">
      <PublicHeader />
      <main>{children}</main>
      <PublicFooter />
    </div>
  );
}

export function PublicPageIntro({
  eyebrow,
  title,
  description,
}: {
  eyebrow: string;
  title: string;
  description: string;
}) {
  return (
    <header className="border-b border-[#dfe3e1] bg-white">
      <div className="mx-auto max-w-4xl px-4 py-7 sm:px-5 sm:py-8">
        <p className="text-[10px] font-bold uppercase tracking-[.18em] text-[#057c73]">
          {eyebrow}
        </p>
        <h1 className="mt-2 text-3xl tracking-[-.03em] sm:text-4xl">{title}</h1>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-[#6d716f]">
          {description}
        </p>
      </div>
    </header>
  );
}

export function LegalPage({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <PublicSite>
      <PublicPageIntro
        eyebrow={`Effective ${publicBusiness.policyEffectiveDate}`}
        title={title}
        description={description}
      />
      <article className="mx-auto max-w-4xl space-y-5 px-4 py-7 text-sm leading-6 text-[#475467] sm:px-5 sm:py-8">
        {children}
      </article>
    </PublicSite>
  );
}

export function LegalSection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <section className="border border-[#dfe3e1] bg-white p-5">
      <h2 className="text-xl text-[#26272a]">{title}</h2>
      <div className="mt-2 space-y-2">{children}</div>
    </section>
  );
}

export function PublicContactDetails() {
  const configured =
    publicBusiness.supportEmail ||
    publicBusiness.supportPhone ||
    publicBusiness.address;
  return (
    <div className="space-y-1 text-sm leading-6 text-[#475467]">
      <p>
        <strong>Business:</strong> {publicBusiness.legalName}
      </p>
      {publicBusiness.supportEmail ? (
        <p>
          <strong>Email:</strong>{" "}
          <a
            className="text-[#057c73] underline"
            href={`mailto:${publicBusiness.supportEmail}`}
          >
            {publicBusiness.supportEmail}
          </a>
        </p>
      ) : null}
      {publicBusiness.supportPhone ? (
        <p>
          <strong>Phone:</strong>{" "}
          <a
            className="text-[#057c73] underline"
            href={`tel:${publicBusiness.supportPhone}`}
          >
            {publicBusiness.supportPhone}
          </a>
        </p>
      ) : null}
      {publicBusiness.address ? (
        <p className="whitespace-pre-line">
          <strong>Address:</strong> {publicBusiness.address}
        </p>
      ) : null}
      <p>
        <strong>Website:</strong>{" "}
        <a className="text-[#057c73] underline" href={publicBusiness.website}>
          {publicBusiness.website}
        </a>
      </p>
      {!configured ? (
        <p className="mt-2 border-l-2 border-amber-500 bg-amber-50 px-3 py-2 text-xs text-amber-900">
          For support, contact the AV Smartbilling representative who supplied
          your application. Verified public contact details will appear here
          when configured.
        </p>
      ) : null}
    </div>
  );
}
