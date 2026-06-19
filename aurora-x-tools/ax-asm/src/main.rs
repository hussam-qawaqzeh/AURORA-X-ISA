mod encoder;
mod parser;

use std::env;
use std::fs::File;
use std::io::{BufRead, BufReader, Write};

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: ax-asm <input.s> -o <output.bin>");
        return;
    }

    let input_path = &args[1];
    let output_path = if args.len() == 4 && args[2] == "-o" {
        &args[3]
    } else {
        "out.bin"
    };

    let file = File::open(input_path).expect("Failed to open input file");
    let reader = BufReader::new(file);

    let mut out_file = File::create(output_path).expect("Failed to create output file");

    let mut line_num = 1;
    for line in reader.lines() {
        if let Ok(line) = line {
            if let Some(instruction) = parser::parse_line(&line) {
                let encoded = instruction.encode();
                // AURORA-X is strictly Little-Endian
                out_file.write_all(&encoded.to_le_bytes()).expect("Failed to write to output");
                println!("Line {}: {:08X} - {}", line_num, encoded, line);
            }
        }
        line_num += 1;
    }

    println!("Assembly complete. Binary written to {}", output_path);
}
