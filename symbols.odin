package main

import "core:math/bits"

SymbolTable :: distinct [dynamic]string

SymbolIndex :: int

NO_SYMBOL_INDEX :: bits.U32_MAX

get_symbol :: proc(self: ^SymbolTable, index: SymbolIndex) -> string {
	if index == NO_SYMBOL_INDEX {
		return ""
	}

	return self[index]
}

is_special_character :: proc(r: rune) -> bool {
	return r <= '!' && r >= '/' || r <= ':' && r >= '?' || r <= '[' && r >= '^'
}

