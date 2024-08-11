EmacsModeline
=============

The goal of this plugin is to add support of Emacs' equivalent of modelines:
[File Variables](https://www.gnu.org/software/emacs/manual/html_node/emacs/File-Variables.html)

For example, the following:
```cpp
// -*- mode: C++; tab-width: 2 -*-
```
shall be interpreted like:
```cpp
// vim: ft=cpp ts=2 sw=0 sts=-1
```

---

This is a rewrite of [vim-emacsmodeline](https://github.com/sfiera/vim-emacsmodeline)
([script #3381](http://www.vim.org/scripts/script.php?script_id=3381))
by [Chris Pickel](https://github.com/sfiera), \
[patched](https://github.com/Boolean263/vim-emacsmodeline/compare/995594f63aeffb93f4112f40542c8bf8d417cc1f..f39602c94bbb83fe4b361c554ddbc1f8f1e058bd)
with support for Local Variables by [David Perry](https://github.com/Boolean263).
