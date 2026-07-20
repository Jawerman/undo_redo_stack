package undo

import "core:fmt"
import "core:slice"
Undo_Stack :: struct($T: typeid) {
	stack:       []T,
	top:         int,
	current:     int,
	bottom:      int,
	has_content: bool,
}

undo_stack_add :: proc(u: ^Undo_Stack($T), elem: ^T) {
	if u.has_content {
		u.current = normalize_stack_index(u.current + 1, len(u.stack))
		u.top = u.current
		if u.bottom == u.top {
			u.bottom = normalize_stack_index(u.bottom + 1, len(u.stack))
		}
	}
	u.stack[u.current] = elem^
	u.has_content = true
}

undo_stack_reset :: proc(u: ^Undo_Stack($T)) {
	slice.zero(u.stack)
	u.bottom = 0
	u.top = 0
	u.current = 0
	u.has_content = false
}

undo_stack_undo :: proc(u: ^Undo_Stack($T)) -> (^T, bool) {
	if u.current == u.bottom do return nil, false
	u.current = normalize_stack_index(u.current - 1, len(u.stack))
	return &u.stack[u.current], true
}

undo_stack_redo :: proc(u: ^Undo_Stack($T)) -> (^T, bool) {
	if u.current == u.top do return nil, false
	u.current = normalize_stack_index(u.current + 1, len(u.stack))
	return &u.stack[u.current], true
}


@(private = "file")
normalize_stack_index :: proc(index, stack_size: int) -> int {
	return ((index % stack_size) + stack_size) % stack_size
}


undo_stack_get_current_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.current
}

undo_stack_get_top_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.top
}

undo_stack_get_bottom_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.bottom
}
