---
name: explain-diff
description: >
  Use when the user asks to explain, summarize, or walk through a code change, diff,
  commit, branch, or pull request so they can review it faster. Trigger on "explain this
  diff", "explain this PR", "walk me through this change", "what does this branch do",
  "write up this change", or "brief me on this commit". Covers both inline text output
  and a shareable self-contained HTML file; the user picks HTML by saying "html",
  "file", or "shareable". Replaces the former explain-diff-html and explain-diff-text
  skills.
---

# Explain Diff

Write a review brief for a maintainer of this codebase. The reader knows the language,
the frameworks, and the architecture, and has not yet read this diff. Every sentence
tells them something the diff title does not.

## Steps

1. Resolve the target and read the intent first. Commit: `git show <sha>`. Branch:
   `git diff <base>...HEAD` plus `git log <base>..HEAD`. PR: `gh pr view <n> --json
   title,body,commits` then `gh pr diff <n>`. The PR body, ticket text, and commit
   messages carry the why.
2. Read the whole diff. Open surrounding code only to answer a question the diff raises:
   what a called function does, who else calls a changed symbol, what a fixture asserts.
3. Pick the format. Default is markdown inline in the reply. Produce HTML when the user
   says "html", "file", or "shareable". Include the Quiz section only when the user asks
   for a quiz.
4. Fill the template below, count the words, and cut to the budget.

## Template

**Change** (1 to 2 sentences). What the change does and why. Take the why from the ticket
or PR body. If no why is recorded, say so in one clause.

**Context** (0 to 5 bullets; leave the section out when there are none). Pre-existing facts
the diff depends on that the diff itself does not show: an invariant, a caller, a config
value, what a type means. Each bullet names the fact and a `path:line`.

**Walkthrough** (2 to 5 groups). Group by concern, not by file, and order the groups so
each builds on the last: types or data, then logic, then callers, then tests. Each group
is a bold label, one to three sentences on what changed and the design choice behind it,
and the files touched. Quote code only when the exact expression is the point, and keep
each quote under 8 lines.

**Review focus** (3 to 6 bullets). Where the reviewer should spend their time: behavior
changes for existing callers, edge cases the diff handles or skips, rollout or migration
steps, what the new tests prove and what they leave unproven. When a bullet would ask the
reviewer to confirm something a search of the repo can settle (other callers updated, a
symbol still referenced, a test exists), run the search and state the answer instead. Each
bullet ends with a `path:line`.

**Quiz** (only when requested). Five multiple-choice questions that need the substance of
the change to answer. Answers and per-option feedback go in a separate section at the end.

## Budget

| Changed lines in diff | Total words |
|---|---|
| under 300 | 200 to 350 |
| 300 to 1000 | 350 to 550 |
| over 1000 | 550 to 800 |

Hit the budget by selection, not compression. Cut a sentence when the reader could infer
it from the diff or from knowing the codebase. Keep it when it states intent, a hidden
dependency, or a risk.

## Sentence test

Each sentence does one of these:

- States intent the code does not show.
- Names a pre-existing fact the diff relies on, with a location.
- Flags a risk, gap, or thing to verify.
- Orients: which group or file to read next.

A sentence that defines a language feature, a framework API, or a general engineering
concept does none of these. Refer to types, flags, and services by the names the codebase
uses.

## Example (text mode, 59-line diff)

**Change**
Two `AdventureService` fetches passed the watch cache policy to `fetch`, which
`SupergraphClient` rejects, so trailhead search-result taps and the ski tour nearby-routes
list threw on every call (FOX-15983). This switches both to the non-watch policy and adds
the success tests that would have caught it.

**Context**
- `SupergraphClient.fetch` guards against `.returnCacheDataAndFetch` and throws
  `GraphQLError.invalidOperation`, because that policy yields two results and `fetch`
  returns one. `ONXSupergraph/SupergraphClient.swift`
- Every other `AdventureService` already declares `nonWatchCachePolicy =
  .returnCacheDataElseFetch` alongside `cachePolicy`. `SkiTourService.swift:11`

**Walkthrough**
**Policy fix.** `TrailheadService` gains the `nonWatchCachePolicy` property its seven
siblings already have. `requestTrailheadByIdentifiers` and
`SkiTourService.requestSkiTourNearbyRoutes` now pass it instead of `cachePolicy`.
`TrailheadService.swift:12,41`, `SkiTourService.swift:314`

**Tests.** Each service gets a `_success` test built on `MockResultInterceptor.success`
with `expectedCachePolicy: .returnCacheDataElseFetch`. The interceptor only sees the
policy when the request gets past the client guard, so a regression fails on the guard's
error rather than on the assertion. `TrailheadServiceTests.swift:101`,
`SkiTourServiceTests.swift:315`

**Review focus**
- The existing `_failure` tests passed on the guard's error without reaching the
  interceptor. Check no other service method has only a failure test.
  `SkiTourServiceTests.swift:342`
- `.returnCacheDataElseFetch` serves stale cache without refetching. Confirm that is
  acceptable for trailhead detail on a search tap. `ONXMapViewer+SearchResultPresenter.swift:239`
- The `Foundation` import reorder in `TrailheadService.swift:1` is formatter noise.

## HTML mode

Same content, same budget, rendered as one self-contained file with inline CSS and no
external assets.

1. Path: `/tmp/YYYY-MM-DD-explain-<slug>.html` with today's date. Run `open` on it when
   saved and give the user the path.
2. Sections in template order, with a table of contents at the top linking to each.
3. Code in `<pre><code>` blocks. Before saving, confirm every element that holds code has
   `white-space: pre` or `pre-wrap` in its CSS.
4. Render Review focus bullets as callouts.
5. Add a diagram only when the change reroutes data flow across three or more components.
   Build it from HTML elements, not ASCII.
6. Quiz, when requested: clickable multiple choice with inline right/wrong feedback in
   plain JavaScript.
