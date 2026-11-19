# A19 L2c (condensed by Orchestrator A; NOT RUN when written)
`routeA-L2c.sml` (ca624cc5…), case L2c-0001: defines `VokY3` and `refund_valid_event`; R4 `refund_valid_event_gives_VokY3`;
bridge `refund_events_premise_gives_l2r_third_premise`; assembly `refund_profile_a_sl_events` = `refund_profile_a_sl_reach`
at `Vok := VokY3` with premise 3 replaced by R6 (every io event of every finite run of the totalised machine is a valid
read or write event). R3 is not needed. Worker's estimate of a first-run export: 15–25 %.
What R6/L3 still needs: a source-level event invariant for the TextIO functions the program uses
(TextIOProgScript.sml:379 read_into; :182, :201 writei/output), and the transfer to every clock (machine_sem, io-event
monotonicity lemmas in targetPropsScript.sml:1078, 1108, 1134).
