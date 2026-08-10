package main

import "core:strings"
IAType :: enum {
	LINE_VAR,
	NUM,
}

InstructionArgument :: struct {
	type: IAType,
	data: int,
}

InstructionType :: enum {
	FUNCTION,
	SET,
	END,
}

Instruction :: struct {
	type:      InstructionType,
	arguments: [dynamic]InstructionArgument,
}

create_instruction :: proc(
	type: InstructionType,
	arguments := []InstructionArgument{},
) -> Instruction {
	instruction := Instruction {
		type      = type,
		arguments = make([dynamic]InstructionArgument, 0, len(arguments)),
	}
	copy(instruction.arguments[:], arguments)

	return instruction
}

InstructionTable :: distinct [dynamic]Instruction

IRGeneratorContext :: struct {
	tree_nodes:   ^[dynamic]ASTNode,
	symbols:      ^SymbolTable,
	instructions: InstructionTable,
	item_slot:    u32,
	block_depth:  u32,
}

create_ir_generator_context :: proc(parser_context: ^ParserContext) -> IRGeneratorContext {
	ir_generator_context := IRGeneratorContext{}

	ir_generator_context.tree_nodes = &parser_context.tree_nodes
	ir_generator_context.symbols = parser_context.symbols
	ir_generator_context.instructions = make(InstructionTable)

	return ir_generator_context
}

destroy_ir_generator_context :: proc(self: ^IRGeneratorContext) {
	for instruction in self.instructions {
		delete(instruction.arguments)
	}

	delete(self.instructions)
}

IRGeneratorStatus :: enum {
	SUCCESS,
	FAILURE,
}

create_ir_from_ast :: proc(self: ^IRGeneratorContext) -> IRGeneratorStatus {
	return create_ir_from_node(self, &self.tree_nodes[0])
}

create_ir_from_node :: proc(
	self: ^IRGeneratorContext,
	current_node: ^ASTNode,
) -> IRGeneratorStatus {
	output_code: Instruction

	#partial switch current_node.type {
	case .PROGRAM ..= .BLOCK:
		break
	case .DEFINE_CONST:
		append(&self.instructions, create_instruction(.FUNCTION))

		for child_index in current_node.children {
			create_ir_from_node(self, &self.tree_nodes[child_index]) or_return
		}
		append(&self.instructions, create_instruction(.END))

		return .SUCCESS
	case .DEFINE_SET:
		append(&self.instructions, create_instruction(.SET))
	case .CONSTANT:
		append(
			&self.instructions[len(self.instructions) - 1].arguments,
			InstructionArgument{type = .NUM, data = current_node.data},
		)

		return .SUCCESS
	case .IDENTIFIER:
		append(
			&self.instructions[len(self.instructions) - 1].arguments,
			InstructionArgument{type = .LINE_VAR, data = current_node.data},
		)

		return .SUCCESS
	}

	for child_index in current_node.children {
		create_ir_from_node(self, &self.tree_nodes[child_index]) or_return
	}

	return .SUCCESS
}

create_json_from_ir :: proc(self: ^IRGeneratorContext) -> string {
	output_json, err := strings.builder_make(0, 13)
	if err != nil {
		return ""
	}

	strings.write_string(&output_json, "{\"blocks\":[")

	for &instruction, index in self.instructions {
		if index > 0 && !(instruction.type == .END && self.block_depth >= 0) {
			strings.write_rune(&output_json, ',')
		}
		create_json_from_instruction(self, &output_json, &instruction)
	}

	strings.write_string(&output_json, "]}")

	return strings.to_string(output_json)
}

create_json_from_instruction :: proc(
	self: ^IRGeneratorContext,
	output_json: ^strings.Builder,
	instruction: ^Instruction,
) {
	switch instruction.type {
	case .FUNCTION:
		strings.write_string(output_json, "{\"block\":\"func\",\"data\":\"")
		strings.write_string(output_json, self.symbols[instruction.arguments[0].data])
		strings.write_string(
			output_json,
			"\",\"id\":\"block\",\"args\":{\"items\":[{\"item\":{\"id\":\"bl_tag\",\"data\":{\"option\":\"False\",\"tag\":\"Is Hidden\",\"action\":\"dynamic\",\"block\":\"func\"}},\"slot\":26}]}}",
		)
	case .SET:
		strings.write_string(
			output_json,
			"{\"id\":\"block\",\"action\":\"=\",\"args\":{\"items\":[",
		)

		for &argument, index in instruction.arguments {
			if index > 0 {
				strings.write_rune(output_json, ',')
			}
			create_json_from_argument(self, output_json, &argument)
			self.item_slot += 1
		}
		self.item_slot = 0

		strings.write_string(
			output_json,
			"]},\"block\":\"set_var\",\"inverted\":\"\",\"attribute\":\"\",\"target\":\"\"}",
		)

		break
	case .END:
	}
}

create_json_from_argument :: proc(
	self: ^IRGeneratorContext,
	output_json: ^strings.Builder,
	argument: ^InstructionArgument,
) {
	strings.write_string(output_json, "{\"slot\":")
	strings.write_uint(output_json, uint(self.item_slot))
	strings.write_string(output_json, ",\"item\":{")

	switch argument.type {
	case .LINE_VAR:
		strings.write_string(output_json, "\"id\":\"var\",\"data\":{\"name\":\"")
		strings.write_string(output_json, self.symbols[argument.data])
		strings.write_string(output_json, "\",\"scope\":\"line\"")
	case .NUM:
		strings.write_string(output_json, "\"id\":\"num\",\"data\":{\"name\":\"")
		strings.write_string(output_json, self.symbols[argument.data])
		strings.write_string(output_json, "\"")
	}

	strings.write_string(output_json, "}}}")
}

