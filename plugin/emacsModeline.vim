" EmacsModeline.vim
" -*- mode: vim; tab-width: 2; indent-tabs-mode: nil; fill-column: 80 -*-
" Author: Jorengarenar <dev@jorenar.com>
" License: Vim

if exists('g:loaded_emacsModeline') | finish | endif
let s:cpo_save = &cpo | set cpo&vim

let g:emacsMode2vimFt = get(g:, 'emacsMode2vimFt', {})
call extend(g:emacsMode2vimFt,
      \ {
      \   'c++':          'cpp',
      \   'js':           'javascript',
      \   'makefile':     'make',
      \   'protobuf':     'proto',
      \   'shell-script': 'sh',
      \ },
      \ 'keep')
call map(copy(g:emacsMode2vimFt),
      \  {k -> extend(g:emacsMode2vimFt,
      \               { tolower(k): tolower(g:emacsMode2vimFt->remove(k)) }) }
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
  let fsize = bufname('')->getfsize()
  let start_min = (fsize > 3000) ? byte2line(fsize-3000) : 1

  let pos = getcurpos()

  call cursor(line('$'), 99)
  let end = search('End:', 'b', start_min)
  if end == 0 | return {} | endif

  call cursor(end, 99)
  const pattern = '\v^(\A*)\s*Local [Vv]ariables:\s*(\A*)$'
  let start = search(pattern, 'b', start_min)
  if start == 0 | return {} | endif

  call setpos('.', pos)

  let firstline = getline(start)
  let cstart = substitute(firstline, pattern, '\1', '')
  let cend = substitute(firstline, pattern, '\2', '')

  let [ start, end ] += [ 1, -1 ]
  if end <= start | return {} | endif

  let l:options = {}
  for line in getline(start, end)
    let line = line
          \ ->substitute('\V\^'.cstart, '', '')
          \ ->substitute('\V'.cend.'\$', '', '')
    call extend(l:options, s:parseOptionsInLine(line))
  endfor
  return l:options
endfunction

function! ParseEmacsModelines()
  let l:options = {}
  call extend(l:options, s:parseFirstLines())
  call extend(l:options, s:parseLocalVariables())

  if has_key(l:options, 'mode')
    let l:ft = {m -> get(g:emacsMode2vimFt, m, m)}(tolower(l:options.mode))
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
endfunc

augroup EMACSMODELINE
  autocmd!
  autocmd BufReadPost * if &modeline | call ParseEmacsModelines() | endif
augroup END

let g:loaded_emacsModeline = 1
let &cpo = s:cpo_save | unlet s:cpo_save
