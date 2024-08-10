" EmacsModeline.vim
" -*- mode: vim; tab-width: 2; indent-tabs-mode: nil; fill-column: 90 -*-
" Author: Jorengarenar <dev@jorenar.com>
" License: Vim

if exists('g:loaded_emacsModeline') | finish | endif
let s:cpo_save = &cpo | set cpo&vim

let g:emacsModeline_mode2filetype = get(g:, 'emacsModeline_mode2filetype', {})
call extend(g:emacsModeline_mode2filetype,
      \ {
      \   'c++':          'cpp',
      \   'js':           'javascript',
      \   'makefile':     'make',
      \   'protobuf':     'proto',
      \   'shell-script': 'sh',
      \ },
      \ 'keep')
call map(copy(g:emacsModeline_mode2filetype),
      \  {k -> extend(g:emacsModeline_mode2filetype,
      \               { tolower(k): tolower(g:emacsModeline_mode2filetype->remove(k)) }) }
      \ )


" Other Emacs options seen in the wild include:
"  - *-file-style: formatting style (&formatprg, &cinoptions etc. in Vim)
"  - compile-command: setting &makeprg in modelines is disabled
"  - default-directory: changing PWD, similar options in Vim disabled for modelines
"  - lexical-binding: seems specific to Emacs Lisp dialect
"  - package: it does specify something, but rather noting with Vim equivalent
"  - syntax: seems similar in purpose to vars like `g:asmsyntax`, `g:is_posix` etc.

let s:opts_map = {
      \   'basic-offset':     [ 'softtabstop', 'shiftwidth' ],
      \   'buffer-read-only': [ 'readonly' ],
      \   'coding':           [ 'fileencoding' ],
      \   'encoding':         [ 'fileencoding' ],
      \   'fill-column':      [ 'textwidth' ],
      \   'indent-tabs-mode': [ 'expandtab' ],
      \   'tab-width':        [ 'tabstop' ],
      \ }

let s:opts_map_regex = {
      \   '.*-basic-offset':  [ 'softtabstop', 'shiftwidth' ],
      \   '.*-indent-level':  [],
      \   '.*-indentation':   [],
      \ }

let s:opt_nils = {
      \   'textwidth': 0,
      \   'expandtab': 1,
      \ }

let s:opt_ts = {
      \   'expandtab': 0,
      \ }


function! s:setVimOpt(opt, val)
  if a:val ==# 't'
    try
      exec 'let' '&l:'.a:opt '=' 's:opt_ts[a:opt]'
    catch /E716: Key not present in Dictionary:/
      exec 'setl '.a:opt
    endtry
  elseif a:val ==# 'nil'
    try
      exec 'let' '&l:'.a:opt '=' 's:opt_nils[a:opt]'
    catch /E716: Key not present in Dictionary:/
      try
        exec 'setl' ('no'.a:opt)
      catch /E474: Invalid argument: no/
        try
          exec 'setl' (a:opt.'=')
        catch /E521: Number required after =/
          try
            exec 'setl' (a:opt.'=0')
          catch /E487: Argument must be positive:/
            " TODO: warning
            exec 'setl' (a:opt.'&')
          endtry
        endtry
      endtry
    endtry
  else
    exec 'let' ('&l:'.a:opt) '=' 'a:val'
  endif
endfunction

function! s:setEmacsOpt(emacs_opt, val)
  let l:options = []
  if has_key(s:opts_map, a:emacs_opt)
    let l:options = s:opts_map[a:emacs_opt]
  else
    let l:key = keys(s:opts_map_regex)->filter('a:emacs_opt =~# v:val')
    if empty(l:key) | return | endif
    let l:options = s:opts_map_regex[l:key[0]]
  endif

  for l:opt in l:options
    if l:opt == '!'
      " TODO: error msg
      continue
    endif
    call s:setVimOpt(l:opt, a:val)
  endfor
endfunction

function! s:parseOptionsInLine(line) abort
  if a:line !~ '[:;]'
    return { 'mode': trim(a:line) }
  endif

  let l:options = {}

  for l:v in a:line->split(';')
    let l:opt = l:v->split(':')->map('trim(v:val)')
    let l:key = tolower(l:opt[0])
    let l:options[key] = l:opt[1]
  endfor

  return l:options
endfunction

function! s:parseFirstLines() abort
  let l:options = {}
  for n in range(1, 2)
    let line = getline(n)
    if line =~ '.*-\*-\(.*\)-\*-.*'
      let l:line = l:line
            \ ->substitute('\M^\.\{-}-*-', '', '')
            \ ->substitute('\M-*-\.\{-}$', '', '')
      call extend(l:options, s:parseOptionsInLine(l:line))
    endif
  endfor
  return l:options
endfunction

function! s:parseLocalVariables() abort
  let l:fsize = bufname('')->getfsize()
  let l:start_min = (l:fsize > 3000) ? byte2line(l:fsize-3000) : 1

  call cursor('$', 999)
  let l:end = search('End:', 'b', l:start_min)
  if l:end == 0 | return {} | endif

  call cursor(l:end, 999)
  let l:pattern = '\v^(\A*)\s*Local [Vv]ariables:\s*(\A*)$'
  let l:start = search(l:pattern, 'b', l:start_min)
  if l:start == 0 | return {} | endif

  let l:firstline = getline(l:start)
  let l:cstart = substitute(l:firstline, l:pattern, '\1', '')
  let l:cend = substitute(l:firstline, l:pattern, '\2', '')

  let [ l:start, l:end ] += [ 1, -1 ]
  if l:start > l:end | return {} | endif

  let l:options = {}
  for l:line in getline(l:start, l:end)
    let l:line = l:line
          \ ->substitute('\V\^'.l:cstart, '', '')
          \ ->substitute('\V'.l:cend.'\$', '', '')
    call extend(l:options, s:parseOptionsInLine(l:line))
  endfor
  return l:options
endfunction

function! ParseEmacsModelines()
  let l:pos = getcurpos()

  let l:options = {}
  call extend(l:options, s:parseFirstLines())
  call extend(l:options, s:parseLocalVariables())

  call setpos('.', l:pos)

  if has_key(l:options, 'mode')
    let l:ft = {m -> get(g:emacsModeline_mode2filetype, m, m)}(tolower(l:options.mode))
    if empty(&ft)
      exec 'setf' l:ft
    elseif l:ft != &ft
      exec 'set' 'filetype='.l:ft
    endif
    call remove(l:options, 'mode')
  endif

  if has_key(l:options, 'tab-width')
    call s:setEmacsOpt('tab-width', l:options['tab-width'])
    setl shiftwidth=0 softtabstop=-1
    call remove(l:options, 'tab-width')
  endif

  for [l:opt,l:val] in items(l:options)
    call s:setEmacsOpt(l:opt, l:val)
  endfor
endfunction

augroup EMACSMODELINE
  autocmd!
  autocmd BufReadPost * if &modeline | call ParseEmacsModelines() | endif
augroup END

let g:loaded_emacsModeline = 1
let &cpo = s:cpo_save | unlet s:cpo_save
