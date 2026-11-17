(* Lab-level static checks. *)
val asm_no_label_def = Define `
  asm_no_label (ls:num list) a =
    case a of
      labLang$Jump (Lab n1 _) => ~MEM n1 ls
    | JumpCmp _ _ _ (Lab n1 _) => ~MEM n1 ls
    | Call (Lab n1 _) => ~MEM n1 ls
    | LocValue _ (Lab n1 _) => ~MEM n1 ls
    | _ => T`;
val line_no_label_def = Define `
  line_no_label ls l = case l of LabAsm a _ _ _ => asm_no_label ls a | _ => T`;
val line_is_exit_def = Define `
  line_is_exit l = case l of
      LabAsm (Jump _) _ _ _ => T
    | LabAsm Halt _ _ _ => T
    | Asm (Asmi (JumpReg _)) _ _ => T
    | _ => F`;
val is_label_def = Define `is_label l = case l of Label _ _ _ => T | _ => F`;
val sec_ends_exit_def = Define `
  sec_ends_exit sec = case REVERSE (FILTER (\l. ~is_label l) (Section_lines sec)) of [] => F | l::_ => line_is_exit l`;
val no_fall_def = Define `
  (no_fall (ls:num list) [] = T) /\
  (no_fall ls [s] = T) /\
  (no_fall ls (s1::s2::rest) =
     ((MEM (Section_num s2) ls /\ ~MEM (Section_num s1) ls ==> sec_ends_exit s1) /\ no_fall ls (s2::rest)))`;
val lab_closed_def = Define `
  lab_closed ls secs <=>
    EVERY (\sec. MEM (Section_num sec) ls \/ EVERY (line_no_label ls) (Section_lines sec)) secs /\
    (case secs of [] => T | s::_ => ~MEM (Section_num s) ls) /\
    no_fall ls secs`;
val line_is_install_def = Define `line_is_install l = case l of LabAsm Install _ _ _ => T | _ => F`;
val line_is_jumpreg_def = Define `line_is_jumpreg l = case l of Asm (Asmi (JumpReg _)) _ _ => T | _ => F`;
val line_is_locvalue_def = Define `line_is_locvalue l = case l of LabAsm (LocValue _ _) _ _ _ => T | _ => F`;
val lab_stats_def = Define `
  lab_stats secs =
    (LENGTH secs,
     MAP Section_num (FILTER (\sec. EXISTS line_is_install (Section_lines sec)) secs),
     SUM (MAP (\sec. LENGTH (FILTER line_is_jumpreg (Section_lines sec))) secs),
     SUM (MAP (\sec. LENGTH (FILTER line_is_locvalue (Section_lines sec))) secs),
     MAP Section_num (FILTER (\sec. ~EVERY (line_no_label [29;31]) (Section_lines sec)) secs))`;
val lab_names_def = Define `lab_names secs = MAP Section_num secs`;
val lab_check_def = Define `lab_check ls c p = case lab_forge8 c p of NONE => F | SOME L => lab_closed ls L`;
val lab_info_def = Define `lab_info c p = case lab_forge8 c p of NONE => NONE | SOME L => SOME (lab_stats L, TAKE 40 (lab_names L))`;
