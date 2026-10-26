import { applyModel } from "../interop/model";
import type { State } from "../ts/types";

const initial: State = { balances: new Map([[0n, 10n], [1n, 0n]]), accepted: new Map() };
const first = applyModel(initial, 1n, { sender: 0n, recipient: 1n, amount: 3n });
console.log(first.outcome);
const second = applyModel(first.state, 2n, { sender: 0n, recipient: 0n, amount: 1n });
console.log(second.outcome);
