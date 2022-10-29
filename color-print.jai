Foreground_Color :: enum u8 {
   Black  :: 30;
   Red    :: 31;
   Green  :: 32;
   Orange :: 33;
   Blue   :: 34;
}

Background_Color :: enum u8 {
   Black  :: 40;
   Red    :: 41;
   Green  :: 42;
   Orange :: 43;
   Blue   :: 44;
}

Text_Style :: enum u8 {
   Bold      :: 1;
   Dim       :: 2;
   Italic    :: 3;
   Underline :: 4;
   Blink     :: 5;
   Invert    :: 7;
   Strike    :: 9;
}

// @Todo(Judah): Windows shouldn't rely on ANSI sequences sadly...
// @Note(Judah): Maybe make 'format_string' $$ so we can do search/replace at compile-time
color_print :: (format_string: string, args: ..Any, stderr := false) -> int {
   builder: String_Builder;
   builder.allocator = temporary_allocator;
   print_to_builder(*builder, format_string, ..args);

   pre_expanded := builder_to_string(*builder, allocator = temporary_allocator, do_reset = true);

   cursor := 0;
   while cursor < pre_expanded.count {
      chr := pre_expanded.data[cursor];
      if chr == {
         case #char "@";
            cursor += 1;
            if cursor >= pre_expanded.count && context.print_style.log_runtime_errors {
               log_error("Expected style declaration after @ at character %", cursor);
               return 0;
            }

            fore:   Foreground_Color;
            back:   Background_Color;
            styles: Text_Style;

            style := pre_expanded;
            style.data  += cursor;
            style.count  = 0;

            // Get all styles for the next string
            set_background := false;
            while cursor < pre_expanded.count {
               chr := pre_expanded.data[cursor];
               if chr == #char "," || chr == #char "{" {
                  if style == {
                     case "black";
                        if set_background then back = .Black; else fore = .Black;
                        set_background = !set_background;
                     case "red";
                        if set_background then back = .Red; else fore = .Red;
                        set_background = !set_background;
                     case "green";
                        if set_background then back = .Green; else fore = .Green;
                        set_background = !set_background;
                     case "blue";
                        if set_background then back = .Blue; else fore = .Blue;
                        set_background = !set_background;

                     case "yellow"; #through;
                     case "orange";
                        if set_background then back = .Orange; else fore = .Orange;
                        set_background = !set_background;

                     case "bold";
                        styles = .Bold;
                     case "dim";
                        styles = .Dim;
                     case "italic";
                        styles = .Italic;
                     case "ul"; #through;
                     case "underline";
                        styles = .Underline;
                     case "blink";
                        styles = .Blink;
                     case "invert";
                        styles = .Invert;
                     case "strike";
                        styles = .Strike;

                     case;
                        if (!style.count || style == "_") && styles == 0 {
                           set_background = true;
                        }
                        else if context.print_style.log_runtime_errors {
                           log_error("Unknown style directive '%' at character %", style, cursor);
                           return -1;
                        }
                  }

                  if chr == #char "{" {
                     cursor += 1;
                     break;
                  }

                  cursor += 1;
                  style.data += style.count + 1;
                  style.count = 0;
                  continue;
               }

               cursor      += 1;
               style.count += 1;
            }

            // Push the style and inner string

            append(*builder, "\e[");
            if fore   then print_to_builder(*builder, "%", cast(u8)fore);
            if back   then print_to_builder(*builder, ";%", cast(u8)back);
            if styles then print_to_builder(*builder, ";%", cast(u8)styles);
            append(*builder, "m");

            while cursor < pre_expanded.count {
               chr := pre_expanded.data[cursor];
               if chr == {
                  case #char "\\";
                     cursor += 1;
                     if cursor >= pre_expanded.count && context.print_style.log_runtime_errors {
                        log_error("Empty escape sequence at character %", cursor);
                        return -1;
                     }

                     if pre_expanded.data[cursor] == {
                        case #char "{"; #through;
                        case #char "}";
                           append(*builder, pre_expanded.data[cursor]);
                           cursor += 1;
                           continue;
                     }

                  case #char "}";
                     break;
               }

               append(*builder, chr);
               cursor += 1;
            }

            append(*builder, "\e[0;m");
         case;
            append(*builder, chr);
      }

      cursor += 1;
   }

   return write_builder(*builder, to_standard_error = stderr);
} @PrintLike


#scope_file;

is_letter :: (chr: u8) -> bool {
   return chr >= #char "a" && chr <= #char "z" ||
          chr >= #char "A" && chr <= #char "Z";
}



