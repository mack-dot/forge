import { apply as correct } from "../ts/ledger";
import type { Apply } from "../ts/types";

// Deliberate rejection fixture. A self-transfer credits funds without a debit.
export const apply: Apply = (state, id, request) => {
  const balance = state.balances.get(request.sender);
  if (!state.accepted.has(id) && request.sender === request.recipient &&
      balance !== undefined && request.amount > 0n && request.amount <= balance) {
    const balances = new Map(state.balances);
    balances.set(request.recipient, balance + request.amount);
    const accepted = new Map(state.accepted);
    accepted.set(id, { ...request });
    return { state: { balances, accepted }, outcome: "Ok" };
  }
  return correct(state, id, request);
};
