e (xcf "dfy_Refund" st);
val ts = [(xlet ‘POSTv v0. REF v0 (Litv (StrLit charge))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v1. REF v1 (Litv (StrLit request))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v2. REF v2 (Litv (IntLit original))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v3. REF v3 (Litv (IntLit remaining))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v4. REF v4 (Boolv enabled)’ >- (xref >> xsimpl)),
(xlet ‘POSTv v5. REF v5 (Boolv opened)’ >- (xref >> xsimpl)),
(xlet ‘POSTv v6. REF v6 (Boolv candidate)’ >- (xref >> xsimpl)),
(xlet ‘POSTv v7. REF v7 (Litv (IntLit amount))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v8. REF v8 (Litv (StrLit reason))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v9. REF v9 (Litv (IntLit 0))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v10. REF v10 (Litv (IntLit 0))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v11. REF v11 (Litv (IntLit 0))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v12. REF v12 (Litv (IntLit 0))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v13. REF v13 (Litv (IntLit 0))’ >- (xref >> xsimpl)),
(xlet ‘POSTv v14. REF v14 (Litv (IntLit 0))’ >- (xref >> xsimpl))];
val _ = (List.app (fn (i,t) => (print ("STEP " ^ Int.toString i ^ "\n"); e t; ())) (Lib.enumerate 0 ts)) handle e => (print (General.exnMessage e ^ "\n"); print (Parse.term_to_string (snd (top_goal ())) ^ "\n"));
OS.Process.exit OS.Process.success;
