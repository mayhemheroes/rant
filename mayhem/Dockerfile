# Build Stage
FROM --platform=linux/amd64 ubuntu:22.04 AS builder

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl build-essential
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install -f cargo-fuzz

ADD . /src
WORKDIR /src

RUN cargo +nightly fuzz build && \
    mv fuzz/target/x86_64-unknown-linux-gnu/release/compile /compile

RUN RUSTFLAGS="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -C codegen-units=1" \
    cargo +nightly build --release --manifest-path fuzz/Cargo.toml && \
    mv fuzz/target/release/compile /compile_no_inst

# Build CLI
RUN cargo build --features cli

# Package Stage
FROM ubuntu:22.04

COPY --from=builder /compile /compile_no_inst /
COPY --from=builder /src/target/debug/rant /
