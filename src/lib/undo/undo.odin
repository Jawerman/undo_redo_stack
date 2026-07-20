// Generic undo/redo stack based on a circular buffer.
//
// Model: each call to stack_add stores a complete state snapshot
// at a position in the buffer. Three pointers manage navigation:
//
//   - bottom:  index of the oldest surviving element (undo floor)
//   - current: index of the currently visible state (cursor)
//   - top:     index of the last added or reached state (redo ceiling)
//
// The buffer is circular: when full, subsequent adds overwrite
// the oldest slots by advancing bottom.
//
// skip_current_on_add controls whether the next add advances the cursor
// or overwrites in-place. It is used for:
//   1. First add: write to slot 0 without advancing.
//   2. Post-unlock (bottom_override_allowed): overwrite the bottom
//      without moving pointers, allowing branching from a past state.
package undo

import "core:fmt"
import "core:slice"

// Undo_Stack_Config immutable configuration for the stack.
// Set at creation time and survives stack_reset.
Undo_Stack_Config :: struct {
	// bottom_override_allowed: when true, undoing all the way to the bottom
	// unlocks the floor. The next stack_add overwrites the bottom slot
	// without advancing bottom or current, preserving the existing redo
	// path. Useful for delta mode where overwriting a base delta is less
	// destructive than overwriting a full snapshot.
	bottom_override_allowed: bool,
}

// Undo_Stack generic undo/redo stack parametrized by state type T.
// The buffer is externally allocated via stack_create or by assigning to the stack field.
Undo_Stack :: struct($T: typeid) {
	stack:               []T,       // underlying circular buffer
	top:                 int,       // redo ceiling index
	current:             int,       // visible state index (cursor)
	bottom:              int,       // undo floor index
	config:              Undo_Stack_Config,
	skip_current_on_add: bool,      // when false, next add overwrites in-place
}

// stack_create creates a stack with a heap-allocated buffer of the given size.
stack_create :: proc($T: typeid, size: int, config := Undo_Stack_Config{}, allocator := context.allocator) -> Undo_Stack(T) {
	return Undo_Stack(T){
		config = config,
		stack = make([]T, size, allocator = allocator)
	}
}

// stack_destroy frees the stack's buffer.
stack_destroy :: proc(u: ^Undo_Stack($T)) {
	delete(u.stack)
}

// stack_add appends a state snapshot to the buffer.
// When skip_current_on_add is true (normal case), it advances current and top,
// and if top reaches bottom, bottom advances (circular overflow, old data lost).
// When skip_current_on_add is false (first add or post-unlock), it overwrites
// the current slot without moving any pointer, preserving top and the redo path.
// After the add, skip_current_on_add is always set to true.
stack_add :: proc(u: ^Undo_Stack($T), elem: ^T) {
	if u.skip_current_on_add {
		u.current = normalize_stack_index(u.current + 1, len(u.stack))
		u.top = u.current
		if u.bottom == u.top {
			u.bottom = normalize_stack_index(u.bottom + 1, len(u.stack))
		}
	}
	u.stack[u.current] = elem^
	u.skip_current_on_add = true
}

// stack_reset fully clears the stack: zeros the buffer, resets
// all three pointers to 0 and skip_current_on_add to false.
// Config is NOT reset (it is configuration, not transient state).
stack_reset :: proc(u: ^Undo_Stack($T)) {
	slice.zero(u.stack)
	u.bottom = 0
	u.top = 0
	u.current = 0
	u.skip_current_on_add = false
}

// stack_undo moves the cursor one step back and returns a pointer to the previous state.
// If current is already at bottom, returns nil/false (cannot go further back).
// If bottom_override_allowed is enabled and moving back leaves current == bottom,
// skip_current_on_add is unlocked to allow overwriting the bottom
// on the next stack_add.
stack_undo :: proc(u: ^Undo_Stack($T)) -> (^T, bool) {
	if u.current == u.bottom do return nil, false
	u.current = normalize_stack_index(u.current - 1, len(u.stack))
	if u.config.bottom_override_allowed && u.bottom == u.current {
		u.skip_current_on_add = false
	}
	return &u.stack[u.current], true
}

// stack_redo moves the cursor one step forward and returns a pointer to the next state.
// If current is already at top, returns nil/false (no future to redo).
stack_redo :: proc(u: ^Undo_Stack($T)) -> (^T, bool) {
	if u.current == u.top do return nil, false
	u.current = normalize_stack_index(u.current + 1, len(u.stack))
	return &u.stack[u.current], true
}


// normalize_stack_index converts an index (potentially negative or greater
// than stack_size) to the valid range [0, stack_size) using double modulo.
// Example: index -1 on a stack of size 5 -> 4.
@(private = "file")
normalize_stack_index :: proc(index, stack_size: int) -> int {
	return ((index % stack_size) + stack_size) % stack_size
}


// stack_get_current_index returns the cursor index (visible state).
stack_get_current_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.current
}

// stack_get_top_index returns the redo ceiling index.
stack_get_top_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.top
}

// stack_get_bottom_index returns the undo floor index.
stack_get_bottom_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.bottom
}
