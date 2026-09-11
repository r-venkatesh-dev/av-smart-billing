const desktopVersion = process.env.NEXT_PUBLIC_DESKTOP_VERSION?.trim() || "0.3.0";
const defaultDownloadsUrl = "https://pub-51a0e58578b448948e5647729cfd26e7.r2.dev/downloads";
const configuredDownloadsUrl = process.env.NEXT_PUBLIC_DOWNLOADS_BASE_URL?.trim().replace(/\/+$/, "");
const releaseBaseUrl = configuredDownloadsUrl || defaultDownloadsUrl;

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
