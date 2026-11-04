e (xcf "dfy_Refund" st);
e (xlet ‘POSTv v0. REF v0 (Litv (StrLit charge))’);
e xref;
e xsimpl;
val _ = print (Parse.term_to_string (snd (top_goal ())) ^ "\n");
OS.Process.exit OS.Process.success;
