#![no_main]
use libfuzzer_sys::fuzz_target;

// rant-cli target: drives the FULL path the `rant <file>` CLI exercises — compile
// AND run the program on the Rant VM. (The `compile` target only compiles.) Built as
// a cargo-fuzz libFuzzer binary so Mayhem reads coverage edges the same proven way
// the `compile` target does; an uninstrumented file-input `/mayhem/rant @@` carried
// no coverage Mayhem could read and failed live dynamic analysis.
fuzz_target!(|data: &str| {
    let mut rant = rant::Rant::new();
    if let Ok(program) = rant.compile_quiet(data) {
        let _ = rant.run(&program);
    }
});
