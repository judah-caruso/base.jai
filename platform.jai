#if OS == .WINDOWS {
   PLATFORM_SEPARATOR :: "\\";
} else {
   PLATFORM_SEPARATOR :: "/";
}

/*
Rel_Path :: struct {
   path:      string;
   flags:     Path_Flags;
   extension: string;
}

Path_Flags :: Bit_Set(Path_Flag);

Path_Flag :: enum_flags {
   File;
   Directory;
   Exists;
}

to_path :: (sub_dir: string) -> Rel_Path {
}

operator+ :: (lhs: Rel_Path, rhs: string) -> Rel_Path {
}

operator+ :: (lhs: Rel_Path, rhs: Rel_Path) -> Rel_Path {
}

to_string :: (rel: *Rel_Path) -> string {
   return rel.path;
}
*/
