import Image from "next/image";

export function BrandLogo({ size = 40, className = "" }: { size?: number; className?: string }) {
  return <Image src="/app-logo.png" alt="AV Smartbilling logo" width={size} height={size} priority className={`shrink-0 rounded-[22%] object-cover ${className}`} />;
}
