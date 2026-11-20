signature forge_refundRouteAFlatTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_entry_forces_plain_user_state : thm
    val refund_entry_refuses_tagged_user_state : thm
    val refund_route_a_flat_plain_shape : thm
end
