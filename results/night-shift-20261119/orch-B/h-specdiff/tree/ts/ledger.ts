import type { Apply } from "./types";

// Caller precondition: the state is WellFormed under the approved ledger spec.
// This implementation is compared with the proved model; it is not proved.
export const apply: Apply = (state, id, request) => {
  const previous = state.accepted.get(id);
  if (previous !== undefined) {
    const identical = previous.sender === request.sender &&
      previous.recipient === request.recipient && previous.amount === request.amount;
    return { state, outcome: identical ? "Ok" : "Rejected" };
  }
  const debit = state.balances.get(request.sender);
  const credit = state.balances.get(request.recipient);
  const feeBalance = state.balances.get(0n);
  if (debit === undefined || credit === undefined || request.sender === request.recipient ||
      feeBalance === undefined || request.sender === 0n || request.recipient === 0n ||
      request.amount <= 0n || request.amount + 1n > debit) {
    return { state, outcome: "Rejected" };
  }
  const balances = new Map(state.balances);
  balances.set(request.sender, debit - request.amount - 1n);
  balances.set(request.recipient, credit + request.amount);
  balances.set(0n, feeBalance + 1n);
  const accepted = new Map(state.accepted);
  accepted.set(id, { ...request });
  return { state: { balances, accepted }, outcome: "Ok" };
};
