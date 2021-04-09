# Noteflow

> Note: Beta-level software that frequently changes. Feel free to create feature requests.
> Commands probably won't change, but backing up or putting your notes under source control before using is highly recommended.

Noteflow is a Neovim plugin written in Lua that aims to minimize amount of
work needed to take notes and maintain a personal knowledge base of
markdown notes. It provides multiple commands to ease repetitive and arduous
tasks. By mapping those commands, you should be able to seamlessly manage
your Vault (a folder with notes) using only a few keystrokes. Additionally, Noteflow exposes hooks to easily customize it programatically.

Noteflow is, however, fairly opinionated when it comes to the structure
of a note. It makes the following assumptions:

- metadata is kept in a frontmatter. Frontmatter is a section of a note
that is separated by a triple-dash line "---". Its content is in yaml format. For example:

```yaml
---
title: Foobar
created: 2021-12-12T12:12:12
tags: [programming]
---
```

- title of a note is either in the frontmatter or the first H1 header
- tags are preferably stored in the frontmatter, but they can also be read from the
body of a note in the following format: #&lt;tag&gt;
- notes reference each other via `[[wikilinks]]`. A wikilink contains a note title and optional description. That means note titles must be unique

Noteflow also tries to be compatible with other plain note-taking apps like
[obsidian.md[(https://obsidian.md), [GitJournal](https://gitjournal.io/) and
[vscode-markdown-notes](https://github.com/kortina/vscode-markdown-notes).

This plugin does not provide environment to work with markdown files, like syntax,
highlighting etc. You should use it alongside a Markdown plugin. I recommend
[vim-markdown](https://github.com/plasticboy/vim-markdown).

Best used under source control.

## Features

You can see some of the features in action in this cast:

[![asciicast](https://asciinema.org/a/405771.svg)](https://asciinema.org/a/405771)

- Powered, mainly, by the amazing [Telescope](https://github.com/nvim-telescope/telescope.nvim)
- Fuzzy searching by title and tags
- Searching by content (live grep)
- Only plain text files - you own the data
- Create note based on a title and a template
- Create note by following a wikilink
- Jump to the target note by following a wikilink, even if it's in another directory in a Vault
- Rename a note and all its references in a Vault with a single command
- Quickly add and remove tags
- Update `modified` attribute in the frontmatter on save
- Add hooks to personalize your experience
- Make a daily note once per day
- Quickly change a word into a reference (wikilink with a description)
- Limited additional markdown support (wikilink highlighting etc.)
- Autocompletion based on omnifunc

## Requirements

- [neovim](https://github.com/neovim/neovim/releases) 0.5.0+
- [fzf](https://github.com/junegunn/fzf)
- [ripgrep](https://github.com/BurntSushi/ripgrep)

## Try it out!

Before jumping in to install and configure, you can test drive this plugin
using preconfigured minimal setup. All you have to do is clone this repo and
run `make demo` ! You need to have requirements installed, though.

```bash
git clone https://github.com/mnowotnik/noteflow.nvim.git
make demo
```

Commands start with Noteflow prefix.
Mappings are as in [Configuration](#configuration).

## Installation

By using a plugin manager:

- packer
```lua
    use 'mnowotnik/noteflow.nvim'
    use 'nvim-lua/plenary.nvim'
    use 'nvim-telescope/telescope.nvim'
    use 'nvim-lua/popup.nvim'
```

- vim-plug
```viml
    Plug 'mnowotnik/noteflow.nvim'
    Plug 'nvim-lua/plenary.nvim'
    Plug 'nvim-telescope/telescope.nvim'
    Plug 'nvim-lua/popup.nvim'
```


## Configuration

In your neovim lua configuration files add:

```lua
 -- turn on experimental markdown extension
 -- currently compatible with vim-markdown
vim.g.noteflow_extended_markdown = 1

require('noteflow').setup({
    vault_dir = "~/Notes", -- nuff said

    -- relative to vault_dir or absolute
    -- "Templates" is default value
    templates_dir = "Templates",

    -- relative to vault_dir
    -- "Daily" is default value
    daily_dir = "Daily",

    -- optional hook to make note filename
    make_note_slug = function(title) return title end,

    -- optional hook to make daily note filename
    make_daily_slug = function(title) return title end,
})
```

Proposed mappings:

```viml
nn <leader>nd :NoteflowDaily<cr>
nn <leader>nf :NoteflowFind<cr>
nn <leader>ne :NoteflowEditTags<cr>
nn <leader>nt :NoteflowTags<cr>
nn <leader>ng :NoteflowGrep<cr>
nn <leader>ns :NoteflowStagedGrep<cr>
nn <leader>nl :NoteflowInsertLink<cr>
```

In `ftplugin/noteflow.vim` file add:

```viml
set omnifunc=v:lua.noteflow_omnifunc
nn <C-]> lua require('noteflow').follow_wikilink
```

To enable omnicompletion for wikilinks and tags in Telescope prompt and to use
Ctrl-] to jump to a linked note.

## Vault structure

You can either keep every note in a single directory, in many small ones or a
few big ones, depending on how many groups you want to split your notes into.

After you've configured Noteflow, you have to create your Vault.
In the folder pointed to by `vault_dir`, you can create these example directories:

```shell
├── Daily # for daily notes
├── Bar # a user category
├── Foo # a user category
└── Templates # stores user templates
```

## Development

Download dependencies and run the full test suite.

`make test`

Run a single [plenary](https://github.com/nvim-lua/plenary.nvim) specification:

`make testfile=tests/plenary/follow_link_spec.lua testfile`

## Notice

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
