emacsmodeline.vim
=================

The goal of this plugin is to parser Emacs' File Variables in similar fashion
as Vim's modelines in an attempt to set the equivalent options.

For example, the following:
```cpp
// # -*- mode: C++; tab-width: 2 -*-
```
will be interpreted the same as:
```cpp
// # vim:ft=cpp:sw=2:sts=2:ts=2:
```

---

This is a fork of [emacsmodeline.vim](https://github.com/sfiera/vim-emacsmodeline)
([script #3381](http://www.vim.org/scripts/script.php?script_id=3381))
by [Chris Pickel](https://github.com/sfiera)
