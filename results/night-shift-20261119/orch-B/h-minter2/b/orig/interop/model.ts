import BigNumber from "bignumber.js";
import type { Apply, Request, State } from "../ts/types";

interface ModelMap<V> extends Iterable<[BigNumber, V]> {
  update(key: BigNumber, value: V): ModelMap<V>;
}
interface ModelRequest {
  readonly dtor_sender: BigNumber;
  readonly dtor_recipient: BigNumber;
  readonly dtor_amount: BigNumber;
}
interface ModelState {
  readonly dtor_balances: ModelMap<BigNumber>;
  readonly dtor_accepted: ModelMap<ModelRequest>;
}
interface GeneratedModule {
  runtime: { Map: { Empty: ModelMap<never> } };
  Ledger: {
    Request: { create_TransferRequest(sender: BigNumber, recipient: BigNumber, amount: BigNumber): ModelRequest };
    State: { create_LedgerState(balances: ModelMap<BigNumber>, accepted: ModelMap<ModelRequest>): ModelState };
    __default: { Apply(state: ModelState, id: BigNumber, request: ModelRequest):
      [ModelState, { readonly is_Ok: boolean; readonly is_Rejected: boolean }] };
  };
}

// The build adds only the tracked CommonJS export footer to Dafny's output.
const { Ledger, runtime } = require("../build/js/ledger.cjs") as GeneratedModule;
const number = (value: bigint): BigNumber => new BigNumber(value.toString());
const integer = (value: BigNumber): bigint => {
  if (!value.isInteger()) throw new Error("Model returned a non-integer value");
  return BigInt(value.toFixed());
};
const requestToModel = (request: Request): ModelRequest => Ledger.Request.create_TransferRequest(
  number(request.sender), number(request.recipient), number(request.amount),
);
const requestFromModel = (request: ModelRequest): Request => ({
  sender: integer(request.dtor_sender), recipient: integer(request.dtor_recipient),
  amount: integer(request.dtor_amount),
});

export const applyModel: Apply = (state, id, request) => {
  let balances: ModelMap<BigNumber> = runtime.Map.Empty;
  for (const [key, value] of state.balances) balances = balances.update(number(key), number(value));
  let accepted: ModelMap<ModelRequest> = runtime.Map.Empty;
  for (const [key, value] of state.accepted) accepted = accepted.update(number(key), requestToModel(value));
  const [next, outcome] = Ledger.__default.Apply(
    Ledger.State.create_LedgerState(balances, accepted), number(id), requestToModel(request),
  );
  if (outcome.is_Ok === outcome.is_Rejected) throw new Error("Unexpected generated outcome");
  const result: State = {
    balances: new Map(Array.from(next.dtor_balances, ([key, value]) => [integer(key), integer(value)])),
    accepted: new Map(Array.from(next.dtor_accepted, ([key, value]) => [integer(key), requestFromModel(value)])),
  };
  return { state: result, outcome: outcome.is_Ok ? "Ok" : "Rejected" };
};
