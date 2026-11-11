# What's New voice: the harrowing tale

Spoonjoy's release notes are told as harrowing tales: a small kitchen drama, written like an adventure, about a change that really happened. Most apps say "bug fixes and performance improvements". We tell the story of the ellipsis that ate the recipe title, and how it was defeated.

The tale is the fun part. The truth is the rule.

## The rules

1. **Every sentence is true for this update.** App Review checks that release notes match the update (App Store Review Guideline 2.3, accurate metadata), and readers stop trusting a funny changelog the first time it lies. If the tale says the button glows amber at night, the button glows amber at night. Drama goes in how you say it, never in what you claim.
2. **The peril is the old behaviour; the hero is the change.** Name what used to go wrong, in the user's own terms ("long recipe names vanished mid-word"), then what happens now ("they wrap onto the next line"). A reader who skims only the second sentence still learns what changed.
3. **Small and concrete.** Two to four sentences per tale. One change per fragment. A concrete picture beats an adjective: "find it with flour on your glasses", not "more visible".
4. **The kitchen is the world.** Flour, timers, sticky hands, the cookbook on the counter, the friend who sent the recipe. No space battles, no gore, nothing a twelve-year-old couldn't read aloud at dinner.
5. **Spoonjoy's words for Spoonjoy's things.** Cook mode, Kitchen, Cookbooks, Shopping, Cooks, fork. Say what a person sees, never the code: "the main button", not "`.primary`"; "the typefaces", not "Fraunces".
6. **True on every platform it names.** A tale for both platforms can't mention the Lock Screen, Dynamic Island, iPhone Duo or taps, because the Mac has none. Give the iPhone its own fragment (`platforms: [ios]`) when only the iPhone changed.
7. **No one gets mocked.** The villain is a bug, an ellipsis, a pale button. Never a person, a reviewer, a competitor or the user.
8. **Plain text.** The App Store shows no formatting. Use `•` for a bullet, and leave out links and emoji.
9. **The TestFlight line is the opposite.** It is plain, flat and specific, for a tester who wants to know what to try: "At night, the main button (Cook, Start cooking, Next step, Add item) fills amber."

## The shape of a release

What's New is assembled in a fixed order: an optional prologue, then the tales by `order`, then an optional epilogue. Together they read as one story.

- **Prologue:** a title and one or two sentences of stakes. "Spoonjoy 1.2, or: The Night the Cookbook Got Its Clothes Back."
- **Tales:** the changes, most important first.
- **Epilogue:** one line that lands the joke. "No recipes were harmed in the making of this update. One ellipsis was."

## Examples

A fix:

> For weeks, a shopping list checked off in a tunnel would forget itself the moment you came back above ground. Spoonjoy now holds on to every tick until it can tell the server, so the eggs stay crossed off.

A new feature:

> You asked Siri for the next step with dough up to your wrists, and Siri asked you to unlock your iPhone. Now "Next step in Spoonjoy" works from the Lock Screen, and your phone stays clean.

A tiny polish:

> A chef's @handle on their profile, which used to shout across three lines, has been asked to use its indoor voice.

A change that is not a story: if nobody using the app could notice it, it gets the `no-user-facing-change` label and no tale at all. A tale about nothing is the one thing worse than "bug fixes and performance improvements".

The first two examples show the voice; they are not changes in any release. A fragment's tale describes its own pull request.
