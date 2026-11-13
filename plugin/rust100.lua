if vim.g.loaded_rust100 then
  return
end
vim.g.loaded_rust100 = true

vim.api.nvim_create_user_command("Rust100", function(opts)
  require("rust100").command(opts.fargs)
end, {
  nargs = "*",
  complete = function(arglead)
    return require("rust100").complete(arglead)
  end,
  desc = "Study the 100 Exercises to Learn Rust course",
})
