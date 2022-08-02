/// Lexer is a general purpose lexing module for turning plaintext
/// into an array of user-defined tokens. Below is a standard usage guide:

/*
    A lexer can be instantiated like so:
        lexer: Lexer;

    By default it uses predefined values for:
        - classes of tokens (TOKEN_KIND)
        - how the classes are mapped to Jai values (TOKEN_VALUE)
        - if unicode is valid in the source text (UNICODE)
        - if whitespace should be ignored (IGNORE_WHITESPACE)

    Lexer makes no notion of how tokens are captured, and only
    makes assumptions (which can be overridden) about what
    whitespace and newlines are.

    The capturing and classification of tokens is done via
    'Handlers' implemented through:
        - a predicate: what constitues a valid starting token for the scanner
        - a scanner: what a valid capture is from the point of the predicate

    Handlers are created with 'register_handler.' An example handler for
    scanning identifiers could be implemented like so:

        register_handler(*lexer, starts_identifier, (lexer: *$L) {
            identifier := capture_while(lexer, continues_identifier);

            token := array_add(*lexer.tokens);
            token.kind    = .Identifier;
            token._string = identifier;
        });

        starts_identifier :: (char: u8) -> bool {
            return is_lettr(char) || char == #char "_";
        }

        continues_identifier :: (char: u8) -> bool {
            return starts_identifier(char) || is_number(char);
        }

    Handlers are checked *in order* of their registration, so precedence
    is defined through the order in which 'register_handler' is called.

    Once all handlers are registered, the lexing process can be started
    via 'lex' like so:

        ok := lex(*lexer);
        if !ok {
            // errors occured during lexing
            // and can be formatted/output through lexer.errors
        }

    For more examples, take a look at the test suite below.
*/

Lexer :: struct(
    TOKEN_VALUE       := Default_Value,
    TOKEN_KIND        := Default_Kind,
    UNICODE           := true,
    IGNORE_WHITESPACE := true)
{
    source:   string;
    tokens:   [..]Token;
    handlers: [..]Handler;
    errors:   [..]Error;
    position: Position;

    #if UNICODE {
        current: rune;
    }
    else {
        current: u8;
    }

    Token :: struct {
        kind:        TOKEN_KIND;
        using value: TOKEN_VALUE;
    }

    Handler :: struct {
        predicate: Predicate;
        scanner:   Scanner;
    }

    Error :: struct {
        message:  string;
        hints:    [..]string;
        position: Position;
    }

    Position :: struct {
        filename: string;
        line:     int = 1;
        column:   int = 1;

        source: struct {
            data:  *u8;
            start: int;
            end:   int;
        };
    }

    Scanner :: #type (lexer: *Lexer(TOKEN_VALUE, TOKEN_KIND, UNICODE, IGNORE_WHITESPACE)) -> (ok: bool);

    #if UNICODE {
        Predicate :: #type (lexeme: rune) -> bool;
    }
    else {
        Predicate :: #type (lexeme: u8) -> bool;
    }
}

Default_Kind :: enum {
    Invalid;
    Bool;
    Rune;
    Byte;
    Integer;
    Float;
    String;
    Identifier;
}

Default_Value :: union {
    _bool:   bool;
    _byte:   u8;
    _rune:   rune;
    _string: string;
    _int:    s64;
    _float:  float64;
}

register_handler :: (lexer: *Lexer, predicate: lexer.Predicate, scanner: lexer.Scanner) {
    handler := array_add(*lexer.handlers);
    handler.predicate = predicate;
    handler.scanner   = scanner;
}

lex :: (lexer: *Lexer, filename: string) -> (ok: bool) {
    contents, ok := read_entire_file(file);
    if !ok {
        error(lexer, "Unable to read file '%'", filename);
        return false;
    }

    lexer.source = contents;
    return lex(lexer);
}

lex :: (lexer: *Lexer) -> (ok: bool) {
    decl_peek(lexer);

    while lexer.source.count {
        #if lexer.IGNORE_WHITESPACE skip_while(lexer, is_whitespace);
        if !lexer.source.count break;

        token := peek(lexer);
        had_valid_handler := false;
        for handler: lexer.handlers if handler.predicate(token) {
            if !handler.scanner(lexer) return false;
            had_valid_handler = true;
            break handler;
        }

        if !had_valid_handler {
            error(lexer, sprint("Unexpected character '%'", to_string(token)));
            return false;
        }
    }

    return true;
}

error :: (lexer: *Lexer, message: string, hints: ..string) {
    error := array_add(*lexer.errors);
    error.message = message;
    array_add(*error.hints, ..hints);
}

capture_while :: (lexer: *Lexer, predicate: lexer.Predicate) -> string {
    decl_peek(lexer);
    decl_next(lexer);

    builder: String_Builder;
    while lexer.source.count {
        token := peek(lexer);
        if !predicate(token) break;
        append(*builder, to_string(token));
        next(lexer);
    }

    return builder_to_string(*builder);
}

skip_while :: (lexer: *Lexer, predicate: lexer.Predicate) {
    decl_peek(lexer);
    decl_next(lexer);

    while lexer.source.count {
        token := peek(lexer);
        if !predicate(token) break;
        next(lexer);
    }
}

decl_next :: (lexer: *Lexer) #expand {
    #if lexer.UNICODE {
        `next :: next_rune;
    }
    else {
        `next :: next_char;
    }
}

next_rune :: (lexer: *Lexer) -> rune, bool {
    rune, width, status := character_utf8_to_utf32(lexer.source.data, lexer.source.count);
    if status != .CONVERSION_OK {
        return 0, false;
    }

    if rune == #char "\n" {
        lexer.position.line  += 1;
        lexer.position.column = 1;
    }
    else {
        lexer.position.column += 1;
    }

    lexer.current       = rune;
    lexer.source.data  += width;
    lexer.source.count -= width;

    return rune, true;
}

next_char :: (lexer: *Lexer) -> u8, bool {
    if !lexer.source.count return 0, false;

    char := lexer.source.data[0];
    if char == #char "\n" {
        lexer.position.line  += 1;
        lexer.position.column = 1;
    }
    else {
        lexer.position.column += 1;
    }

    lexer.current       = char;
    lexer.source.data  += 1;
    lexer.source.count -= 1;

    return char, true;
}

decl_peek :: (lexer: *Lexer) #expand {
    #if lexer.UNICODE {
        `peek :: peek_rune;
    }
    else {
        `peek :: peek_char;
    }
}

peek_rune :: (lexer: *Lexer) -> rune, bool {
    rune, width, status := character_utf8_to_utf32(lexer.source.data, lexer.source.count);
    if status != .CONVERSION_OK return 0, false;
    lexer.current = rune;
    return rune, true;
}

peek_char :: (lexer: *Lexer) -> u8, bool {
    if !lexer.source.count return 0, false;
    char := lexer.source.data[0];
    lexer.current = char;
    return char, true;
}

// @TODO: Make this more robust for unicode
is_whitespace :: (r: rune) -> bool {
    return r == #char " "  ||
           r == #char "\t" ||
           r == #char "\n";
};

// @NOTE: Maybe add vertical tab?
is_whitespace :: (chr: u8) -> bool {
    return chr == #char " "  ||
           chr == #char "\t" ||
           chr == #char "\n";
};


#scope_file

#if RUN_INTERNAL_TESTS #run {
    suite("Lexer", #code {
        test("empty", (t: *Test) {
            lexer: Lexer;
            lexer.source = ". int { foo }";

            ok := lex(*lexer);
            expect(t, !ok, "empty lexer had no handlers and should've failed");
            expect(t, lexer.errors.count, "empty lexer failed but had no errors");
            expect(t, !lexer.tokens.count, "empty lexer should not produce tokens");
        });

        test("unicode", (t: *Test) {
            lexer: Lexer;
            lexer.source = "hello, world 123 3.14";

            is_letter :: (r: rune) -> bool {
                return r >= #char "a" && r <= #char "z" ||
                       r >= #char "A" && r <= #char "Z";
            }

            is_number :: (r: rune) -> bool {
                return r >= #char "0" && r <= #char "9";
            }

            register_handler(*lexer, is_letter, (lexer: *$L) -> bool {
                identifier := capture_while(lexer, (chr) =>
                    is_letter(chr) ||
                    is_number(chr) ||
                    chr == #char "_"
                );

                if identifier.count <= 0 {
                    return false;
                }

                token := array_add(*lexer.tokens);
                token.kind    = .Identifier;
                token._string = identifier;
                return true;
            });

            register_handler(*lexer, is_number, (lexer: *$L) -> bool {
                number := capture_while(lexer, (chr) =>
                    is_number(chr)   ||
                    chr == #char "." ||
                    chr == #char "_"
                );

                if number.count <= 0 {
                    return false;
                }

                is_float := false;
                for :iter_runes number if it == #char "." {
                    is_float = true;
                }

                token := array_add(*lexer.tokens);
                if is_float {
                    token.kind = .Float;

                    _float, ok := parse_float(*number);
                    if !ok return false;

                    token._float = _float;
                }
                else {
                    token.kind = .Integer;

                    _int, ok := parse_int(*number);
                    if !ok return false;

                    token._int = _int;
                }

                return true;
            });

            register_handler(*lexer, (chr) => !is_whitespace(chr), (lexer: *$L) -> bool {
                token := array_add(*lexer.tokens);
                token.kind  = .Rune;
                token._rune = next_rune(lexer);
                return true;
            });

            expect(t, lex(*lexer), "lexing failed with these errors: %", lexer.errors);
            expect(t, lexer.tokens.count == 5, "lexing produced too many tokens: %", lexer.tokens.count);

            expect(t, lexer.tokens[0].kind    == .Identifier, "expected 0th token to be an Identifier, instead was %", lexer.tokens[0].kind);
            expect(t, lexer.tokens[0]._string == "hello", "expected 0th token to equal 'hello', instead was '%'", lexer.tokens[0]._string);

            expect(t, lexer.tokens[1].kind  == .Rune, "expected 1st token to be a Rune, instead was %", lexer.tokens[1].kind);
            expect(t, lexer.tokens[1]._rune == #char ",", "expected 1st token to equal ',', instead was '%'", to_string(lexer.tokens[1]._rune));

            expect(t, lexer.tokens[2].kind    == .Identifier, "expected 2nd token to be an Identifier, instead was %", lexer.tokens[2].kind);
            expect(t, lexer.tokens[2]._string == "world", "expected 2nd token to equal 'world', instead was '%'", lexer.tokens[2]._string);

            expect(t, lexer.tokens[3].kind == .Integer, "expected 3rd token to be an Integer, instead was %", lexer.tokens[3].kind);
            expect(t, lexer.tokens[3]._int == 123, "expected 3rd token to equal 123, instead was '%'", lexer.tokens[3]._int);

            expect(t, lexer.tokens[4].kind   == .Float, "expected 4th token to be a Float, instead was %", lexer.tokens[4].kind);
            expect(t, lexer.tokens[4]._float - 3.14 <= 0.1, "expected 4th token to approximately equal 3.14, instead was '%'", lexer.tokens[4]._float);
        });

        test("ascii", (t: *Test) {
            is_letter :: (chr: u8) -> bool {
                return chr >= #char "a" && chr <= #char "z" ||
                       chr >= #char "A" && chr <= #char "Z";
            }

            is_number :: (chr: u8) -> bool {
                return chr >= #char "0" && chr <= #char "9";
            }

            Kind :: enum {
                None;
                Character;
                Identifier;
                Float;
                Integer;
            }

            Value :: union {
                _char:   u8;
                _string: string;
                _float:  float64;
                _int:    s64;
            }

            lexer: Lexer(TOKEN_VALUE = Value, TOKEN_KIND = Kind, UNICODE = false);
            lexer.source = "hello, world 123 3.14";

            register_handler(*lexer, is_letter, (lexer: *$L) -> bool {
                identifier := capture_while(lexer, (chr) =>
                    is_letter(chr) ||
                    is_number(chr) ||
                    chr == #char "_"
                );

                if identifier.count <= 0 {
                    return false;
                }

                token := array_add(*lexer.tokens);
                token.kind    = .Identifier;
                token._string = identifier;
                return true;
            });

            register_handler(*lexer, is_number, (lexer: *$L) -> bool {
                number := capture_while(lexer, (chr) =>
                    is_number(chr)   ||
                    chr == #char "." ||
                    chr == #char "_"
                );

                if number.count <= 0 {
                    return false;
                }

                is_float := false;
                for :iter_ascii number if it == #char "." {
                    is_float = true;
                }

                token := array_add(*lexer.tokens);
                if is_float {
                    token.kind = .Float;

                    _float, ok := parse_float(*number);
                    if !ok return false;

                    token._float = _float;
                }
                else {
                    token.kind = .Integer;

                    _int, ok := parse_int(*number);
                    if !ok return false;

                    token._int = _int;
                }

                return true;
            });

            register_handler(*lexer, (chr) => !is_whitespace(chr), (lexer: *$L) -> bool {
                token := array_add(*lexer.tokens);
                token.kind  = .Character;
                token._char = next_char(lexer);
                return true;
            });

            expect(t, lex(*lexer), "lexing failed with these errors: %", lexer.errors);
            expect(t, lexer.tokens.count == 5, "lexing produced too many tokens: %", lexer.tokens.count);

            expect(t, lexer.tokens[0].kind    == .Identifier, "expected 0th token to be an Identifier, instead was %", lexer.tokens[0].kind);
            expect(t, lexer.tokens[0]._string == "hello", "expected 0th token to equal 'hello', instead was '%'", lexer.tokens[0]._string);

            expect(t, lexer.tokens[1].kind  == .Character, "expected 1st token to be a Character, instead was %", lexer.tokens[1].kind);
            expect(t, lexer.tokens[1]._char == #char ",", "expected 1st token to equal ',', instead was '%'", to_string(lexer.tokens[1]._char));

            expect(t, lexer.tokens[2].kind    == .Identifier, "expected 2nd token to be an Identifier, instead was %", lexer.tokens[2].kind);
            expect(t, lexer.tokens[2]._string == "world", "expected 2nd token to equal 'world', instead was '%'", lexer.tokens[2]._string);

            expect(t, lexer.tokens[3].kind == .Integer, "expected 3rd token to be an Integer, instead was %", lexer.tokens[3].kind);
            expect(t, lexer.tokens[3]._int == 123, "expected 3rd token to equal 123, instead was '%'", lexer.tokens[3]._int);

            expect(t, lexer.tokens[4].kind   == .Float, "expected 4th token to be a Float, instead was %", lexer.tokens[4].kind);
            expect(t, lexer.tokens[4]._float - 3.14 <= 0.1, "expected 4th token to approximately equal 3.14, instead was '%'", lexer.tokens[4]._float);
        });
    });
}

#import "Unicode";
#import "Sloppy_Math";
