package main

CoreType :: enum {
	NUM,
	TXT,
	STR,
}

IdentifierType :: struct {
	core: CoreType,
	data: uint,
}

TypeContext :: struct {
	variables:  map[string]IdentifierType,
	symbols:    ^SymbolTable,
	tree_nodes: ^[dynamic]ASTNode,
}

create_type_context :: proc(parser_context: ^ParserContext) -> TypeContext {
	type_context := TypeContext{}
	type_context.variables = make(map[string]IdentifierType)
	type_context.symbols = parser_context.symbols
	type_context.tree_nodes = &parser_context.tree_nodes

	return type_context
}
