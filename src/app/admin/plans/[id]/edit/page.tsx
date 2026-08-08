import { notFound } from "next/navigation";
import { PlanForm } from "@/components/admin-forms";
import { PageHeader } from "@/components/ui";
import { listAdminPlans } from "@/data/admin";

export default async function EditPlanPage({ params }: PageProps<"/admin/plans/[id]/edit">) {
  const { id } = await params;
  const plan = (await listAdminPlans()).find((item) => item.id === id);
  if (!plan) notFound();
  return <div className="mx-auto max-w-4xl space-y-7"><PageHeader backHref="/admin/plans" eyebrow="Configuration" title="Edit plan" description="Update this licensing plan in Supabase." /><PlanForm plan={plan} /></div>;
}
