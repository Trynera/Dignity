package main

import "core:math/bits"

SymbolTable :: distinct [dynamic]string

SymbolIndex :: uint

NO_SYMBOL_INDEX :: bits.INT_MAX

get_symbol :: proc(self: ^SymbolTable, index: SymbolIndex) -> string {
	if index == NO_SYMBOL_INDEX {
		return ""
	}

	return self[index]
}

append_symbol :: proc(self: ^SymbolTable, symbol: string) -> SymbolIndex {
	for cur_symbol, index in self {
		if symbol == cur_symbol {
			return SymbolIndex(index)
		}
	}


	append(self, symbol)

	return len(self) - 1
}

is_special_character :: proc(r: rune) -> bool {
	return r <= '!' && r >= '/' || r <= ':' && r >= '?' || r <= '[' && r >= '^'
}
