mod encoder;
mod parser;

use byteorder::{LittleEndian, WriteBytesExt};
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

    let mut binary_out = Vec::new();
    let mut line_num = 0;
    for line in reader.lines() {
        if let Ok(orig_line) = line {
            if let Some(instruction) = parser::parse_line(&orig_line) {
                let mcode = instruction.encode();
                println!("Line {}: {:08X} - {}", line_num + 1, mcode, orig_line);
                binary_out.push(mcode);
            }
        } else {
            eprintln!("Error on line {}:", line_num + 1);
            std::process::exit(1);
        }
        line_num += 1;
    }

    // 1. Write binary file (.bin) for ax-emu
    let mut file = File::create(output_path).expect("Failed to create binary output file");
    for &word in &binary_out {
        file.write_u32::<LittleEndian>(word).expect("Failed to write to file");
    }

    // 2. Write hex file (.hex) for Verilog readmemh
    let hex_path = output_path.replace(".bin", ".hex");
    let mut hex_file = File::create(&hex_path).unwrap_or_else(|_| File::create(format!("{}.hex", output_path)).unwrap());
    for &word in &binary_out {
        writeln!(hex_file, "{:08X}", word).expect("Failed to write hex file");
    }

    println!("Assembly complete. Binary written to {}, Hex written to {}", output_path, hex_path);
}
