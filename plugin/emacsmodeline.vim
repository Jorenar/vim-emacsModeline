" EmacsModeline.vim
" -*- mode: vim; tab-width: 2; indent-tabs-mode: nil; fill-column: 80 -*-
" Author: Chris Pickel <sfiera@gmail.com>
" Maintainer: Jorengarenar <dev@jorenar.com>
" License: Vim

if exists('g:loaded_emacsmodeline') | finish | endif
let s:cpo_save = &cpo | set cpo&vim

" Note: Entries to emacsModeDict must be lowercase. E. g. 'makefile' instead of 'Makefile'.
let s:emacsModeDictDefault = {
      \   'c++':          'cpp',
      \   'shell-script': 'sh',
      \   'makefile':     'make',
      \   'js':           'javascript',
      \   'protobuf':     'proto',
      \ }

if (!exists('g:emacsModeDict'))
  let g:emacsModeDict = {}
endif

" Add all default entries to the mode dict, keeping any user-defined entries
call extend(g:emacsModeDict, s:emacsModeDictDefault, 'keep')

function! s:FindParameterValue(modeline, emacs_name, value)
  let pattern = '\c' . '\(^\|.*;\)\s*' . a:emacs_name . ':\s*\(' . a:value . '\)\s*\($\|;.*\)'
  if a:modeline =~ pattern
    return substitute(a:modeline, pattern, '\2', '')
  endif
  return ''
endfunc

function! s:SetVimModeOption(modeline)
  let value = s:FindParameterValue(a:modeline, 'mode', '[A-Za-z_+-]\+')
  if strlen(value)
    let value = tolower(value)
    if (has_key(g:emacsModeDict, value))
      let value = g:emacsModeDict[value]
    endif
    exec 'setf' value
  endif
endfunc

function! s:SetVimNumberOption(modeline, emacs_name, vim_name)
  let value = s:FindParameterValue(a:modeline, a:emacs_name, '\d\+')
  if strlen(value)
    exec 'setlocal ' . a:vim_name . '=' . value
    return 1
  endif
  return 0
endfunc

function! s:SetVimStringOption(modeline, emacs_name, vim_name, validate_pattern)
  let value = s:FindParameterValue(a:modeline, a:emacs_name, a:validate_pattern)
  if strlen(value)
    exec 'setlocal ' . a:vim_name . '=' . value
    return 1
  endif
  return 0
endfunc

function! s:SetVimToggleOption(modeline, emacs_name, vim_name, nil_value)
  let value = s:FindParameterValue(a:modeline, a:emacs_name, '[^;[:space:]]\+')
  if strlen(value)
    if (value ==# 'nil') == a:nil_value
      exec 'setlocal ' . a:vim_name
    else
      exec 'setlocal no' . a:vim_name
    end
  endif
endfunc

function! s:ParseEmacsOption(modeline)

  call s:SetVimModeOption(a:modeline)

  call s:SetVimNumberOption(a:modeline, 'fill-column',        'textwidth')
  if s:SetVimNumberOption(a:modeline,   'tab-width',          'tabstop')
    " - When shiftwidth is zero, the 'tabstop' value is used.
    "   Use the shiftwidth() function to get the effective shiftwidth value.
    " - When 'sts' is negative, the value of 'shiftwidth' is used.
    setlocal shiftwidth=0
    setlocal softtabstop=-1
  endif
  call s:SetVimNumberOption(a:modeline, 'c-basic-offset',     'softtabstop')
  call s:SetVimNumberOption(a:modeline, 'c-basic-offset',     'shiftwidth')

  call s:SetVimToggleOption(a:modeline, 'buffer-read-only',   'readonly',     0)
  call s:SetVimToggleOption(a:modeline, 'indent-tabs-mode',   'expandtab',    1)
  call s:SetVimStringOption(a:modeline, 'coding',             'fileencoding', '[\w\-]\+')

  let value = substitute(a:modeline, '^ *\([^ ]*\) *$', '\L\1', '')
  if (has_key(g:emacsModeDict, value))
    exec 'setf' g:emacsModeDict[value]
  endif

  " Other emacs options seen in the wild include:
  "  * c-file-style: no vim equivalent (?).
  "  * compile-command: probably equivalent to &makeprg.  However, vim will refuse to
  "    set it from a modeline, as a security risk, and we follow that decision here.
  "  * mmm-classes: appears to be for other languages inline in HTML, e.g. PHP.
  "  * package: equal to mode, in the one place I've seen it.
  "  * syntax: equal to mode, in the one place I've seen it.
endfunc

function! ParseEmacsModeLine()
  " Prepare to scan the first 2 lines.
  let lines = range(1, 2)

  let pattern = '.*-\*-\(.*\)-\*-.*'
  for n in lines
    let line = getline(n)
    if line =~ pattern
      let modeline = substitute(line, pattern, '\1', '')
      call s:ParseEmacsOption(modeline)
    endif
  endfor

  " Prepare to scan the last 3000 characters' worth of lines.
  let trylastline = line('$')
  let bname = bufname('')
  let fsize = getfsize(bname)
  if fsize > 3000
    let tryfirstline = byte2line(fsize-3000)
  else
    let tryfirstline = 1
  endif

  " Find the last line in the file that has 'Local Variables:' in it,
  " to try and be reasonably sure we aren't hitting another use of
  " that string. Use the comments around that string to filter out
  " all but the option name and value, as emacs purportedly does.
  let firstline=-1
  let lastline=-1
  let lines = range(trylastline, tryfirstline, -1)
  let pattern = '^\(.*\)[ \t]*Local [vV]ariables:[ \t]*\(.*\)$'
  for n in lines
    let line = getline(n)
    if line =~# 'End:'
      let lastline = n - 1
    elseif line =~ pattern
      let firstline = n + 1
      let cstart = substitute(line, pattern, '\1', '')
      let cend = substitute(line, pattern, '\2', '')
      break
    endif
  endfor

  " Now actually parse the lines we've found.
  if firstline != -1 && lastline > firstline
    let lines = range(firstline, lastline)
    for n in lines
      let modeline = getline(n)
      let modeline = substitute(modeline, '^'.cstart, '', '')
      let modeline = substitute(modeline, cend.'$', '', '')
      call s:ParseEmacsOption(modeline)
    endfor
  endif
endfunc

augroup EMACSMODELINE
  autocmd!
  autocmd BufReadPost * :call ParseEmacsModeLine()
augroup END

let g:loaded_emacsmodeline = 1
let &cpo = s:cpo_save | unlet s:cpo_save
