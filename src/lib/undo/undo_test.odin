package undo

import "core:testing"

STACK_SIZE :: 5

// Case: add a single element to an empty stack.
// Verifies that skip_current_on_add activates and all indices stay at 0.
@(test)
test_add_single_element :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	state := 10
	stack_add(&u, &state)

	testing.expect(t, u.skip_current_on_add == true)
	testing.expect(t, u.current == 0)
	testing.expect(t, u.top == 0)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 10)
}

// Case: add two consecutive elements.
// Verifies that current and top advance, bottom stays at 0.
@(test)
test_add_two_elements :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2 := 10, 20
	stack_add(&u, &s1)
	stack_add(&u, &s2)

	testing.expect(t, u.current == 1)
	testing.expect(t, u.top == 1)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 10)
	testing.expect(t, u.stack[1] == 20)
}

// Case: fill the stack to exact capacity without overflow.
// Verifies that all indices and values are correct when filled to max.
@(test)
test_add_fills_stack_no_overflow :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	values := [STACK_SIZE]int{10, 20, 30, 40, 50}
	for &v in values {
		stack_add(&u, &v)
	}

	testing.expect(t, u.current == STACK_SIZE - 1)
	testing.expect(t, u.top == STACK_SIZE - 1)
	testing.expect(t, u.bottom == 0)
	for i in 0 ..< STACK_SIZE {
		testing.expect(t, u.stack[i] == values[i])
	}
}

// Case: add one element beyond capacity (circular overflow).
// Verifies that current and top wrap to 0 and bottom advances to 1.
@(test)
test_add_overflow_circular :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	for i in 1 ..= STACK_SIZE + 1 {
		v := i
		stack_add(&u, &v)
	}

	testing.expect(t, u.current == 0)
	testing.expect(t, u.top == 0)
	testing.expect(t, u.bottom == 1)
	testing.expect(t, u.stack[0] == STACK_SIZE + 1)
}

// Case: verify that overflow overwrites the old bottom slot.
// After overwriting, confirms that undo returns the element that was at
// the position before bottom (the second-to-last added).
@(test)
test_add_overwrites_old_bottom :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	for i in 1 ..= STACK_SIZE + 1 {
		v := i
		stack_add(&u, &v)
	}

	testing.expect(t, u.bottom == 1)
	testing.expect(t, u.stack[0] == STACK_SIZE + 1)
	testing.expect(t, u.stack[4] == STACK_SIZE)

	r, ok := stack_undo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == STACK_SIZE)
}

// Case: undo with a single element on the stack.
// Verifies that undo is not possible (current == bottom) and returns nil/false.
@(test)
test_undo_single_element_returns_false :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	state := 42
	stack_add(&u, &state)

	result, can_undo := stack_undo(&u)
	testing.expect(t, can_undo == false)
	testing.expect(t, result == nil)
}

// Case: undo after adding multiple elements.
// Verifies that each undo moves current back and returns the correct value.
@(test)
test_undo_after_multiple_adds :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	result, can_undo := stack_undo(&u)
	testing.expect(t, can_undo)
	testing.expect(t, result^ == 20)
	testing.expect(t, u.current == 1)

	result2, can_undo2 := stack_undo(&u)
	testing.expect(t, can_undo2)
	testing.expect(t, result2^ == 10)
	testing.expect(t, u.current == 0)
}

// Case: reach bottom with undo and verify no further undo is possible.
// Confirms that undo at bottom returns false and does not modify state.
@(test)
test_undo_to_bottom_stops :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2 := 10, 20
	stack_add(&u, &s1)
	stack_add(&u, &s2)

	stack_undo(&u)
	_, can_undo := stack_undo(&u)
	testing.expect(t, can_undo == false)

	_, can_undo2 := stack_undo(&u)
	testing.expect(t, can_undo2 == false)
}

// Case: redo when current == top (no future to redo).
// Verifies that it returns nil/false without modifying the stack.
@(test)
test_redo_at_top_returns_false :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	state := 10
	stack_add(&u, &state)

	result, can_redo := stack_redo(&u)
	testing.expect(t, can_redo == false)
	testing.expect(t, result == nil)
}

// Case: redo after performing two undos.
// Verifies that each redo advances current and returns the correct value in order.
@(test)
test_redo_after_undo :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	stack_undo(&u)
	stack_undo(&u)

	result, can_redo := stack_redo(&u)
	testing.expect(t, can_redo)
	testing.expect(t, result^ == 20)

	result2, can_redo2 := stack_redo(&u)
	testing.expect(t, can_redo2)
	testing.expect(t, result2^ == 30)
}

// Case: redo until reaching top and verify no further redo is possible.
// Confirms that redo at top returns false and does not modify state.
@(test)
test_redo_to_top_stops :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2 := 10, 20
	stack_add(&u, &s1)
	stack_add(&u, &s2)

	stack_undo(&u)
	stack_redo(&u)
	_, can_redo := stack_redo(&u)
	testing.expect(t, can_redo == false)
}

// Case: stack reset.
// Verifies that all fields are reset, and the buffer is zeroed completely.
@(test)
test_reset_clears_everything :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	stack_reset(&u)

	testing.expect(t, u.skip_current_on_add == false)
	testing.expect(t, u.current == 0)
	testing.expect(t, u.top == 0)
	testing.expect(t, u.bottom == 0)

	for i in 0 ..< STACK_SIZE {
		testing.expect(t, u.stack[i] == 0)
	}
}

// Case: reset followed by new adds.
// Verifies that the stack works as new after reset,
// starting from indices 0,0,0.
@(test)
test_reset_then_add_fresh :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2 := 10, 20
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_reset(&u)

	v1, v2 := 100, 200
	stack_add(&u, &v1)
	stack_add(&u, &v2)

	testing.expect(t, u.current == 1)
	testing.expect(t, u.top == 1)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 100)
	testing.expect(t, u.stack[1] == 200)
}

// Case: full add -> undo -> redo sequential flow.
// Verifies the sequence: add(10), add(20), add(30),
// undo->20, undo->10, redo->20, redo->30.
@(test)
test_full_undo_redo_flow :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	r, _ := stack_undo(&u)
	testing.expect(t, r^ == 20)

	r, _ = stack_undo(&u)
	testing.expect(t, r^ == 10)

	r, _ = stack_redo(&u)
	testing.expect(t, r^ == 20)

	r, _ = stack_redo(&u)
	testing.expect(t, r^ == 30)
}

// Case: undo/redo after circular stack overflow.
// Verifies that bottom advances correctly and undo/redo works
// with the values that survived the overflow.
@(test)
test_undo_redo_with_overflow :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	for i in 1 ..= STACK_SIZE + 2 {
		v := i
		stack_add(&u, &v)
	}

	testing.expect(t, u.bottom == 2)

	r, ok := stack_undo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == STACK_SIZE + 1)

	r, ok = stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == STACK_SIZE + 2)
}

// Case: add a new element after undo(s).
// Verifies that the "future" (elements after current) is truncated:
// top moves back to current and redo no longer works.
@(test)
test_add_after_undo_truncates_future :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	stack_undo(&u)
	stack_undo(&u)

	new_val := 15
	stack_add(&u, &new_val)

	testing.expect(t, u.current == 1)
	testing.expect(t, u.top == 1)

	_, can_redo := stack_redo(&u)
	testing.expect(t, can_redo == false)
}

// Case: index getters after several operations.
// Verifies that get_current_index, get_top_index and get_bottom_index
// return consistent values after add, undo and redo.
@(test)
test_getters_indices :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	testing.expect(t, stack_get_current_index(&u) == 2)
	testing.expect(t, stack_get_top_index(&u) == 2)
	testing.expect(t, stack_get_bottom_index(&u) == 0)

	stack_undo(&u)
	testing.expect(t, stack_get_current_index(&u) == 1)

	stack_redo(&u)
	testing.expect(t, stack_get_current_index(&u) == 2)
}

// Case: undo on a stack that never received an add.
// Verifies that it returns nil/false without errors.
@(test)
test_undo_on_empty_stack :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	result, can_undo := stack_undo(&u)
	testing.expect(t, can_undo == false)
	testing.expect(t, result == nil)
}

// Case: redo on a stack that never received an add.
// Verifies that it returns nil/false without errors.
@(test)
test_redo_on_empty_stack :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	result, can_redo := stack_redo(&u)
	testing.expect(t, can_redo == false)
	testing.expect(t, result == nil)
}

// Case: undo after a single add, verifying that current and bottom
// remain at 0 (the pointer does not overflow backwards).
@(test)
test_add_single_then_undo_stays_at_bottom :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	state := 42
	stack_add(&u, &state)

	_, can_undo := stack_undo(&u)
	testing.expect(t, can_undo == false)

	testing.expect(t, stack_get_current_index(&u) == 0)
	testing.expect(t, stack_get_bottom_index(&u) == 0)
}

// Case: minimum stack size (2).
// Verifies behavior with reduced capacity: more aggressive overflow,
// undo and redo work correctly with only 2 slots.
@(test)
test_stack_size_two :: proc(t: ^testing.T) {
	u := stack_create(int, 2)
	defer stack_destroy(&u)

	s1, s2, s3, s4, s5 := 1, 2, 3, 4, 5
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)
	stack_add(&u, &s4)
	stack_add(&u, &s5)

	testing.expect(t, u.bottom == 1)
	testing.expect(t, u.top == 0)
	testing.expect(t, u.current == 0)
	testing.expect(t, u.stack[0] == 5)
	testing.expect(t, u.stack[1] == 4)

	r, ok := stack_undo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 4)

	r, ok = stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 5)
}

// Case: multiple undos followed by multiple redos.
// Verifies the integrity of the full sequence:
// add(10..50) -> undo to bottom -> redo to top.
@(test)
test_many_undos_and_redos :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	for i in 1 ..= STACK_SIZE {
		v := i * 10
		stack_add(&u, &v)
	}

	for i in 1 ..< STACK_SIZE {
		r, ok := stack_undo(&u)
		testing.expect(t, ok)
		testing.expect(t, r^ == (STACK_SIZE - i) * 10)
	}

	for i in 2 ..< STACK_SIZE {
		r, ok := stack_redo(&u)
		testing.expect(t, ok)
		testing.expect(t, r^ == i * 10)
	}
}

// Case: add after a single undo, then undo/redo on the new path.
// Verifies that undo goes back to the element before the new add,
// redo advances to the newly added element, and there is no access
// to the truncated future.
@(test)
test_add_after_undo_then_undo :: proc(t: ^testing.T) {
	u := stack_create(int, STACK_SIZE)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	stack_undo(&u)

	new_val := 25
	stack_add(&u, &new_val)

	r, ok := stack_undo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 20)

	r, ok = stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 25)

	_, can_redo := stack_redo(&u)
	testing.expect(t, can_redo == false)
}

// Case: index getters after multiple overflows (7 adds to a stack of 3).
// Verifies that indices wrap correctly in the circular buffer
// after writing more than double the capacity.
@(test)
test_getters_after_overflow :: proc(t: ^testing.T) {
	u := stack_create(int, 3)
	defer stack_destroy(&u)

	for i in 1 ..= 7 {
		v := i
		stack_add(&u, &v)
	}

	testing.expect(t, stack_get_bottom_index(&u) == 1)
	testing.expect(t, stack_get_top_index(&u) == 0)
	testing.expect(t, stack_get_current_index(&u) == 0)
}

// ============================================================
// Tests with bottom_override_allowed = true
// ============================================================

OVERRIDE_STACK_SIZE :: 5

override_config :: Undo_Stack_Config {
	bottom_override_allowed = true,
}

// Case: undo to bottom with bottom_override_allowed enabled.
// Verifies that skip_current_on_add unlocks when current reaches bottom.
@(test)
test_undo_to_bottom_unlocks :: proc(t: ^testing.T) {
	u := stack_create(int, OVERRIDE_STACK_SIZE, config = override_config)
	defer stack_destroy(&u)

	s1, s2 := 10, 20
	stack_add(&u, &s1)
	stack_add(&u, &s2)

	testing.expect(t, u.skip_current_on_add == true)
	testing.expect(t, u.current == 1)
	testing.expect(t, u.bottom == 0)

	stack_undo(&u)

	testing.expect(t, u.skip_current_on_add == false)
	testing.expect(t, u.current == 0)
	testing.expect(t, u.bottom == 0)
}

// Case: add after unlocking overwrites the bottom slot in-place.
// Verifies that current and bottom do not change index and the value is overwritten.
@(test)
test_add_after_unlock_overwrites_in_place :: proc(t: ^testing.T) {
	u := stack_create(int, OVERRIDE_STACK_SIZE, config = override_config)
	defer stack_destroy(&u)

	s1, s2 := 10, 20
	stack_add(&u, &s1)
	stack_add(&u, &s2)

	stack_undo(&u)

	new_val := 99
	stack_add(&u, &new_val)

	testing.expect(t, u.current == 0)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 99)
	testing.expect(t, u.skip_current_on_add == true)
}

// Case: overwriting the bottom preserves the redo path.
// add(10,20,30) -> undo->10 (unlock) -> add(15) -> redo->20 -> redo->30.
// The bottom overwrite does not truncate the future because the post-unlock add
// does not advance current/top.
@(test)
test_branch_preserves_redo_path :: proc(t: ^testing.T) {
	u := stack_create(int, OVERRIDE_STACK_SIZE, config = override_config)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	stack_undo(&u)
	stack_undo(&u)

	new_val := 15
	stack_add(&u, &new_val)

	testing.expect(t, u.current == 0)
	testing.expect(t, u.stack[0] == 15)
	testing.expect(t, u.top == 2)

	r, ok := stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 20)

	r, ok = stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 30)

	_, can_redo := stack_redo(&u)
	testing.expect(t, can_redo == false)
}

// Case: the bottom index does not move on overwrite.
// Verifies that bottom remains at 0 after the post-unlock overwrite.
@(test)
test_bottom_index_stable_after_overwrite :: proc(t: ^testing.T) {
	u := stack_create(int, OVERRIDE_STACK_SIZE, config = override_config)
	defer stack_destroy(&u)

	s1, s2 := 10, 20
	stack_add(&u, &s1)
	stack_add(&u, &s2)

	stack_undo(&u)

	new_val := 99
	stack_add(&u, &new_val)

	testing.expect(t, stack_get_bottom_index(&u) == 0)
	testing.expect(t, stack_get_current_index(&u) == 0)
	testing.expect(t, stack_get_top_index(&u) == 1)
}

// Case: a new add after the overwrite does truncate the future.
// Unlike the post-unlock add (which overwrites in-place), a normal add
// after the overwrite advances current and top, truncating the redo path.
@(test)
test_new_add_after_overwrite_truncates :: proc(t: ^testing.T) {
	u := stack_create(int, OVERRIDE_STACK_SIZE, config = override_config)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	stack_undo(&u)
	stack_undo(&u)

	overwrite := 15
	stack_add(&u, &overwrite)

	new_val := 25
	stack_add(&u, &new_val)

	testing.expect(t, u.current == 1)
	testing.expect(t, u.top == 1)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 15)
	testing.expect(t, u.stack[1] == 25)

	_, can_redo := stack_redo(&u)
	testing.expect(t, can_redo == false)
}

// Case: repeated cycles of undo-to-bottom -> overwrite.
// Verifies that the unlock mechanism works repeatedly:
// add(10,20,30) -> undo->10 -> overwrite(15) -> redo->20 -> redo->30
// -> undo->20 -> undo->15 -> overwrite(25).
@(test)
test_multiple_overwrite_cycles :: proc(t: ^testing.T) {
	u := stack_create(int, OVERRIDE_STACK_SIZE, config = override_config)
	defer stack_destroy(&u)

	s1, s2, s3 := 10, 20, 30
	stack_add(&u, &s1)
	stack_add(&u, &s2)
	stack_add(&u, &s3)

	stack_undo(&u)
	stack_undo(&u)

	v1 := 15
	stack_add(&u, &v1)

	stack_redo(&u)
	stack_redo(&u)

	stack_undo(&u)
	stack_undo(&u)

	v2 := 25
	stack_add(&u, &v2)

	testing.expect(t, u.current == 0)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 25)

	r, ok := stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 20)

	r, ok = stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 30)
}

// Case: overflow advances bottom, then undo to that moved bottom and overwrite.
// Verifies that the mechanism works correctly when bottom is not at 0.
@(test)
test_overflow_then_undo_to_moved_bottom :: proc(t: ^testing.T) {
	u := stack_create(int, OVERRIDE_STACK_SIZE, config = override_config)
	defer stack_destroy(&u)

	for i in 1 ..= OVERRIDE_STACK_SIZE + 1 {
		v := i
		stack_add(&u, &v)
	}

	testing.expect(t, u.bottom == 1)
	testing.expect(t, u.current == 0)

	stack_undo(&u)
	testing.expect(t, u.current == 4)
	testing.expect(t, u.stack[4] == OVERRIDE_STACK_SIZE)

	stack_undo(&u)
	testing.expect(t, u.current == 3)
	testing.expect(t, u.stack[3] == OVERRIDE_STACK_SIZE - 1)

	stack_undo(&u)
	testing.expect(t, u.current == 2)
	testing.expect(t, u.stack[2] == OVERRIDE_STACK_SIZE - 2)

	stack_undo(&u)
	testing.expect(t, u.current == 1)
	testing.expect(t, u.skip_current_on_add == false)

	new_val := 99
	stack_add(&u, &new_val)

	testing.expect(t, u.current == 1)
	testing.expect(t, u.bottom == 1)
	testing.expect(t, u.stack[1] == 99)
}

// Case: with bottom_override_allowed=true, a single element cannot be unlocked.
// The unlock condition requires current to move to bottom, but with a single
// element current is already at bottom and undo returns false before reaching
// the unlock code.
@(test)
test_single_element_cannot_unlock :: proc(t: ^testing.T) {
	u := stack_create(int, OVERRIDE_STACK_SIZE, config = override_config)
	defer stack_destroy(&u)

	state := 42
	stack_add(&u, &state)

	testing.expect(t, u.current == 0)
	testing.expect(t, u.bottom == 0)

	_, can_undo := stack_undo(&u)
	testing.expect(t, can_undo == false)

	testing.expect(t, u.skip_current_on_add == true)
}

// Case: reset after unlock preserves config but clears skip_current_on_add.
// Verifies that config.bottom_override_allowed is not reset (it is configuration),
// but skip_current_on_add returns to false and the stack works as new.
@(test)
test_reset_after_unlock_preserves_config :: proc(t: ^testing.T) {
	u := stack_create(int, OVERRIDE_STACK_SIZE, config = override_config)
	defer stack_destroy(&u)

	s1, s2 := 10, 20
	stack_add(&u, &s1)
	stack_add(&u, &s2)

	stack_undo(&u)

	stack_reset(&u)

	testing.expect(t, u.skip_current_on_add == false)
	testing.expect(t, u.current == 0)
	testing.expect(t, u.top == 0)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.config.bottom_override_allowed == true)

	v1, v2 := 100, 200
	stack_add(&u, &v1)
	stack_add(&u, &v2)

	testing.expect(t, u.current == 1)
	testing.expect(t, u.top == 1)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 100)
	testing.expect(t, u.stack[1] == 200)
}
