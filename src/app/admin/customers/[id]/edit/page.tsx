import { notFound } from "next/navigation";
import { CustomerForm } from "@/components/admin-forms";
import { PageHeader } from "@/components/ui";
import { getAdminCustomer } from "@/data/admin";

export default async function EditCustomerPage({ params }: PageProps<"/admin/customers/[id]/edit">) {
  const { id } = await params;
  const customer = await getAdminCustomer(id);
  if (!customer) notFound();
  return <div className="space-y-7"><PageHeader backHref={`/admin/customers/${id}`} eyebrow="Management" title="Edit customer" description="Update this Supabase customer record." /><CustomerForm customer={customer} /></div>;
}
