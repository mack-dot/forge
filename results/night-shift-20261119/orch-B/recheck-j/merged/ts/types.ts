export type Request = Readonly<{ sender: bigint; recipient: bigint; amount: bigint }>;
export type Outcome = "Ok" | "Rejected";
export type State = Readonly<{
  balances: ReadonlyMap<bigint, bigint>;
  accepted: ReadonlyMap<bigint, Request>;
}>;
export type Result = Readonly<{ state: State; outcome: Outcome }>;
export type Apply = (state: State, id: bigint, request: Request) => Result;
