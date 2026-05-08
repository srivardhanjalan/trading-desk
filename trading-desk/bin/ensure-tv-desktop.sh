#!/bin/bash
# SessionStart hook: ensure TradingView Desktop is running with CDP.
# - Gated on TD_TV_ENABLED=true in ~/workspace/secrets/trading-desk/.env
#   (set by setup skill if user opted in to TV Desktop integration).
# - Silent no-op if disabled, on non-macOS, or if TV is already running.
# - Launches asynchronously so claude session startup is never blocked.

set -e

ENV_FILE="$HOME/workspace/secrets/trading-desk/.env"
[ -f "$ENV_FILE" ] || exit 0
# shellcheck disable=SC1090
source "$ENV_FILE" 2>/dev/null || exit 0

[ "${TD_TV_ENABLED:-false}" = "true" ] || exit 0
[[ "$(uname)" != "Darwin" ]] && exit 0

# Already running? Done.
pgrep -x "TradingView" > /dev/null 2>&1 && exit 0

# Launch with CDP enabled. Return immediately — open is async.
open -a TradingView --args --remote-debugging-port=9222 2>/dev/null &
disown 2>/dev/null || true

exit 0
