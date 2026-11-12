---
testflight: Continue with Google or GitHub in a second window now closes the first window's sign-in sheet instead of leaving it to fail.
platforms: [ios, mac]
order: 60
---
Starting Google or GitHub sign-in in two windows at once used to doom the first one: its return was turned away as an expired session, and the sheet sat there as if nothing was wrong. Now the newer sign-in wins and the older sheet closes itself, so the one in front of you is the one that works.
