import { applyModel } from "../interop/model";
import type { State } from "../ts/types";

const initial: State = { balances: new Map([[0n, 0n], [1n, 10n], [2n, 0n]]), accepted: new Map() };
const first = applyModel(initial, 1n, { sender: 1n, recipient: 2n, amount: 3n });
console.log(first.outcome);
const second = applyModel(first.state, 2n, { sender: 1n, recipient: 1n, amount: 1n });
console.log(second.outcome);
