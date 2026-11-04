val (asl,g) = top_goal();
val _ = List.app (fn t => print (Parse.term_to_string t ^ "\n---\n")) asl;
print ("GOAL " ^ Parse.term_to_string g ^ "\n");
OS.Process.exit OS.Process.success;
