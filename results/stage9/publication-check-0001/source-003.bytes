From LinuxProcessSemantics.LinuxProcessSem Require Import MemImageType.
From OssFuzzTheorems.Core Require Import Images.
From Forge.Binary.images Require Program.

Definition program : Image :=
  mkImage Program.M.loaded_segments Program.M.init_pc Program.M.phdrs.

Lemma program_wf : image_wf program.
Proof. check_image_wf. Qed.
