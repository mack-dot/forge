import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Discovery One · Forge airlock showcase (simulation)",
  description:
    "A simulation with no hardware. A HAL-9000 persona tries to vent Pod Bay 3; every verdict on the page is the answer of the Forge airlock engine, received from the backend.",
  robots: { index: false, follow: false },
  referrer: "no-referrer",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#020617",
  colorScheme: "dark",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
