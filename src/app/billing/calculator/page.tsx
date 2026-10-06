import { PageHeader } from "@/components/ui";
import { GstCalculator } from "@/components/gst-calculator";

export default function Page() {
  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Utility Tools"
        title="GST Calculator"
        description="Quick offline GST calculation with price breakup, standard tax slabs, and inclusive/exclusive modes."
      />
      <GstCalculator />
    </div>
  );
}
