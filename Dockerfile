###########################################################
# bashnative - the UNIX userland system, written in BASH
# Multi-stage build: compile patched bash, then create
# a minimal image with just bash + bashnative scripts
###########################################################

# --- Stage 1: compile patched bash with 'fs' builtin ---
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc6-dev make curl ca-certificates bison \
    && rm -rf /var/lib/apt/lists/*

COPY build/fs.def /src/fs.def
COPY build/build-bash.sh /src/build-bash.sh
RUN chmod +x /src/build-bash.sh

WORKDIR /src
RUN ./build-bash.sh --static -j$(nproc)

# --- Stage 2: minimal image ---
FROM scratch

# the one binary
COPY --from=builder /src/_bashbuild/bash-5.2/bash /bin/bash

# all bashnative scripts
COPY bin/  /bin/
COPY function/ /function/

# shell configuration
COPY etc/profile /etc/profile

# bashnative needs to find its function library
ENV BASHNATIVE=/
ENV TERM=xterm-256color

# basic filesystem structure
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
# /tmp for mktemp etc
COPY --from=builder /tmp /tmp

ENTRYPOINT ["/bin/bash"]
CMD ["--login"]
