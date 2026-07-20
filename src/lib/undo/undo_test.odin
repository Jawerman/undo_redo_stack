package undo

import "core:testing"

STACK_SIZE :: 5

// Caso: agregar un solo elemento a una stack vacía.
// Verifica que has_content se activa y todos los índices quedan en 0.
@(test)
test_add_single_element :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	state := 10
	undo_stack_add(&u, &state)

	testing.expect(t, u.is_bottom_locked == true)
	testing.expect(t, u.current == 0)
	testing.expect(t, u.top == 0)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 10)
}

// Caso: agregar dos elementos consecutivos.
// Verifica que current y top avanzan, bottom se mantiene en 0.
@(test)
test_add_two_elements :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2 := 10, 20
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)

	testing.expect(t, u.current == 1)
	testing.expect(t, u.top == 1)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 10)
	testing.expect(t, u.stack[1] == 20)
}

// Caso: llenar exactamente la capacidad de la stack sin overflow.
// Verifica que todos los índices y valores son correctos al llenar al máximo.
@(test)
test_add_fills_stack_no_overflow :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	values := [STACK_SIZE]int{10, 20, 30, 40, 50}
	for &v in values {
		undo_stack_add(&u, &v)
	}

	testing.expect(t, u.current == STACK_SIZE - 1)
	testing.expect(t, u.top == STACK_SIZE - 1)
	testing.expect(t, u.bottom == 0)
	for i in 0 ..< STACK_SIZE {
		testing.expect(t, u.stack[i] == values[i])
	}
}

// Caso: agregar un elemento más allá de la capacidad (overflow circular).
// Verifica que current y top se envuelven a 0 y bottom avanza a 1.
@(test)
test_add_overflow_circular :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	for i in 1 ..= STACK_SIZE + 1 {
		v := i
		undo_stack_add(&u, &v)
	}

	testing.expect(t, u.current == 0)
	testing.expect(t, u.top == 0)
	testing.expect(t, u.bottom == 1)
	testing.expect(t, u.stack[0] == STACK_SIZE + 1)
}

// Caso: verificar que el overflow sobreescribe el slot del antiguo bottom.
// Tras sobreescribir, confirma que undo retorna el elemento que estaba en la
// posición anterior al bottom (el penúltimo añadido).
@(test)
test_add_overwrites_old_bottom :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	for i in 1 ..= STACK_SIZE + 1 {
		v := i
		undo_stack_add(&u, &v)
	}

	testing.expect(t, u.bottom == 1)
	testing.expect(t, u.stack[0] == STACK_SIZE + 1)
	testing.expect(t, u.stack[4] == STACK_SIZE)

	r, ok := undo_stack_undo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == STACK_SIZE)
}

// Caso: undo con un solo elemento en la stack.
// Verifica que no se puede hacer undo (current == bottom) y retorna nil/false.
@(test)
test_undo_single_element_returns_false :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	state := 42
	undo_stack_add(&u, &state)

	result, can_undo := undo_stack_undo(&u)
	testing.expect(t, can_undo == false)
	testing.expect(t, result == nil)
}

// Caso: undo tras agregar múltiples elementos.
// Verifica que cada undo retrocede current y retorna el valor correcto.
@(test)
test_undo_after_multiple_adds :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2, s3 := 10, 20, 30
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)
	undo_stack_add(&u, &s3)

	result, can_undo := undo_stack_undo(&u)
	testing.expect(t, can_undo)
	testing.expect(t, result^ == 20)
	testing.expect(t, u.current == 1)

	result2, can_undo2 := undo_stack_undo(&u)
	testing.expect(t, can_undo2)
	testing.expect(t, result2^ == 10)
	testing.expect(t, u.current == 0)
}

// Caso: llegar al bottom con undo y verificar que no se puede seguir.
// Confirma que undo en bottom retorna false y no modifica el estado.
@(test)
test_undo_to_bottom_stops :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2 := 10, 20
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)

	undo_stack_undo(&u)
	_, can_undo := undo_stack_undo(&u)
	testing.expect(t, can_undo == false)

	_, can_undo2 := undo_stack_undo(&u)
	testing.expect(t, can_undo2 == false)
}

// Caso: redo cuando current == top (no hay "futuro" que rehacer).
// Verifica que retorna nil/false sin modificar la stack.
@(test)
test_redo_at_top_returns_false :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	state := 10
	undo_stack_add(&u, &state)

	result, can_redo := undo_stack_redo(&u)
	testing.expect(t, can_redo == false)
	testing.expect(t, result == nil)
}

// Caso: redo después de hacer dos undos.
// Verifica que cada redo avanza current y retorna el valor correcto en orden.
@(test)
test_redo_after_undo :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2, s3 := 10, 20, 30
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)
	undo_stack_add(&u, &s3)

	undo_stack_undo(&u)
	undo_stack_undo(&u)

	result, can_redo := undo_stack_redo(&u)
	testing.expect(t, can_redo)
	testing.expect(t, result^ == 20)

	result2, can_redo2 := undo_stack_redo(&u)
	testing.expect(t, can_redo2)
	testing.expect(t, result2^ == 30)
}

// Caso: redo hasta llegar al top y verificar que no se puede seguir.
// Confirma que redo en top retorna false y no modifica el estado.
@(test)
test_redo_to_top_stops :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
	stack = buf[:],
	}

	s1, s2 := 10, 20
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)

	undo_stack_undo(&u)
	undo_stack_redo(&u)
	_, can_redo := undo_stack_redo(&u)
	testing.expect(t, can_redo == false)
}

// Caso: reset de la stack.
// Verifica que todos los campos se reinician, has_content es false,
// y el buffer se zeroes completamente.
@(test)
test_reset_clears_everything :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2, s3 := 10, 20, 30
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)
	undo_stack_add(&u, &s3)

	undo_stack_reset(&u)

	testing.expect(t, u.is_bottom_locked == false)
	testing.expect(t, u.current == 0)
	testing.expect(t, u.top == 0)
	testing.expect(t, u.bottom == 0)

	for i in 0 ..< STACK_SIZE {
		testing.expect(t, u.stack[i] == 0)
	}
}

// Caso: reset seguido de nuevos adds.
// Verifica que la stack funciona como nueva después del reset,
// comenzando desde índices 0,0,0.
@(test)
test_reset_then_add_fresh :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2 := 10, 20
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)
	undo_stack_reset(&u)

	v1, v2 := 100, 200
	undo_stack_add(&u, &v1)
	undo_stack_add(&u, &v2)

	testing.expect(t, u.current == 1)
	testing.expect(t, u.top == 1)
	testing.expect(t, u.bottom == 0)
	testing.expect(t, u.stack[0] == 100)
	testing.expect(t, u.stack[1] == 200)
}

// Caso: flujo completo add → undo → redo secuencial.
// Verifica la secuencia: add(10), add(20), add(30),
// undo→20, undo→10, redo→20, redo→30.
@(test)
test_full_undo_redo_flow :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2, s3 := 10, 20, 30
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)
	undo_stack_add(&u, &s3)

	r, _ := undo_stack_undo(&u)
	testing.expect(t, r^ == 20)

	r, _ = undo_stack_undo(&u)
	testing.expect(t, r^ == 10)

	r, _ = undo_stack_redo(&u)
	testing.expect(t, r^ == 20)

	r, _ = undo_stack_redo(&u)
	testing.expect(t, r^ == 30)
}

// Caso: undo/redo tras overflow de la stack circular.
// Verifica que bottom avanza correctamente y undo/redo funciona
// con los valores que sobrevivieron al overflow.
@(test)
test_undo_redo_with_overflow :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	for i in 1 ..= STACK_SIZE + 2 {
		v := i
		undo_stack_add(&u, &v)
	}

	testing.expect(t, u.bottom == 2)

	r, ok := undo_stack_undo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == STACK_SIZE + 1)

	r, ok = undo_stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == STACK_SIZE + 2)
}

// Caso: agregar un nuevo elemento después de undo(s).
// Verifica que el "futuro" (elementos que estaban después de current)
// se trunca: top retrocede a current y redo ya no funciona.
@(test)
test_add_after_undo_truncates_future :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2, s3 := 10, 20, 30
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)
	undo_stack_add(&u, &s3)

	undo_stack_undo(&u)
	undo_stack_undo(&u)

	new_val := 15
	undo_stack_add(&u, &new_val)

	testing.expect(t, u.current == 1)
	testing.expect(t, u.top == 1)

	_, can_redo := undo_stack_redo(&u)
	testing.expect(t, can_redo == false)
}

// Caso: getters de índices tras varias operaciones.
// Verifica que get_current_index, get_top_index y get_bottom_index
// retornan valores coherentes tras add, undo y redo.
@(test)
test_getters_indices :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2, s3 := 10, 20, 30
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)
	undo_stack_add(&u, &s3)

	testing.expect(t, undo_stack_get_current_index(&u) == 2)
	testing.expect(t, undo_stack_get_top_index(&u) == 2)
	testing.expect(t, undo_stack_get_bottom_index(&u) == 0)

	undo_stack_undo(&u)
	testing.expect(t, undo_stack_get_current_index(&u) == 1)

	undo_stack_redo(&u)
	testing.expect(t, undo_stack_get_current_index(&u) == 2)
}

// Caso: undo en una stack que nunca recibió add (has_content == false).
// Verifica que retorna nil/false sin errores.
@(test)
test_undo_on_empty_stack :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	result, can_undo := undo_stack_undo(&u)
	testing.expect(t, can_undo == false)
	testing.expect(t, result == nil)
}

// Caso: redo en una stack que nunca recibió add (has_content == false).
// Verifica que retorna nil/false sin errores.
@(test)
test_redo_on_empty_stack :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	result, can_redo := undo_stack_redo(&u)
	testing.expect(t, can_redo == false)
	testing.expect(t, result == nil)
}

// Caso: undo tras un solo add, verificando que current y bottom
// permanecen en 0 (el puntero no se desborda hacia atrás).
@(test)
test_add_single_then_undo_stays_at_bottom :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	state := 42
	undo_stack_add(&u, &state)

	_, can_undo := undo_stack_undo(&u)
	testing.expect(t, can_undo == false)

	testing.expect(t, undo_stack_get_current_index(&u) == 0)
	testing.expect(t, undo_stack_get_bottom_index(&u) == 0)
}

// Caso: stack con tamaño mínimo (2).
// Verifica comportamiento con capacidad reducida: overflow más agresivo,
// undo y redo funcionan correctamente con solo 2 slots.
@(test)
test_stack_size_two :: proc(t: ^testing.T) {
	buf: [2]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2, s3, s4, s5 := 1, 2, 3, 4, 5
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)
	undo_stack_add(&u, &s3)
	undo_stack_add(&u, &s4)
	undo_stack_add(&u, &s5)

	testing.expect(t, u.bottom == 1)
	testing.expect(t, u.top == 0)
	testing.expect(t, u.current == 0)
	testing.expect(t, u.stack[0] == 5)
	testing.expect(t, u.stack[1] == 4)

	r, ok := undo_stack_undo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 4)

	r, ok = undo_stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 5)
}

// Caso: múltiples undos seguidos de múltiples redos.
// Verifica la integridad de la secuencia completa:
// add(10..50) → undo hasta el fondo → redo hasta el tope.
@(test)
test_many_undos_and_redos :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	for i in 1 ..= STACK_SIZE {
		v := i * 10
		undo_stack_add(&u, &v)
	}

	for i in 1 ..< STACK_SIZE {
		r, ok := undo_stack_undo(&u)
		testing.expect(t, ok)
		testing.expect(t, r^ == (STACK_SIZE - i) * 10)
	}

	for i in 2 ..< STACK_SIZE {
		r, ok := undo_stack_redo(&u)
		testing.expect(t, ok)
		testing.expect(t, r^ == i * 10)
	}
}

// Caso: add después de un solo undo, y luego undo/redo sobre el nuevo camino.
// Verifica que undo retrocede al elemento anterior al add nuevo,
// redo avanza al elemento recién agregado, y no hay acceso al futuro truncado.
@(test)
test_add_after_undo_then_undo :: proc(t: ^testing.T) {
	buf: [STACK_SIZE]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	s1, s2, s3 := 10, 20, 30
	undo_stack_add(&u, &s1)
	undo_stack_add(&u, &s2)
	undo_stack_add(&u, &s3)

	undo_stack_undo(&u)

	new_val := 25
	undo_stack_add(&u, &new_val)

	r, ok := undo_stack_undo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 20)

	r, ok = undo_stack_redo(&u)
	testing.expect(t, ok)
	testing.expect(t, r^ == 25)

	_, can_redo := undo_stack_redo(&u)
	testing.expect(t, can_redo == false)
}

// Caso: getters de índices tras múltiples overflows (7 adds a stack de 3).
// Verifica que los índices se envuelven correctamente en el buffer circular
// después de escribir más de el doble de la capacidad.
@(test)
test_getters_after_overflow :: proc(t: ^testing.T) {
	buf: [3]int
	u := Undo_Stack(int) {
		stack = buf[:],
	}

	for i in 1 ..= 7 {
		v := i
		undo_stack_add(&u, &v)
	}

	testing.expect(t, undo_stack_get_bottom_index(&u) == 1)
	testing.expect(t, undo_stack_get_top_index(&u) == 0)
	testing.expect(t, undo_stack_get_current_index(&u) == 0)
}
