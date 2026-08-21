package main

import "core:fmt"
import "core:mem"
import "core:os"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	cmd_args := os.args

	if len(cmd_args) < 2 {
		fmt.println("Usage: dignity <file path>")
		return
	}

	tokenizer_context := create_tokenizer_context()
	defer destroy_tokenizer_context(&tokenizer_context)

	tokenizer_context.open_file = cmd_args[1]
	tokenizer_status := tokenize(&tokenizer_context)
	if tokenizer_status != .SUCCESS {
		fmt.printfln("{}\n", tokenizer_context.symbols[:])
		fmt.println(tokenizer_context.tokens[:])
		return
	}

	fmt.printfln("{}\n", tokenizer_context.symbols[:])

	parser_context := create_parser_context(&tokenizer_context)
	defer destroy_parser_context(&parser_context)

	parser_status := parse_program(&parser_context)
	if parser_status != .SUCCESS {
		fmt.printfln("{}\n", parser_context.symbols^)
		fmt.println(parser_context.tree_nodes[:])
		return
	}

	ir_generator_context := create_ir_generator_context(&parser_context)

	defer destroy_ir_generator_context(&ir_generator_context)

	ir_generator_status := create_ir_from_ast(&ir_generator_context)
	if ir_generator_status != .SUCCESS {
		fmt.printfln("{}\n", ir_generator_context.symbols^)
		for node in ir_generator_context.tree_nodes^ {
			fmt.println(node)
		}
		fmt.printfln("\n{}", ir_generator_context.instructions[:])
		return
	}

	generated_json := create_json_from_ir(&ir_generator_context)

	fmt.println(generated_json)
}
