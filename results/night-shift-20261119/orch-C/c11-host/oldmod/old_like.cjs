// model of the demo's module (impl/RefundFinality.dfy + REFUND_FOOTER): the same exports WITHOUT IssueBytes2.
const m = require("/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs");
module.exports = { RefundFinality: m.RefundFinality, Refund: m.Refund, runtime: m.runtime };
