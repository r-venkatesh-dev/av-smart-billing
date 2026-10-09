import { PublicSite } from "@/components/public-site";
import { RenewalCheckout } from "@/app/renew/renewal-checkout";

export const metadata = {
  title: "Renew License | AV Smartbilling",
  description: "Renew and extend your existing AV Smartbilling license key seamlessly.",
};

export const dynamic = "force-dynamic";

export default async function RenewPage({ searchParams }: PageProps<"/renew">) {
  const params = await searchParams;
  const initialToken = typeof params.token === "string" ? params.token : undefined;

  return (
    <PublicSite>
      <section className="mx-auto max-w-4xl px-4 py-8 sm:px-6 sm:py-12">
        <div className="mb-8 text-center sm:text-left">
          <p className="text-[11px] font-bold uppercase tracking-[.18em] text-[#057c73]">
            Instant License Renewal
          </p>
          <h1 className="mt-2 text-3xl font-extrabold tracking-tight text-[#171b36] sm:text-4xl">
            Extend Your AV Smartbilling License
          </h1>
          <p className="mt-2 text-sm leading-6 text-[#5f6663]">
            Renew your subscription without re-entering your business details or losing offline data.
            Your existing license key remains active and will be extended directly.
          </p>
        </div>

        <RenewalCheckout initialToken={initialToken} />
      </section>
    </PublicSite>
  );
}
