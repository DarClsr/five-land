# Wuyang Cross-Slash Start Pose Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and validate one transparent HD front-right cross-slash start pose for Wuyang.

**Architecture:** Use the accepted 640×640 idle first frame as the only identity reference. Submit one HD still-image edit into an ignored output directory, then stop after media and credit validation so the user can approve the pose before animation.

**Tech Stack:** Meowa game-assets CLI, PowerShell, PNG/RGBA validation

---

### Task 1: Preflight And Generate One Candidate

**Files:**
- Read: `.superpowers/generated/wuyang-idle-iso-front-right-20260804/*/validation_frames/frame_01.png`
- Create: `.superpowers/generated/wuyang-cross-slash-start-pose-20260804/`

- [x] **Step 1: Verify the source and balance**

Run:

```powershell
$source = Get-ChildItem -Recurse -File .superpowers/generated/wuyang-idle-iso-front-right-20260804 -Filter frame_01.png | Where-Object { $_.DirectoryName -like '*validation_frames' } | Select-Object -First 1
Get-FileHash $source.FullName -Algorithm SHA256
python .agents/skills/game-assets/meowart_api.py credits-balance
```

Expected: source SHA-256 `4047BB11BA62F76B192D97E8296BD9D56B6FD72B871294A0B8B72298CB7FC03D`; balance is readable before submission.

- [x] **Step 2: Submit one HD pose edit**

Run:

```powershell
python .agents/skills/game-assets/meowart_api.py image-edit-run `
  --reference-image $source.FullName `
  --prompt "Keep this exact character, outfit, colors, face, hairstyle, and two black daggers. Change only the pose: she faces front-right in a low attack-ready stance, weight on the rear leg, front foot stepping front-right, torso twisted back, one dagger raised behind the shoulder and the other guarding low across the waist, ready to perform an inward cross slash. Keep the full body and both daggers visible with transparent motion space in front-right. No effects, motion trails, ground, shadow, text, or background." `
  --mode hd `
  --resolution 1K `
  --aspect-ratio 1:1 `
  --remove-bg-method advanced `
  --output-dir .superpowers/generated/wuyang-cross-slash-start-pose-20260804
```

Expected: one completed task directory containing `final_outputs.json` and declared final PNG media. Do not resubmit on timeout.

### Task 2: Validate And Hand Off

**Files:**
- Read: `.superpowers/generated/wuyang-cross-slash-start-pose-20260804/*/final_outputs.json`
- Read: final PNG listed by the manifest

- [x] **Step 1: Validate final media**

Read the sanitized manifest and inspect the declared PNG. Confirm a square RGBA image, transparent background and edges, stable Wuyang identity, readable dual daggers, front-right direction, full body, attack-ready silhouette, and grounded feet.

- [x] **Step 2: Check credits and report**

Run:

```powershell
python .agents/skills/game-assets/meowart_api.py credits-balance
```

Expected: report the exact before/after credit delta and show only the declared final PNG. Do not generate the 8-frame attack until the user approves this pose.

## Outcome

- Job: `job_4b316350da0e492680185425e38d8510`
- Final media: 640×640 RGBA PNG with transparent corners and readable dual daggers.
- Credits: trial credits changed from 97 to 90; permanent credits remained 600.
- Anchor check: source foot baseline is `y=606`; candidate baseline is `y=624`. If the pose is accepted, translate it upward by 18 pixels without resampling before animation.

### Task 3: Generate One Identity-Corrected R2

**Files:**
- Read: accepted idle `validation_frames/frame_01.png`
- Read: R1 `remove_bg.png`
- Create: `.superpowers/generated/wuyang-cross-slash-start-pose-r2-20260804/`

- [x] **Step 1: Verify both references and balance**

Expected hashes are `4047BB11BA62F76B192D97E8296BD9D56B6FD72B871294A0B8B72298CB7FC03D` for the identity reference and `2915118233728DA185A38F89DCD126B59F4CA13E8269CB8FF7A72B6FFA03D559` for the pose reference. Trial balance before R2 is 90.

- [x] **Step 2: Submit one two-reference edit**

```powershell
python .agents/skills/game-assets/meowart_api.py image-edit-run `
  --reference-image $identity.FullName `
  --reference-image $pose.FullName `
  --prompt "Use the first image for the exact character identity, front-right three-quarter view, outfit, proportions, and two short black daggers. Use the second image only for the low attack-ready stance and hand arrangement. Keep both blades the same short dagger length as the first image; do not turn either weapon into a sword. Full body, transparent background, no effects or motion blur." `
  --mode hd --resolution 1K --aspect-ratio 1:1 --remove-bg-method advanced `
  --output-dir .superpowers/generated/wuyang-cross-slash-start-pose-r2-20260804
```

Expected: one R2 task with one manifest-declared PNG. Do not generate R3 automatically.

- [x] **Step 3: Validate R2 and post-check balance**

Confirm dimensions, RGBA, alpha, identity, front-right direction, two short daggers, pose readability, visible bounds, foot baseline, and exact credit delta. Show only the manifest-declared R2 media for approval.

## R2 Outcome

- Job: `job_f653489a927e4ce4a95eb8650a25e468`
- Final media: 640×640 RGBA PNG; SHA-256 `B96BF530AD8F89D732C6CEBF7C5BEDD8B924087D3DF892824F0FEA55F537E794`.
- Credits: trial credits changed from 90 to 83; permanent credits remained 600.
- Anchor: candidate foot baseline is `y=612`, six pixels below the accepted `y=606` baseline.
- Review: identity and scale improved, but the lower weapon remains too long and the view remains too frontal. Do not use R2 as the production animation source without explicit user acceptance.

### Task 4: Shorten The Lower Weapon In R3

**Files:**
- Read: R2 `remove_bg.png`
- Create: `.superpowers/generated/wuyang-cross-slash-start-pose-r3-20260804/`

- [x] **Step 1: Verify R2 and balance**

R2 SHA-256 is `B96BF530AD8F89D732C6CEBF7C5BEDD8B924087D3DF892824F0FEA55F537E794`; trial balance before R3 is 83.

- [x] **Step 2: Submit one precise weapon edit**

```powershell
python .agents/skills/game-assets/meowart_api.py image-edit-run `
  --reference-image $r2.FullName `
  --prompt "Change only the lower front weapon: shorten its blade into a black dagger matching the raised dagger's blade length and style. Keep the character, face, hair, clothing, body proportions, hands, attack-ready pose, camera angle, scale, canvas, and transparency unchanged. Do not change the raised dagger." `
  --mode hd --resolution 1K --aspect-ratio 1:1 --remove-bg-method advanced `
  --output-dir .superpowers/generated/wuyang-cross-slash-start-pose-r3-20260804
```

- [x] **Step 3: Validate R3 and balance**

Inspect the manifest-declared PNG, dimensions, alpha, both weapon lengths, identity, pose, visible bounds and foot baseline. Report the exact credit delta and do not generate R4 automatically.

## R3 Outcome

- Job: `job_75d62c63dfb643958d796462cca54481`
- Final media: 640×640 RGBA PNG; SHA-256 `EF1174507A98E369EFF32D41457459556DE5F0AB89CA097526FB1440B54F196A`.
- Credits: trial credits changed from 83 to 76; permanent credits remained 600.
- Review: lower weapon now reads as a short dagger, while identity, pose and `y=612` foot baseline remain stable. Await user approval before the free six-pixel anchor correction.

## Final Start Pose

- Accepted R3 was translated upward by six pixels without resampling.
- Final path: `.superpowers/attack-start-pose-final/wuyang-cross-slash-start-pose-grounded.png`
- Final SHA-256: `626AE3DA0F8E6BC5C9BE6CD0F26807DF26DAD9984316C049DC5EF9174B79B61F`
- Validation: 640×640 RGBA, exact pixel shift confirmed, transparent bottom rows, foot baseline `y=606`, credits unchanged at 76 trial and 600 permanent.
