package main

import "core:fmt"
import "core:os"

main :: proc() {
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

