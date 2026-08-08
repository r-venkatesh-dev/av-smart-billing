import { PlanForm } from "@/components/admin-forms";
import { PageHeader } from "@/components/ui";

export default function NewPlanPage() {
  return <div className="mx-auto max-w-4xl space-y-7"><PageHeader backHref="/admin/plans" eyebrow="Configuration" title="Create plan" description="Add a licensing plan to Supabase." /><PlanForm /></div>;
}
