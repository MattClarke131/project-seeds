# Working in this repo

## PR Body Conventions
1. Use bullet-point lists when possible.
Lists are easier to read than paragraphs.

2. Give bullet-points a short, bolded summary first.
This summary should be on the order of 1-5 words.
The review process involves getting a high level understanding first, then diving into details.

## PR Body Format
1. (Required) Context Header
Start with this header.
Reiterate the problem being solved.
Be concise.

2. (Required) Changes Header
Include a bulleted list of changes.

3. (Optional) Decisions Header
Include a bulleted list of decisions made.
Each decision should have a title summary and a description underneath.

4. (Optional) Pre-Merge Verification Header
Include steps ran before merging to verify.

5. (Optional) Post-Merge Steps Header
Include an ordered list of manual steps needed to be run after merging.
Include specific commands
Use nested bullets if necessary.

6. (Optional) Post-Merge Verification Header
Include an ordered list of verification steps.
Include specific commands


## Commit and PR conventions
- **Do not include links to claude code sessions**

- **Squash-merge uses "PR title and description" as the commit message**, not
the list of intermediate commit titles. When writing a PR description, write
it as the permanent record: what changed and why.

- That said, **intermediate commits still matter**: keep messages concise but
descriptive, not "fix" or "wip". They're squashed out of `main`, but they're
still the working trail during review.
