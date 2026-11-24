package main

import "core:fmt"
import "core:strings"
import "core:unicode"
import "core:math/bits"

SymbolTable :: distinct [dynamic]string

SymbolIndex :: uint

NO_SYMBOL_INDEX :: bits.UINT_MAX

get_symbol :: proc(self: ^SymbolTable, index: SymbolIndex) -> string {
	if index == NO_SYMBOL_INDEX {
		return ""
	}

	return self[index]
}

append_symbol :: proc(self: ^SymbolTable, symbol: string) -> SymbolIndex {
	for cur_symbol, index in self {
		if cur_symbol == symbol do return SymbolIndex(index)
	}

	cloned_string, err := strings.clone(symbol)
	if err != nil {
		fmt.eprintfln("Some bs: {}", err)

		return len(self) - 1
	}

	append(self, cloned_string)

	return len(self) - 1
}

is_special_character :: proc(r: rune) -> bool {
	switch (r) {
	case '!'..='/':
		break
	case ':'..='@':
		break
	case '['..='^':
		break
	case '{'..='~':
		break
	case:
		return false
	}

	return true
}
