const desktopVersion = process.env.NEXT_PUBLIC_DESKTOP_VERSION?.trim() || "0.3.0";

export const publicDownloads = {
  desktopVersion,
  playStoreUrl: process.env.NEXT_PUBLIC_PLAY_STORE_URL?.trim() || "https://play.google.com/store/apps/details?id=in.avsmartbilling.mobile",
  windowsUrl: `/downloads/AV-Smartbilling-Setup-${desktopVersion}.exe`,
  macArm64Url: `/downloads/AV-Smartbilling-${desktopVersion}-arm64.dmg`,
  macX64Url: `/downloads/AV-Smartbilling-${desktopVersion}-x64.dmg`,
};
