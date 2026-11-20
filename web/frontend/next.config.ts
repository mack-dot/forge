import path from "node:path";
import type { NextConfig } from "next";

// Static export: the page is plain files. It holds no server-side secret and
// talks only to the API base URL (NEXT_PUBLIC_API_BASE).
const nextConfig: NextConfig = {
  output: "export",
  reactStrictMode: true,
  poweredByHeader: false,
  images: { unoptimized: true },
  devIndicators: false,
  // This folder is its own root: the build must not look at the repository root above it.
  turbopack: { root: path.resolve(__dirname) },
};

export default nextConfig;
