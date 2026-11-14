# rust-100.nvim

A Neovim companion for learning Rust with Mainmatter's *100 Exercises to Learn Rust* course.

The goal is to keep the study loop in Neovim: read a lesson, open its exercise, find the work left to do, run the course checks, and continue from the saved progress.

## Project status

The initial Neovim workflow is in place: course dashboard, lesson and exercise navigation, TODO quickfix, asynchronous checks, and automatic first-run setup.

## Planned workflow

- Open the course dashboard and resume the current exercise.
- Read the matching Markdown lesson inside Neovim.
- Navigate `TODO` and `todo!()` markers through the quickfix list.
- Run the official workshop runner (`wr`) without blocking the editor.
- See check results and course progress, then open the next exercise.

The plugin downloads the official course checkout when needed and installs its workshop runner in the background. Course content and exercise verification remain owned by their upstream projects.

## Requirements

- Neovim 0.10 or newer for Neovim's asynchronous `vim.system()` process API.
- Git and Rust/Cargo. The plugin clones the course and installs `wr` automatically when needed.
- `rust-analyzer` is recommended for Rust diagnostics and completion, but the plugin will not install or configure it.

## Setup

With `lazy.nvim`, add this spec to `lua/plugins/rust100.lua` (or the equivalent file in your plugin-spec directory):

```lua
return {
  "JDTWOR/rust-100.nvim",
  lazy = false,
  opts = { auto_setup = true, auto_check = true },
  config = function(_, opts)
    require("rust100").setup(opts)
  end,
}
```

On the first `:Rust100` command, the plugin searches the current buffer and working directory for a course checkout. If none is found, it clones the official repository to `stdpath("data")/rust100/course`. It installs `wr` into `stdpath("data")/rust100/toolchain` in the background using Cargo. Set `course_root` to choose a different checkout location. Set `auto_setup = false` to disable downloads and installation.

Opening an exercise shows the Rust source at full width and places the cursor on its first code placeholder. The winbar lists the exercise status and shortcuts. Press `<leader>rl` to read the lesson in a wrapped reading view, then `q` to return to the code. Saving the exercise runs its check automatically after a short debounce; the default `auto_check_delay` is 700 milliseconds. A passing result marks the exercise solved and waits for you to move on with `<leader>rn`. Set `auto_check = false` to run checks manually with `<leader>rr` or `:Rust100 check`.

## Commands

| Command | Action |
| --- | --- |
| `:Rust100` | Open the course dashboard |
| `:Rust100 open [index]` | Open the exercise code at full width |
| `:Rust100 lesson [index]` | Open a lesson |
| `:Rust100 check` | Verify the current exercise now |
| `:Rust100 next` | Open the next exercise |
| `:Rust100 todos` | Add `TODO` and `todo!()` markers to quickfix |
| `:Rust100 health` | Show tool and course availability |

Exercise indexes follow the order in the course's `book/src/SUMMARY.md` and start at 1. The dashboard lets you browse with `j`/`k`, open with `Enter`, read the lesson with `l`, verify with `r`, and close with `q`. In an exercise, `<leader>rp` and `<leader>rn` move backward and forward. `<leader>rl` reads the lesson, `<leader>rr` checks now, `<leader>rt` opens TODO quickfix, and `<leader>rm` returns to the course map. By default, saving the exercise runs the same check automatically; a passing result marks it solved and waits for `<leader>rn`.

The plugin stores its dashboard cursor and checkmarks under `stdpath("state")/rust100/`. Exercises checked through the plugin also update `wr`'s official progress database. If `wr` is used directly for other exercises, the dashboard's local checkmarks do not automatically sync with that database.

## Upstream projects

- Course: <https://github.com/mainmatter/100-exercises-to-learn-rust>
- Course website: <https://rust-exercises.com/100-exercises/>
- Workshop runner: <https://github.com/mainmatter/rust-workshop-runner>

The course repository states that its material is released under CC BY-NC 4.0. The plugin uses the upstream checkout and retains its attribution. The license for this plugin's own code is still to be decided.

## Work plan

See [docs/WORK_PLAN.md](docs/WORK_PLAN.md) for phases, the first milestone, acceptance criteria, and open decisions.
