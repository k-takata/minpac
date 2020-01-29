" ---------------------------------------------------------------------
" minpac: A minimal package manager for Vim 8 (and Neovim)
"
" Maintainer:   Ken Takata
" Last Change:  2018-09-01
" License:      VIM License
" URL:          https://github.com/k-takata/minpac
" ---------------------------------------------------------------------

if exists('g:loaded_minpac')
  finish
endif
let g:loaded_minpac = 1


" Get a list of package/plugin directories.
function! minpac#getpackages(...)
  return call("minpac#impl#getpackages", a:000)
endfunction


function! s:ensure_initialization() abort
  if !exists('g:minpac#opt')
    echohl WarningMsg
    echom 'Minpac has not been initialized. Use the default values.'
    echohl None
    call minpac#init()
  endif
endfunction

" Initialize minpac.
function! minpac#init(...) abort
  let l:opt = extend(
                      \ copy(get(a:000, 0, {})),
                      \ {
                          \ 'dir': '',
                          \ 'package_name': 'minpac',
                          \ 'git': 'git',
                          \ 'depth': 1,
                          \ 'jobs': 8,
                          \ 'verbose': 2,
                          \ 'status_open': 'vertical',
                          \ 'site': 'github',
                          \ 'sites': {
                                         \ 'github': 'https://github.com/',
                                         \ 'gitlab': 'https://gitlab.com/',
                                         \ 'bitbucket': 'https://bitbucket.org/'
                                     \ }
                      \ },
                      \ 'keep'
                  \ )

  let g:minpac#opt = l:opt
  let g:minpac#pluglist = {}

  let l:packdir = l:opt.dir
  if l:packdir ==# ''
    " If 'dir' is not specified, the first directory of 'packpath' is used.
    let l:packdir = split(&packpath, ',')[0]
  endif
  let l:opt.minpac_dir = l:packdir . '/pack/' . l:opt.package_name
  let l:opt.minpac_start_dir = l:opt.minpac_dir . '/start'
  let l:opt.minpac_opt_dir = l:opt.minpac_dir . '/opt'
  if !isdirectory(l:packdir)
    echoerr 'Pack directory not available: ' . l:packdir
    return
  endif
  if !isdirectory(l:opt.minpac_start_dir)
    call mkdir(l:opt.minpac_start_dir, 'p')
  endif
  if !isdirectory(l:opt.minpac_opt_dir)
    call mkdir(l:opt.minpac_opt_dir, 'p')
  endif
endfunction


" Register the specified plugin.
function! minpac#add(plugname, ...) abort
  call s:ensure_initialization()
  let l:opt = extend(
                      \ copy(get(a:000, 0, {})),
                      \ {
                         \ 'name': '',
                         \ 'type': 'start',
                         \ 'depth': g:minpac#opt.depth,
                         \ 'frozen': 0,
                         \ 'branch': '',
                         \ 'rev': '',
                         \ 'do': '',
                         \ 'site': g:minpac#opt.site
                      \ },
                      \ 'keep'
                  \ )

  " URL
  if a:plugname =~? '^[-._0-9a-z]\+\/[-._0-9a-z]\+$'
    let l:url = g:minpac#opt.sites[l:opt.site]
    let l:opt.url = l:url . a:plugname . '.git'
  else
    let l:opt.url = a:plugname
  endif

  " Name of the plugin
  if l:opt.name ==# ''
    let l:opt.name = matchstr(l:opt.url, '[/\\]\zs[^/\\]\+$')
    let l:opt.name = substitute(l:opt.name, '\C\.git$', '', '')
  endif
  if l:opt.name ==# ''
    echoerr 'Cannot extract the plugin name. (' . a:plugname . ')'
    return
  endif

  " Loading type / Local directory
  if l:opt.type ==# 'start'
    let l:opt.dir = g:minpac#opt.minpac_start_dir . '/' . l:opt.name
  elseif l:opt.type ==# 'opt'
    let l:opt.dir = g:minpac#opt.minpac_opt_dir . '/' . l:opt.name
  else
    echoerr "Wrong type (must be 'start' or 'opt'): " . l:opt.type
    return
  endif

  " Initialize the status
  let l:opt.stat = {'errcode': 0, 'lines': [], 'prev_rev': '', 'installed': -1}

  " Add to pluglist
  let g:minpac#pluglist[l:opt.name] = l:opt
endfunction


" Update all or specified plugin(s).
function! minpac#update(...)
  call s:ensure_initialization()
  return call("minpac#impl#update", a:000)
endfunction


" Remove plugins that are not registered.
function! minpac#clean(...)
  call s:ensure_initialization()
  return call("minpac#impl#clean", a:000)
endfunction

function! minpac#status(...)
  call s:ensure_initialization()
  let l:opt = extend(copy(get(a:000, 0, {})),
        \ {'open': g:minpac#opt.status_open}, 'keep')
  return minpac#status#get(l:opt)
endfunction


" Get information of specified plugin. Mainly for debugging.
function! minpac#getpluginfo(name)
  call s:ensure_initialization()
  return g:minpac#pluglist[a:name]
endfunction


" Get a list of plugin information. Mainly for debugging.
function! minpac#getpluglist()
  return g:minpac#pluglist
endfunction

" vim: set ts=8 sw=2 et:
