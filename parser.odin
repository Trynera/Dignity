package main

import "core:fmt"

/*
    The data on each node can be multiple things,
    specifically for identifiers it is a symbol index!
*/

ParserContext :: struct {
	tree_nodes: [dynamic]ASTNode,
	symbols:    ^SymbolTable,
	tokens:     ^TokenTable,
}

create_parser_context :: proc(tokenizer_context: ^TokenizerContext) -> ParserContext {
	parser_context := ParserContext{}

	parser_context.tree_nodes = make([dynamic]ASTNode, 1)
	parser_context.symbols = &tokenizer_context.symbols
	parser_context.tokens = &tokenizer_context.tokens

	return parser_context
}

destroy_parser_context :: proc(self: ^ParserContext) {
	for node_index := 0; node_index < len(self.tree_nodes); node_index += 1 {
		destroy_node(&self.tree_nodes[node_index])
	}

	if self.tree_nodes != nil {
		delete(self.tree_nodes)
	}
}

NodeType :: enum {
	PROGRAM,
	BLOCK,
	IDENTIFIER,
	DEFINE_CONST,
	DEFINE_SET,
	SET,
	PLUS,
	CONSTANT,
	ARGUMENT,
}

NodeIndex :: int

ASTNode :: struct {
	children: [dynamic]NodeIndex,
	type:     NodeType,
	data:     int,
}

ParserStatus :: enum {
	SUCCESS,
	FAILURE,
}

create_node :: proc(type: NodeType, data: int = 0, children: []NodeIndex = {}) -> ASTNode {
	node := ASTNode {
		children = make([dynamic]NodeIndex, 0, len(children)),
		type     = type,
		data     = data,
	}
	copy(node.children[:], children)

	return node
}

destroy_node :: proc(self: ^ASTNode) {
	delete(self.children)
}

parse_program :: proc(self: ^ParserContext) -> ParserStatus {
	for token_index := 0; token_index < len(self.tokens); token_index += 1 {
		if self.tokens[token_index].type == .FILEPATH {
			continue
		}

		parse_tlstmt(self, &token_index) or_return
		append(&self.tree_nodes[0].children, len(self.tree_nodes) - 1)
	}

	return .SUCCESS
}

parse_tlstmt :: proc(self: ^ParserContext, token_index: ^int) -> ParserStatus {
	current_token := &self.tokens[token_index^]

	if current_token.type != .IDENTIFIER {
		fmt.printfln(
			"Token at {}:{} isn't an identifier",
			current_token.line,
			current_token.column,
		)

		return .FAILURE
	}

	identifier_node := create_node(.IDENTIFIER, current_token.symbol_index)

	token_index^ += 1
	current_token = &self.tokens[token_index^]

	if current_token.type != .COLON {
		fmt.printfln("Token at {}:{} isn't a COLON", current_token.line, current_token.column)

		return .FAILURE
	}

	token_index^ += 1
	current_token = &self.tokens[token_index^]

	type_identifier := "auto"
	type_data := current_token.symbol_index
	if current_token.type != .COLON {
		type_identifier = get_symbol(self.symbols, type_data)
	}

	define_node := create_node(.DEFINE_CONST, type_data, {len(self.tree_nodes)})

	append(&define_node.children, len(self.tree_nodes))
	append(&self.tree_nodes, identifier_node)

	token_index^ += 1
	parse_expr(self, token_index) or_return

	append(&define_node.children, len(self.tree_nodes) - 1)
	append(&self.tree_nodes, define_node)

	return .SUCCESS
}

parse_stmt :: proc(self: ^ParserContext, token_index: ^int) -> ParserStatus {
	current_token := &self.tokens[token_index^]

	if current_token.type != .IDENTIFIER {
		fmt.printfln(
			"Token at {}:{} isn't an identifier",
			current_token.line,
			current_token.column,
		)

		return .FAILURE
	}

	identifier_node := create_node(.IDENTIFIER, current_token.symbol_index)

	token_index^ += 1
	current_token = &self.tokens[token_index^]

	if current_token.type != .COLON {
		fmt.printfln("Token at {}:{} isn't a COLON", current_token.line, current_token.column)

		return .FAILURE
	}

	token_index^ += 1
	current_token = &self.tokens[token_index^]

	type_identifier := "auto"
	type_data := current_token.symbol_index
	if current_token.type != .EQUAL {
		type_identifier = get_symbol(self.symbols, type_data)

		token_index^ += 1
	}

	define_node := create_node(.DEFINE_SET, type_data, {len(self.tree_nodes)})

	append(&define_node.children, len(self.tree_nodes))
	append(&self.tree_nodes, identifier_node)

	token_index^ += 1
	parse_expr(self, token_index) or_return

	append(&define_node.children, len(self.tree_nodes) - 1)
	append(&self.tree_nodes, define_node)

	return .SUCCESS
}

parse_expr :: proc(self: ^ParserContext, token_index: ^int) -> ParserStatus {
	current_token := &self.tokens[token_index^]

	if current_token.type == .LPAREN {
		token_index^ += 1
		current_token = &self.tokens[token_index^]

		if current_token.type == .RPAREN {
			return parse_func(self, token_index)
		}
	}

	constant_node := create_node(.CONSTANT, current_token.symbol_index)
	append(&self.tree_nodes, constant_node)

	return .SUCCESS
}

parse_func :: proc(self: ^ParserContext, token_index: ^int) -> ParserStatus {
	current_token := &self.tokens[token_index^]

	if current_token.type != .RPAREN {
	}

	token_index^ += 1
	current_token = &self.tokens[token_index^]

	if current_token.type != .LBRACE {
		fmt.printfln("Expected Codeblock, found {}", current_token)

		return .FAILURE
	}

	token_index^ += 1

	block_node := create_node(.BLOCK)

	for ; self.tokens[token_index^].type != .RBRACE; token_index^ += 1 {
		if self.tokens[token_index^].type == .FILEPATH {
			continue
		}

		parse_stmt(self, token_index) or_return
		append(&block_node.children, len(self.tree_nodes) - 1)
	}

	append(&self.tree_nodes, block_node)

	return .SUCCESS
}

