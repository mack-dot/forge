"use client";

import dynamic from "next/dynamic";

// The experience runs in the browser only: its state comes from the API and
// from the viewer's motion preference. The static page holds no data.
const Experience = dynamic(() => import("@/components/Experience"), { ssr: false });

export default function Page() {
  return (
    <>
      <noscript>
        <p style={{ padding: "2rem", color: "#e2e8f0", fontFamily: "monospace" }}>
          Discovery One is a simulation that needs JavaScript. It shows results of a backend API; without scripts it
          shows nothing.
        </p>
      </noscript>
      <Experience />
    </>
  );
}
