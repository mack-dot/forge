import type { Verdict } from "@/lib/api";

/**
 * Evidence: the engine's request and answer lines exactly as the backend sent
 * them, and the latency that the backend measured. Plain style, no glow.
 * Every value is a React text node. It is never parsed as HTML.
 */
export default function Evidence({ verdict, source }: { verdict: Verdict; source: string }) {
  const missing = <span className="text-slate-400">not received</span>;
  return (
    <>
      {verdict.as_expected === false && (
        <p
          className="mb-1.5 border-2 border-amber-300 bg-amber-950/70 px-3 py-2 text-[0.86rem] font-bold text-amber-100"
          role="alert"
          data-testid="unexpected-answer"
        >
          <span className="mr-2 bg-amber-300 px-1.5 text-black">UNEXPECTED ANSWER</span>
          the engine did not give the expected class of answer
        </p>
      )}
      <div className="evidence px-3 py-2.5 text-[0.8rem] leading-relaxed" data-testid="evidence">
      <div className="mb-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-[0.68rem] text-slate-300">
        <span className="tag">evidence</span>
        <span>{source} · lines as received</span>
      </div>
      <dl className="grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-0.5">
        <dt className="text-slate-400">engine_request</dt>
        <dd className="break-words whitespace-pre-wrap" data-testid="engine-request">
          {verdict.engine_request ?? missing}
        </dd>
        <dt className="text-slate-400">engine_answer</dt>
        <dd className="break-words whitespace-pre-wrap font-bold text-white" data-testid="engine-answer">
          {verdict.engine_answer ?? missing}
        </dd>
        <dt className="text-slate-400">committed</dt>
        <dd data-testid="committed">{verdict.committed === null ? missing : String(verdict.committed)}</dd>
        <dt className="text-slate-400">latency_ms</dt>
        <dd className="tabular-nums" data-testid="latency">
          {verdict.latency_ms === null ? missing : String(verdict.latency_ms)}
          <span className="text-slate-400"> · measured by the backend</span>
        </dd>
        {verdict.pre_state_hash_source !== null && (
          <>
            <dt className="text-slate-400">pre_state_hash_source</dt>
            <dd className="break-words whitespace-pre-wrap">{verdict.pre_state_hash_source}</dd>
          </>
        )}
        {verdict.expected_answer !== null && (
          <>
            <dt className="text-slate-400">expected_answer</dt>
            <dd className="break-words whitespace-pre-wrap" data-testid="expected-answer">
              {verdict.expected_answer.join(" | ")}
            </dd>
          </>
        )}
        {verdict.as_expected !== null && (
          <>
            <dt className={verdict.as_expected ? "text-slate-400" : "text-amber-300"}>as_expected</dt>
            <dd className={verdict.as_expected ? "" : "font-bold text-amber-200"} data-testid="as-expected">
              {String(verdict.as_expected)}
            </dd>
          </>
        )}
        {verdict.readback_error !== null && (
          <>
            <dt className="text-amber-300">readback_error</dt>
            <dd className="break-words whitespace-pre-wrap text-amber-200" data-testid="readback-error">
              {verdict.readback_error}
            </dd>
          </>
        )}
        </dl>
      </div>
    </>
  );
}
