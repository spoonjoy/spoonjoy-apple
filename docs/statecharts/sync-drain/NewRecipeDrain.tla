---- MODULE NewRecipeDrain ----
\* Offline: you create a recipe (edit X) and add a step to it (edit Y). Y points at the recipe's
\* temporary id until the server creates the recipe and names its real id.
\* Mirrors NativeSyncEngine.bootstrapAndDrain: load the queue, send each edit
\* in order (skip it if it left the queue meanwhile), take an accepted edit off the stored queue at once and
\* point the rest of the stored queue at the new id, then write the drain's outcome with queueAfterDrain.
\* Drains is the set of sync passes that can run at the same time on the one shared store: the app's own
\* sync, and the Siri / Shortcuts intent that sends the edit it just queued (SpoonjoyAppIntents.syncQueued).
\* TakeTurns is NativeSyncDrainTurns: a pass starts only when no other pass on the store is running.
EXTENDS Naturals, FiniteSets

CONSTANTS Drains, MaxRuns, TakeTurns

Edits == {"X", "Y"}
None == "none"

VARIABLES
    queued,     \* edits in the stored queue
    yRef,       \* what the stored copy of Y points at: "temp" or "real"
    yErr,       \* the stored copy of Y carries an error shown to you
    pc,         \* each drain: "idle", "atX", "xAccepted", "atY", "write"
    loaded,     \* each drain: the edits it loaded
    loadedYRef, \* each drain: what its loaded copy of Y points at
    knowsId,    \* each drain: it learned the recipe's real id in this pass
    unsent,     \* each drain: edits it will write back, and how ("temp"/"real" for Y, "wait" for X)
    yHeld,      \* each drain: Y is held behind X
    recipeOnServer, recipeCreates, yRejected, yAccepted, runs

vars == <<queued, yRef, yErr, pc, loaded, loadedYRef, knowsId, unsent, yHeld,
          recipeOnServer, recipeCreates, yRejected, yAccepted, runs>>

Init ==
    /\ queued = Edits /\ yRef = "temp" /\ yErr = FALSE
    /\ pc = [d \in Drains |-> "idle"]
    /\ loaded = [d \in Drains |-> {}]
    /\ loadedYRef = [d \in Drains |-> "temp"]
    /\ knowsId = [d \in Drains |-> FALSE]
    /\ unsent = [d \in Drains |-> [e \in Edits |-> None]]
    /\ yHeld = [d \in Drains |-> FALSE]
    /\ recipeOnServer = FALSE /\ recipeCreates = 0 /\ yRejected = 0 /\ yAccepted = 0
    /\ runs = [d \in Drains |-> 0]

ASyncStarts(d) ==
    /\ pc[d] = "idle" /\ runs[d] < MaxRuns /\ queued # {}
    /\ TakeTurns => \A o \in Drains : pc[o] = "idle"
    /\ pc' = [pc EXCEPT ![d] = "atX"]
    /\ loaded' = [loaded EXCEPT ![d] = queued]
    /\ loadedYRef' = [loadedYRef EXCEPT ![d] = yRef]
    /\ knowsId' = [knowsId EXCEPT ![d] = FALSE]
    /\ unsent' = [unsent EXCEPT ![d] = [e \in Edits |-> None]]
    /\ yHeld' = [yHeld EXCEPT ![d] = FALSE]
    /\ UNCHANGED <<queued, yRef, yErr, recipeOnServer, recipeCreates, yRejected, yAccepted, runs>>

\* X not loaded, or it left the queue while this drain ran: skip it.
XSkipped(d) ==
    /\ pc[d] = "atX" /\ ("X" \notin loaded[d] \/ "X" \notin queued)
    /\ pc' = [pc EXCEPT ![d] = "atY"]
    /\ UNCHANGED <<queued, yRef, yErr, loaded, loadedYRef, knowsId, unsent, yHeld,
                   recipeOnServer, recipeCreates, yRejected, yAccepted, runs>>

\* The server creates the recipe (or, for a repeat of the same clientMutationId, returns the same one).
ServerCreatesRecipe(d) ==
    /\ pc[d] = "atX" /\ "X" \in loaded[d] /\ "X" \in queued
    /\ recipeOnServer' = TRUE /\ recipeCreates' = recipeCreates + 1
    /\ knowsId' = [knowsId EXCEPT ![d] = TRUE]
    /\ pc' = [pc EXCEPT ![d] = "xAccepted"]
    /\ UNCHANGED <<queued, yRef, yErr, loaded, loadedYRef, unsent, yHeld, yRejected, yAccepted, runs>>
    
\* Right after the server accepts X, one store step takes X off the queue and points Y at the real id.
AcceptedEditLeavesQueue(d) ==
    /\ pc[d] = "xAccepted"
    /\ queued' = queued \ {"X"}
    /\ yRef' = IF "Y" \in queued THEN "real" ELSE yRef
    /\ pc' = [pc EXCEPT ![d] = "atY"]
    /\ UNCHANGED <<yErr, loaded, loadedYRef, knowsId, unsent, yHeld, recipeOnServer, recipeCreates, yRejected, yAccepted, runs>>

ServerSaysTryLater(d) ==
    /\ pc[d] = "atX" /\ "X" \in loaded[d] /\ "X" \in queued
    /\ unsent' = [unsent EXCEPT ![d]["X"] = "wait"]
    /\ yHeld' = [yHeld EXCEPT ![d] = TRUE]
    /\ pc' = [pc EXCEPT ![d] = "atY"]
    /\ UNCHANGED <<queued, yRef, yErr, loaded, loadedYRef, knowsId, recipeOnServer, recipeCreates, yRejected, yAccepted, runs>>

YSkipped(d) ==
    /\ pc[d] = "atY" /\ ("Y" \notin loaded[d] \/ "Y" \notin queued)
    /\ pc' = [pc EXCEPT ![d] = "write"]
    /\ UNCHANGED <<queued, yRef, yErr, loaded, loadedYRef, knowsId, unsent, yHeld,
                   recipeOnServer, recipeCreates, yRejected, yAccepted, runs>>

YWaits(d) ==
    /\ pc[d] = "atY" /\ "Y" \in loaded[d] /\ "Y" \in queued /\ yHeld[d]
    /\ unsent' = [unsent EXCEPT ![d]["Y"] = IF knowsId[d] THEN "real" ELSE loadedYRef[d]]
    /\ pc' = [pc EXCEPT ![d] = "write"]
    /\ UNCHANGED <<queued, yRef, yErr, loaded, loadedYRef, knowsId, yHeld, recipeOnServer, recipeCreates, yRejected, yAccepted, runs>>

\* The drain sends its own copy of Y, with its own id replacements.
SentRef(d) == IF knowsId[d] THEN "real" ELSE loadedYRef[d]

ServerAddsStep(d) ==
    /\ pc[d] = "atY" /\ "Y" \in loaded[d] /\ "Y" \in queued /\ ~yHeld[d]
    /\ SentRef(d) = "real" /\ recipeOnServer
    /\ yAccepted' = yAccepted + 1
    /\ queued' = queued \ {"Y"}
    /\ pc' = [pc EXCEPT ![d] = "write"]
    /\ UNCHANGED <<yRef, yErr, loaded, loadedYRef, knowsId, unsent, yHeld, recipeOnServer, recipeCreates, yRejected, runs>>

\* A network blip: the step stays queued as this drain sent it, to retry later.
ServerSaysTryLaterForStep(d) ==
    /\ pc[d] = "atY" /\ "Y" \in loaded[d] /\ "Y" \in queued /\ ~yHeld[d]
    /\ unsent' = [unsent EXCEPT ![d]["Y"] = SentRef(d)]
    /\ pc' = [pc EXCEPT ![d] = "write"]
    /\ UNCHANGED <<queued, yRef, yErr, loaded, loadedYRef, knowsId, yHeld, recipeOnServer, recipeCreates, yRejected, yAccepted, runs>>

\* A step for a recipe id the server has never seen is refused (a conflict, kept with an error).
ServerRefusesStep(d) ==
    /\ pc[d] = "atY" /\ "Y" \in loaded[d] /\ "Y" \in queued /\ ~yHeld[d]
    /\ SentRef(d) = "temp"
    /\ yRejected' = yRejected + 1
    /\ unsent' = [unsent EXCEPT ![d]["Y"] = "temp-error"]
    /\ pc' = [pc EXCEPT ![d] = "write"]
    /\ UNCHANGED <<queued, yRef, yErr, loaded, loadedYRef, knowsId, yHeld, recipeOnServer, recipeCreates, yAccepted, runs>>

\* queueAfterDrain: for each edit in the stored queue now: one this drain loaded is replaced by its unsent
\* copy or dropped; one it did not load is kept, pointed at the ids this drain learned.
DrainWritesBack(d) ==
    /\ pc[d] = "write"
    /\ LET keep(e) == IF e \in loaded[d] THEN unsent[d][e] # None ELSE TRUE IN
       /\ queued' = {e \in queued : keep(e)}
       /\ yRef' = IF "Y" \in queued /\ "Y" \in loaded[d] /\ unsent[d]["Y"] # None
                     THEN (IF unsent[d]["Y"] = "real" THEN "real" ELSE "temp")
                     ELSE IF "Y" \in queued /\ knowsId[d] THEN "real" ELSE yRef
       /\ yErr' = IF "Y" \in queued /\ "Y" \in loaded[d] /\ unsent[d]["Y"] # None
                     THEN unsent[d]["Y"] = "temp-error" ELSE yErr
    /\ pc' = [pc EXCEPT ![d] = "idle"]
    /\ runs' = [runs EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<loaded, loadedYRef, knowsId, unsent, yHeld, recipeOnServer, recipeCreates, yRejected, yAccepted>>

\* The app is closed or killed. Every pass in this process stops where it is, with no write-back.
TheAppQuits ==
    /\ \E d \in Drains : pc[d] # "idle"
    /\ pc' = [d \in Drains |-> "idle"]
    /\ runs' = [d \in Drains |-> IF pc[d] # "idle" THEN runs[d] + 1 ELSE runs[d]]
    /\ UNCHANGED <<queued, yRef, yErr, loaded, loadedYRef, knowsId, unsent, yHeld,
                   recipeOnServer, recipeCreates, yRejected, yAccepted>>

Done ==
    /\ \A d \in Drains : pc[d] = "idle" /\ (runs[d] >= MaxRuns \/ queued = {})
    /\ UNCHANGED vars

Next ==
    \/ TheAppQuits \/ Done
    \/ \E d \in Drains :
        \/ ASyncStarts(d) \/ XSkipped(d) \/ ServerCreatesRecipe(d) \/ AcceptedEditLeavesQueue(d)
        \/ ServerSaysTryLater(d) \/ YSkipped(d) \/ YWaits(d) \/ ServerAddsStep(d) \/ ServerRefusesStep(d) \/ ServerSaysTryLaterForStep(d)
        \/ DrainWritesBack(d)

Spec == Init /\ [][Next]_vars

\* Rules you would agree to.
\* A step you added to a new recipe is never refused just because it was sent with the recipe's temporary id.
NeverSentWithTemporaryId == yRejected = 0
\* Once the recipe is created and off the queue, a queued step for it points at the real recipe.
QueuedStepPointsAtRealRecipe == ("X" \notin queued /\ "Y" \in queued) => yRef = "real"
\* When no sync is running, a queued step for a created recipe points at the real recipe.
AtRestStepPointsAtRealRecipe == (\A d \in Drains : pc[d] = "idle") => QueuedStepPointsAtRealRecipe
\* The step is added once.
StepAddedOnce == yAccepted <= 1
====
