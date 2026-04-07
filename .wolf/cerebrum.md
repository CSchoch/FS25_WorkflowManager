# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-04-05

## User Preferences

<!-- How the user likes things done. Code style, tools, patterns, communication. -->

## Key Learnings

- **Project:** FS25_WorkflowManager

## Do-Not-Repeat

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->

[2026-04-07] Support idle poll must check if main step CHANGED, not just if it has sub-steps. The poll for `waitingForMainStep` ran every update cycle and would immediately restart support on the same main step because it didn't track which step triggered the idle. Fix: use `waitingForMainStepIndex` to record which step was active when idle was entered; only resume when `mainActiveData.currentStep ~= waitingForMainStepIndex`.

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->
