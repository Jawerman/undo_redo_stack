// Undo/Redo stack genérico basado en un buffer circular.
//
// Modelo: cada llamada a stack_add almacena un snapshot completo del estado
// en una posición del buffer. Tres punteros gestionan la navegación:
//
//   - bottom:  índice del elemento más antiguo que sobrevive (suelo de undo)
//   - current: índice del estado visible actualmente (cursor)
//   - top:     índice del último estado añadido o alcanzado (techo de redo)
//
// El buffer es circular: al llenarse, los adds posteriores sobreescriben
// los slots más antiguos avanzando bottom.
//
// skip_current_on_add controla si el próximo add avanza el cursor o
// sobreescribe en el sitio. Se usa para:
//   1. Primer add: escribir en slot 0 sin avanzar.
//   2. Post-unlock (bottom_override_allowed): sobreescribir el bottom
//      sin mover punteros, permitiendo ramificar desde un estado pasado.
package undo

import "core:fmt"
import "core:slice"

// Undo_Stack_Config configuración inmutable de la stack.
// Se establece en la creación y sobrevive a stack_reset.
Undo_Stack_Config :: struct {
	// bottom_override_allowed: si es true, hacer undo hasta el bottom
	// desbloquea el suelo. El siguiente stack_add sobreescribe el slot
	// del bottom sin avanzar bottom ni current, preservando el camino
	// de redo existente. Útil para modo delta donde sobreescribir un
	// delta base es menos destructivo que sobreescribir un snapshot.
	bottom_override_allowed: bool,
}

// Undo_Stack stack undo/redo genérica parametrizada por el tipo de estado T.
// El buffer se allocate externamente vía stack_create o asignándose al campo stack.
Undo_Stack :: struct($T: typeid) {
	stack:               []T,       // buffer circular subyacente
	top:                 int,       // índice del techo de redo
	current:             int,       // índice del estado visible (cursor)
	bottom:              int,       // índice del suelo de undo
	config:              Undo_Stack_Config,
	skip_current_on_add: bool,      // si false, el próximo add sobreescribe in-place
}

// stack_create crea una stack con buffer heap-allocated del tamaño indicado.
stack_create :: proc($T: typeid, size: int, config := Undo_Stack_Config{}, allocator := context.allocator) -> Undo_Stack(T) {
	return Undo_Stack(T){
		config = config,
		stack = make([]T, size, allocator = allocator)
	}
}

// stack_destroy libera el buffer de la stack.
stack_destroy :: proc(u: ^Undo_Stack($T)) {
	delete(u.stack)
}

// stack_add añade un snapshot del estado al buffer.
// Si skip_current_on_add es true (caso normal), avanza current y top,
// y si top alcanza bottom, bottom avanza (overflow circular, datos antiguos perdidos).
// Si skip_current_on_add es false (primer add o post-unlock), sobreescribe
// el slot de current sin mover ningún puntero, preservando top y el camino de redo.
// Después del add, skip_current_on_add siempre queda en true.
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

// stack_reset limpia completamente la stack: zeros el buffer, resetea
// los tres punteros a 0 y skip_current_on_add a false.
// La config NO se resetea (es configuración, no estado transitorio).
stack_reset :: proc(u: ^Undo_Stack($T)) {
	slice.zero(u.stack)
	u.bottom = 0
	u.top = 0
	u.current = 0
	u.skip_current_on_add = false
}

// stack_undo retrocede el cursor un paso y retorna un puntero al estado anterior.
// Si current ya está en bottom, retorna nil/false (no se puede retroceder más).
// Si bottom_override_allowed está habilitado y el retroceso deja current == bottom,
// se desbloquea skip_current_on_add para permitir sobreescribir el bottom
// en el próximo stack_add.
stack_undo :: proc(u: ^Undo_Stack($T)) -> (^T, bool) {
	if u.current == u.bottom do return nil, false
	u.current = normalize_stack_index(u.current - 1, len(u.stack))
	if u.config.bottom_override_allowed && u.bottom == u.current {
		u.skip_current_on_add = false
	}
	return &u.stack[u.current], true
}

// stack_redo avanza el cursor un paso y retorna un puntero al estado siguiente.
// Si current ya está en top, retorna nil/false (no hay futuro que rehacer).
stack_redo :: proc(u: ^Undo_Stack($T)) -> (^T, bool) {
	if u.current == u.top do return nil, false
	u.current = normalize_stack_index(u.current + 1, len(u.stack))
	return &u.stack[u.current], true
}


// normalize_stack_index convierte un índice (potencialmente negativo o mayor
// que stack_size) al rango válido [0, stack_size) usando doble módulo.
// Ejemplo: índice -1 en stack de tamaño 5 → 4.
@(private = "file")
normalize_stack_index :: proc(index, stack_size: int) -> int {
	return ((index % stack_size) + stack_size) % stack_size
}


// stack_get_current_index retorna el índice del cursor (estado visible).
stack_get_current_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.current
}

// stack_get_top_index retorna el índice del techo de redo.
stack_get_top_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.top
}

// stack_get_bottom_index retorna el índice del suelo de undo.
stack_get_bottom_index :: #force_inline proc(u: ^Undo_Stack($T)) -> int {
	return u.bottom
}
