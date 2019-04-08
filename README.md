# Hot Fuzz

vim-hotfuzz is a small, fast fuzzy-finding plugin for vim.

Its speed relies entirely on [fd](https://github.com/sharkdp/fd), which must be installed separately - see the `fd` [installation instructions](https://github.com/sharkdp/fd#installation).
If `fd` is not installed, vim-hotfuzz falls back to using vim's `globpath()`, which works on small codebases but will quickly deteriorate as the number of files and subdirectories increases.

## Usage

Usage revolves around the primary command `:HotFuzz`.
This command accepts filename "segments", which are used as components of a fuzzy search.
Note that only filename segments are searched, not path name.

```vim
:HotFuzz fo ba    " matches foo.bar and Foobar but not foob.ar
```

Run `:HotFuzz fo ba` and hit return to go straight to the first match.
This is a quick and easy way to get around a codebase, but the real strength of vim-hotfuzz is the tab-completion (as long as `'wildmenu'` is enabled of course).
Hitting `<Tab>` (or whatever `'wildchar'` has been set to) will perform the file search and allow tabbing through the matches to select the correct file.

Matches are sorted by:

- case-sensitive match from start
- non-case-sensitive match from start
- case-sensitive match
- non-case-sensitive match
- length of entire path

This means that:

```vim
:HotFuzz Foo ba
```

will match these files, in this order:

```
a/b/Foobar
a/football
a.b.Football
a/a.foo.bar
a.foo.bar.baz
```

When `:HotFuzz` is used _without_ tab completion, the number of file matches is echoed so it is clear that the opened buffer is not the only match.

### HotFuzzToArgs

Running `:HotFuzzToArgs` after a hot fuzz search populates the local argument with the matches from the previous search, allowing navigation using the standard arg-list commands, e.g. `:next` and `:prev`.

## Limitations

As mentioned above, file segments are only matched against filenames, not paths, as this is a limitation of `fd`.
So when a codebase contains multiple files with the same name, the only way to reach a specific file is to `<Tab>` to it.
If this proves to be a problem, try some...

## Alternatives

- [fzf.vim](https://github.com/junegunn/fzf.vim): An extremely powerful and extremely extensible fuzzy-finding tool. Depends on the external [fzf](https://github.com/junegunn/fzf) tool by the same author.
- [ctrlp.vim](https://github.com/ctrlpvim/ctrlp.vim): Before `fzf` came along, `ctrlp` had the fuzzy-finding market cornered. It's a powerful tool written in pure vimscript so is still a great option for those who don't want external dependencies.
