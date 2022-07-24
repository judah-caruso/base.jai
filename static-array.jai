Static_Array :: struct(CAPACITY: int, T: Type) {
    elements: [CAPACITY]T;
    count: int;

    _zero_value : T = ---; // 'Private' value used when removing
}

array_add :: inline (array: *Static_Array, element: array.T) {
    ensure_array_has_room(array, 1);
    array.elements[array.count] = element;
    array.count += 1;
}

array_add :: inline (array: *Static_Array) -> *array.T {
    ensure_array_has_room(array, 1);
    defer array.count += 1;
    return *array.elements[array.count];
}

array_add :: inline (array: *Static_Array, to_append: ..array.T) {
    ensure_array_has_room(array, to_append.count);
    memcpy(array.elements.data + array.count, to_append.data, to_append.count * size_of(array.T));
    array.count += to_append.count;
}

array_reset_keeping_memory :: inline (array: *Static_Array) {
    array.count = 0;
}

array_reset :: inline (array: *Static_Array) {
    for 0..array.count - 1 array.elements[it] = array._zero_value;
    array.count = 0;
}

array_ordered_remove_by_value :: inline (array: *Static_Array, value: array.T) {
    for array if it == value {
        array_ordered_remove_by_index(array, it_index);
        return;
    }
}

array_ordered_remove_by_index :: inline (array: *Static_Array, index: int) {
    assert(index >= 0, "Invalid index: %", index);
    assert(index < array.CAPACITY && index < array.count, "Invalid index: % (count: %, capacity: %)", index, array.count, array.CAPACITY);

    for index..array.count - 2 {
        array.elements[it]     = array.elements[it + 1];
        array.elements[it + 1] = array._zero_value;
    }

    array.count -= 1;
}

array_unordered_remove_by_index :: inline (array: *Static_Array, index: int) {
    assert(index >= 0, "Invalid index: %", index);
    assert(index < array.CAPACITY && index < array.count, "Invalid index: % (count: %, capacity: %)", index, array.count, array.CAPACITY);

    if array.count > 1 && index != array.count - 1 {
        array.elements[index]           = array.elements[array.count - 1];
        array.elements[array.count - 1] = array._zero_value;
    }

    array.count -= 1;
}

array_ordered_remove_by_pointer :: inline (array: *Static_Array, item: *array.T) {
    for * array if it == item {
        array_ordered_remove_by_index(array, it_index);
        return;
    }
}

array_unordered_remove_by_pointer :: inline (array: *Static_Array, item: *array.T) {
    for * array if it == item {
        array_unordered_remove_by_index(array, it_index);
        return;
    }
}

array_find :: inline (array: Static_Array, item: array.T) -> bool, s64 {
    for array if it == item return true, it_index;
    return false, -1;
}

array_add_if_unique :: inline (array: *Static_Array, item: array.T) -> bool, s64 {
    found, index := array_find(<<array, item);
    if found return false, index;

    array_add(array, item);
    return true, array.count - 1;
}

array_to_dynamic :: (array: *Static_Array, allocator := context.allocator) -> [..]array.T {
    result: [..]array.T;

    result.count     = array.count;
    result.allocated = array.count;
    result.allocator = allocator;
    result.data      = alloc(array.count * size_of(array.T), allocator);
    memcpy(result.data, array.elements.data, array.count * size_of(array.T));

    return result;
}

push :: array_add;

pop :: inline (array: *Static_Array) -> array.T {
    assert(array.count >= 1, "Tried to pop too many elements");

    defer {
        array.elements[array.count - 1] = array._zero_value;
        array.count -= 1;
    }

    return array.elements[array.count - 1];
}

pop_pointer :: inline (array: *Static_Array) -> *array.T {
    assert(array.count >= 1, "Tried to pop too many elements");
    defer array.count -= 1;
    return *array.elements[array.count - 1];
}

for_expansion :: (array: *Static_Array, body: Code, flags: For_Flags) #expand {
    iter := cast([]array.T)array.elements;
    iter.count = array.count;

    for *=(flags & .POINTER == .POINTER) <=(flags & .REVERSE == .REVERSE) `it, `it_index: iter {
        #insert(break=break it) body;
    }
}

operator [] :: inline (array: Static_Array, index: int) -> array.T {
    assert(index >= 0 && index < array.count, "Invalid index: % (max: %)", index, array.count - 1);
    return array.elements[index];
}


#scope_file

ensure_array_has_room :: (array: *Static_Array, count: int, loc := #caller_location) #expand {
    assert(array.count + count <= array.CAPACITY, "Attempt to add too many elements! Want: %, Max: %", array.count + count, array.CAPACITY, loc = loc);
}

#if RUN_INTERNAL_TESTS #run {
    suite("Static Array", #code {
        test("dynamic api to static", (t: *Test) {
            dynamic: [..]int;
            static:  Static_Array(10, int);

            for 0..static.CAPACITY - 1 {
                array_add(*dynamic, 10);
                array_add(*static, 10);

                expect(t, dynamic.count == static.count, "arrays had mismatched count: % vs. %", dynamic.count, static.count);
                expect(t, dynamic[it] == static[it], "%th elements didn't match (dyn: %, static: %)", it, dynamic[it], static[it]);
            }

            array_reset(*dynamic);
            array_reset(*static);
            expect(t, dynamic.count == static.count, "arrays had unmatched counts after reset: % vs. %", dynamic.count, static.count);
            for static expect(t, it == static._zero_value, "%th element wasn't zeroed out: %", it_index, it);
        });

        test("array_to_dynamic", (t: *Test) {
            static: Static_Array(3, float64);
            for 0..static.CAPACITY - 1 {
                array_add(*static, 3.14 + it);
            }

            dynamic := array_to_dynamic(*static);
            for dynamic expect(t, it == static[it_index], "%th element was unmatched after dynamic conversion: % != %", it_index, it, static[it_index]);

            array_add(*dynamic, 3.14 * 2);
            expect(t, static.count != dynamic.count, "arrays had matching count after append: % vs. %", static.count, dynamic.count);
        });

        test("push/pop", (t: *Test) {
            Command :: struct {
                tag:  Tag;
                args: [..]Argument;

                Tag :: enum {
                    Move;
                    Push;
                    Add;
                    Sub;
                }

                Argument :: struct {
                    kind:  Kind;
                    value: Union(u8, s64, float64);

                    Kind :: enum {
                        Stack;
                        Register;
                        Literal;
                    }
                }
            }

            static: Static_Array(16, Command);

            {
                cmd := push(*static);
                cmd.tag = .Move;

                loc := array_add(*cmd.args);
                loc.kind = .Register;
                set(*loc.value, cast(u8)1);

                val := array_add(*cmd.args);
                val.kind = .Literal;
                set(*val.value, 100);
            }

            {
                cmd := push(*static);
                cmd.tag = .Add;

                loc := array_add(*cmd.args);
                loc.kind = .Register;
                set(*loc.value, cast(u8)1);

                val := array_add(*cmd.args);
                val.kind = .Literal;
                set(*val.value, 1);
            }

            while static.count {
                cmd := pop(*static);
                // ...
            }

            expect(t, static.count == 0, "array still had count after pop: %", static.count);
        });
    });
}
