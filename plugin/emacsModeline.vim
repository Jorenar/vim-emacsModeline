" EmacsModeline
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
      \   'linux-c':      'c',
      \   'makefile':     'make',
      \   'protobuf':     'proto',
      \   'shell-script': 'sh',
      \ },
      \ 'keep')
call map(copy(g:emacsModeline_mode2filetype),
      \  {k -> extend(g:emacsModeline_mode2filetype,
      \               { tolower(k): g:emacsModeline_mode2filetype->remove(k) }) }
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


function! s:setVimOpt(opt, val) abort
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

function! s:setEmacsOpt(emacs_opt, val) abort
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

function! s:listFiletypes() abort
  let l:fts = []
  let l:fts += getcompletion('', 'filetype')
  let l:fts += g:emacsModeline_mode2filetype->values()
  let l:fts += range(1, bufnr('$'))->map('getbufvar(v:val, "&ft")')->filter('!empty(v:val)')

  let l:autocmds = has('nvim') ? nvim_get_autocmds({}) : autocmd_get()
  let l:fts += l:autocmds->copy()
        \ ->filter('v:val.event == "FileType"')
        \ ->map('v:val.pattern')
  let l:fts += l:autocmds->copy()
        \ ->map(has('nvim') ? 'v:val.command' : 'v:val.cmd')
        \ ->matchstrlist('\v\C%(<setf%[iletype]\s+%(FALLBACK\s+)?|<%(ft|filetype)\=)\zs\f+')
        \ ->map('v:val.text')

  return l:fts->sort()->uniq()
endfunction

function! s:setFiletype(mode) abort
  let l:ft = {m -> g:emacsModeline_mode2filetype->get(m, m)}(tolower(a:mode))

  if getcompletion(l:ft, 'filetype')->index(l:ft) < 0
    let l:filetypes = s:listFiletypes()
    let l:idx = l:filetypes->index(l:ft, 0, v:true)
    if l:idx < 0 | return | endif
    let l:ft = l:filetypes[l:idx]
  endif

  if empty(&ft)
    exec 'setf' l:ft
  elseif l:ft != &ft
    exec 'set' 'filetype='.l:ft
  endif
endfunction

function! s:isEnabled() abort
  if !&l:modeline
    return v:false
  endif

  if get(g:, 'emacsModeline_skip_if_modeline', v:true) && &modelines > 0
    let l:lines = getline(1, &modelines) + getline(line('$')-&modelines, line('$'))
    let l:patterns = [
          \   '\v\C((^|\s)(vi|vim([<=>]?\d\d\d)?)|\s+ex):\s*(set?)@!\S',
          \   '\v\C((^|\s)(vi|vim([<=>]?\d\d\d)?)|\s+ex):\s*set?\s+\S.*:',
          \   '\v\C(^|\s)Vim([<=>]?\d\d\d)?:\s*set \S.*:',
          \ ]
    if l:patterns->map('l:lines->match(v:val)') != [ -1, -1, -1 ]
      return v:false
    endif
  endif

  return v:true
endfunction

function! s:parseEmacsModelines() abort
  let l:pos = getcurpos()

  let l:options = {}
  call extend(l:options, s:parseFirstLines())
  call extend(l:options, s:parseLocalVariables())

  call setpos('.', l:pos)

  if has_key(l:options, 'mode')
    call s:setFiletype(l:options.mode)
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
  autocmd BufReadPost * if s:isEnabled() | call s:parseEmacsModelines() | endif
augroup END

let g:loaded_emacsModeline = 1
let &cpo = s:cpo_save | unlet s:cpo_save
