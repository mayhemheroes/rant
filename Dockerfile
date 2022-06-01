FROM rust:latest as builder
COPY . /rant
WORKDIR /rant
RUN cargo build --features cli

FROM debian:bullseye-slim
COPY --from=builder /rant/target/debug/rant .