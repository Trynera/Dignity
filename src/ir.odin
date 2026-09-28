package main

import "core:fmt"
import "core:strings"

IAType :: enum {
	LINE_VAR,
	GAME_VAR,
	NUM,
	TXT,
	STR,
	MATH,
}

InstructionArgument :: struct {
	type: IAType,
	data: uint,
}

InstructionType :: enum {
	FUNCTION,
	PROCESS,
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
		arguments = make([dynamic]InstructionArgument, len(arguments)),
	}
	copy(instruction.arguments[:], arguments)

	return instruction
}

InstructionTable :: distinct [dynamic]Instruction

IRGeneratorContext :: struct {
	tree_nodes:   ^[dynamic]ASTNode,
	symbols:      ^SymbolTable,
	variables:    map[string]string,
	constants:	  map[string]string,
	instructions: InstructionTable,
	builder:      strings.Builder,
	item_slot:    u32,
	block_depth:  u32,
}

create_ir_generator_context :: proc(parser_context: ^ParserContext) -> IRGeneratorContext {
	ir_generator_context := IRGeneratorContext{}

	ir_generator_context.tree_nodes = &parser_context.tree_nodes
	ir_generator_context.symbols = parser_context.symbols
	ir_generator_context.variables = make(map[string]string)
	ir_generator_context.constants = make(map[string]string)
	ir_generator_context.instructions = make(InstructionTable)
	ir_generator_context.builder = strings.builder_make(0, 16)

	return ir_generator_context
}

destroy_ir_generator_context :: proc(self: ^IRGeneratorContext) {
	for instruction in self.instructions {
		delete(instruction.arguments)
	}

	delete(self.variables)
	delete(self.constants)
	delete(self.instructions)
	strings.builder_destroy(&self.builder)
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
	case .FUNCTION:
		append(
			&self.instructions,
			create_instruction(current_node.data == 0 ? .FUNCTION : .PROCESS),
		)

		for child_index in current_node.children {
			create_ir_from_node(self, &self.tree_nodes[child_index]) or_return
		}

		append(&self.instructions, create_instruction(.END))

		return .SUCCESS
	case .DEFINE_CONST:
		last_child := len(current_node.children) - 1
		if self.tree_nodes[current_node.children[last_child]].type == .FUNCTION {
			break
		}

		identifier := get_symbol(self.symbols, self.tree_nodes[current_node.children[0]].data)
		value := get_symbol(self.symbols, self.tree_nodes[current_node.children[1]].data)
		self.constants[identifier] = value

		return .SUCCESS
	case .DEFINE_SET:
		append(&self.instructions, create_instruction(.SET))
	case .DEFINE:
		identifier := get_symbol(self.symbols, self.tree_nodes[current_node.children[0]].data)
		variable_type := get_symbol(self.symbols, current_node.data)

		self.constants[identifier] = variable_type

		return .SUCCESS
	case .SET:
		_, ok := self.constants[get_symbol(self.symbols, current_node.data)]
		append(
			&self.instructions,
			create_instruction(
				.SET,
				{InstructionArgument{type = ok ? .GAME_VAR : .LINE_VAR, data = current_node.data}},
			),
		)
	case .OPERATOR:
		operators_symbol := get_symbol(self.symbols, current_node.data)

		item_builder := strings.builder_make(0, 4)
		current_child_node: ^ASTNode

		for child_index, current_index in current_node.children {
			if current_index != 0 {
				strings.write_byte(&item_builder, operators_symbol[current_index-1])
			}
			current_child_node = &self.tree_nodes[child_index]
			constant_value, ok := self.constants[get_symbol(self.symbols, current_child_node.data)]

			if ok {
				strings.write_string(&item_builder, constant_value)
				continue
			}

			strings.write_string(&item_builder, get_symbol(self.symbols, current_child_node.data))
		}

		symbol_string := strings.to_string(item_builder)
		symbol_index := append_symbol(self.symbols, &symbol_string)

		append(
			&self.instructions[len(self.instructions) - 1].arguments,
			InstructionArgument{type = .MATH, data = symbol_index},
		)

		return .SUCCESS
	case .CONSTANT:
		variable_value, ok := self.constants[get_symbol(self.symbols, current_node.data)]

		if ok {
			current_node.data = append_symbol(self.symbols, &variable_value)
		}

		first_char := get_symbol(self.symbols, current_node.data)[0]
		argument_type := first_char == '"' ? IAType.TXT : (first_char == 's') ? IAType.STR : IAType.NUM

		append(
			&self.instructions[len(self.instructions) - 1].arguments,
			InstructionArgument{type = argument_type, data = current_node.data},
		)

		return .SUCCESS
	case .IDENTIFIER:
		identifier := get_symbol(self.symbols, current_node.data)
		variable_value, ok := self.constants[identifier]

		if !ok {
			append(
				&self.instructions[len(self.instructions) - 1].arguments,
				InstructionArgument{type = .LINE_VAR, data = current_node.data},
			)

			return .SUCCESS
		}

		value_node := ASTNode{}
		value_node.type = .CONSTANT
		value_node.data = append_symbol(self.symbols, &variable_value)

		create_ir_from_node(self, &value_node) or_return

		return .SUCCESS
	}

	for child_index in current_node.children {
		create_ir_from_node(self, &self.tree_nodes[child_index]) or_return
	}

	return .SUCCESS
}

create_json_from_ir :: proc(self: ^IRGeneratorContext) -> string {
	strings.write_string(&self.builder, "{\"blocks\":[")

	for &instruction, index in self.instructions {
		if index > 0 && !(instruction.type == .END && self.block_depth >= 0) {
			strings.write_rune(&self.builder, ',')
		}
		create_json_from_instruction(self, &instruction)
	}

	strings.write_string(&self.builder, "]}")

	return strings.to_string(self.builder)
}

create_json_from_instruction :: proc(self: ^IRGeneratorContext, instruction: ^Instruction) {
	switch instruction.type {
	case .FUNCTION:
		strings.write_string(&self.builder, "{\"block\":\"func\",\"data\":\"")
		strings.write_string(
			&self.builder,
			get_symbol(self.symbols, instruction.arguments[0].data),
		)
		strings.write_string(
			&self.builder,
			"\",\"id\":\"block\",\"args\":{\"items\":[{\"item\":{\"id\":\"bl_tag\",\"data\":{\"option\":\"False\",\"tag\":\"Is Hidden\",\"action\":\"dynamic\",\"block\":\"func\"}},\"slot\":26}]}}",
		)
	case .PROCESS:
		strings.write_string(&self.builder, "{\"block\":\"process\",\"data\":\"")
		strings.write_string(
			&self.builder,
			get_symbol(self.symbols, instruction.arguments[0].data),
		)
		strings.write_string(
			&self.builder,
			"\",\"id\":\"block\",\"args\":{\"items\":[{\"item\":{\"id\":\"bl_tag\",\"data\":{\"option\":\"False\",\"tag\":\"Is Hidden\",\"action\":\"dynamic\",\"block\":\"process\"}},\"slot\":26}]}}",
		)
	case .SET:
		strings.write_string(
			&self.builder,
			"{\"id\":\"block\",\"action\":\"=\",\"args\":{\"items\":[",
		)

		for &argument, index in instruction.arguments {
			if index > 0 {
				strings.write_rune(&self.builder, ',')
			}
			create_json_from_argument(self, &self.builder, &argument)
			self.item_slot += 1
		}
		self.item_slot = 0

		strings.write_string(
			&self.builder,
			"]},\"block\":\"set_var\",\"inverted\":\"\",\"attribute\":\"\",\"target\":\"\"}",
		)
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
		strings.write_string(output_json, get_symbol(self.symbols, argument.data))
		strings.write_string(output_json, "\",\"scope\":\"line\"")
	case .GAME_VAR:
		strings.write_string(output_json, "\"id\":\"var\",\"data\":{\"name\":\"")
		strings.write_string(output_json, get_symbol(self.symbols, argument.data))
		strings.write_string(output_json, "\",\"scope\":\"unsaved\"")
	case .NUM:
		strings.write_string(output_json, "\"id\":\"num\",\"data\":{\"name\":\"")
		strings.write_string(output_json, get_symbol(self.symbols, argument.data))
		strings.write_string(output_json, "\"")
	case .TXT:
		strings.write_string(output_json, "\"id\":\"txt\",\"data\":{\"name\":\"")
		strings.write_string(output_json, get_symbol(self.symbols, argument.data)[1:])
		strings.write_string(output_json, "\"")
	case .STR:
		strings.write_string(output_json, "\"id\":\"comp\",\"data\":{\"name\":\"")
		strings.write_string(output_json, get_symbol(self.symbols, argument.data)[1:])
		strings.write_string(output_json, "\"")
	case .MATH:
		strings.write_string(output_json, "\"id\":\"num\",\"data\":{\"name\":\"%math(")
		strings.write_string(output_json, get_symbol(self.symbols, argument.data))
		strings.write_string(output_json, ")\"")
	}

	strings.write_string(output_json, "}}}")
}
