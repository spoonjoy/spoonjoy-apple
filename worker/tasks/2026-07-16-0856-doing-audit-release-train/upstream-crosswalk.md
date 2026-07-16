# Canonical Audit Unit Crosswalk

All rows must reach `merged/adopted`, `verified`, or a named human-only `BLOCKED_HUMAN` disposition before final closure. `pending` is never terminal. Evidence resolves through `evidence-index.md`; rollback classes resolve through the doing doc's containment matrix.

## Accepted-Ancestry Preconditions

These merged foundations are explicit preconditions even where the canonical doing queue begins after them. Unit 10/11 validators must prove each merge commit is an ancestor of the selected final main SHA.

| Accepted work | PR | Exact merge commit | Required ancestry/evidence | Release gate |
| --- | --- | --- | --- | --- |
| Native Photo Studio baseline | native #47 | `bad81b49a07c006814315a56e4c98311693a7256` | ancestor of final native SHA; N0 behavior represented in Unit 6A/11 matrix | 11 |
| Web Photo Studio polish | web #255 | `b22c5fece92886a03747ccc5e05e525c4b97be55` | ancestor of final web SHA; seven-state deployed visual matrix | 10 |
| Router action matching | web #263 | `6958370b2bd69658fed1a51ffc5694b40b35b23b` | ancestor of final web SHA; provider/live action canary | 10 |
| Browser readiness | web #267 | `e7b0e9ec662b96467bac9581dbad459c77b4bd0b` | ancestor of final web SHA; readiness artifact | 10 |
| Dual-channel readiness | web #269 | `b07d787ee7da7a57f137354a3323f0a7da5e8050` | ancestor of final web SHA; `.data` and document fallback evidence | 10 |
| Feedback tunnel HTTP/2 durability | native #56 | `0309768c31a37ca1c2627e0efefc86aa721f62b0` | ancestor of final native SHA; exact-main Native run `29528190225` and live listener/tunnel/Apple delivery/Slugger evidence | 11, 12A, 14 |

## Canonical Queue

| Canonical unit | Disposition / owner | PR | Exact merge or current head | Evidence key | Rollback | Release unit |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | adopted complete / coordinated worker + release train | canonical audit doing/Desk | `c4d13881`, `77a8c2d` | `ownership.inventory` | `CLEANUP_RECOVERY` | 0 |
| 1a | adopted merged / coordinated worker | web #256 | `f4f28db88689fc922fee8132257c564831679986` | `web.w1.tests` | `WEB_RELEASE` | 1 |
| 1b | adopted merged / coordinated worker | web #256 | `f4f28db88689fc922fee8132257c564831679986` | `web.w1.impl` | `WEB_RELEASE` | 1 |
| 1c | adopted deployed / coordinated worker | web #258, #274 | `7adaa2206c8ed47748e8f897714c57b972353ef3`, `dcf296bd22d2fb9b98f55fbb7c411e88606986f3` | `web.w1.verify` | `WEB_RELEASE` | 1 |
| 2a | adopted merged / release train | native #48 | `0bacf7e1c48a162e9fbca87ff0edba01ba6319b2` | `native.n1.tests` | `NATIVE_REVERT` | 1 |
| 2b | adopted merged / release train | native #48 | `0bacf7e1c48a162e9fbca87ff0edba01ba6319b2` | `native.n1.impl` | `NATIVE_REVERT` | 1 |
| 2c | adopted verified / release train | native #48, #49 | `0bacf7e1c48a162e9fbca87ff0edba01ba6319b2`, `b910c11101a81bc950d8dcf8d2046804ca60d0ae` | `native.n1.verify` | `NATIVE_REVERT` | 1 |
| 3a | adopted merged / coordinated worker | web #261 | `1fecbb75131d7b6d083caf93a4009b21673bd85b` | `web.w2.tests` | `WEB_REVERT` | 1 |
| 3b | adopted merged / coordinated worker | web #261 | `1fecbb75131d7b6d083caf93a4009b21673bd85b` | `web.w2.impl` | `WEB_REVERT` | 1 |
| 3c | adopted deployed / coordinated worker | web #261 | `1fecbb75131d7b6d083caf93a4009b21673bd85b` | `web.w2.verify` | `WEB_RELEASE` | 1 |
| 3d | adopted merged / coordinated worker | web #262 | `7b06c49696f949d7429ae6898b92f5b0e1c807d6` | `web.w3.tests` | `WEB_REVERT` | 1 |
| 3e | adopted merged / coordinated worker | web #262 | `7b06c49696f949d7429ae6898b92f5b0e1c807d6` | `web.w3.impl` | `WEB_REVERT` | 1 |
| 3f | adopted deployed / coordinated worker | web #262 | `7b06c49696f949d7429ae6898b92f5b0e1c807d6` | `web.w3.verify` | `WEB_RELEASE` | 1 |
| 3g | adopted merged / coordinated worker | web #260 | `edf22ce1dd051937982d1908feb5813034eb276c` | `web.w4.tests` | `APPLE_SWITCH` | 1 |
| 3h | adopted merged / coordinated worker | web #260 | `edf22ce1dd051937982d1908feb5813034eb276c` | `web.w4.impl` | `APPLE_SWITCH` | 1 |
| 3i | adopted deployed / coordinated worker | web #260 | `edf22ce1dd051937982d1908feb5813034eb276c` | `web.w4.verify` | `APPLE_SWITCH` | 1 |
| 3j | adopted complete / release train + authorized Apple session | Apple Services ID `app.spoonjoy.client` | clean plus six legacy return URLs; evidence checksum `e990e5d00a0dac9969e9fcc8930c04a25c82c6506c996b6add38c8b17e8b4c7b` | `apple.callback.registration` | `APPLE_SWITCH` | 2A |
| 3k | pending / release train | W5 PR pending | pending | `web.w5.tests` | `APPLE_SWITCH` | 2B |
| 3l | pending / release train | W5 PR pending | pending | `web.w5.impl` | `APPLE_SWITCH` | 2C |
| 3m | pending / release train | W5 PR pending | pending | `web.w5.verify` | `APPLE_SWITCH` | 2D |
| 4.0 | adopted deployed / coordinated worker | web #259 | `5c0fd3c2916c22698b40dd233bdee2045adf04d4` | `web.w6.contract` | `WEB_REVERT` | 1 |
| 4a | merged, hostile follow-up active / coordinated worker | native #52 + #54 | `e8eac40a90b47102d61dd61a9a5658e85e325ad2`; rebased repair head `f1e296a92f58ed4dc534120bca505593eb7504e5` | `native.n2.tests` | `NATIVE_REVERT` | 1 |
| 4b | merged, hostile follow-up active / coordinated worker | native #52 + #54 | `e8eac40a90b47102d61dd61a9a5658e85e325ad2`; rebased repair head `f1e296a92f58ed4dc534120bca505593eb7504e5` | `native.n2.impl` | `NATIVE_REVERT` | 1 |
| 4c | exact #52 main green but follow-up nonterminal / coordinated worker | native #52 + #54 | run `29518076006`; rebased #54 PR run `29529426309` in progress; repair main run pending | `native.n2.verify` | `NATIVE_REVERT` | 1 |
| 5a | pending / release train | N3 PR pending | pending | `native.n3.tests` | `NATIVE_REVERT` | 5 |
| 5b | pending / release train | N3 PR pending | pending | `native.n3.impl` | `NATIVE_REVERT` | 5 |
| 5c | pending / release train | N3 PR pending | pending | `native.n3.verify` | `NATIVE_REVERT` | 5 |
| 6a | adopted merged / coordinated worker | native #53 | `8b5418b7608105d242e44493812ddbbb47d63374` | `native.n4.tests` | `NATIVE_REVERT` | 1 |
| 6b | adopted merged / coordinated worker | native #53 | `8b5418b7608105d242e44493812ddbbb47d63374` | `native.n4.impl` | `NATIVE_REVERT` | 1 |
| 6c | adopted verified / coordinated worker | native #53 | `8b5418b7608105d242e44493812ddbbb47d63374` | `native.n4.verify` | `NATIVE_REVERT` | 1 |
| 6d | pending final visual / release train | native #53 + final SHA | pending final evidence | `native.signed_out.visual` | `NATIVE_REVERT` | 11 |
| 7a | pending / release train | N5 PR pending | pending | `native.n5.tests` | `NATIVE_REVERT` | 6A |
| 7b | pending / release train | N5 PR pending | pending | `native.n5.impl` | `NATIVE_REVERT` | 6A |
| 7c | pending / release train | N5 PR pending | pending | `native.n5.verify` | `NATIVE_REVERT` | 6A |
| 7d | pending / release train | N5 + W17 PRs pending | pending | `photo_studio.visual.35` | `NATIVE_REVERT`, `WEB_REVERT` | 6B, 10, 11 |
| 8a | active / coordinated worker | web #266 | current head in handoff | `web.w7.tests` | `WEB_REVERT` | 1 |
| 8b | active / coordinated worker | web #266 | current head in handoff | `web.w7.impl` | `WEB_REVERT` | 1 |
| 8c | active / coordinated worker | web #266 | current head in handoff | `web.w7.verify` | `WEB_REVERT` | 1 |
| 9a | pending / release train | W8 PR pending | pending | `web.w8.tests` | `LOCAL_DATA` | 3 |
| 9b | pending / release train | W8 PR pending | pending | `web.w8.impl` | `LOCAL_DATA` | 3 |
| 9c | pending / release train | W8 PR pending | pending | `web.w8.verify` | `LOCAL_DATA` | 3 |
| 10a | pending / release train | W9 PR pending | pending | `web.w9.tests` | `CLEANUP_RECOVERY` | 4 |
| 10b | pending / release train | W9 PR pending | pending | `web.w9.impl` | `CLEANUP_RECOVERY` | 4 |
| 10c | pending / release train | W9 PR pending | pending | `web.w9.verify` | `CLEANUP_RECOVERY` | 4 |
| 10d | adopted merged / release train | native #50 | `7c146632e9e16d53176da502e4fdca87ab17f580` | `native.n6.tests` | `CLEANUP_RECOVERY` | 1 |
| 10e | adopted merged / release train | native #50 | `7c146632e9e16d53176da502e4fdca87ab17f580` | `native.n6.impl` | `CLEANUP_RECOVERY` | 1 |
| 10f | adopted verified / release train | native #50 | `7c146632e9e16d53176da502e4fdca87ab17f580` | `native.n6.verify` | `CLEANUP_RECOVERY` | 1 |
| 11.0 | adopted merged / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419` | `web.w10.baseline` | `WEB_REVERT` | 1 |
| 11a | adopted merged / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419` | `web.w10.tests` | `WEB_REVERT` | 1 |
| 11b | adopted merged / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419` | `web.w10.impl` | `WEB_REVERT` | 1 |
| 11c | adopted deployed / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419`; deploy run `29516572367` | `web.w10.verify` | `WEB_RELEASE` | 1 |
| 11.1a | adopted merged / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419` | `web.w11.tests` | `WEB_REVERT` | 1 |
| 11.1b | adopted merged / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419` | `web.w11.impl` | `WEB_REVERT` | 1 |
| 11.1c | adopted deployed / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419`; deploy run `29516572367` | `web.w11.verify` | `WEB_RELEASE` | 1 |
| 11.2a | adopted merged / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419` | `web.w12.tests` | `WEB_REVERT` | 1 |
| 11.2b | adopted merged / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419` | `web.w12.impl` | `WEB_REVERT` | 1 |
| 11.2c | adopted deployed / coordinated worker | web #270 | `405d614981f684e101f5099ad5d27f89b5b54419`; deploy run `29516572367` | `web.w12.verify` | `WEB_RELEASE` | 1 |
| 12.0 | pending / release train | N7/N8 PRs pending | pending | `native.cover.baseline` | `NATIVE_REVERT` | 7 |
| 12a | pending / release train | N7 PR pending | pending | `native.n7.tests` | `NATIVE_REVERT` | 7 |
| 12b | pending / release train | N7 PR pending | pending | `native.n7.impl` | `NATIVE_REVERT` | 7 |
| 12c | pending / release train | N7 PR pending | pending | `native.n7.verify` | `NATIVE_REVERT` | 7 |
| 12d | pending / release train | N8 PR pending | pending | `native.n8.tests` | `NATIVE_REVERT` | 8 |
| 12e | pending / release train | N8 PR pending | pending | `native.n8.impl` | `NATIVE_REVERT` | 8 |
| 12f | pending / release train | N8 PR pending | pending | `native.n8.verify` | `NATIVE_REVERT` | 8 |
| 13a | adopted merged / coordinated worker | web #264 | `4226751167480d95822f1bac8b5143327b3813d7` | `web.w13.tests` | `WEB_REVERT` | 1 |
| 13b | adopted merged / coordinated worker | web #264 | `4226751167480d95822f1bac8b5143327b3813d7` | `web.w13.impl` | `WEB_REVERT` | 1 |
| 13c | adopted deployed / coordinated worker | web #264 | `4226751167480d95822f1bac8b5143327b3813d7` | `web.w13.verify` | `WEB_RELEASE` | 1 |
| 14a | active / coordinated worker | web #271 | current head in handoff | `web.w14.tests` | `WEB_RELEASE` | 1 |
| 14b | active / coordinated worker | web #271 | current head in handoff | `web.w14.impl` | `WEB_RELEASE` | 1 |
| 14c | active / coordinated worker | web #271 | current head in handoff | `web.w14.verify` | `WEB_RELEASE` | 1 |
| 15a | adopted merged / coordinated worker | web #268 | `2f392840a24fb1c5886cb843071e29f719e1b946` | `web.w15.tests` | `WEB_REVERT` | 1 |
| 15b | adopted merged / coordinated worker | web #268 | `2f392840a24fb1c5886cb843071e29f719e1b946` | `web.w15.impl` | `WEB_REVERT` | 1 |
| 15c | adopted deployed / coordinated worker | web #268 | `2f392840a24fb1c5886cb843071e29f719e1b946` | `web.w15.verify` | `WEB_RELEASE` | 1 |
| 15d | pending final deployed visual / release train | web #268 + final SHA | pending | `web.home.visual` | `WEB_RELEASE` | 10 |
| 16a | active / coordinated worker | web #272 | `66aa76a42a8f39c00b9535f7c23f33b93c5afb41` | `web.w16.tests` | `WEB_REVERT` | 1 |
| 16b | active / coordinated worker | web #272 | `66aa76a42a8f39c00b9535f7c23f33b93c5afb41` | `web.w16.impl` | `WEB_REVERT` | 1 |
| 16c | active / coordinated worker | web #272 | `66aa76a42a8f39c00b9535f7c23f33b93c5afb41` | `web.w16.verify` | `WEB_RELEASE` | 1 |
| 16d | adopted merged / release train | native #51 | `3013c361ef178ccb2af67a61e3f2a1d72df46f35` | `native.n9.tests` | `NATIVE_REVERT` | 1 |
| 16e | adopted merged / release train | native #51 | `3013c361ef178ccb2af67a61e3f2a1d72df46f35` | `native.n9.impl` | `NATIVE_REVERT` | 1 |
| 16f | adopted verified / release train | native #51 | `3013c361ef178ccb2af67a61e3f2a1d72df46f35` | `native.n9.verify` | `NATIVE_REVERT` | 1 |
| 17a | pending / release train | N10 PR pending | pending | `native.n10.tests` | `NATIVE_REVERT` | 9 |
| 17b | pending / release train | N10 PR pending | pending | `native.n10.impl` | `NATIVE_REVERT` | 9 |
| 17c | pending / release train | N10 PR pending | pending | `native.n10.verify` | `NATIVE_REVERT` | 9 |
| 18 | pending / release train | final web SHA | pending | `web.unit18` | `WEB_RELEASE` | 10 |
| 19 | pending / release train | final deployed web SHA | pending | `web.unit19` | `WEB_RELEASE` | 10 |
| 20 | pending / release train | final native SHA | pending | `native.unit20` | `NATIVE_REVERT` | 11 |
| 21 | delegated exclusively / release train | exact TestFlight candidate | pending | `testflight.unit21` | `TESTFLIGHT_CONTAIN` | 12A-12D |
| 22 | shared closure; native/TestFlight exclusive / release train | cleanup/Desk | pending | `closure.unit22` | `CLEANUP_RECOVERY` | 13-14 |

Final gate: every accepted-ancestry row passes `git merge-base --is-ancestor`; canonical `pending`, `active`, hostile-follow-up, and unmatched row counts must all equal zero except rows carrying a fully populated named `BLOCKED_HUMAN` disposition.
