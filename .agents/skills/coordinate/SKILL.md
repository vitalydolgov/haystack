---
name: coordinate
description: >
  Coordinate development of a task. Use when the user asks to coordinate
  a task or runs /coordinate.
---

# Coordinate development

You are the lead of an engineering team of agents. Decompose an assigned task, delegate the work, and review what was done.

## Instructions

### 1. Decide the type

Classify the work as one type. Use the type the user named. Otherwise decide from the provided context.

- A feature adds a concrete concept.
- A bugfix corrects what is broken.
- A refactor keeps the behavior and changes the structure.

### 2. Create the branch

Create a branch at the current commit. Take its name from the current detached worktree. Check out that branch.

Leave existing dirty and untracked files unstaged.

### 3. Prepare the worktree

Copy these ignored files from the original directory into this worktree when they exist. Keep each file at the same relative path. Creating the worktree leaves them out.

- `.env`
- `project.local.yml`

### 4. Investigate the codebase

Read the repo for the assigned task.

Ask the user to clarify anything the provided context does not make clear. Settle that before you write the plan.

### 5. Make the plan

Write the plan before you delegate. Name each layer that changes, one task for that layer, and a separate task for each layer whose tests change.

#### 5a. Choose the layers

| Layer | Directory |
| --- | --- |
| domain | `Haystack/Domain/` |
| application | `Haystack/Application/` |
| infrastructure | `Haystack/Infrastructure/` |
| presentation | `Haystack/Presentation/` |

Read the repo and decide which of these layers the assigned task changes, and which files in them change. Leave out a layer that has no file changes.

#### 5b. Split the work

Write one task for each layer that changes. Name the layer, the files, and the change in that layer.

#### 5c. Split out tests

Read `HaystackTests/` and decide which test files the assigned task changes. Write a separate task for each layer whose tests change. Name the files and the change. Leave out a layer that has no test changes.

### 6. Build the dependency graph

A task depends on an earlier task when it needs a type, method, protocol, or file that the earlier task adds or changes. When two tasks edit the same file, the task that introduces the change runs first. A test task waits for the code task of its layer.

Tasks that do not depend on each other form one wave. Start a wave only after every task it depends on has committed on the branch.

### 7. Spawn the agents

Spawn a wave, review its commits, then start the next wave.

#### 7a. Spawn the wave

Spawn every task in the current wave together, without a worktree. Each agent commits on the branch from step 2.

The spawned agent does not see this conversation. Give it the branch name, the type from step 1, and that one task. Tell it to stage only the files this task changed, commit them on that branch, and report the commit SHA. Tell it that its commit must compile, and that when that commit changes tests those tests must pass.

Wait until each agent has committed on the branch.

#### 7b. Review

Review each agent's commit once it is on the branch, before the next wave.

- Confirm the commit is on the branch.
- Confirm the changes are the assigned task.
- Compile the code and confirm it succeeds.
- When that commit changes tests, run those tests and confirm they pass.

Then spawn the next wave.

## Boundary

- Do not edit the code. The spawned agent does that work.
- Do not commit. The spawned agent commits its task.
- Do not merge the branch.
