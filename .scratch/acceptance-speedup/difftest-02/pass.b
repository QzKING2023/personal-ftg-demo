PASS  236C segment 1 launches the dummy into float hitstun via keyboard input
PASS  5A opens the air route as the first hit via keyboard
PASS  6A lands to open the jump cancel window after the freeze
PASS  S crouches the player via the real keyboard path
PASS  S plus back enters the crouch guard
PASS  S stops an existing backward walk on the first crouch frame
PASS  air action after jump cancel starts the jA pursuit move
PASS  air direction release/reversal keeps takeoff momentum and facing +1
PASS  air direction release/reversal keeps takeoff momentum and facing -1
PASS  air route key A lands as combo hit 4
PASS  air route key B lands as combo hit 5
PASS  air route key D lands as combo hit 6
PASS  attack hits once when the dummy is close
PASS  attack misses when the dummy is far away (hp unchanged from the earlier hit)
PASS  both 236C segments apply their own damage (8×1.0 + 12×0.90)
PASS  buffered 5B chain-cancels 5A as the second hit
PASS  buffered 6A chain-cancels 5B into the launcher
PASS  crouching squashes the player visuals
PASS  damage applied exactly once per swing (A-starter scaled 5.8)
PASS  derivative moves carry explicit input bindings from the shared resource
PASS  double-tapping the back key starts the backdash with the same duration
PASS  double-tapping the forward key starts the 12-frame dash via the real input path
PASS  dummy damaged before reset
PASS  dummy enters hitstun on hit
PASS  dummy flashes on the hit event
PASS  dummy recovers to neutral after hitstun
PASS  dummy returns to neutral after landing
PASS  dummy starts at full hp
PASS  dummy starts neutral
PASS  dummy status display starts neutral
PASS  dummy view follows the session position
PASS  dummy view shows the trajectory-scaled knockback displacement (120px/s)
PASS  facing stays locked toward the dummy through both dashes
PASS  first attack lands via injected input
PASS  forward jump lifts the player before the air input
PASS  forward jump lifts the player before the air input
PASS  guarding tints the player visuals
PASS  hint block stays clear of the status column
PASS  hint label shows the refusal and the offending field
PASS  hit flash clears after its duration
PASS  holding S plus back stays in place
PASS  holding back keeps facing the dummy through the whole keyboard input
PASS  holding the back direction enters the standing guard
PASS  holding the direction key alone never dashes
PASS  input right after the hit cancels 5A into 5B via the buffer
PASS  j214D starts while still airborne via the real input path
PASS  j214D starts while still airborne via the real input path
PASS  j5D closes the air route at six hits (the combo ends via the cancel-window close after the closer)
PASS  jA pursuit lands as the second combo hit via keyboard input
PASS  jump cancel clears the move but keeps the combo alive
PASS  jump cancel request leaves the ground after the four pre-jump frames
PASS  keyboard 214 from ground neutral (holding back) locks 214D
PASS  keyboard 236 then C locks the two-segment derivative
PASS  keyboard I then K within the 3-frame tolerance starts the B+C throw
PASS  keyboard air 214 folded by the locked facing starts the configured j214D
PASS  keyboard air 214 folded by the locked facing starts the configured j214D
PASS  keyboard forward + A locks the 6A launcher for the jump cancel route
PASS  launcher puts the dummy into float hitstun
PASS  main scene drives a combat session
PASS  main scene spawns Dummy
PASS  main scene spawns Player
PASS  no extra hits land after the route
PASS  no extra hits: the pursuit does not refresh the float for another launch
PASS  player and dummy both land after the pursuit
PASS  player lands and the dummy recovers naturally after the air finisher
PASS  player lands back on the ground
PASS  player moves right with input held
PASS  player rests against the wall after input released
PASS  player rises well above the ground on jump
PASS  player stops at the right stage wall
PASS  player view follows the session position
PASS  refusal reason is observable on the training ground
PASS  rejection reports resource source, move id and field
PASS  releasing S stands back up
PASS  releasing S while holding forward resumes movement immediately
PASS  releasing everything returns to plain standing
PASS  reset restores dummy hp
PASS  reset restores dummy state
PASS  reset restores player spawn
PASS  route damage is 6A at C-starter scale plus decayed jA
PASS  route damage totals 39.6 through the three-layer corrections (j5D base 16, ticket 08)
PASS  scene reloaded on reset
PASS  second hit applies the accumulated-layer damage (12x0.648)
PASS  segment 2's air extension lands into ground hitstun (no mid-air tech on this baseline)
PASS  session 5A damage comes from the shared resource (frozen baseline 10)
PASS  session 5A startup comes from the shared resource (frozen baseline 5)
PASS  session table contains the configured j214D
PASS  session table contains the configured j214D
PASS  session tracks two combo hits
PASS  shared manifest loads and validates for the training ground
PASS  solver refuses the same table for the same observable reason
PASS  space jump-cancels the confirmed launcher into the air after pre-jump
PASS  started-but-whiffed is distinguishable on the real input path
PASS  started-but-whiffed is distinguishable on the real input path
PASS  status display returns to neutral
PASS  status display shows the airborne player posture
PASS  status display shows the airborne posture during the route
PASS  status display shows the combo hit count
PASS  status display shows the float hitstun state
PASS  status display shows the hitstun state
PASS  status display shows the six-hit combo
PASS  status text fits inside the design viewport width
PASS  switching to S plus forward stays crouched in place without guarding
PASS  the backdash moves the player away from the dummy while facing stays locked toward it
PASS  the debug line shows the backdash (撤)
PASS  the debug line shows the crouch guard posture
PASS  the debug line shows the forward dash (冲) while it runs
PASS  the debug line shows the standing guard posture
PASS  the forward dash visibly advances the player toward the dummy side
PASS  the hint line documents the B+C throw input
PASS  the keyboard 214D connects on the nearby dummy
PASS  the same B+C sequence out of throw range starts nothing and never falls back to a strike
PASS  the tech window is observably tracked while the throw runs
PASS  the throw never counts as a combo hit
PASS  the throw result deals no HP damage
PASS  the thrown dummy recovers naturally after the throw hitstun
PASS  the un-teched throw result puts the dummy into ground hitstun via the real input path
PASS  training ground refuses to run on an invalid move table
PASS  training ground runs the temp manifest with the configured air derivative
PASS  training ground runs the temp manifest with the configured air derivative
PASS  training ground session runs the shared manifest move set
PASS  training ground shows the same rejection reason as the shared loader
PASS  visuals return to normal after the posture clears
