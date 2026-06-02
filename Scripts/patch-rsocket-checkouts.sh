#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKOUT_ROOT="${1:-"$ROOT_DIR/.build/checkouts"}"

NIO_SHIM="$CHECKOUT_ROOT/swift-nio/Sources/CNIODarwin/shim.c"
RSOCKET_EXAMPLES="$CHECKOUT_ROOT/rsocket-swift/Sources/RSocketCore/Extensions/RequestExamples.swift"

if [[ -f "$NIO_SHIM" ]] && grep -q 'errx(EX_SOFTWARE, "recvmmsg shim not implemented on Darwin platforms\\n");' "$NIO_SHIM"; then
  chmod u+w "$NIO_SHIM"
  perl -0pi -e 's/#include <stdlib.h>\n/#include <stdlib.h>\n#include <stdio.h>\n/' "$NIO_SHIM"
  perl -0pi -e 's/errx\(EX_SOFTWARE, "recvmmsg shim not implemented on Darwin platforms\\n"\);/fprintf(stderr, "recvmmsg shim not implemented on Darwin platforms\\n");\n    abort();/' "$NIO_SHIM"
  echo "Patched SwiftNIO Darwin recvmmsg shim for this SDK."
fi

if [[ -f "$RSOCKET_EXAMPLES" ]]; then
  chmod u+w "$RSOCKET_EXAMPLES"
  mv "$RSOCKET_EXAMPLES" "$RSOCKET_EXAMPLES.disabled"
  echo "Disabled stale RSocket RequestExamples.swift helper source."
fi
