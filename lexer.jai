/// General purpose lexing

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

#import,file "utilities.jai";

#import "String";
#import "Unicode";
#import "Sloppy_Math";
