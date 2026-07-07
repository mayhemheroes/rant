#!/usr/bin/env bash
#
# rant/mayhem/build.sh — build rant-lang/rant cargo-fuzz targets + CLI for Mayhem.
set -euo pipefail
# Rust instrumentation uses RUSTFLAGS (-Zsanitizer=address), NOT clang $SANITIZER_FLAGS.

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${MAYHEM_JOBS:=$(nproc)}"
export CARGO_BUILD_JOBS="$MAYHEM_JOBS"
: "${RUST_DEBUG_FLAGS:=-C debuginfo=2 -C force-frame-pointers=yes -C llvm-args=--dwarf-version=2}"

cd "$SRC"

ASAN_RT="$(find "$RUSTUP_HOME/toolchains" -name "librustc-nightly_rt.asan.a" 2>/dev/null | head -1)"
if [ -n "$ASAN_RT" ] && [ -f "$ASAN_RT" ]; then
  echo "Stripping debug info from Rust ASan runtime to enforce DWARF < 4: $ASAN_RT"
  objcopy --strip-debug "$ASAN_RT"
fi
export CFLAGS="${CFLAGS:+$CFLAGS }-gdwarf-3"
export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }-gdwarf-3"

FUZZ_DIR="mayhem/fuzz"
TRIPLE="x86_64-unknown-linux-gnu"

export RUSTFLAGS="${RUSTFLAGS:-} --cfg fuzzing -Zsanitizer=address ${RUST_DEBUG_FLAGS}"

# Two libFuzzer targets:
#   compile — compiles the input (rant::Rant::compile_quiet)
#   run     — compiles AND runs it on the Rant VM (the rant-cli path). libFuzzer is
#             the proven coverage mechanism for this repo; an uninstrumented, or a
#             sancov-only file-input, `/mayhem/rant @@` produced no edges Mayhem could
#             read and failed live dynamic analysis, so rant-cli now points at /mayhem/run.
echo "=== cargo fuzz build: libFuzzer targets (compile, run) + ASan ==="
echo "RUSTFLAGS=$RUSTFLAGS"
cargo fuzz build --fuzz-dir "$FUZZ_DIR" -O --debug-assertions
for t in compile run; do
  bin="$SRC/$FUZZ_DIR/target/$TRIPLE/release/$t"
  [ -x "$bin" ] || { echo "ERROR: missing $bin" >&2; exit 1; }
  cp "$bin" "/mayhem/$t"
  echo "built /mayhem/$t"
done

echo "=== cargo build: no-inst file-input reproducers (compile_no_inst, run_no_inst) ==="
RUSTFLAGS_NOINST="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -Ccodegen-units=1 ${RUST_DEBUG_FLAGS}"
RUSTFLAGS="$RUSTFLAGS_NOINST" cargo build --release --manifest-path "$FUZZ_DIR/Cargo.toml"
for t in compile run; do
  bin_no_inst="$SRC/$FUZZ_DIR/target/release/$t"
  [ -x "$bin_no_inst" ] || { echo "ERROR: missing $bin_no_inst" >&2; exit 1; }
  cp "$bin_no_inst" "/mayhem/${t}_no_inst"
  echo "built /mayhem/${t}_no_inst"
done

echo "=== cargo build: rant CLI (uninstrumented; kept for manual reproduction) ==="
RUSTFLAGS="${RUST_DEBUG_FLAGS}" cargo build --features cli
cli="$SRC/target/debug/rant"
[ -x "$cli" ] || { echo "ERROR: missing $cli" >&2; exit 1; }
cp "$cli" /mayhem/rant
echo "built /mayhem/rant"

echo "build.sh complete:"
ls -la /mayhem/compile /mayhem/compile_no_inst /mayhem/run /mayhem/run_no_inst /mayhem/rant
