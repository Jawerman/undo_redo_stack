package main
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import "lib/undo"
import rl "vendor:raylib"

test_stack: undo.Undo_Stack(int)

WIDTH, HEIGHT :: 800, 600
STACK_SIZE :: 10
STACK_BLOCK_DRAW_SIZE :: [2]i32{100, 50}
STACK_TOTAL_HEIGHT :: STACK_SIZE * STACK_BLOCK_DRAW_SIZE.y
STACK_DRAWING_POSITION :: [2]i32{20, 50}
FONT_SIZE :: 20
FONT_PADDING :: [2]i32{STACK_BLOCK_DRAW_SIZE.x / 2, STACK_BLOCK_DRAW_SIZE.y / 2 - FONT_SIZE / 2}

Indicators :: enum {
	Current,
	Top,
	Bottom,
}
INDICATOR_TEXTS: [Indicators]string = {
	.Top     = "Top",
	.Bottom  = "Bottom",
	.Current = "Current",
}

BLOCK_INDICATORS_GAP :: 20

main :: proc() {
	stack_content: [STACK_SIZE]int
	test_stack.stack = stack_content[:]

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WIDTH, HEIGHT, "Test window")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()

	state := 1
	next_state := state + 1

	undo.undo_stack_add(&test_stack, &state)
	for !rl.WindowShouldClose() {

		if rl.IsKeyPressed(.A) {
			state = next_state
			next_state += 1
			undo.undo_stack_add(&test_stack, &state)
		}
		if rl.IsKeyPressed(.R) {
			state = 1
			next_state = state + 1
			undo.undo_stack_reset(&test_stack)
		}

		if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.Z) {
			if rl.IsKeyDown(.LEFT_SHIFT) {
				if redo_state, can_redo := undo.undo_stack_redo(&test_stack); can_redo {
					state = redo_state^
				}
			} else {
				if undo_state, can_undo := undo.undo_stack_undo(&test_stack); can_undo {
					state = undo_state^
				}
			}
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		current_state := fmt.ctprint(state)
		rl.DrawText(current_state, BLOCK_INDICATORS_GAP, BLOCK_INDICATORS_GAP, 20, rl.WHITE)

		draw_stack(&test_stack)

		free_all(context.temp_allocator)
	}
}


draw_stack :: proc(u: ^undo.Undo_Stack(int)) {
	for &state, index in u.stack {
		block_relative_position := [2]i32 {
			0,
			STACK_TOTAL_HEIGHT - (i32(index + 1) * STACK_BLOCK_DRAW_SIZE.y),
		}

		block_position := STACK_DRAWING_POSITION + block_relative_position

		rl.DrawRectangleLines(
			block_position.x,
			block_position.y,
			STACK_BLOCK_DRAW_SIZE.x,
			STACK_BLOCK_DRAW_SIZE.y,
			rl.WHITE,
		)


		text := fmt.ctprint(state)

		half_text_size := rl.MeasureText(text, FONT_SIZE) / 2
		text_position := block_position + FONT_PADDING

		rl.DrawText(text, text_position.x - half_text_size, text_position.y, FONT_SIZE, rl.WHITE)

		present_indicators: [Indicators]bool

		present_indicators[.Top] = index == undo.undo_stack_get_top_index(u)
		present_indicators[.Current] = index == undo.undo_stack_get_current_index(u)
		present_indicators[.Bottom] = index == undo.undo_stack_get_bottom_index(u)

		half_block_width := STACK_BLOCK_DRAW_SIZE.x / 2
		indicators_position := text_position.x + half_block_width + BLOCK_INDICATORS_GAP

		for is_present, indicator_type in present_indicators {
			indicator_text := fmt.ctprint(INDICATOR_TEXTS[indicator_type])
			if is_present {
				rl.DrawText(
					indicator_text,
					indicators_position,
					text_position.y,
					FONT_SIZE,
					rl.WHITE,
				)
			}
			indicators_position += rl.MeasureText(indicator_text, FONT_SIZE) + BLOCK_INDICATORS_GAP
		}
	}
}
