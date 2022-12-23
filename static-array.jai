/// Fixed-size array that feels like [..]T

// @Todo: Maybe remake the [..]T API instead of this mirroring it?

Static_Array :: struct(CAPACITY: int, T: Type) {
    elements: [CAPACITY]T;
    count: int;

    // @Todo: Can this be made constant?
    ZERO : T = ---; // 'Private' value used when removing
}

len :: inline (array: Static_Array) -> int {
    return array.count;
}

cap :: inline (array: Static_Array) -> int {
    return array.CAPACITY;
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
    for 0..array.count - 1 array.elements[it] = array.ZERO;
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
        array.elements[it + 1] = array.ZERO;
    }

    array.count -= 1;
}

array_unordered_remove_by_index :: inline (array: *Static_Array, index: int) {
    assert(index >= 0, "Invalid index: %", index);
    assert(index < array.CAPACITY && index < array.count, "Invalid index: % (count: %, capacity: %)", index, array.count, array.CAPACITY);

    if array.count > 1 && index != array.count - 1 {
        array.elements[index]           = array.elements[array.count - 1];
        array.elements[array.count - 1] = array.ZERO;
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

    element := array.elements[array.count - 1];

    array.elements[array.count - 1] = array.ZERO;
    array.count -= 1;
    return element;
}

pop_pointer :: inline (array: *Static_Array) -> *array.T #must {
    assert(array.count >= 1, "Tried to pop too many elements");
    element := *array.elements[array.count - 1];
    array.count -= 1;
    return element;
}

to_array :: (array: Static_Array) -> []array.T {
    slice := cast([]array.T)array.elements;
    slice.count = array.count;
    return slice;
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

operator *[] :: inline (array: Static_Array, index: int) -> *array.T {
    assert(index >= 0 && index < array.count, "Invalid index: % (max: %)", index, array.count - 1);
    return *array.elements[index];
}

operator []= :: inline (array: *Static_Array, index: int, value: array.T) {
    assert(index >= 0 && index < array.CAPACITY, "Invalid index: % (max: %)", index, array.CAPACITY);
    array.elements[index] = value;
}


#scope_file

ensure_array_has_room :: (array: *Static_Array, count: int, loc := #caller_location) #expand {
    assert(array.count + count <= array.CAPACITY, "Attempt to add too many elements! Want: %, Max: %", array.count + count, array.CAPACITY, loc = loc);
}

