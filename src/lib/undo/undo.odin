package undo

import "core:fmt"
import "core:slice"

Undo_Stack_Config :: struct {
	bottom_override_allowed: bool,
}

Undo_Stack :: struct($T: typeid) {
	stack:               []T,
	top:                 int,
	current:             int,
	bottom:              int,
	config:              Undo_Stack_Config,
	skip_current_on_add: bool,
}

stack_create :: proc($T: typeid, size: int, config := Undo_Stack_Config{}, allocator := context.allocator) -> Undo_Stack(T) {
	return Undo_Stack(T){
		config = config,
		stack = make([]T, size, allocator = allocator)
	}
}

stack_destroy :: proc(u: ^Undo_Stack($T)) {
	delete(u.stack)
}

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

stack_reset :: proc(u: ^Undo_Stack($T)) {
	slice.zero(u.stack)
	u.bottom = 0
	u.top = 0
	u.current = 0
	u.skip_current_on_add = false
}

stack_undo :: proc(u: ^Undo_Stack($T)) -> (^T, bool) {
	if u.current == u.bottom do return nil, false
	u.current = normalize_stack_index(u.current - 1, len(u.stack))
	if u.config.bottom_override_allowed && u.bottom == u.current {
		u.skip_current_on_add = false
	}
	return &u.stack[u.current], true
}

stack_redo :: proc(u: ^Undo_Stack($T)) -> (^T, bool) {
	if u.current == u.top do return nil, false
	u.current = normalize_stack_index(u.current + 1, len(u.stack))
	return &u.stack[u.current], true
}


@(private = "file")
normalize_stack_index :: proc(index, stack_size: int) -> int {
	return ((index % stack_size) + stack_size) % stack_size
}


stack_get_current_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.current
}

stack_get_top_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.top
}

stack_get_bottom_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.bottom
}
