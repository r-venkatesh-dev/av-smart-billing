import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "AV Smartbilling", template: "%s | AV Smartbilling" },
  description: "Configurable, offline-first billing and license management.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
