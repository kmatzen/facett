------------------------------ MODULE SleepState ------------------------------
(***************************************************************************)
(* A TLA+ model of Facett's camera sleep tracking, covering the physical    *)
(* camera as well as the app's belief about it.                            *)
(*                                                                         *)
(* Three variants are modelled, selected by the Variant constant, so the    *)
(* model checker can show why the shipped design is the one that works:     *)
(*                                                                         *)
(*   "original" - setDeviceSleeping wrote through an optional chain into    *)
(*                dictionaries that nothing populates, so the flag was      *)
(*                never actually set and isDeviceSleeping always returned   *)
(*                false.                                                    *)
(*                                                                          *)
(*   "naive"    - the obvious fix: record the flag and always ignore        *)
(*                advertisements from a camera believed to be asleep.       *)
(*                                                                          *)
(*   "graced"   - what is now in BLEDeviceStateManager: ignore              *)
(*                advertisements only inside the shutdown window, and treat *)
(*                a later advertisement as evidence the camera woke.        *)
(*                                                                          *)
(* Time is modelled as the abstract state of the flag ("recent" vs "stale") *)
(* with a fair GraceExpires action, rather than a clock. Using a bounded    *)
(* integer clock would let behaviours stutter at the bound and make the     *)
(* liveness property vacuous.                                              *)
(***************************************************************************)
EXTENDS Naturals

CONSTANT Variant   \* "original" | "naive" | "graced"

VARIABLES
    cam,      \* physical camera: "awake" | "shuttingDown" | "asleep"
    appLoc,   \* app's view: "absent" | "discovered" | "connected"
    flag      \* sleep flag: "none" | "recent" (inside grace) | "stale" (past grace)

vars == <<cam, appLoc, flag>>

CamStates  == {"awake", "shuttingDown", "asleep"}
AppStates  == {"absent", "discovered", "connected"}
FlagStates == {"none", "recent", "stale"}

TypeOK ==
    /\ cam    \in CamStates
    /\ appLoc \in AppStates
    /\ flag   \in FlagStates

Init ==
    /\ cam = "awake"
    /\ appLoc = "absent"
    /\ flag = "none"

-----------------------------------------------------------------------------
\* A camera radiates advertisements unless it has finished going to sleep.
Advertising == cam \in {"awake", "shuttingDown"}

(***************************************************************************)
(* shouldIgnoreAdvertisement, per variant.                                 *)
(*                                                                         *)
(* "original" never ignores, because the flag is never set in the first    *)
(* place -- the app immediately re-discovers a camera it just told to      *)
(* sleep, and BLEConnectionHandler then schedules a reconnect.             *)
(***************************************************************************)
ShouldIgnore(f) ==
    CASE Variant = "original" -> FALSE
      [] Variant = "naive"    -> f # "none"
      [] Variant = "graced"   -> f = "recent"
      [] Variant = "confirmed" -> f = "recent"

\* Flag written when the sleep command is sent.
FlagAfterSleepCommand ==
    IF Variant = "original" THEN "none" ELSE "recent"

\* Flag after an advertisement is honoured. Only "graced" treats the
\* advertisement as evidence that the camera woke up.
FlagAfterHonouredAdvert(f) ==
    IF Variant \in {"graced", "confirmed"} /\ f = "stale" THEN "none" ELSE f

-----------------------------------------------------------------------------
\* User asks the app to put a connected camera to sleep.
SendSleepCommand ==
    /\ appLoc = "connected"
    /\ cam = "awake"
    /\ cam' = "shuttingDown"
    /\ flag' = FlagAfterSleepCommand
    /\ UNCHANGED appLoc

\* The camera drops the BLE link as it shuts down.
CameraDisconnects ==
    /\ appLoc = "connected"
    /\ cam # "awake"
    \* BLEConnectionHandler moves the camera back to discoveredGoPros unless it
    \* believes the camera is sleeping.
    /\ appLoc' = IF flag = "none" THEN "discovered" ELSE "absent"
    /\ UNCHANGED <<cam, flag>>

\* The camera finishes powering down and stops advertising.
ShutdownCompletes ==
    /\ cam = "shuttingDown"
    /\ cam' = "asleep"
    /\ UNCHANGED <<appLoc, flag>>

(***************************************************************************)
(* The app stops believing the camera is mid-shutdown.                     *)
(*                                                                         *)
(* "graced" concludes this purely from elapsed time, which is why it fails *)
(* NoFightingOwnSleep: a camera still advertising when the window closes   *)
(* gets re-discovered mid-shutdown.                                        *)
(*                                                                         *)
(* "confirmed" instead requires having observed the camera go silent, so   *)
(* the conclusion is drawn from evidence rather than from a guess about    *)
(* how long shutdown takes.                                               *)
(***************************************************************************)
GraceExpires ==
    /\ flag = "recent"
    /\ (Variant = "confirmed" => ~Advertising)
    /\ flag' = "stale"
    /\ UNCHANGED <<cam, appLoc>>

\* The user presses the power button on a sleeping camera.
UserWakesCamera ==
    /\ cam = "asleep"
    /\ cam' = "awake"
    /\ UNCHANGED <<appLoc, flag>>

(***************************************************************************)
(* didDiscover. Enabled only when the advertisement will actually be       *)
(* honoured, so that an ignored advertisement is modelled as the action    *)
(* being disabled rather than as a stuttering step -- otherwise weak       *)
(* fairness could be satisfied by doing nothing.                           *)
(***************************************************************************)
ReceiveAdvertisement ==
    /\ Advertising
    /\ appLoc = "absent"
    /\ ~ShouldIgnore(flag)
    /\ appLoc' = "discovered"
    /\ flag' = FlagAfterHonouredAdvert(flag)
    /\ UNCHANGED cam

\* connectToGoPro requires the camera to be in discoveredGoPros.
Connect ==
    /\ appLoc = "discovered"
    /\ appLoc' = "connected"
    /\ flag' = "none"          \* a connected camera is awake by definition
    /\ UNCHANGED cam

-----------------------------------------------------------------------------
Next ==
    \/ SendSleepCommand
    \/ CameraDisconnects
    \/ ShutdownCompletes
    \/ GraceExpires
    \/ UserWakesCamera
    \/ ReceiveAdvertisement
    \/ Connect

(***************************************************************************)
(* Fairness on everything the app or physics drives. UserWakesCamera is    *)
(* deliberately unfair: the user is under no obligation to ever press the  *)
(* button, and the liveness property below is conditioned on the camera    *)
(* being awake anyway.                                                     *)
(***************************************************************************)
Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(ReceiveAdvertisement)
    /\ WF_vars(GraceExpires)
    /\ WF_vars(ShutdownCompletes)
    /\ WF_vars(CameraDisconnects)

-----------------------------------------------------------------------------
\*                              PROPERTIES

(***************************************************************************)
(* The app must not undo its own sleep command: while the camera is still  *)
(* shutting down, it must not reappear as a connectable camera.            *)
(* Violated by "original", where the flag is never set.                    *)
(***************************************************************************)
NoFightingOwnSleep ==
    [](cam = "shuttingDown" => appLoc # "discovered")

(***************************************************************************)
(* An awake camera must eventually become reachable. A camera kept out of  *)
(* discoveredGoPros can never be connected to, because connectToGoPro      *)
(* requires it to be there -- so believing it asleep forever makes it      *)
(* permanently invisible with no way for the user to recover.              *)
(* Violated by "naive", which never clears the flag.                       *)
(***************************************************************************)
AwakeCameraBecomesReachable ==
    (cam = "awake" /\ appLoc = "absent") ~> (appLoc # "absent")

\* Same claim as SleepVisibility's, stated over this model, to confirm the
\* property discriminates between the designs rather than passing vacuously.
NeverPermanentlyInvisibleWhileAwake ==
    ~<>[](cam = "awake" /\ appLoc = "absent")

\* Sanity: the app never believes a camera is asleep while connected to it.
NoSleepingWhileConnected ==
    [](appLoc = "connected" => flag # "recent")

=============================================================================
