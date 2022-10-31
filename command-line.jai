// @Todo:
// - API should be a single call: give it the type
// you want returned and it'll take care of the rest.
// - It should generate '-h', -help', '--help' strings
// outlining expected arguments and what values they
// can take.

parse_command_line_args :: ($T: Type, usage_str := "") -> (*T, ok: bool, err: string) {
   #insert -> string { // #modify doesn't work here?
      info := type_info(T);
      if info.type != .STRUCT {
         #import "Compiler";
         compiler_report(sprint("Expected T to be struct, instead was '%'", T), #location(T));
         return "";
      }

      outcome: String_Builder;
      append(*outcome, "arg_infos: [..]Command_Arg_Info;\n");

      for info.members {
         flag := false;
         required := false;

         print_to_builder(*outcome, "array_add(*arg_infos, .{ \"%\", false, %, % });\n", it.name, flag, required);
      }

      return to_string(*outcome);
   }

   cl_args := get_command_line_arguments();
   defer {
      free(cl_args.data);
      free(arg_infos.data);
   }

   args := cl_args;
   args.count -= 1;
   args.data  += 1;

   t := New(T);
   err := false;
   defer if err free(t);

   i := 0;
   while i < args.count {
      arg := args[i];
      print("%\n", arg);
      i += 1;
   }

   for info: arg_infos {
      if info.required && !info.set {
         err = true;
         return null, false, tprint("arg '%' is required!", info.name);
      }
   }

   return t, false, "";
}

#scope_file;

Command_Arg_Info :: struct {
   name:     string;
   set:      bool;
   flag:     bool;
   required: bool;
};

