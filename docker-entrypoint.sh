#!/bin/sh
# Starts the virtual display Firefox renders on, then runs trmnlp with the given arguments.

# A restarted container keeps /tmp, and Xvfb will not start over the last run's lock if its pid is in use again.
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

Xvfb :99 -nolisten tcp >/tmp/xvfb.log 2>&1 &
xvfb_pid=$!

waited_steps=0
until [ -e /tmp/.X11-unix/X99 ]; do
  if ! kill -0 "$xvfb_pid" 2>/dev/null || [ "$waited_steps" -ge 200 ]; then
    echo "trmnlp: the virtual display (Xvfb) did not start. Its output:" >&2
    cat /tmp/xvfb.log >&2
    exit 1
  fi
  waited_steps=$((waited_steps + 1))
  sleep 0.05
done

exec /app/bin/trmnlp "$@"
