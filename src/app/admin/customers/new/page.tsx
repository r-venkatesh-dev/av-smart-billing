import { CustomerForm } from "@/components/admin-forms";
import { PageHeader } from "@/components/ui";

export default function NewCustomerPage() {
  return <div className="mx-auto max-w-4xl space-y-7"><PageHeader backHref="/admin/customers" eyebrow="Management" title="Add customer" description="Create a customer record in Supabase." /><CustomerForm /></div>;
}
