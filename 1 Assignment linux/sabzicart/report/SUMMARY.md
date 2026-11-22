# SUMMARY: SabziCart Practice Day

## 3 things I learned today
1. File permissions in numbers and special bits: chmod 700/600 to lock down secrets, 2770 (setgid) so new files in a team folder inherit the team's group, and 1777 (sticky bit) for a shared drop box like /tmp.
2. How to debug a service: systemctl --user status shows the state, journalctl --user -u shows the real error. The "website down" bug was only a missing execute bit (status=203/EXEC), and it was in the logs.
3. How to find and stop processes safely: pgrep -af and pkill -f with a ^ anchor match the full command line precisely, and kill -9 is needed for a process that ignores the normal kill.

## 1 thing that is still confusing
Socket activation: after I stopped avahi-daemon it came back on its own because of TriggeredBy avahi-daemon.socket. I understand the idea, but I am not sure how to stop such a service for good (stopping the .socket as well?).

## The command I am proudest of
tar -xzvf ~/sabzicart/archive/configs-2026-10-08.tar.gz -C /tmp/vault notes/vault.txt
It extracted exactly one file from an archive without spilling the rest (and not the old copy), which was the key to piece 4 of the vault.
