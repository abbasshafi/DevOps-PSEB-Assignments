#!/bin/bash
# PRACTICE ONLY: starts some misbehaving background processes for ticket T-108.
LOG="$HOME/sabzicart/logs/noisy.log"
setsid bash -c "exec -a sabzi-report-generator yes" > /dev/null 2>&1 < /dev/null &
for n in 1 2 3 4 5; do
  setsid bash -c "exec -a sabzi-worker-$n sleep 7200" > /dev/null 2>&1 < /dev/null &
done
setsid bash -c "exec -a noisy-logger bash -c 'while true; do date >> \"$LOG\"; sleep 0.5; done'" > /dev/null 2>&1 < /dev/null &
setsid bash -c "exec -a sabzi-stubborn bash -c 'trap \"\" TERM; while true; do sleep 1; done'" > /dev/null 2>&1 < /dev/null &
sleep 1
echo "Chaos started: 8 processes are now misbehaving on this machine."
echo "Your job (ticket T-108): find them, understand them, and stop them."
