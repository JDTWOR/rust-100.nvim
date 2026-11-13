# rust-100.nvim

A Neovim companion for learning Rust with Mainmatter's *100 Exercises to Learn Rust* course.

The goal is to keep the study loop in Neovim: read a lesson, open its exercise, find the work left to do, run the course checks, and continue from the saved progress.

## Project status

This repository currently contains the project proposal and implementation plan. The first implementation milestone is a small end-to-end slice: open a local course lesson and exercise, run the workshop check, show its result, and continue when it passes.

## Planned workflow

- Open the course dashboard and resume the current exercise.
- Read the matching Markdown lesson inside Neovim.
- Navigate `TODO` and `todo!()` markers through the quickfix list.
- Run the official workshop runner (`wr`) without blocking the editor.
- See check results and course progress, then open the next exercise.

The plugin is intended to orchestrate the existing course checkout and `wr`; course content and exercise verification remain owned by their upstream projects.

## Requirements

- Neovim 0.10 or newer for Neovim's asynchronous `vim.system()` process API.
- A local checkout of the course, with its Git metadata intact.
- Git, Rust/Cargo, and the `wr` workshop runner.
- `rust-analyzer` is recommended for Rust diagnostics and completion, but the plugin will not install or configure it.

## Upstream projects

- Course: <https://github.com/mainmatter/100-exercises-to-learn-rust>
- Course website: <https://rust-exercises.com/100-exercises/>
- Workshop runner: <https://github.com/mainmatter/rust-workshop-runner>

The course repository states that its material is released under CC BY-NC 4.0. The planned setup flow will use an upstream checkout and retain its attribution. The license for this plugin's own code is still to be decided.

## Work plan

See [docs/WORK_PLAN.md](docs/WORK_PLAN.md) for phases, the first milestone, acceptance criteria, and open decisions.
