Union :: struct(TYPES: ..Type) {
    type:   Type;
    memory: [#run get_largest_type(TYPES)]u8;

    type_belongs :: (u: *Union, T: Type) -> bool {
        for type: TYPES if type == T then return true;
        return false;
    }
}

is_a :: inline (using u: *Union, $T: Type) -> bool {
    return type == T;
}

unwrap :: (using u: *Union) -> Type, *void {
    return type, memory.data;
}

set :: (using u: *Union, value: $T) {
    assert(type_belongs(u, T), "Value of type % does not exist within %", T, TYPES);

    type = T;
    (<<cast(*T)memory.data) = value;
}

get :: (using u: *Union, $T: Type) -> *T, bool {
    assert(type_belongs(u, T), "Type % does not exist within %", T, TYPES);

    if type == T then return cast(*T)memory.data, true;
    return null, false;
}


#scope_file

get_largest_type :: (types: []Type) -> s64 {
    largest := 0;

    for T: types {
        info := type_info(type_of(T));
        if info.runtime_size > largest then largest = info.runtime_size;
    }

    return largest;
}

#if RUN_INTERNAL_TESTS #run {
    suite("Union", #code {
        test("primitive types", (t: *Test) {
            u: Union(s64, u8, float64);

            set(*u, 35);
            expect(t, u.type == s64, "type was expected to be s64, instead was %", u.type);

            set(*u, cast(float64)3.14);
            expect(t, u.type == float64, "type was expected to be float64, instead was %", u.type);

            set(*u, cast(u8)255);
            expect(t, u.type == u8, "type was expected to be u8, instead was %", u.type);
        });

        test("struct types", (t: *Test) {
            Foo :: struct { a: int; };
            Bar :: struct { b: int; };

            u: Union(Foo, Bar);

            set(*u, Foo.{ 10 });
            expect(t, u.type == Foo, "type was expected to be Foo, instead was %", u.type);

            foo, f_ok := get(*u, Foo);
            expect(t, f_ok && foo.a == 10, "foo had invalid data: %", foo);

            set(*u, Bar.{ 20 });
            expect(t, u.type == Bar, "type was expected to be Bar, instead was %", u.type);

            bar, b_ok := get(*u, Bar);
            expect(t, b_ok && bar.b == 20, "bar had invalid data: %", bar);
        });

        test("union of unions", (t: *Test) {
            Base :: Union(A, B, C, D);
            A :: struct { a: int; };
            B :: struct { b: int; };
            C :: struct { c: int; };
            D :: struct { value: Union(*A, *B, *C, *D); }

            base: Base;

            set(*base, A.{ 10 });
            expect(t, base.type == A, "expected type to be A, instead was %", base.type);

            a, a_ok := get(*base, A);
            expect(t, a_ok && a.a == 10, "a had invalid data: %", a);

            set(*base, B.{ -1 });
            expect(t, base.type == B, "expected type to be B, instead was %", base.type);

            b, b_ok := get(*base, B);
            expect(t, b_ok && b.b == -1, "b had invalid data: %", b);

            {
                d: D;
                set(*d.value, *C.{ 255 });
                set(*base, d);
            }

            expect(t, base.type == D, "expected type to be D, instead was %", base.type);

            d, d_ok := get(*base, D);
            expect(t, d_ok && d.value.type == *C, "expected type to be *C, instead was", d.value.type);

            c, c_ok := get(*d.value, *C);
            expect(t, c_ok, "unable to get *C from D");
            expect(t, (<<c).c == 255, "c had invalid data: %", <<(<<c));
        });
    });
}

