#run {
   set_build_options_dc(.{ do_output = false });

   files := file_list(".", false, false);
   for files if lib_module(it) {
      print("Compiling '%' as a standalone module... ", it);

      content := replace(FILE_TO_COMPILE, "$name", it);
      assert(write_entire_file(FILENAME, content), "Unable to write '%'", FILENAME);

      res, out, err := run_command("jai", FILENAME, capture_and_return_output = true);
      if res.exit_code != 0 {
         print("fail!\n");
         if out.count print(out);
         if err.count print(err);
         break;
      }

      print("ok!\n");
   }

   file_delete(FILENAME);
}

lib_module :: (path: string) -> bool {
   base := path_basename(path);
   if base == "module" return false;

   return path_extension(path) == "jai" &&
          !starts_with(base, ".")       &&
          !starts_with(base, "_");
}

FILENAME :: "_test.jai";
FILE_TO_COMPILE :: #string END
#load "$name";

#run {
   set_build_options_dc(.{ do_output = false });
   write_string("$name compiles as a standalone module!\n");
}

#scope_file
#import "Compiler";
END;

#scope_file

#import "File";
#import "Basic";
#import "String";
#import "Process";
#import "Compiler";
#import "File_Utilities";
