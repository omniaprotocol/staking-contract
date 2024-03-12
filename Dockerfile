FROM ghcr.io/foundry-rs/foundry:latest

WORKDIR /usr/src/staking

# Get contracts
COPY lib lib
COPY cache cache
COPY script script
COPY src src
COPY remappings.txt remappings.txt
COPY foundry.toml foundry.toml

RUN forge build

CMD ["anvil --host 0.0.0.0 --port 8547"]