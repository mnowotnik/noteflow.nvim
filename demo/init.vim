" minimal setup
set rtp+=$PWD
set rtp+=$PWD/deps/plenary.nvim
set rtp+=$PWD/deps/telescope.nvim
set rtp+=$PWD/deps/popup.nvim
runtime plugin/plenary.vim
runtime plugin/telescope.vim
runtime plugin/noteflow.vim
colorscheme desert
set hidden
set completeopt=menuone,noinsert,noselect
set shortmess+=c
set noswapfile
set termguicolors
let g:mapleader=','

lua << EOF

require('noteflow'):setup({
  vault_dir = require('os').getenv('PWD') .. '/demo',
  on_open = function(bufnr)
    vim.api.nvim_exec([=[
      setl omnifunc=v:lua.noteflow_omnifunc
      nn <buffer> <silent> <C-]> :lua require('noteflow').follow_wikilink()<cr>
    ]=], false)
  end
})

-- example Telescope configuration
require('telescope').setup {
  defaults = {
    prompt_prefix = ' >',

    winblend = 0,
    preview_cutoff = 120,

    layout_strategy = 'horizontal',
    layout_defaults = {
      horizontal = {
        width_padding = 0.1,
        height_padding = 0.1,
        preview_width = 0.6,
      },
      vertical = {
        width_padding = 0.05,
        height_padding = 1,
        preview_height = 0.5,
      }
    },

    selection_strategy = "reset",
    sorting_strategy = "descending",
    scroll_strategy = "cycle",
    prompt_position = "top",
    color_devicons = true,

}}
EOF

nn <leader>nd :NoteflowDaily<cr>
nn <leader>nf :NoteflowFind<cr>
nn <leader>ne :NoteflowEditTags<cr>
nn <leader>nt :NoteflowTags<cr>
nn <leader>ng :NoteflowGrep<cr>
nn <leader>ns :NoteflowStagedGrep<cr>
nn <leader>nl :NoteflowInsertLink<cr>
" nn <leader>nn :NoteflowNew<cr>
