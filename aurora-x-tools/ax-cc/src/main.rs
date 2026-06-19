use std::env;
use std::fs;

pub mod lexer;
pub mod parser;
pub mod codegen;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: ax-cc <input.c> -o <output.s>");
        return;
    }

    let input_file = &args[1];
    let output_file = &args[3];

    let code = fs::read_to_string(input_file).expect("Failed to read input file");
    
    let tokens = lexer::lex(&code);
    let ast = parser::parse(&tokens);
    let asm = codegen::generate(&ast);

    fs::write(output_file, asm).expect("Failed to write output file");
    println!("Compilation complete. Output written to {}", output_file);
}
