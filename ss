#!/bin/sh
set -eu
#
# ss — open a windowed login (Screen Sharing virtual session) of another local
#      macOS account, from this account.
#
#   ss <shortname>   open / focus a desktop window for that local account
#   ss -l            list active sessions (tunnels)
#   ss -k <user>     stop one user's session tunnel
#   ss -K            stop all session tunnels started by this tool
#   ss -h            help
#
# NOTE: pgrep/pkill return non-zero when nothing matches; every such call below
# is guarded by `if`/`||` so `set -e` doesn't abort. Keep those guards if editing.

REMOTE_PORT=5900     # macOS Screen Sharing port, reached on loopback via ssh
BASE=5900            # local port = BASE + (uid - 500); uid 501 -> 5901

# ERE matching ANY tunnel this tool creates (macOS pgrep/pkill use ERE).
# Allows ssh options between -fN and -L, and either "-L port:..." or "-Lport:...".
match='ssh([[:space:]]+[^[:space:]]+)*[[:space:]]+-L[[:space:]]*[0-9]+:127\.0\.0\.1:'"$REMOTE_PORT"'([[:space:]]+[^[:space:]]+)*[[:space:]][^[:space:]]+@localhost'

die() { echo "ss: $*" 1>&2; exit 1; }

tunnel_match() {
  printf 'ssh([[:space:]]+[^[:space:]]+)*[[:space:]]+-L[[:space:]]*%s:127\\.0\\.0\\.1:%s([[:space:]]+[^[:space:]]+)*[[:space:]]%s@localhost' "$1" "$REMOTE_PORT" "$2"
}

usage() {
  cat 1>&2 <<'EOF'
usage:
  ss <shortname>   open a windowed login of that local account
  ss -l            list active sessions
  ss -k <user>     stop one user's session tunnel
  ss -K            stop all session tunnels
  ss -h            show this help
EOF
}

# Validate a username is a real, normal local account; echo its stable port.
# Runs in a subshell (called via $(...)), so a die() here exits that subshell
# and the caller's `|| exit 1` propagates it.
port_for() {
  _uid=$(id -u "$1" 2>/dev/null) || {
    _accts=$(dscl . -list /Users UniqueID \
             | awk '$2>=501 && $2<5000 && $1 !~ /^_/ {print $1}' | sort | tr '\n' ' ')
    die "no such local account: $1 (available: $_accts)"
  }
  case "$_uid" in ''|*[!0-9]*) die "could not resolve a numeric uid for $1";; esac
  [ "$_uid" -ge 501 ] || die "$1 (uid $_uid) is not a normal user account"
  _port=$(( BASE + _uid - 500 ))
  [ "$_port" -lt 65536 ] || die "computed port $_port out of range for uid $_uid"
  printf '%s\n' "$_port"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -l|--list)
      pgrep -afl "$match" || echo "no active sessions"
      exit 0 ;;
  -K|--stop-all)
      if pkill -f "$match"; then echo "stopped all sessions"
      else echo "no sessions running"; fi
      exit 0 ;;
  -k|--stop)
      u=${2:-}; [ -n "$u" ] || die "usage: ss -k <user>"
      p=$(port_for "$u") || exit 1
      if pkill -f "$(tunnel_match "$p" "$u")"
      then echo "stopped session for $u"; else echo "no session for $u"; fi
      exit 0 ;;
  "")  usage; exit 1 ;;
  -*)  die "unknown option: $1" ;;
esac

user=$1

# Refuse to open the account you're already running as (compare by uid so a
# differently-spelled name resolving to the same account is still caught).
selfuid=$(id -u)
tgtuid=$(id -u "$user" 2>/dev/null) || true
[ "${tgtuid:-x}" != "$selfuid" ] || \
  die "$user is the account you're currently using — open a *different* account"

port=$(port_for "$user") || exit 1

# Bring up the tunnel only if it isn't already running for this user+port.
if ! pgrep -f "$(tunnel_match "$port" "$user")" \
     >/dev/null 2>&1; then
  echo "ss: starting session for ${user} on local port ${port} — authenticate as ${user}…" 1>&2
  # Dedicated connection (ignore any ssh multiplexing config); fail loudly if the
  # local port can't bind; let a dead connection exit so the next run rebuilds it.
  ssh -fN \
      -o ControlMaster=no -o ControlPath=none \
      -o StrictHostKeyChecking=accept-new \
      -o ExitOnForwardFailure=yes \
      -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
      -L "${port}:127.0.0.1:${REMOTE_PORT}" \
      "${user}@localhost"
fi

# Open Screen Sharing, pre-filling the target username; you type their password.
exec open "vnc://${user}@127.0.0.1:${port}"
