---
name: explain-diff-text
description: >
  Use when the user asks for a rich explanation of a code change, diff, branch, or PR
  and wants it delivered as plain text directly in the conversation (not a saved HTML file).
  Produces an inline markdown write-up with background, intuition, a code walkthrough, and a quiz.
  Trigger on "explain this diff", "explain this PR", "walk me through this change" when the user
  wants the answer in-chat rather than a file. For a self-contained interactive HTML file instead,
  use the explain-diff-html skill.
---

# Explain Diff (Plain Text)

Please give me a rich explanation of the specified code change, written directly in
your reply as plain-text markdown. Do NOT create an HTML file or any other file;
the whole explanation lives in the conversation.

It should have these sections:

- Background: Explain the existing system relevant to this change. (You should
broadly explore surrounding code for this.) We don't know how much the reader
already knows, so include a deep background for beginners (note that it can be
skipped if the reader is already familiar), and then a more narrow background
directly relevant to the change.
- Intuition: Explain the core intuition for the code change. The focus here is to
explain the essence, not the full details. Use concrete examples with toy data.
- Code: Do a high-level walkthrough of the changes to the code. Group/order the
changes in an understandable way.
- Quiz: Come up with five questions that test the reader's knowledge of this PR.
This should be medium difficulty, difficult enough that you actually need to
understand the substance of the PR to answer them, but not gotchas. The goal is
to help the reader make sure that they've actually understood. Present the five
questions as multiple choice. Put the answer key and per-option feedback at the
very bottom under a clearly separated "Answers" heading so the reader can attempt
the questions before scrolling down.

Format:

- Output everything inline in your reply as GitHub-flavored markdown. Use markdown
headings for each section and start with a short table of contents (a bulleted list
of the section headings).
- Please write with the clarity and flow of Martin Kleppmann, making it engaging
and written in classic style. Transitions between sections should be smooth.
- For diagrams, use plain-text/ASCII sketches or markdown tables since the output
is text. Pick a small number of diagram families and reuse them throughout. Useful
kinds:
  - A very simplified sketch of the UI the user sees in the app, to explain UI changes.
  - A data-flow / component-communication sketch. Include example data in it.
- Use fenced code blocks (triple backticks) for all code and for any ASCII diagrams,
so whitespace and newlines are preserved.
- Call out key concepts, definitions, and important edge cases with a bolded
**Note:** / **Definition:** / **Edge case:** prefix so they stand out in text.
