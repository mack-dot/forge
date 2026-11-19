(* X4 DRAFT, 2026-11-19. NOT RUN. Never type-checked by Poly/ML. HOL4 at commit 9783a499 (pinned tree
   .toolchain/experiments/refund-cakeml-20261104/HOL). Expect small API fixes at the first run.

   Two parts.
   PART A (dat_guard.sml): must be the FIRST file after --holstate on the hol command line, BEFORE any
     <thy>Theory.sml is loaded. It wraps TheoryReader.load_thydata_fn so that every .dat file read from
     disk is SHA-1 hashed at load time and compared with the hash string from its Theory.sml.
     Reason: HOL does not do this. TheoryReader.sml:27-37 (load_thydata_from_dat) reads the file and calls
     Theory.link_parents (thyname, hash) with the hash STRING passed in by the generated Theory.sml
     (see e4-0001/theory-export/forge_refundSlideProfileATheory.sml: `hash = "a8f4f9be..."`).
     Theory.sml:703-723 (link_parents) compares only (name, hash-string) pairs in the theory graph
     (Theory.sml:127-148 thyid; :178 Graph.isin). Nothing recomputes SHA-1 of the file at load.
     The hook is public: TheoryReader.sig `val load_thydata_fn : (...) ref` (TheoryReader.sml:72-78).
     SHA1.sha1_file is the function HOL itself uses at export (Theory.sml:1128; SHA1.sig:5-6).
     LIMIT: theories already inside the --holstate heap are NOT re-read; the guard sees only theories
     loaded from files in this session. Heap theories are bound by the heap SHA-256 and the heap build
     record, outside this script.
   PART B (closure_export.sml): prints the export in format forge.closure-export/1 (see check_closure.py).
*)

(* ===================== PART A: dat_guard.sml ===================== *)
val forge_dat_log : (string * string * string * string) list ref = ref [];
local
  val inner = !TheoryReader.load_thydata_fn
in
  val _ = TheoryReader.load_thydata_fn :=
    (fn (r as {thyname, path, hash}) =>
       let val h = SHA1.sha1_file {filename = path}
       in forge_dat_log := (thyname, hash, h, path) :: !forge_dat_log;
          if h = hash then inner r
          else raise Fail ("FORGE_DAT_HASH_MISMATCH " ^ thyname ^ " " ^ path ^ " sml=" ^ hash ^ " file=" ^ h)
       end)
end;

(* ===================== PART B: closure_export.sml ===================== *)
(* Inputs: environment variables FORGE_THY, FORGE_THM, FORGE_STOP (comma list of theory names at which the
   definition closure stops: the HOL core and the pinned upstream CakeML/L3 theories; each such theory is
   still listed in the ANCESTOR records and bound by its .dat hash). *)
val _ = Globals.max_print_depth := ~1;     (* no "..." elision in STATEMENT_TEXT *)
val _ = Globals.show_tags := false;
fun env s = case OS.Process.getEnv s of SOME v => v | NONE => raise Fail ("missing env " ^ s);
val T = env "FORGE_THY";  val N = env "FORGE_THM";
val stop = String.tokens (fn c => c = #",") (env "FORGE_STOP");
fun stopped thy = List.exists (fn s => s = thy) stop;

val out = ref ([] : string list);
fun emit fields = out := String.concatWith "\t" fields :: !out;

(* Canonical, print-independent serialisation. Type: FinalType-sig.sml:18 dest_thy_type; is_vartype /
   dest_vartype. Term: Term.dest_term (VAR | CONST | COMB | LAMB), FinalTerm-sig.sml:47 dest_thy_const.
   Bound variables become de Bruijn indices, so alpha-equivalent terms give equal text (as aconv). *)
fun cty ty =
  if is_vartype ty then "'" ^ dest_vartype ty
  else let val {Thy, Tyop, Args} = dest_thy_type ty
       in "(" ^ String.concatWith " " ((Thy ^ "$" ^ Tyop) :: map cty Args) ^ ")" end;
fun index v [] _ = NONE
  | index v (x :: xs) i = if Term.term_eq v x then SOME i else index v xs (i + 1);
fun ctm bound tm =
  case dest_term tm of
      VAR (n, ty) => (case index tm bound 0 of
                          SOME i => "(b " ^ Int.toString i ^ ")"
                        | NONE => "(v " ^ n ^ " " ^ cty ty ^ ")")
    | CONST _ => let val {Thy, Name, Ty} = dest_thy_const tm
                 in "(c " ^ Thy ^ "$" ^ Name ^ " " ^ cty Ty ^ ")" end
    | COMB (f, x) => "(a " ^ ctm bound f ^ " " ^ ctm bound x ^ ")"
    | LAMB (v, b) => "(l " ^ cty (type_of v) ^ " " ^ ctm (v :: bound) b ^ ")";
val canon = ctm [];
fun canon_thm th = String.concatWith " " (canon (concl th) :: map canon (hyp th));

(* Tags: Tag.sml:27 dest_tag gives (oracles, axioms). For a theorem read from disk the axiom list is
   always empty (Tag.sml:76-77 read_disk_tag; Tag.sml:82-89 "axioms are not currently dumped"), so axiom
   use is checked by listing DB.axioms over the whole ancestry, not by the tag. *)
fun tagrec name th =
  let val (ors, _) = Tag.dest_tag (Thm.tag th)
  in emit ["THM_TAG", name, String.concatWith "," (Listsort.sort String.compare ors),
           Int.toString (length (hyp th))] end;

(* Target. DB.fetch: DB.sml:538. *)
val th = DB.fetch T N;
val _ = emit ["TARGET", T, N];
val _ = emit ["STATEMENT", canon_thm th];
val _ = emit ["STATEMENT_TEXT", String.toString (Parse.thm_to_string th)];
val _ = tagrec (T ^ "." ^ N) th;

(* Definition closure. Constants: HolKernel.find_terms is_const (HolKernelDoc.sig:23). Definitions of a
   theory: DB.definitions (DB.sig:30). A definition is taken as defining (Thy,Name) when its conclusion
   contains that constant. This OVER-approximates (it also takes definitions that merely mention it);
   over-approximation only makes the closure larger, never hides a definition. Constants with no such
   definition in their own theory are NODEF (primitives such as min$=, min$==>, min$@, or constructors
   whose characterising theorem is not of class Def); the exact comparison with the pinned manifest makes
   every NODEF a reviewed, pinned fact. Types: type operators with a <tyop>_TY_DEF definition in their
   theory (HOL naming used by new_type_definition and Datatype). *)
fun consts_of tm = map dest_thy_const (find_terms is_const tm);
fun tyops_of ty acc =
  if is_vartype ty then acc
  else let val {Thy, Tyop, Args} = dest_thy_type ty
       in List.foldl (fn (a, A) => tyops_of a A) ((Thy, Tyop) :: acc) Args end;
fun tyops_tm tm = List.foldl (fn (t, A) => tyops_of (type_of t) A) [] (find_terms (fn _ => true) tm);
fun mentions thy name tm =
  List.exists (fn {Thy, Name, ...} => Thy = thy andalso Name = name) (consts_of tm);

val seen_c = ref ([] : (string * string) list);
val seen_t = ref ([] : (string * string) list);
val seen_d = ref ([] : string list);
fun member x xs = List.exists (fn y => y = x) xs;

fun visit_def (dthy, dname, dth) =
  if member (dthy ^ "." ^ dname) (!seen_d) then ()
  else (seen_d := (dthy ^ "." ^ dname) :: !seen_d;
        emit ["DEF", dthy ^ "." ^ dname, canon_thm dth];
        tagrec (dthy ^ "." ^ dname) dth;
        visit_tm (concl dth))
and visit_const {Thy, Name, Ty} =
  if member (Thy, Name) (!seen_c) then ()
  else (seen_c := (Thy, Name) :: !seen_c;
        if stopped Thy then emit ["CONST", Thy ^ "$" ^ Name, cty Ty, "STOP"]
        else
          let val defs = List.filter (fn (_, d) => mentions Thy Name (concl d)) (DB.definitions Thy)
              val defs = Listsort.sort (fn ((a, _), (b, _)) => String.compare (a, b)) defs
          in if null defs then emit ["CONST", Thy ^ "$" ^ Name, cty Ty, "NODEF"]
             else (List.app (fn (dn, _) => emit ["CONST", Thy ^ "$" ^ Name, cty Ty, "DEF " ^ Thy ^ "." ^ dn]) defs;
                   List.app (fn (dn, d) => visit_def (Thy, dn, d)) defs)
          end)
and visit_type (thy, tyop) =
  if member (thy, tyop) (!seen_t) then ()
  else (seen_t := (thy, tyop) :: !seen_t;
        if stopped thy then emit ["TYPE", thy ^ "$" ^ tyop, "STOP"]
        else case List.find (fn (n, _) => n = tyop ^ "_TY_DEF") (DB.definitions thy) of
                 SOME (n, d) => (emit ["TYPE", thy ^ "$" ^ tyop, "DEF " ^ thy ^ "." ^ n]; visit_def (thy, n, d))
               | NONE => emit ["TYPE", thy ^ "$" ^ tyop, "NODEF"])
and visit_tm tm = (List.app visit_const (consts_of tm); List.app visit_type (tyops_tm tm));

val _ = List.app visit_tm (concl th :: hyp th);

(* Ancestry. Theory.ancestry (Theory.sig:45, Theory.sml:334 via Graph.ancestryl), Theory.parents
   (Theory.sig:44), Theory.hash (Theory.sig:42, Theory.sml:306/325: the hash STRING in the graph).
   The ancestor list includes STOP theories; each is bound by its .dat hash in the manifest. *)
val closure = T :: Theory.ancestry T;
val _ = List.app (fn n =>
          emit ["ANCESTOR", n, Theory.hash n,
                String.concatWith "," (Listsort.sort String.compare (Theory.parents n))]) closure;

(* Axioms over the whole ancestry: DB.axioms (DB.sig:28), class Axm (Theory.sml:300). *)
val _ = List.app (fn n => List.app (fn (a, ax) => emit ["AXIOM", n ^ "." ^ a, canon (concl ax)]) (DB.axioms n)) closure;

(* Files read by the guard in this session (PART A). *)
val _ = List.app (fn (t, _, h, p) => emit ["LOADED_DAT", t, h, p]) (rev (!forge_dat_log));

(* Stable order: sort all records except the header and footer; then write. *)
val body = Listsort.sort String.compare (!out);
val lines = ("FORMAT\tforge.closure-export/1") :: body;
val _ = List.app (fn l => print (l ^ "\n")) lines;
val _ = print ("END\t" ^ Int.toString (length lines) ^ "\n");
val _ = print "CLOSURE_EXPORT_COMPLETE\n";   (* marker line; strip it (and HOL banner lines) before check_closure.py *)
val _ = OS.Process.exit OS.Process.success;

(* KNOWN GAPS of this draft (to fix at the first run):
   - Kernel compute (cv_compute) leaves no tag (std-thm.ML:1533-1559: the new theorem's tag is only the
     merge of the tags of its input equations). The export cannot show that a theorem used compute.
     The trusted base therefore includes src/thm/Compute.sml. Count.Compute (Count.sig) counts uses per
     SESSION only, so it cannot be read back for theorems loaded from disk.
   - Thm.disk_thm is public (FinalThm-sig.sml:150). Any ML code in the session can make a theorem whose tag
     is only DISK_THM. The export shows what is in the DB; it cannot show that a .dat came from a proof.
     That is why the .dat bytes must come from a replay by a second operator.
   - Definitions with a name that does not hold the constant (for example records, Datatype internals,
     or constants made by new_specification under another name) are caught by the "mentions" rule; constants
     defined only through theorems of class Thm (not Def) come out NODEF and must be reviewed by name.
   - Output goes to stdout with HOL messages mixed in; the runner must keep only lines whose first field
     is one of the record kinds. *)
