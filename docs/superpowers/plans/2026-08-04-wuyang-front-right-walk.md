# Wuyang Front-Right Walk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and validate one eight-frame HD front-right walk loop for Wuyang without integrating it into Godot.

**Architecture:** Reuse the approved first idle frame as the identity, direction, canvas, and anchor reference. Run one Meowa `animate-run` task, then validate only the sanitized final outputs.

**Tech Stack:** Meowa game-assets CLI, PowerShell, local media inspection

---

### Task 1: Generate The Trial

**Files:**
- Read: `.superpowers/generated/wuyang-idle-iso-front-right-20260804/*/validation_frames/frame_01.png`
- Create: `.superpowers/generated/wuyang-walk-iso-front-right-20260804/`

- [ ] **Step 1: Confirm the source exists and check credits**

Run `python .agents/skills/game-assets/meowart_api.py credits-balance` and verify the approved source PNG exists.

- [ ] **Step 2: Generate one animation**

Run `animate-run` with the approved frame, prompt `The character runs toward the front-right in a guarded dual-dagger stance, with a restrained stride and a seamless loop; locked camera`, `--output-frames 8`, `--output-format webp`, `--animation-type walk`, and `--remove-bg-method advanced`.

- [ ] **Step 3: Validate deliverables**

Read `final_outputs.json`; inspect every listed file; confirm format, dimensions, alpha, eight frames, loop continuity, stable identity, fixed camera, and stable foot anchor.

- [ ] **Step 4: Check credits and report**

Run `credits-balance` again, report the exact credit delta, and show the approved media. Do not copy it into `assets/` or modify Godot scenes.
