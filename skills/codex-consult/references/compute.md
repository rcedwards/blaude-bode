# Parallel Work And Resources

## Parallel work

Before running agents concurrently, compare the active tasks' declared `files` and their shared
resources:

- Disjoint file lists may run concurrently in the same repository, as long as no tool mutates a
  shared generated file.
- Overlapping paths or shared contracts require sequential handoff or separate worktrees.
- Shared build outputs, databases, ports, GPUs, caches, and evidence paths count as conflicts too.
  File-level disjointness is not sufficient on its own.

Review a committed SHA when possible. For an uncommitted target, reserve that task's `files` and its
shared resources until the review ends. Disjoint work may continue; otherwise use a separate worktree
or a committed snapshot.

## Worktrees

File overlap is a reason to isolate, not a reason to refuse the work:

```bash
git worktree add ../<repo>-codex-impl-01 -b codex-impl-01
git worktree list
```

Do not integrate or remove a worktree until its execution has stopped, its handoff is saved, and you
have inspected the diff. After accepting isolated work, integrate its commits into the target,
inspect the resulting diff, and re-run the affected acceptance checks **there**. A check that passed
in the worktree has not been observed against the integrated state. Mark the task complete and remove
the worktree only after the target checks pass.

## Resource gating

Before expensive local tests or research workloads, inspect only the processes, compute, memory,
disk, ports, or services the task actually depends on. For NVIDIA GPU workloads:

```bash
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader
nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader
```

Record a decision when resource state changes execution timing, isolation, or acceptance.
