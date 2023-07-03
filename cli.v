module cli

import math
import os

pub enum Type {
	any
	bool
	int
	i64
	f64
	string
}

fn Type.from_str(str string) !Type {
	if str == 'any' {
		return .any
	}
	if str == 'bool' {
		return .bool
	}
	if str == 'int' {
		return .int
	}
	if str == 'i64' {
		return .i64
	}
	if str == 'f64' {
		return .f64
	}
	if str == 'string' {
		return .string
	}
	return error('Unknown type')
}

pub struct Argument {
pub:
	name string
	typ  Type
}

pub struct ProgramOption {
pub:
	long_key      string
	short_key     string
	default_value Input = 'false'.bool() // workaround for checker warning
	description   string
}

pub struct Program {
pub:
	name        string
	description string
	version     string
	arguments   []Argument
	options     []ProgramOption
}

pub fn (p Program) help() string {
	mut out := 'Usage:  ${p.name}'

	if p.options.len != 0 {
		out += ' [OPTIONS]'
	}

	if p.arguments.len != 0 {
		for arg in p.arguments {
			out += ' <${arg}>'
		}
	}

	out += '\n${p.description}'

	if p.options.len != 0 {
		out += '\n\nOptions:\n'
		for i, opt in p.options {
			opt_str := '-${opt.short_key}, --${opt.long_key}'
			out += (opt_str + ' '.repeat(math.max(2, 30 - opt_str.len)) + opt.description +
				if i != p.options.len - 1 { '\n' } else { '' })
		}
	}

	return out
}

pub fn (p Program) parse() ParsedProgram {
	mut parsed_pos_args := []?Input{}
	mut parsed_opts := map[string]Input{}
	mut long_options := map[string]Input{}
	mut short_options := map[string]Input{}
	mut j := 0
	for i := 1; i < os.args.len; i++ {
		e := os.args[i]
		if e.len > 1 && e.substr(0, 1) == '-' {
			start := if e.len > 2 && e.substr(1, 2) == '-' { 2 } else { 1 }
			eq_idx := e.index('=')
			mut key := ''
			mut value := 'true'
			if eq_idx != none {
				key = e.substr(start, eq_idx as int)
				value = e.substr(eq_idx as int + 1, e.len)
				i++
			} else {
				key = e.substr(start, e.len)
			}
			if start == 2 {
				long_options[key] = value
			} else {
				short_options[key] = value
			}
		} else {
			parsed_pos_args << parse_input_type(e, p.arguments[j].typ)
			j++
		}
	}

	for opt in p.options {
		parsed_opts[opt.long_key] = parse_input_type(long_options[opt.long_key] or {
			short_options[opt.short_key] or { opt.default_value }
		}, Type.from_str(opt.default_value.type_name()) or { Type.string }) or { opt.default_value }
	}

	for j < p.arguments.len {
		parsed_pos_args << ?Input(none)
		j++
	}

	return ParsedProgram{
		options: parsed_opts
		arguments: parsed_pos_args
	}
}

// returns none if not possible to cast to type
fn parse_input_type(inp Input, typ Type) ?Input {
	match inp {
		string {
			if typ == .bool || typ == .any {
				if inp == 'true' {
					return true
				}
				if inp == 'false' {
					return false
				}
			}

			if typ == .int || typ == .any {
				return inp.int()
			}

			if typ == .i64 || typ == .any {
				return inp.i64()
			}

			if typ == .f64 || typ == .any {
				return inp.f64()
			}

			if typ == .string || typ == .any {
				return inp
			}
		}
		else {
			if inp.type_name() == typ.str() {
				return inp
			}
		}
	}
	return none
	// return error('Could not cast to type')
}

type Input = bool | f64 | i64 | int | string
type ParsedProgramOption = map[string]Input
type ParsedProgramPositional = []?Input

pub struct ParsedProgram {
	options ParsedProgramOption
pub:
	arguments ParsedProgramPositional
}

pub fn (p ParsedProgram) get_opt(opt string) Input {
	return p.options[opt] or { false }
}
