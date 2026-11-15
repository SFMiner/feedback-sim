**Feedback! — Game Design Document v0.1**
=========================================

GDD 0.1

Godot 4.7 · GDScript · Middle school biology · Fable agent handoff

**Core concept:** A playful, visually intuitive simulation that teaches positive and negative feedback by progressing from a familiar classroom analogy to abstract models and finally to interactive biological systems.

The experience is divided into two parts:

* **Part I — Watch:** Two short, automated demonstrations introduce the principles.

* **Part II — Experiment:** Students manipulate blood clotting and blood glucose regulation, observe the biological consequences, and connect their observations to graphs.

The primary goal is understanding **how a system's response amplifies or counteracts a change**, not memorizing what a particular graph looks like.

I'll treat this as a small, complete first release rather than an extensible platform with numerous hypothetical future features.
FEEDBACK!
=========

Game Design Document — Version 0.1
----------------------------------

**Project type:** Interactive educational simulation  
**Engine:** Godot 4.7  
**Language:** GDScript  
**Primary platform:** Web browser (HTML5/WebAssembly)  
**Audience:** Middle school science, primarily grades 6–8  
**Development:** Fable coding agent  
**Status:** Initial implementation specification

* * *

1. Executive Summary
   ====================

_Feedback!_ is a short educational simulation designed to help students understand positive and negative feedback mechanisms, particularly in biological systems.

The program begins with two automated demonstrations and progresses into two interactive biological simulations.

### Part I — Watch

1. **Classroom Chatter:** Cartoon students become increasingly noisy. A teacher repeatedly intervenes until distracted by another teacher, allowing the noise to escalate unchecked.

2. **Abstract Feedback:** A changing quantity is represented by a moving marker and an animated graph. Positive feedback amplifies changes; negative feedback produces corrective responses.

### Part II — Experiment

3. **Blood Clotting:** Students investigate how platelet activation recruits additional platelets and helps form a plug at an injury.

4. **Blood Glucose Regulation:** Students investigate how insulin and glucagon help maintain blood glucose homeostasis.

The program uses simple animation, playful sound effects, and time-series graphs to connect observable events to abstract scientific concepts.
1.1 Core learning objectives
----------------------------

Students should be able to:

* Identify positive and negative feedback.

* Explain that positive feedback amplifies an initial change.

* Explain that negative feedback counteracts a change.

* Recognize that multiple feedback mechanisms can operate within one system.

* Predict how a system might behave when a feedback mechanism is interrupted.

* Connect the events in a simulated system to changes in a line graph.

* Identify platelet recruitment as an example of positive feedback.

* Identify blood glucose regulation as an example of negative feedback.

1.2 Design principles
---------------------

* Show cause and effect before introducing formal vocabulary.

* Favor animation over lengthy explanations.

* Keep text concise and reading demands low.

* Use the same visual and auditory cues across related concepts.

* Make graphs meaningful by connecting them to visible events.

* Preserve scientific accuracy while allowing simplified models.

* Avoid unnecessary complexity and feature creep.

* * *

2. Program Structure
   ====================

The program has four modules, arranged in a suggested sequence.

| Module            | Type                   | Student interaction                    |
| ----------------- | ---------------------- | -------------------------------------- |
| Classroom Chatter | Animated demonstration | Play, pause, replay, skip              |
| Abstract Feedback | Animated demonstration | Play, pause, replay, skip              |
| Blood Clotting    | Interactive simulation | Manipulate conditions, run experiments |
| Blood Glucose     | Interactive simulation | Manipulate conditions, run experiments |

The opening two demonstrations are intentionally noninteractive except for playback controls.

Students should be able to replay any module or navigate directly to a module from the main menu.

Completing a module must not be required to unlock another.

* * *

3. Module One: Classroom Chatter
   ================================

3.1 Purpose
-----------

Introduce positive and negative feedback using a familiar experience.

The classroom contains both a positive-feedback mechanism (conversation encouraging additional conversation and louder speech) and a negative-feedback mechanism (teacher intervention reducing the noise).

Students see what happens when the negative-feedback mechanism is temporarily disabled.
3.2 Visual design
-----------------

The scene depicts a classroom with approximately 12–16 students seated at desks and one teacher at the front.

All characters are drawn procedurally using simple geometric shapes:

* Ellipses for heads and bodies.

* Lines for arms and legs.

* Simple facial expressions.

* Basic geometric hairstyles.

* Minimal desks and classroom furniture.

The student population must visually reflect a diverse school community.

### Character diversity requirements

* Use a curated palette of approximately 10–12 natural skin tones, including a broad range of undertones.

* Include different hair colors, textures, lengths, and styles.

* Vary clothing colors and character proportions.

* Randomize appearance independently of simulated behavior.

* Do not correlate skin tone, hairstyle, or other appearance traits with disruptive behavior.

Use deterministic random seeds where practical so a replay reproduces the same student appearances.
3.3 Student animation
---------------------

Each student has an activity level ranging from 0 to 1.

| Activity | Visual state                               |
| -------- | ------------------------------------------ |
| 0–0.2    | Quiet, minimal movement                    |
| 0.2–0.5  | Talking, gentle head movement              |
| 0.5–0.8  | Animated conversation, faster head bobbing |
| 0.8–1.0  | Excited talking, exaggerated movement      |

The activity level controls head movement, mouth animation, arm movement, and participation in the chatter soundtrack.

Characters should not move in perfect synchronization.
3.4 Cartoon dialogue audio
--------------------------

No recorded human speech is needed.

Student voices are represented by synthesized, brass-like cartoon sounds reminiscent of muted trombone speech effects.

Create four distinct student voice presets:

| Voice | Sound                         |
| ----- | ----------------------------- |
| A     | Low, rounded “womp-womp”      |
| B     | Medium-low “wah-wah”          |
| C     | Medium-high “wah-wah-wah”     |
| D     | Higher, shorter “wap-wap-wap” |

Each student is assigned a preset, with small randomized pitch and timing variations.

Speech-like bursts should overlap irregularly, rather than forming a synchronized musical pattern.

As classroom activity rises:

* More student voices become active.

* The frequency of vocalizations increases.

* Their combined volume increases.

* Student animations become more energetic.

The soundtrack must have a maximum output level to prevent unpleasant or distorted playback.

The sounds should be original procedural audio, not copied recordings.
3.5 Teacher sound and animation
-------------------------------

The teacher uses a fifth voice, substantially deeper than any student voice.

When intervening, the teacher raises both arms and produces three emphatic notes:

**WHOMP! WHOMP! WHOMP!**

Each note causes a visible reduction in classroom noise.

At the conclusion of the third note, the simulated classroom noise reaches zero.

The teacher then lowers their arms.

The teacher's visual and auditory responses are synchronized with the graph.
3.6 Demonstration sequence
--------------------------

### Phase A: Negative feedback active

1. Classroom begins quietly.

2. One student initiates conversation.

3. Nearby students become involved.

4. More students begin talking and increasing their volume.

5. Classroom noise rises.

6. Noise crosses the teacher's intervention threshold.

7. Teacher raises their arms and makes three deep corrective sounds.

8. Noise decreases to zero.

9. After a short quiet interval, chatter gradually resumes.

10. The cycle repeats approximately three times.

The graph shows repeated increases and sharp decreases.

### Phase B: Negative feedback interrupted

1. A second teacher enters the classroom.

2. The second teacher approaches the first.

3. Both teachers turn toward one another.

4. They begin a quiet conversation.

5. The classroom's teacher-intervention mechanism becomes inactive.

6. Student conversations resume.

7. The chatter spreads and intensifies without correction.

8. Classroom volume approaches its maximum.

9. The graph levels off near the system's upper limit.

Display the message:

**“The positive feedback is still working. What happened to the negative feedback?”**

After a brief interval, the demonstration ends.
3.7 Simulation mechanics
------------------------

The scene should use a lightweight model of individual student participation.

Suggested state variables:

* `student_activity[i]`

* `student_voice_id[i]`

* `noise_level`

* `chatter_spread_rate`

* `loudness_amplification`

* `teacher_threshold`

* `teacher_active`

* `teacher_intervening`

* `teacher_distracted`

Students influence nearby students, causing participation to spread.

The aggregate noise level depends on both the number of active students and their activity levels.

The teacher's response reduces student activity and associated noise in three timed steps.

During distraction, the corrective mechanism is disabled.

A maximum noise level represents the finite number of students and their limited ability to increase volume. This prevents mathematically unbounded growth.

The model must support repeatable behavior with small variations rather than relying on a predetermined graph drawn independently of classroom events.
3.8 Real-time graph
-------------------

Display a graph beside or beneath the classroom.

* X-axis: Time

* Y-axis: Classroom Noise

* Horizontal dashed line: Teacher Intervention Threshold

* Moving marker: Current noise level

The graph should update continuously from actual simulation values.

When the teacher intervenes, the graph falls in three visible steps synchronized with the three deep sound effects.

When the teacher becomes distracted, the graph continues rising beyond the usual intervention threshold.

The graph should scroll or scale as necessary without becoming visually cluttered.

A replay should reproduce the same recorded curve.

* * *

4. Module Two: Abstract Feedback
   ================================

4.1 Purpose
-----------

Remove the classroom context and show the underlying relationships directly.

This demonstration introduces a changing quantity, a reference or target level, and feedback responses.

It should resemble a playful, simple arcade animation rather than a conventional scientific presentation.
4.2 Negative-feedback demonstration
-----------------------------------

Display a graph with:

* A horizontal target line.

* A moving marker tracing a quantity over time.

* A corrective object above the graph.

* A second corrective object below the graph.

The marker begins rising.

When the quantity exceeds the upper threshold, the upper corrective object strikes or pushes the marker downward with a short **BIP!** sound.

The quantity falls, overshoots the target, and eventually crosses the lower threshold.

The lower corrective object pushes it upward with a **BOOP!** sound.

The pattern repeats, creating a recognizable oscillating curve.

### Scientific qualification

This is an intentionally exaggerated model of delayed, threshold-triggered negative feedback.

Negative feedback does not always create oscillations. Some negative-feedback systems return smoothly toward their target.

Include a concise explanatory caption:

“Negative feedback opposes a change. Sometimes delayed corrections make a system rise and fall repeatedly.”

The mathematical behavior should come from a simplified response-and-delay model rather than an arbitrary sine-wave animation.
4.3 Positive-feedback demonstration
-----------------------------------

Begin with a marker moving upward from a baseline.

Each increase activates an animated booster.

The booster causes an additional increase, which strengthens subsequent responses.

The graph rises increasingly rapidly.

A practical upper limit eventually slows and stops further growth.

Display:

**“Positive feedback amplifies a change.”**

The graph should demonstrate accelerating growth, followed by leveling off because of an explicitly identified limit.

Positive feedback must not be defined as merely making a quantity increase. It amplifies the direction of the initial change.
4.4 Interface
-------------

Both abstract demonstrations are automated.

Controls:

* Play

* Pause

* Replay

* Skip

No interactive sliders or mathematical parameter editing are required in version 0.1.

The classroom and abstract demonstrations should reuse similar feedback sounds and graphical conventions.

* * *

5. Module Three: Blood Clotting
   ===============================

5.1 Purpose
-----------

Show positive feedback operating within a biological process.

Students investigate how platelet activation recruits additional platelets, allowing a platelet plug to form at a damaged blood vessel.
5.2 Visual environment
----------------------

Depict a simplified section of a damaged blood vessel.

Visible elements:

* Vessel wall.

* Wound or damaged region.

* Flowing red blood cells.

* Circulating platelets.

* Activated platelets.

* Chemical recruitment signals.

* Developing platelet plug.

The primary visual focus is platelet recruitment.

A fibrin mesh can appear during the final stage to indicate clot stabilization.

The interface should distinguish platelets from chemical signaling particles.
5.3 Biological sequence
-----------------------

1. Vessel injury exposes material that allows platelets to adhere.

2. Platelets attach to the damaged region.

3. Adhering platelets become activated.

4. Activated platelets release recruitment signals, including ADP.

5. Additional platelets become activated and join the developing plug.

6. Newly activated platelets contribute additional signals.

7. The platelet plug grows.

8. Plug growth slows as the exposed injury becomes covered and local regulatory processes limit further accumulation.

This is a simplified representation of primary hemostasis, not a complete model of the coagulation cascade.
5.4 Student controls
--------------------

Provide three primary controls:

**Wound Size**

* Small

* Medium

* Large

Changes the exposed area requiring coverage.

**Platelet Availability**

* Low

* Normal

* High

Changes the supply of circulating platelets.

**Recruitment Signaling**

* Normal

* Reduced

* Blocked

Changes the effectiveness of chemical signaling between activated and circulating platelets.

Include:

* Start Experiment

* Pause

* Reset

* View Results

5.5 Simulation logic
--------------------

Use simplified, visually meaningful rules.

Platelets circulate through the vessel.

Platelets encountering the damaged region have a probability of adhering.

Activated platelets generate nearby chemical signals.

Those signals increase the probability that nearby platelets become activated and join the plug.

This creates positive feedback.

The simulation must distinguish:

* Initial platelet adhesion.

* Signal-mediated recruitment.

* Physical accumulation of platelets.

* Closure of exposed injury.

The total number of platelets is finite.

Growth must not continue indefinitely.

The signaling-blocked condition should reduce recruitment but should not necessarily eliminate all initial adhesion.
5.6 Graph and results
---------------------

During the simulation, record:

* Time

* Number of platelets attached

* Number of newly recruited platelets per interval

* Wound coverage percentage

After the experiment, display a graph.

Default graph:

* X-axis: Time

* Y-axis: Attached Platelets

Include annotated events:

* Injury

* First platelet adhesion

* Increased recruitment

* Plug formation

Students should be able to replay the sequence with the graph synchronized to the animation.

The graph should reflect the simulation data, not a predetermined ideal curve.

The plot will generally demonstrate platelet accumulation accelerating during recruitment and slowing as the plug approaches completion.
5.7 Student reflection
----------------------

After the graph is shown, ask:

**“How did the first platelets cause more platelets to gather?”**

Provide an optional sentence frame:

“The first platelets released signals that caused ______.”

A second optional prompt:

**“What changed when platelet recruitment signals were blocked?”**

These prompts should not prevent students from replaying or continuing.

* * *

6. Module Four: Blood Glucose Regulation
   ========================================

6.1 Purpose
-----------

Illustrate negative feedback maintaining internal conditions near a normal operating range.

Students investigate how the pancreas, liver, and body tissues respond to changing blood glucose concentrations.
6.2 Visual environment
----------------------

Display three major structures:

* Bloodstream

* Pancreas

* Liver

Also show a simplified body-tissue region to represent cells using or storing glucose.

Use animated particles for:

* Glucose

* Insulin

* Glucagon

Particles should be visually distinct and accompanied by labels or symbols so the simulation does not depend on color alone.

The liver includes a graphical glycogen-storage indicator.

Blood glucose concentration is shown using a prominent meter.
6.3 Biological model
--------------------

### High blood glucose

1. Blood glucose rises.

2. Pancreatic beta cells increase insulin secretion.

3. Insulin promotes glucose uptake in responsive tissues and glucose storage.

4. The liver increases glycogen synthesis and reduces glucose output.

5. Blood glucose decreases toward its operating range.

6. The stimulus for increased insulin secretion diminishes.

### Low blood glucose

1. Blood glucose falls.

2. Pancreatic alpha cells increase glucagon secretion.

3. Glucagon acts primarily on the liver.

4. The liver breaks down glycogen and releases glucose into the bloodstream.

5. Blood glucose rises toward its operating range.

6. The stimulus for increased glucagon secretion diminishes.

The model must not imply that all glucose uptake requires insulin or that insulin and glucagon work as simple mutually exclusive switches.
6.4 Student controls
--------------------

Provide three disturbances:

**Eat a Meal**

Introduces glucose into the bloodstream over a short period.

**Exercise**

Increases simulated glucose utilization by muscle tissue.

**Fast**

Stops dietary glucose input while normal glucose utilization continues.

Students may start, pause, reset, and replay experiments.

Two additional controls are provided through an optional Advanced panel:

* Insulin Response: Normal / Reduced

* Glucagon Response: Normal / Reduced

These allow students to experiment with impaired regulatory responses without introducing named diseases in the initial release.
6.5 Simulation mechanics
------------------------

Use a simplified discrete-time model.

State variables:

* `blood_glucose`

* `insulin_activity`

* `glucagon_activity`

* `liver_glycogen`

* `dietary_glucose_input`

* `tissue_glucose_use`

* `liver_glucose_output`

The pancreas responds to blood glucose with finite response rates.

Insulin activity increases glucose removal and storage while suppressing liver glucose output.

Glucagon activity increases liver glucose production, including release from glycogen stores.

The liver's glycogen reserves are finite.

The system should have a baseline operating range and tend toward stability under normal conditions.

Do not force the graph into a sine wave. Normal regulation may return glucose toward baseline smoothly, with delayed or imperfect correction where appropriate.

Use classroom-friendly normalized units if medically realistic quantitative parameters would add complexity without improving understanding.

Avoid presenting normalized values as actual clinical blood glucose measurements.
6.6 Graph and replay
--------------------

Record:

* Blood glucose concentration

* Insulin activity

* Glucagon activity

* Liver glycogen

* Time

Default results graph:

* X-axis: Time

* Y-axis: Blood Glucose

* Shaded band: Target Range

Mark:

* Meal / Exercise / Fasting

* Increased insulin response

* Increased glucagon response

* Return toward target range

Optional graph layers may show insulin and glucagon activity, but should be hidden by default to avoid overwhelming students.

Students can replay the experiment with biological animation and the graph synchronized.
6.7 Student reflection
----------------------

Prompt:

**“What happened when blood glucose moved away from its normal range?”**

Optional sentence frame:

“When glucose became ______, the pancreas responded by ______, causing glucose to move ______.”

Additional prompt:

**“Why is this an example of negative feedback?”**

The expected answer should focus on opposing a change rather than simply reducing glucose.

* * *

7. Shared Graphing System
   =========================

All four modules must use a common graph-rendering component.

The graph engine is responsible for:

* Plotting recorded values over time.

* Supporting animated graph drawing.

* Displaying targets and threshold lines.

* Marking significant events.

* Replaying recorded data.

* Synchronizing graph markers with animation.

* Providing readable axis labels.

* Supporting graphs with different units and data ranges.

Graphs should be scientifically meaningful rather than decorative.

The classroom and abstract modules display graphs live.

The biological modules record data while students experiment and emphasize the graph during the results/replay stage.
7.1 Important graph distinction
-------------------------------

The program must not teach that:

* Positive feedback always produces one particular rising curve.

* Negative feedback always produces a sine wave.

* Every biological positive-feedback system grows exponentially.

* Every negative-feedback system oscillates.

The relationship between a feedback mechanism and the resulting curve depends on the system, its limits, response strength, and delays.

The abstract animations demonstrate recognizable examples, not universal mathematical laws.

* * *

8. User Interface
   =================

8.1 Main menu
-------------

Title: **FEEDBACK!**

Subtitle: _What happens when a system responds to change?_

Main options:

* Watch: Classroom Chatter

* Watch: Abstract Feedback

* Experiment: Blood Clotting

* Experiment: Blood Glucose

Include a brief indication of which modules are demonstrations and which are interactive.
8.2 Common controls
-------------------

* Play / Pause

* Reset / Replay

* Return to Menu

* Next Module

* Sound On / Off

The biological modules additionally include experiment controls.

All buttons must be large enough for classroom use.

Avoid menus covering the simulated biological structures.
8.3 Accessibility
-----------------

Required:

* Scalable interface.

* High-contrast text.

* Minimal reading load.

* Color-independent labels and symbols.

* Mute control.

* Adjustable sound volume.

* Reduced-motion option.

* Visible captions or symbols for meaningful sound cues.

* Ability to pause animated demonstrations.

Meaningful information must never be communicated by sound alone.

* * *

9. Audio Design
   ===============

9.1 Procedural synthesis
------------------------

Use Godot's `AudioStreamGenerator` or another lightweight built-in approach for synthesized sound.

Do not rely on an external audio-generation service.

Required sounds:

| Sound               | Purpose                     |
| ------------------- | --------------------------- |
| Student Voice A     | Low classroom chatter       |
| Student Voice B     | Mid-low chatter             |
| Student Voice C     | Mid-high chatter            |
| Student Voice D     | High chatter                |
| Teacher Voice       | Three deep corrective notes |
| Positive Booster    | Short amplification cue     |
| Negative Correction | Short BIP / BOOP cue        |

The student voices should resemble playful, nonverbal cartoon dialogue.

Use moderate variation in frequency, envelope, and timing to avoid mechanical repetition.

The teacher sound must be distinctly lower than all student sounds.

Audio output should be dynamically limited or conservatively mixed to prevent excessive volume as voices overlap.

Sound must work reliably in the exported web build, including browser audio-start restrictions.

* * *

10. Visual Assets
    =================

10.1 Procedurally generated assets
----------------------------------

The following require no external illustration files:

* Classroom students.

* Teachers.

* Classroom furniture.

* Student expressions and limbs.

* Speech indicators.

* Abstract feedback markers.

* Feedback paddles or corrective objects.

* Graph lines, grids, markers, and labels.

* Most UI elements.

Use Godot drawing primitives and simple transformations.
10.2 Biological assets
----------------------

The teacher/developer may provide vector artwork for:

| Asset                | Required for MVP?                           |
| -------------------- | ------------------------------------------- |
| Platelet             | Yes, but procedural fallback acceptable     |
| Activated platelet   | Yes, but recoloring/shape change acceptable |
| Red blood cell       | Yes, but procedural fallback acceptable     |
| Blood vessel / wound | Yes, but procedural fallback acceptable     |
| Pancreas             | Yes, but procedural fallback acceptable     |
| Liver                | Yes, but procedural fallback acceptable     |
| Glucose              | Yes, simple symbol acceptable               |
| Insulin              | Yes, simple symbol acceptable               |
| Glucagon             | Yes, simple symbol acceptable               |
| Fibrin mesh          | Optional                                    |

**The agent must not block implementation while waiting for artwork.**

Use simple procedural placeholders where necessary.

Asset replacement must not require rewriting the simulation logic.
10.3 Recommended art style
--------------------------

* Clean, colorful, cartoon-like.

* High visual contrast.

* Simple recognizable silhouettes.

* Limited decorative detail.

* Consistent visual language across modules.

The program should look like an approachable educational game, not a clinical simulation.

* * *

11. Technical Architecture
    ==========================

11.1 Platform
-------------

Target Godot 4.7 using GDScript.

The initial deliverable must be a fully functional Godot project.

It should run locally and support a web export suitable for hosting on a school simulation website.

Avoid unnecessary external dependencies.
11.2 Suggested scene structure
------------------------------

    Main├── MainMenu├── Demonstrations│   ├── ClassroomDemo│   │   ├── ClassroomController│   │   ├── StudentCharacters│   │   ├── TeacherCharacters│   │   └── ChatterAudio│   └── AbstractDemo│       ├── PositiveFeedback│       └── NegativeFeedback├── Biology│   ├── ClottingSimulation│   │   ├── ClottingModel│   │   └── ClottingView│   └── GlucoseSimulation│       ├── GlucoseModel│       └── GlucoseView├── Shared│   ├── GraphController│   ├── TimelineRecorder│   ├── AudioController│   └── UIComponents└── Settings

This is a suggested organization rather than a mandatory exact node hierarchy.
11.3 Separation of model and presentation
-----------------------------------------

The simulation logic must be separate from animation and sound.

The model determines:

* What quantities change.

* What responses are triggered.

* When feedback activates.

* What data gets recorded.

The view determines:

* What students see.

* How objects animate.

* Which sounds play.

* How the graph is drawn.

Changing a visual asset must not change the scientific behavior.
11.4 Shared systems
-------------------

The modules may use different scientific simulation rules, but should share common infrastructure:

* Time stepping.

* Event recording.

* Graph drawing.

* Playback.

* Audio volume management.

* Navigation.

* Pause and reset behavior.

Do not force all biological systems into one generic mathematical feedback formula.
11.5 Determinism and replay
---------------------------

Where feasible, simulations should use fixed time steps and seeded random number generators.

The replay system should record the data and key events required to reproduce the experiment.

For v0.1, replay may be based on recorded state snapshots rather than a fully generalized event-reconstruction system.

At minimum, the replayed animation and graph must agree on event timing and measured values.
11.6 Performance
----------------

Target:

* Smooth operation in current desktop browsers.

* A responsive 2D interface.

* Moderate particle counts.

* Efficient drawing and animation.

* No requirement for a dedicated graphics card.

Use visual particles to represent concentrations and flows without requiring an individual simulated molecule for every real molecule.

* * *

12. Scientific Accuracy Requirements
    ====================================

The simulation may simplify biological processes, but must not teach scientifically false relationships.

Specific safeguards:

1. Positive feedback amplifies a change; negative feedback opposes a change.

2. Positive feedback is not synonymous with increase, nor negative feedback with decrease.

3. Negative feedback does not necessarily produce oscillations.

4. The classroom is an analogy, not a biological mechanism.

5. Platelet adhesion and activation involve more than platelet-released chemical signals alone.

6. Platelet plug growth is limited by available platelets, wound coverage, and regulatory processes.

7. Insulin influences glucose uptake, storage, and production, but not all glucose uptake requires insulin.

8. Glucagon promotes hepatic glucose production, including glycogen breakdown.

9. Liver glycogen is finite.

10. Graphs must reflect actual simulation states, not independent scripted curves.

All simplifications should be consistent with the instructional objective.

* * *

13. Assessment and Learning Support
    ===================================

The initial version uses brief, optional reflection prompts.

Do not implement a full quiz system.

Students should be able to:

* Make a prediction.

* Run an experiment.

* Review the graph.

* Explain the observed relationship.

* Reset and try a different condition.

Provide optional sentence frames.

The program should not require typing to complete a simulation.

No scoring, grading, or student accounts are required for v0.1.

* * *

14. Acceptance Criteria
    =======================

The first release is complete when the following conditions are satisfied.
Classroom demonstration
-----------------------

* Procedural classroom contains diverse student characters.

* Student activity spreads visibly between nearby characters.

* Four distinct procedural chatter voices are implemented.

* Teacher uses three deep corrective sounds.

* Teacher intervention reduces noise to zero.

* A second teacher interrupts the negative-feedback mechanism.

* Chatter subsequently escalates toward a maximum.

* A real-time graph accurately records noise level.

* Graph movements and audio events remain synchronized.

* Demonstration can be paused, restarted, and replayed.

Abstract demonstration
----------------------

* Positive feedback visibly amplifies a change.

* Negative feedback visibly produces corrective responses.

* BIP / BOOP sound effects are synchronized with corrections.

* Graphs are clearly labeled.

* The demonstration does not claim that every negative-feedback system oscillates.

Blood clotting
--------------

* Platelets circulate and adhere near an injury.

* Activated platelets recruit additional platelets.

* Recruitment signaling influences plug formation.

* Wound size and platelet availability change outcomes.

* Growth slows as the injury is covered or resources become limiting.

* Results graph reflects recorded platelet accumulation.

* Biological animation can be replayed with the graph.

Blood glucose
-------------

* Meals increase blood glucose.

* Exercise increases glucose utilization.

* Fasting removes dietary glucose input.

* Insulin response opposes elevated blood glucose.

* Glucagon response opposes low blood glucose.

* Liver glycogen storage and release are represented.

* Reduced hormone responses produce meaningful differences.

* Results graph reflects recorded blood glucose values.

* Simulation can be replayed with the graph.

Application
-----------

* All four modules can be accessed from the main menu.

* No external asset is necessary to launch the project.

* Godot project opens without script errors.

* Local desktop build is functional.

* Web export launches and functions correctly.

* Audio can be muted and adjusted.

* All modules can be reset without restarting the application.

* * *

15. Explicitly Out of Scope for v0.1
    ====================================

Do not implement these unless specifically requested later:

* Student accounts or authentication.

* Cloud storage.

* Teacher analytics dashboard.

* Automated grading.

* Complex mathematical model editors.

* Additional biological feedback systems.

* Detailed coagulation cascades.

* Full endocrine physiology.

* Advanced molecular collision simulation.

* Multiplayer functionality.

* Voice acting or speech recognition.

* A general-purpose feedback-loop construction game.

* Complex character animation rigs.

The priority is a polished, functioning set of four connected educational experiences.

* * *

16. Development Instructions for the Fable Agent
    ================================================

Build the complete application from this specification.

Use placeholder graphics where external artwork is unavailable. The classroom and abstract demonstrations should be implemented entirely with procedural shapes and animation.

Prioritize the following internal development order:

1. Establish application navigation, graphing, and timeline recording.

2. Implement the classroom demonstration and procedural sound.

3. Implement the abstract feedback demonstration.

4. Implement blood clotting.

5. Implement blood glucose regulation.

6. Add synchronized replay and student reflection prompts.

7. Test desktop and web builds.

This is an implementation sequence, not a requirement for separate deliveries.

The final project should include a short README explaining how to run, export, and test the simulation, and where externally supplied artwork can replace placeholders.

**Do not add features simply because the architecture could support them.**

If a feature in this specification proves unusually difficult, implement the simplest scientifically accurate alternative and document the deviation.
Definition of success
---------------------

The completed simulation should enable a student to watch an everyday example of feedback, recognize the same pattern in an abstract animation, manipulate biological systems, and explain the resulting changes using evidence from a graph.

The experience should feel playful, intuitive, and visually engaging while remaining faithful to the underlying scientific principles.

H₂**End of GDD v0.1**
-----------------------------------------------------


-----------------------------------------------------

**Two decisions worth preserving during development**
-----------------------------------------------------

The classroom simulation is an analogy, so its deliberately dramatic rise-and-fall graph is appropriate. The biological graphs, however, should follow their own simulated mechanisms rather than being forced to look like the classroom graph.

Also, the biological artwork is **replaceable, not a prerequisite**. The Fable agent should be able to build and test the entire program with procedural placeholders, leaving you free to create better illustrations afterward.

For implementation, I verified that Godot 4.7 provides the necessary procedural audio and custom-drawing facilities, including `AudioStreamGenerator` and `CanvasItem` drawing methods.

Godot Engine (4.7) documentation in English+2

My principal recommendation for the next revision would be to scrutinize **the specific controls and outcomes of the two biological experiments**, since those are where the educational value will depend most heavily on getting the interactions right.


