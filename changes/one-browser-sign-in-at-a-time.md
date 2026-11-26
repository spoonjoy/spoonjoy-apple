---
testflight: Continue with Google or GitHub in a second window now closes the first window's sign-in sheet instead of leaving it to fail.
platforms: [ios, mac]
order: 60
---
Google or GitHub sign-in in two windows at once used to strand the first sheet, its return turned away as expired. Now the newer sign-in wins and the older sheet closes itself.
