#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &str| {
    let rant = rant::Rant::new();
    _ = rant.compile_quiet(data);
});
