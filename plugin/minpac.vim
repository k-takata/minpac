" ---------------------------------------------------------------------
" minpac: A minimal package manager for Vim 8
"
" Maintainer:	Ken Takata
" Last Change:  2017-02-02
" License:      VIM License
" URL:          https://github.com/k-takata/minpac
" ---------------------------------------------------------------------

if exists('g:loaded_minpac')
  finish
endif
let g:loaded_minpac = 1


" Get a list of package/plugin directories.
function! minpac#getpackages(...)
  return minpac#impl#getpackages(a:000)
endfunction


" Initialize minpac.
function! minpac#init(...) abort
  let l:opt = get(a:000, 0, {})

  let g:minpac#opt = {}
  let g:minpac#opt.gitcmd = get(l:opt, 'git', 'git')
  let g:minpac#opt.package_name = get(l:opt, 'package_name', 'minpac')
  let g:minpac#opt.depth = get(l:opt, 'depth', 1)
  let g:minpac#opt.jobs = get(l:opt, 'jobs', 8)

  let g:minpac#pluglist = {}

  let l:packdir = get(l:opt, 'dir', '')
  if l:packdir == ''
    " If 'dir' is not specified, the first directory of 'packpath' is used.
    let l:packdir = split(&packpath, ',')[0]
  endif
  let g:minpac#opt.minpac_dir = l:packdir . '/pack/' . g:minpac#opt.package_name
  let g:minpac#opt.minpac_start_dir = g:minpac#opt.minpac_dir . '/start'
  let g:minpac#opt.minpac_opt_dir = g:minpac#opt.minpac_dir . '/opt'
  if !isdirectory(l:packdir)
    echoerr 'Pack directory not available: ' . l:packdir
    return
  endif
  if !isdirectory(g:minpac#opt.minpac_start_dir)
    call mkdir(g:minpac#opt.minpac_start_dir, 'p')
  endif
  if !isdirectory(g:minpac#opt.minpac_opt_dir)
    call mkdir(g:minpac#opt.minpac_opt_dir, 'p')
  endif
endfunction


" Register the specified plugin.
function! minpac#add(plugname, ...) abort
  let l:opt = get(a:000, 0, {})

  " URL
  if a:plugname =~# '^https?://'
    let l:url = a:plugname
  else
    let l:url = 'https://github.com/' . a:plugname . '.git'
  endif

  " Name of the plugin
  if l:url =~# '\.git$'
    let l:name = matchstr(l:url, '.*/\zs[^/]\+\ze\.git$')
  else
    let l:name = matchstr(l:url, '.*/\zs[^/]\+$')
  endif
  let l:name = get(l:opt, 'name', l:name)
  if l:name == ''
    echoerr 'Cannot specify the plugin name.'
    return
  endif

  " Loading type: 'start' or 'opt'
  let l:type = get(l:opt, 'type', 'start')
  if l:type !=# 'start' && l:type !=# 'opt'
    echoerr "Wrong type (must be 'start' or 'opt'): " . l:type
    return
  endif

  " Local directory
  if l:type ==# 'start'
    let l:dir = g:minpac#opt.minpac_start_dir . '/' . l:name
  else
    let l:dir = g:minpac#opt.minpac_opt_dir . '/' . l:name
  endif

  " Frozen
  let l:frozen = get(l:opt, 'frozen', 0)

  " Clone depth
  let l:depth = get(l:opt, 'depth', g:minpac#opt.depth)

  " Branch
  let l:branch = get(l:opt, 'branch', '')

  " Add to pluglist
  let g:minpac#pluglist[l:name] = {'url': l:url, 'type': l:type, 'dir': l:dir,
        \ 'depth': l:depth, 'frozen': l:frozen, 'branch': l:branch}
endfunction


" Update all or specified plugin(s).
function! minpac#update(...)
  return minpac#impl#update(a:000)
endfunction


" Remove plugins that are not registered.
function! minpac#clean(...)
  return minpac#impl#clean(a:000)
endfunction


" Get information of specified plugin. Mainly for debugging.
function! minpac#getpluginfo(name)
  return g:minpac#pluglist[a:name]
endfunction


" Get a list of plugin information. Only for internal use.
function! minpac#getpluglist()
  return g:minpac#pluglist
endfunction

" vim: set ts=8 sw=2 et:
