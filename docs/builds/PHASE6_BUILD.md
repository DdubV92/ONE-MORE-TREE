# One More Tree: Phase 6 test build

**Download (Windows, about 231 MB zip):**
https://github.com/DdubV92/ONE-MORE-TREE/actions/runs/41776948834/artifacts/13297103353

(You need to be signed in to GitHub. The file is `OneMoreTree-windows-x86_64-phase-6-terror-foreman-23.zip`.)

1. Download the zip and extract it to a new folder. This replaces the previous build.
2. Run `OneMoreTree.exe`. Windows SmartScreen may warn because the build is unsigned: More info, then Run anyway.
3. Choose **Preview Tour**, then press **Tab** for the Tour panel. The new **Phase 6 stops** are:
   - **Night director**: something happens near you every 45–150 s. Stay out of the lamp light too long and the night catches you.
   - **Next family event**: steps through the 26 Terror families.
   - **Dog rescue**: the wind blows the camper door open. Follow the whining, pet Biscuit (E), and walk home together.
   - **Abandon -> hunt**: the Foreman. Hide with E under beds, in the camper wardrobe, under the utility desk, or under the dock.
   - **Hunt: day 35** and **Hunt: ship** jump ahead to the rescue ship. Press E at the end of the dock to board.

Every check passes: 46/46 automated tests, the smoke test, and CI (import, tests, Windows export). It has not been tested on a real GPU or with real audio.
