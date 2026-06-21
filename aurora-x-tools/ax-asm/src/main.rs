mod encoder;
mod parser;

use byteorder::{LittleEndian, WriteBytesExt};
use std::collections::HashMap;
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
    let lines: Vec<String> = reader.lines().filter_map(|l| l.ok()).collect();

    // ================================
    // PASS 1: Symbol Resolution
    // ================================
    let mut labels: HashMap<String, u32> = HashMap::new();
    let mut current_pc = 0;

    for line in &lines {
        let clean_line = line.split(';').next().unwrap_or("").trim();
        if clean_line.is_empty() {
            continue;
        }

        if clean_line.ends_with(':') {
            // It's a label definition, e.g. "loop_start:"
            let label_name = clean_line.trim_end_matches(':').trim().to_string();
            labels.insert(label_name, current_pc);
        } else {
            // It's a real instruction
            current_pc += 4;
        }
    }

    // ================================
    // PASS 2: Code Generation
    // ================================
    let mut binary_out = Vec::new();
    current_pc = 0;
    let mut line_num = 0;

    for line in &lines {
        line_num += 1;
        let clean_line = line.split(';').next().unwrap_or("").trim();
        if clean_line.is_empty() || clean_line.ends_with(':') {
            continue;
        }

        if let Some(instruction) = parser::parse_line(clean_line, &labels, current_pc) {
            let mcode = instruction.encode();
            println!("Line {}: PC={:04X} {:08X} - {}", line_num, current_pc, mcode, clean_line);
            binary_out.push(mcode);
            current_pc += 4;
        } else {
            eprintln!("Error parsing on line {}: {}", line_num, line);
            std::process::exit(1);
        }
    }

    // 1. Write binary file (.bin) for ax-emu
    let bin_path = if output_path.ends_with(".hex") { output_path.replace(".hex", ".bin") } else { output_path.to_string() };
    let mut file = File::create(&bin_path).expect("Failed to create binary output file");
    for &word in &binary_out {
        file.write_u32::<LittleEndian>(word).expect("Failed to write to file");
    }

    // 2. Write hex file (.hex) for Verilog readmemh
    let hex_path = if output_path.ends_with(".hex") { output_path.to_string() } else { output_path.replace(".bin", ".hex") };
    let mut hex_file = File::create(&hex_path).unwrap_or_else(|_| File::create(format!("{}.hex", output_path)).unwrap());
    for &word in &binary_out {
        writeln!(hex_file, "{:08X}", word).expect("Failed to write hex file");
    }

    println!("Assembly complete. Resolving {} labels. Binary written to {}, Hex written to {}", labels.len(), output_path, hex_path);
}
