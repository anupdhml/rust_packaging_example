#!/bin/bash
#
# build.sh
#
# Build rust project for various targets
#
# Meant for use during the final release as part of CI, but can be used for
# local testing too
#
# Usage: build.sh TARGET
# Example: build.sh x86_64-unknown-linux-gnu

# exit the script when a command fails
set -o errexit

# catch exit status for piped commands
set -o pipefail

TARGET=$1

if [ -z "$TARGET" ]; then
  echo "Usage: build.sh TARGET"
  exit 1
fi

if [ "$RUST_PACKAGING_EXAMPLE_MODE" = "debug" ]; then
  BUILD_MODE=debug
else
  BUILD_MODE=release
fi

BIN_NAME="rust-packaging-example"

###############################################################################

echo "Building for target: ${TARGET}..."

# install cross if not already there (helps us build easily across various targets)
# see https://github.com/rust-embedded/cross
#
# currently need to install it from a personal fork for builds to work against custom targets
# (eg: x86_64-alpine-linux-musl which we use for generating working musl binaries right now)
if ! command -v cross > /dev/null 2>&1; then
  echo "Installing cross..."
  cargo install --git https://github.com/anupdhml/cross.git --branch custom_target_fixes
fi

BUILD_ARGS=("--target" "$TARGET")
CUSTOM_RUSTFLAGS=()

if [ "$BUILD_MODE" == "release" ]; then
  BUILD_ARGS+=("--release")

  # for stripping binaries (saving on size, plus minor performance gains)
  # via https://github.com/rust-lang/cargo/issues/3483#issuecomment-431209957
  #
  # TODO once https://github.com/rust-lang/cargo/issues/3483#issuecomment-631395566
  # lands on a stable rust release, switch to using that
  echo "Ensuring release binaries are stripped..."
  CUSTOM_RUSTFLAGS+=("-C" "link-arg=-s")
fi

if [[ "$TARGET" == *"alpine-linux-musl"* ]]; then
  # force static binaries for alpine-linux-musl targets (since we are choosing this
  # target specifically to produce working static musl binaries). Static building
  # is the default rustc behavior for musl targets, but alpine disables it by
  # default (via patches to rust).
  echo "Ensuring static builds for alpine-linux-musl targets..."
  CUSTOM_RUSTFLAGS+=("-C" "target-feature=+crt-static")
fi

export RUSTFLAGS="${RUSTFLAGS} ${CUSTOM_RUSTFLAGS[@]}"
echo "RUSTFLAGS set to: ${RUSTFLAGS}"

cross build "${BUILD_ARGS[@]}"

TARGET_BIN="target/${TARGET}/${BUILD_MODE}/${BIN_NAME}"

echo "Successfully built the binary: ${TARGET_BIN}"

# linking check
echo "Printing linking information for the binary..."
file "$TARGET_BIN"
ldd "$TARGET_BIN"
