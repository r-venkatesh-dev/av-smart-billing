import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { publicDownloads } from "@/lib/public-downloads";

export const runtime = "nodejs";

const DEFAULT_FALLBACK = {
  ok: true,
  platform: "android",
  latestVersion: "1.0.0",
  latestBuildNumber: 2,
  minRequiredBuild: 1,
  releaseNotes: "Initial release with offline-first billing, barcode scanning, and Bluetooth printing.",
  updateUrl: publicDownloads.playStoreUrl,
};

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const platform = (searchParams.get("platform") || "android").toLowerCase();

    if (platform !== "android" && platform !== "ios") {
      return NextResponse.json(
        { ok: false, message: "Invalid platform. Must be 'android' or 'ios'." },
        { status: 400 },
      );
    }

    const supabase = createAdminClient();
    const { data, error } = await supabase
      .from("app_versions")
      .select("platform, latest_version, latest_build_number, min_required_build, release_notes, update_url")
      .eq("platform", platform)
      .eq("is_active", true)
      .order("latest_build_number", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error || !data) {
      // Graceful fallback to default configuration if table isn't migrated yet
      return NextResponse.json(
        {
          ...DEFAULT_FALLBACK,
          platform,
        },
        {
          headers: {
            "Cache-Control": "public, s-maxage=300, stale-while-revalidate=600",
          },
        },
      );
    }

    return NextResponse.json(
      {
        ok: true,
        platform: data.platform,
        latestVersion: data.latest_version,
        latestBuildNumber: data.latest_build_number,
        minRequiredBuild: data.min_required_build,
        releaseNotes: data.release_notes ?? "",
        updateUrl: data.update_url,
      },
      {
        headers: {
          "Cache-Control": "public, s-maxage=300, stale-while-revalidate=600",
        },
      },
    );
  } catch (err) {
    return NextResponse.json(
      DEFAULT_FALLBACK,
      {
        headers: {
          "Cache-Control": "no-store",
        },
      },
    );
  }
}
