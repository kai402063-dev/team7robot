# Independent manual reproduction scope

Target: `a4676cd0fec63dec75f34e88ce6dcc64b79d39e0` on local `ai-migration-baseline`.

The reader started at `docs/DEV_MANUAL.md`, then read its linked handson, ROS 2, Webots, testing, troubleshooting, stateflow, architecture, interfaces, module, extension, defect, course mapping, AI provenance and generated-number documents. `PROGRESS.md` was reached through the manual link. No other build cache or earlier audit script was used as an implementation aid. The target clone was created with the exact local clone command, with the task's assigned new directory `build/clean-final-01`.

Source reads after the manual: `scripts/run_matlab.sh`, `scripts/reproduce_all.m`, `scripts/reproduce_m2.m` to see when ROS starts and preserve process isolation; manual-linked `scripts/build_learning_replay.m`, `scripts/build_lessons.m`, and `algorithms/+tdp/laneClear.m` for the prescribed practice. The initial guessed `lib/+tdp/laneClear.m` did not exist; `rg --files` located the actual documented `algorithms` path. This was a reader navigation error, not a manual defect. State text is read from manual-linked generated/stateflow.json; the original controller builder was not read for reconstructing the hierarchical chart.

All MATLAB, ROS and Webots execution is through independent host processes, with project-provided isolation scripts. No user's MATLAB desktop, browser or desktop display is connected. No installation, push or PR is performed. Shell snapshot / logging helpers are new in this clone's build/independent-audit-01. Reproduction only updates generated files in the new clone as the manual requests; the source worktree's code is not changed.

The parent reported concurrent acceptance-only repairs after this full run started. This run remains fixed to a4676cd; no patches are imported into the running clone. Later targets, if any, need separate identification and must not be called a full a4676cd reproduction.

GUI drag-and-drop has not been performed. Manual model construction uses Stateflow/Simulink APIs from blank new models, and explicit deletion to zero states before hierarchical reconstruction in the prescribed independent replay shell. API construction is recorded separately from the repository's generated-model regression.
