const desktopVersion = process.env.NEXT_PUBLIC_DESKTOP_VERSION?.trim() || "0.3.0";
const releaseTag = `v${desktopVersion}`;
const releaseBaseUrl = `https://github.com/r-venkatesh-dev/av-smart-billing/releases/download/${releaseTag}`;

function installerUrl(filename: string) {
  return `${releaseBaseUrl}/${encodeURIComponent(filename)}`;
}

export const publicDownloads = {
  desktopVersion,
  playStoreUrl: process.env.NEXT_PUBLIC_PLAY_STORE_URL?.trim() || "https://play.google.com/store/apps/details?id=in.avsmartbilling.mobile",
  windowsUrl: installerUrl(`AV-Smartbilling-Setup-${desktopVersion}.exe`),
  macArm64Url: installerUrl(`AV-Smartbilling-${desktopVersion}-arm64.dmg`),
  macX64Url: installerUrl(`AV-Smartbilling-${desktopVersion}-x64.dmg`),
};
