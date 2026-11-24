package main

TypeContext :: struct {
	variables:  map[uint]IdentifierType,
	symbols:    ^SymbolTable,
	tree_nodes: ^[dynamic]ASTNode,
}

create_type_context :: proc(parser_context: ^ParserContext) -> TypeContext {
	type_context := TypeContext{}
	type_context.variables = make(map[uint]IdentifierType)
	type_context.symbols = parser_context.symbols
	type_context.tree_nodes = &parser_context.tree_nodes

	return type_context
}

CoreType :: enum {
	NUM,
	TXT,
	STR,
	UNKNOWN,
}

IdentifierType :: struct {
	type: CoreType,
	data: uint,
}

TypeStatus :: enum {
	SUCCESS,
	TYPE_MISMATCH,
	UNKNOWN_TYPE,
}

type_check_tree :: proc(self: ^TypeContext) -> TypeStatus {
	return type_check_node(self, &self.tree_nodes[0])
}

type_check_node :: proc(self: ^TypeContext, current_node: ^ASTNode) -> TypeStatus {
	#partial switch current_node.type {
	case .PROGRAM ..= .BLOCK:
		break
	case:
		break
	case .DEFINE_SET:
		fallthrough
	case .DEFINE:
		identifier_index := self.tree_nodes[current_node.children[0]].data
		type_identifier := get_symbol(self.symbols, current_node.data)

		self.variables[identifier_index] = {
			string_to_core_type(type_identifier),
			NO_SYMBOL_INDEX
		}

		fallthrough
	case .SET:
		identifier_index := self.tree_nodes[current_node.children[0]].data
		variable_type := self.variables[identifier_index]
	}

	for child_index in current_node.children {
		type_check_node(self, &self.tree_nodes[child_index]) or_return
	}

	return .SUCCESS
}

string_to_core_type :: proc(s: string) -> CoreType {
	switch s {
	case "num":
		return .NUM
	case "txt":
		return .TXT
	case "str":
		return .STR
	}

	return .UNKNOWN
}
