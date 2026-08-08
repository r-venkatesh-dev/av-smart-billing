import { PlatformSettingsForm } from "@/components/admin-forms";
import { PageHeader } from "@/components/ui";
import { getPlatformSettings } from "@/data/admin";

export default async function AdminSettingsPage() {
  const settings = await getPlatformSettings();
  return <div className="mx-auto max-w-4xl space-y-7"><PageHeader eyebrow="Control center" title="Platform settings" description="License-policy defaults stored in Supabase." /><PlatformSettingsForm settings={settings} /></div>;
}
