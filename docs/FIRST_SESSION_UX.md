# Project Ironwright — First-Session UX Contract

**Status:** Active production contract  
**Authority:** The current Project Ironwright conversation with Henrik.

The opening must feel frightening because the Mechromancer is weak and exposed, not because the interface withholds the next interaction or renders critical information unreadable.

On a first run with no valid save, the title screen focuses `NEW WORLD`,
visibly subdues the unavailable `CONTINUE` action, and keeps the no-save
explanation inside the current viewport. The first actionable step must not
depend on a mouse hover or an unexplained disabled menu item.

## 1. First objective clarity

The first objective must identify a real physical wreck rather than merely instructing the player to “leave the light.”

During the initial salvage step, the game provides:

- a pulsing amber marker attached to a real salvage wreck;
- an amber ground route made from restrained world-space lights;
- an approximate distance and cardinal direction in the objective text;
- a world label that states `HOLD E · LOUD`;
- a bottom-centre immediate-interaction prompt;
- explicit warning that salvaging disables the pistol and attracts organisms.

After the first manual salvage, guidance changes to the Heartforge and names the next action: press `E` and manually build the first Scrapper.

World guidance is an onboarding aid, not a permanent quest-arrow system. It is removed once the player has completed the first machine-group preparation.

## 2. Information hierarchy

The HUD separates information by purpose:

- **top-left:** one persistent strategic objective;
- **bottom-centre:** the immediate contextual interaction;
- **top-right:** large material reserves, machine focus, and current remote operation;
- **right side below resources:** a bounded transient machine-report stack;
- **bottom-left:** Mechromancer and Bulwark integrity;
- **bottom-right:** macro command reminders.

Objective text and notifications may not share the same visual region.

## 3. Notification policy

Machine reports are transient toasts rather than a permanent paragraph stack.

- at most three reports are visible;
- duplicate newest reports refresh rather than multiply;
- reports expire after a short readable interval;
- consequential history remains in the bounded run event log;
- the persistent objective is never displaced or obscured by notifications.

Later notification work should remain exception-based. Routine successful activity should not generate alert fatigue.

## 4. Forge menu

The forge is a full-screen modal interaction with a centred, responsive panel.

- the panel is sized from the current viewport with safe margins;
- tall content is scrollable;
- no fabrication option may be clipped off-screen at supported resolutions;
- the close action is a fixed, clearly labelled footer outside the scroll region;
- the dark modal backdrop separates the exposed strategic commitment from normal play;
- adding future robot families must not require manually increasing a hard-coded panel height.

The forge remains intentionally manual during the opening. Responsive presentation does not change the danger, time cost, noise, or attack lockout.

## 5. Evolution empty state

A strategic screen with no current choice must not display active-looking navigation.

When no technology is available:

- Previous and Next controls are hidden;
- the primary button reads `NO EVOLUTION AVAILABLE` and is disabled;
- the summary says that no strategic decision is currently required;
- the detail explains that the player should continue the current world objective;
- the screen does not imply that an unavailable choice is hidden on another page.

## 6. Resource readability

The resource HUD uses large, separated text for Scrap and Cognition Cores. Resource values, machine focus, and operation status have explicit vertical spacing and may not overlap.

Scrap remains the only ordinary stockpiled construction resource. Improving readability must not introduce economy dashboards or additional currencies.

## 7. Responsive acceptance targets

Automated native tests cover an 800×520 viewport as a constrained regression case. The forge and strategic panels must fit inside that viewport using scrollable content.

This is a regression floor, not the final supported-resolution list. The production accessibility milestone must later add text scaling, controller navigation, input remapping, contrast options, and formal resolution coverage.
