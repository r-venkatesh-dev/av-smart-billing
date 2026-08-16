import { LicenseForm } from "@/components/admin-forms";
import { PageHeader } from "@/components/ui";
import { listAdminCustomers, listAdminPlans } from "@/data/admin";

export default async function Page() {
  const [customers, plans] = await Promise.all([listAdminCustomers(), listAdminPlans()]);
  const expiry = new Date();
  expiry.setFullYear(expiry.getFullYear() + 1);
  const defaultExpiry = `${expiry.getFullYear()}-${String(expiry.getMonth() + 1).padStart(2, "0")}-${String(expiry.getDate()).padStart(2, "0")}`;
  return <div className="space-y-7"><PageHeader backHref="/admin/licenses" eyebrow="License issuance" title="Generate license" description="Issue a one-time license key to an active customer using an active plan." /><LicenseForm customers={customers.filter((customer) => customer.status === "ACTIVE").map((customer) => ({ id: customer.id, name: customer.companyName, phone: customer.phone }))} plans={plans.filter((plan) => plan.status === "ACTIVE").map(({ id, name, maxDevices, validationWindowDays }) => ({ id, name, maxDevices, validationWindowDays }))} defaultExpiry={defaultExpiry} /></div>;
}
