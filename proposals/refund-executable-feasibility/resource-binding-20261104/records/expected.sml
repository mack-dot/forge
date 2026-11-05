open preamble;
val expected_config = ``
  find_name (backend$set_oracle arm8_config$arm8_backend_config oracle).stack_conf.reg_names 2 = 1 /\
  find_name (backend$set_oracle arm8_config$arm8_backend_config oracle).stack_conf.reg_names 3 = 2 /\
  find_name (backend$set_oracle arm8_config$arm8_backend_config oracle).stack_conf.reg_names 4 = 3 /\
  2 * max_heap_limit 64 (backend$set_oracle arm8_config$arm8_backend_config oracle).data_conf - 1 = 9007199254740991``;
val expected_limits = ``
  stack_removeProof$get_stack_heap_limit 9007199254740991
    (496542679040w,496811114496w,497079549952w:word64) = (33554384,16777216)``;
val expected_read_limits = ``
  (mc.target.get_reg ms 1:word64) = 496542679040w /\
  mc.target.get_reg ms 2 = 496811114496w /\
  mc.target.get_reg ms 3 = 497079549952w ==>
  backendProof$read_limits arm8_target$arm8_config
    (backend$set_oracle arm8_config$arm8_backend_config oracle) mc ms = (33554384,16777216)``;
