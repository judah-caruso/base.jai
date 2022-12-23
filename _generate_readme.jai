#run {
   set_build_options_dc(.{ do_output = false });

   print("Creating readme from doc comments in modules... ");

   builder: String_Builder;
   modules: [..]string;
   files := file_list(".", false, false);
   for files if lib_module(it) array_add(*modules, it);

   sorted := quick_sort(modules, (l: string, r: string) -> int {
      if l[0] > r[0] {
         return -1;
      }
      return 1;
   });

   for sorted {
      file, ok := read_entire_file(it);
      assert(ok, "Unable to read %", it);
      doc_comments: [..]string;

      lines := split(file, "\n");
      for lines {
         if !starts_with(it, "///") break;
         array_add(*doc_comments, trim(replace(it, "///", "")));
      }

      desc := join(..doc_comments, " ");
      print_to_builder(*builder, "   - %.jai (%)\n", path_basename(it), desc);
   }

   str := sprint(README, builder_to_string(*builder));
   if write_entire_file("README", str) {
      print("ok!\n");
   } else {
      print("fail!\n");
   }
}

lib_module :: (path: string) -> bool {
   if !path.count return false;

   base := path_basename(path);
   if base == "module" return false;

   return path_extension(path) == "jai" &&
          !starts_with(base, ".")       &&
          !starts_with(base, "_");
}

README :: #string END
Base

   My personal library for Jai. For the most
   part, each module can be copy-pasted into
   your project without having to pull in the
   entire library.


Modules

%

Notes

   - To run the internal testing suite: 'jai _run_all_tests.jai'
   - To verify modules work standalone: 'jai _ensure_standalone.jai'
   - To generate this README file: 'jai _generate_readme.jai'


Installation

   Copy files as needed or clone the entire repo:
      #import,file "[name].jai";      // Use a single module
      #import,file "base/module.jai"; // Use the entire library


License - Unlicense (Public Domain)
    See LICENSE for full notice

END;

#import "File";
#import "Sort";
#import "Basic";
#import "String";
#import "Compiler";
#import "File_Utilities";
