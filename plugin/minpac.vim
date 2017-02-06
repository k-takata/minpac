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

let s:joblist = []
let s:remain_jobs = 0

" Get a list of package/plugin directories.
function! minpac#getpackages(...)
  let l:packname = get(a:000, 0, '*')
  let l:packtype = get(a:000, 1, '*')
  let l:plugname = get(a:000, 2, '*')

  if l:packname == '' | let l:packname = '*' | endif
  if l:packtype == '' | let l:packtype = '*' | endif
  if l:plugname == '' | let l:plugname = '*' | endif

  if l:packtype ==# 'NONE'
    let l:pat = 'pack/' . l:packname
  else
    let l:pat = 'pack/' . l:packname . '/' . l:packtype . '/' . l:plugname
  endif
  return filter(globpath(&packpath, l:pat, 0 , 1), {-> isdirectory(v:val)})
endfunction


" Initialize minpac.
function! minpac#init(...)
  let l:opt = get(a:000, 0, {})
  let l:packdir = get(l:opt, 'dir', '')
  let s:gitcmd = get(l:opt, 'git', 'git')
  let s:package_name = get(l:opt, 'package_name', 'minpac')
  let s:depth = get(l:opt, 'depth', 1)
  let s:jobs = get(l:opt, 'jobs', 8)

  let s:pluglist = {}

  if l:packdir == ''
    " If 'dir' is not specified, the first directory of 'packpath' is used.
    let l:packdir = split(&packpath, ',')[0]
  endif
  let s:minpac_dir = l:packdir . '/pack/' . s:package_name
  let s:minpac_start_dir = s:minpac_dir . '/start'
  let s:minpac_opt_dir = s:minpac_dir . '/opt'
  if !isdirectory(l:packdir)
    echoerr 'Pack directory not available: ' . l:packdir
    return
  endif
  if !isdirectory(s:minpac_start_dir)
    call mkdir(s:minpac_start_dir, 'p')
  endif
  if !isdirectory(s:minpac_opt_dir)
    call mkdir(s:minpac_opt_dir, 'p')
  endif
endfunction


" Register the specified plugin.
function! minpac#add(plugname, ...)
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
  let l:name = get(opt, 'name', l:name)
  if l:name == ''
    echoerr 'Cannot specify the plugin name.'
    return
  endif

  " Loading type: 'start' or 'opt'
  let l:type = get(opt, 'type', 'start')
  if l:type !=# 'start' && l:type !=# 'opt'
    echoerr "Wrong type (must be 'start' or 'opt'): " . l:type
    return
  endif

  " Local directory
  if l:type ==# 'start'
    let l:dir = s:minpac_start_dir . '/' . l:name
  else
    let l:dir = s:minpac_opt_dir . '/' . l:name
  endif

  " Frozen
  let l:frozen = get(opt, 'frozen', 0)

  " Clone depth
  let l:depth = get(opt, 'depth', s:depth)

  " Branch
  let l:branch = get(opt, 'branch', '')

  " Add to pluglist
  let s:pluglist[l:name] = {'url': l:url, 'type': l:type, 'dir': l:dir,
        \ 'depth': l:depth, 'frozen': l:frozen, 'branch': l:branch}
endfunction


function! s:decrement_job_count()
  let s:remain_jobs -= 1
  if s:remain_jobs == 0
    echom 'Finished.'
  endif
endfunction

function! s:job_exit_cb(name, job, errcode)
  call filter(s:joblist, {-> v:val isnot a:job})

  let l:err = 1
  if a:errcode == 0
    let l:dir = s:pluglist[a:name].dir
    if isdirectory(l:dir)
      if isdirectory(l:dir . '/doc')
        silent! execute 'helptags' l:dir . '/doc'
      endif
      echom 'Updated: ' . a:name
      let l:err = 0
    endif
  endif
  if l:err
    echohl ErrorMsg
    echom 'Error while updating "' . a:name . '": ' . a:errcode
    echohl None
  endif

  call s:decrement_job_count()
endfunction

function! s:job_err_cb(name, channel, message)
  echohl WarningMsg
  echom a:name . ': ' . a:message
  echohl None
endfunction

function! s:start_job(cmds, name)
  if s:jobs > 0
    if len(s:joblist) > 1
      sleep 20m
    endif
    while len(s:joblist) >= s:jobs
      sleep 500m
    endwhile
  endif

  if has('win32')
    let l:cmds = join(map(a:cmds, {-> (v:val =~# ' ') ? '"' . v:val . '"' : v:val}), ' ')
  else
    let l:cmds = a:cmds
  endif
  let l:job = job_start(l:cmds, {'exit_cb': function('s:job_exit_cb', [a:name]),
        \ 'in_io': 'null', 'out_io': 'null',
        \ 'err_cb': function('s:job_err_cb', [a:name])})
  if job_status(l:job) ==# 'fail'
    echohl ErrorMsg
    echom 'Fail to execute: ' . a:cmds[0]
    echohl None
    call s:decrement_job_count()
    return 1
  endif
  let s:joblist += [l:job]
  return 0
endfunction

" Update a single plugin.
function! s:update_single_plugin(name, force)
  if !has_key(s:pluglist, a:name)
    echoerr 'Plugin not registered: ' . a:name
    return 1
  endif

  let l:pluginfo = s:pluglist[a:name]
  let l:dir = l:pluginfo.dir
  let l:url = l:pluginfo.url
  if !isdirectory(l:dir)
    echo 'Cloning ' . a:name

    let l:cmd = [s:gitcmd, 'clone', '--quiet']
    if l:pluginfo.depth > 0
      let l:cmd += ['--depth=' . l:pluginfo.depth]
    endif
    if l:pluginfo.branch > 0
      let l:cmd += ['--branch=' . l:pluginfo.branch]
    endif
    let l:cmd += [l:url, l:dir]
  else
    if l:pluginfo.frozen && !a:force
      echo 'Skipping ' . a:name
      call s:decrement_job_count()
      return 0
    endif

    echo 'Updating ' . a:name
    let l:cmd = [s:gitcmd, '-C', l:dir, 'pull', '--quiet', '--ff-only']
  endif
  return s:start_job(l:cmd, a:name)
endfunction


" Update all or specified plugin(s).
function! minpac#update(...)
  let l:force = 0
  if a:0 == 0
    let l:names = keys(s:pluglist)
  elseif type(a:1) == v:t_string
    let l:names = [a:1]
    let l:force = 1
  elseif type(a:1) == v:t_list
    let l:names = a:1
    let l:force = 1
  else
    echoerr 'Wrong parameter type. Must be a String or a List of Strings.'
    return
  endif

  if s:remain_jobs > 0
    echom 'Previous update has not been finished.'
    return
  endif
  let s:remain_jobs = len(l:names)

  for l:name in l:names
    let ret = s:update_single_plugin(l:name, l:force)
  endfor
endfunction


" Check if the dir matches specified package name and plugin names.
function! s:match_plugin(dir, packname, plugnames)
  let l:plugname = '\%(' . join(a:plugnames, '\|') . '\)'
  let l:plugname = substitute(l:plugname, '\.', '\\.', 'g')
  let l:plugname = substitute(l:plugname, '\*', '.*', 'g')
  if l:plugname =~ '/'
    let l:pat = '/pack/' . a:packname . '/' . l:plugname . '$'
  else
    let l:pat = '/pack/' . a:packname . '/\%(start\|opt\)/' . l:plugname . '$'
  endif
  if has('win32')
    let l:pat = substitute(l:pat, '/', '[/\\\\]', 'g')
    " case insensitive matching
    return a:dir =~? l:pat
  else
    " case sensitive matching
    return a:dir =~# l:pat
  endif
endfunction

" Remove plugins that are not registered.
function! minpac#clean(...)
  let l:plugin_dirs = minpac#getpackages(s:package_name)

  if a:0 > 0
    " Going to remove only specified plugins.
    if type(a:1) == v:t_string
      let l:names = [a:1]
    elseif type(a:1) == v:t_list
      let l:names = a:1
    else
      echoerr 'Wrong parameter type. Must be a String or a List of Strings.'
      return
    endif
    let l:to_remove = filter(l:plugin_dirs,
          \ {-> s:match_plugin(v:val, s:package_name, l:names)})
  else
    " Remove all plugins that are not registered.
    let l:safelist = map(keys(s:pluglist),
          \ {-> s:pluglist[v:val].type . '/' . v:val})
          \ + ['\%(start\|opt\)/minpac']  " Don't remove itself.
    let l:to_remove = filter(l:plugin_dirs,
          \ {-> !s:match_plugin(v:val, s:package_name, l:safelist)})
  endif
  if len(l:to_remove) == 0
    echo 'Already clean.'
    return
  endif

  " Show the list of plugins to be removed.
  for l:item in l:to_remove
    echo l:item
  endfor

  let l:dir = (len(l:to_remove) > 1) ? 'directories' : 'directory'
  if input('Removing the above ' . l:dir . '. [y/N]? ') =~? '^y'
    echo "\n"
    let err = 0
    for l:item in l:to_remove
      if delete(l:item, 'rf') != 0
        echohl ErrorMsg
        echom 'Clean failed: ' . l:item
        echohl None
        let err = 1
      endif
    endfor
    if err == 0
      echo 'Successfully cleaned.'
    endif
  else
    echo "\n" . 'Not cleaned.'
  endif
endfunction


" Get information of specified plugin. Mainly for debugging.
function! minpac#getpluginfo(name)
  return s:pluglist[a:name]
endfunction


" Get a list of plugin information. Only for internal use.
function! minpac#getpluglist()
  return s:pluglist
endfunction

" vim: set ts=8 sw=2 et:
