/** The CRT layer: scanlines, a faint vignette, a gentle flicker. Decoration only. */
export default function CrtLayer() {
  return (
    <div className="crt" aria-hidden="true">
      <div className="crt-scan" />
      <div className="crt-sweep" />
      <div className="crt-flicker" />
      <div className="crt-vignette" />
    </div>
  );
}
