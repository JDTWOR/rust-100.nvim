# rust-100.nvim

A Neovim companion for learning Rust with Mainmatter's *100 Exercises to Learn Rust* course.

The goal is to keep the study loop in Neovim: read a lesson, open its exercise, find the work left to do, run the course checks, and continue from the saved progress.

## Project status

The initial Neovim workflow is in place: course dashboard, lesson and exercise navigation, TODO quickfix, and asynchronous `wr` checks. The workshop runner is not installed in the development environment, so an end-to-end exercise check has not been run here.

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

Install the course and workshop runner with their upstream instructions:

```sh
git clone https://github.com/mainmatter/100-exercises-to-learn-rust
cargo install --locked workshop-runner
```

## Setup

With `lazy.nvim`, add this spec to `lua/plugins/rust100.lua` (or the equivalent file in your plugin-spec directory):

```lua
return {
  "JDTWOR/rust-100.nvim",
  lazy = false,
  opts = {
    course_root = vim.fn.expand("~/src/100-exercises-to-learn-rust"),
  },
  config = function(_, opts)
    require("rust100").setup(opts)
  end,
}
```

If `course_root` is omitted, the plugin searches upward from the current buffer and working directory. The course checkout must retain its `.git` directory because `wr` uses Git to find the repository root.

## Commands

| Command | Action |
| --- | --- |
| `:Rust100` | Open the course dashboard |
| `:Rust100 open [index]` | Open an exercise and its lesson |
| `:Rust100 lesson [index]` | Open a lesson |
| `:Rust100 check` | Verify the exercise with `wr` |
| `:Rust100 next` | Open the next exercise |
| `:Rust100 todos` | Add `TODO` and `todo!()` markers to quickfix |
| `:Rust100 health` | Show tool and course availability |

Exercise indexes follow the order in the course's `book/src/SUMMARY.md` and start at 1. The dashboard also lets you browse with `j`/`k`, open with `Enter`, read the lesson with `l`, verify with `r`, and close with `q`.

The plugin stores its dashboard cursor and checkmarks under `stdpath("state")/rust100/`. Exercises checked through the plugin also update `wr`'s official progress database. If `wr` is used directly for other exercises, the dashboard's local checkmarks do not automatically sync with that database.

## Upstream projects

- Course: <https://github.com/mainmatter/100-exercises-to-learn-rust>
- Course website: <https://rust-exercises.com/100-exercises/>
- Workshop runner: <https://github.com/mainmatter/rust-workshop-runner>

The course repository states that its material is released under CC BY-NC 4.0. The planned setup flow will use an upstream checkout and retain its attribution. The license for this plugin's own code is still to be decided.

## Work plan

See [docs/WORK_PLAN.md](docs/WORK_PLAN.md) for phases, the first milestone, acceptance criteria, and open decisions.
