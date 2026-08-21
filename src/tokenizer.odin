package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

TokenizerContext :: struct {
	open_file:     string,
	symbols:       SymbolTable,
	tokens:        TokenTable,
	content:       []rune,
	current_line:  u32,
	column_offset: u32,
}

create_tokenizer_context :: proc() -> TokenizerContext {
	tokenizer_context := TokenizerContext{}

	tokenizer_context.symbols = make(SymbolTable, 1)
	tokenizer_context.tokens = make(TokenTable, 1)

	return tokenizer_context
}

destroy_tokenizer_context :: proc(self: ^TokenizerContext) {
	delete(self.symbols)
	delete(self.tokens)
}

TokenType :: enum {
	UNKNOWN,
	IDENTIFIER,
	CONSTANT,
	COLON,
	SEMICOLON,
	EQUAL,
	PLUS,
	DIV,
	LPAREN,
	RPAREN,
	LBRACE,
	RBRACE,
	DIRECTIVE,
	FILEPATH,
}

TokenTable :: distinct [dynamic]Token

Token :: struct {
	type:         TokenType,
	symbol_index: SymbolIndex,
	line:         u32,
	column:       u32,
}

TokenizerStatus :: enum {
	SUCCESS,
	FAILURE,
}

tokenize :: proc(self: ^TokenizerContext) -> TokenizerStatus {
	data, err := os.read_entire_file(self.open_file, context.allocator)
	if err != nil {
		fmt.printfln("Failed to find file at {}", self.open_file)
		return .FAILURE
	}
	defer delete(data, context.allocator)

	self.symbols[0] = self.open_file
	self.tokens[0] = Token {
		type         = .FILEPATH,
		symbol_index = 0,
	}

	self.content = utf8.string_to_runes(string(data))
	self.current_line = 0
	self.column_offset = 0
	for index := 0; index < len(self.content); index += 1 {
		tokenize_character(self, &index) or_return
	}

	delete(self.content)

	return .SUCCESS
}

tokenize_character :: proc(self: ^TokenizerContext, index: ^int) -> TokenizerStatus {
	character := self.content[index^]
	if unicode.is_white_space(character) {
		if character == '\r' {
			index^ += 1
			character = self.content[index^]
		}
		self.column_offset = character == '\n' ? u32(index^) : self.column_offset
		self.current_line += character == '\n' ? 1 : 0
		return .SUCCESS
	}

	current_token := Token {
		symbol_index = NO_SYMBOL_INDEX,
		line         = self.current_line,
		column       = u32(index^) - self.column_offset,
	}

	switch {
	case character == ':':
		current_token.type = .COLON
	case character == ';':
		current_token.type = .SEMICOLON
	case character == '=':
		current_token.type = .EQUAL
	case character == '+':
		current_token.type = .PLUS
	case character == '/':
		current_token.type = .DIV
		next_token := self.content[index^ + 1]
		if next_token == '/' {
			index^ += 2
			for ; self.content[index^] != '\n'; index^ += 1 {}
			self.column_offset = u32(index^)
			self.current_line += 1
			index^ -= 1
			return .SUCCESS
		}
		if next_token != '*' {
			break
		}

		index^ += 2
		for comment_blocks := 1; comment_blocks > 0; index^ += 1 {
			if self.content[index^] == '*' && self.content[index^ + 1] == '/' {
				comment_blocks -= 1
				index^ += 1
			} else if self.content[index^] == '/' && self.content[index^ + 1] == '*' {
				comment_blocks += 1
				index^ += 1
			}
		}
		self.column_offset = u32(index^)
		self.current_line += 1
		index^ -= 1
		return .SUCCESS
	case character == '(':
		current_token.type = .LPAREN
	case character == ')':
		current_token.type = .RPAREN
	case character == '{':
		current_token.type = .LBRACE
	case character == '}':
		current_token.type = .RBRACE
	case character == '#':
		current_token.type = .DIRECTIVE

		index^ += 1

		symbol_builder, err := strings.builder_make(0, 16)
		if err != nil {
			fmt.println("Failed to create symbol builder.")
			return .FAILURE
		}

		for ; !unicode.is_white_space(self.content[index^]); index^ += 1 {
			strings.write_rune(&symbol_builder, self.content[index^])
		}

		symbol_string := strings.to_string(symbol_builder)

		current_token.symbol_index = append_symbol(&self.symbols, symbol_string)

		strings.builder_destroy(&symbol_builder)
	case:
		current_token.type = .IDENTIFIER

		symbol_builder, err := strings.builder_make(0, 16)
		if err != nil {
			fmt.println("Failed to create symbol builder.")
			return .FAILURE
		}

		for ; !is_special_character(self.content[index^]) &&
		    !unicode.is_white_space(self.content[index^]);
		    index^ += 1 {
			strings.write_rune(&symbol_builder, self.content[index^])
		}

		symbol_string := strings.to_string(symbol_builder)

		current_token.symbol_index = append_symbol(&self.symbols, symbol_string)

		strings.builder_destroy(&symbol_builder)
	case unicode.is_digit(character):
		current_token.type = .CONSTANT
		current_token.symbol_index = len(self.symbols)

		digits := strings.builder_make(1)

		for ; unicode.is_digit(self.content[index^]); index^ += 1 {
			strings.write_rune(&digits, self.content[index^])
		}

		if self.content[index^] == '.' {
			strings.write_rune(&digits, self.content[index^])
			index^ += 1
			for ; unicode.is_digit(self.content[index^]); index^ += 1 {
				strings.write_rune(&digits, self.content[index^])
			}
		}

		append(&self.symbols, strings.to_string(digits))

		strings.builder_destroy(&digits)
	}

	append(&self.tokens, current_token)

	return .SUCCESS
}
