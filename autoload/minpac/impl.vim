" ---------------------------------------------------------------------
" minpac: A minimal package manager for Vim 8
"
" Maintainer:	Ken Takata
" Last Change:  2017-02-06
" License:      VIM License
" URL:          https://github.com/k-takata/minpac
" ---------------------------------------------------------------------

let s:joblist = []
let s:remain_jobs = 0

" Get a list of package/plugin directories.
function! minpac#impl#getpackages(args) abort
  let l:packname = get(a:args, 0, '')
  let l:packtype = get(a:args, 1, '')
  let l:plugname = get(a:args, 2, '')

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


function! s:echo_verbose(msg) abort
  if g:minpac#opt.verbose > 0
    echo a:msg
  endif
endfunction

function! s:echom_verbose(msg) abort
  if g:minpac#opt.verbose > 0
    echom a:msg
  endif
endfunction


if has('win32')
  function! s:quote_cmds(cmds)
    " If space is found, surround the argument with "".
    " Assuming double quotations are not used elsewhere.
    return join(map(a:cmds,
          \ {-> (v:val =~# ' ') ? '"' . v:val . '"' : v:val}), ' ')
  endfunction
else
  function! s:quote_cmds(cmds)
    return a:cmds
  endfunction
endif

function! s:system_out_cb(id, message, event) dict abort
  let self.out += a:message
endfunction

function! s:system_exit_cb(id, errcode, event) dict abort
  let self.errcode = a:errcode
  let self.exited = 1
endfunction

" Replacement for system().
" This doesn't open an extra window on MS-Windows.
function! s:system(cmds) abort
  let l:opt = {
        \ 'on_stdout': function('s:system_out_cb'),
        \ 'on_exit': function('s:system_exit_cb'),
        \ 'out': [], 'errcode': -1, 'exited': 0
        \ }
  let l:job = minpac#job#start(s:quote_cmds(a:cmds), l:opt)
  if l:job > 0
    " It worked!
    while !l:opt.exited
      sleep 1m
    endwhile
  endif
  return [l:opt.errcode, l:opt.out]
endfunction

" Get the revision of the specified plugin.
function! s:get_plugin_revision(name) abort
  let l:pluginfo = g:minpac#pluglist[a:name]
  let l:dir = l:pluginfo.dir
  let l:res = s:system([g:minpac#opt.git, '-C', l:dir, 'rev-parse', 'HEAD'])
  if l:res[0] == 0
    return l:res[1][0]
  else
    " Error
    return ''
  endif
endfunction


function! s:decrement_job_count() abort
  let s:remain_jobs -= 1
  if s:remain_jobs == 0
    echom 'Finished.'

    " Restore the pager.
    if exists('s:save_more')
      let &more = s:save_more
      unlet s:save_more
    endif
  endif
endfunction

function! s:job_exit_cb(id, errcode, event) dict abort
  call filter(s:joblist, {-> v:val != a:id})

  let l:err = 1
  if a:errcode == 0
    let l:pluginfo = g:minpac#pluglist[self.name]
    let l:dir = l:pluginfo.dir
    if isdirectory(l:dir)
      " Successfully updated.
      if self.seq == 0 && filereadable(l:dir . '/.gitmodules')
        " Update git submodule.
        let l:cmd = [g:minpac#opt.git, '-C', l:dir, 'submodule', '--quiet',
              \ 'update', '--init', '--recursive']
        call s:echom_verbose('Updating submodules: ' . self.name)
        call s:start_job(l:cmd, self.name, self.seq + 1)
        return
      endif

      " Check if it is actually updated.
      let l:updated = 1
      if l:pluginfo.revision != ''
        if l:pluginfo.revision ==# s:get_plugin_revision(self.name)
          let l:updated = 0
        endif
      endif

      if isdirectory(l:dir . '/doc') && l:updated
        " Generate helptags.
        silent! execute 'helptags' l:dir . '/doc'
      endif
      if l:pluginfo.installed
        if l:updated
          echom 'Updated: ' . self.name
        else
          call s:echom_verbose('Already up-to-date: ' . self.name)
        endif
      else
        echom 'Installed: ' . self.name
      endif
      let l:err = 0
    endif
  endif
  if l:err
    echohl ErrorMsg
    echom 'Error while updating "' . self.name . '": ' . a:errcode
    echohl None
  endif

  call s:decrement_job_count()
endfunction

function! s:job_err_cb(id, message, event) dict abort
  echohl WarningMsg
  for l:line in a:message
    echom self.name . ': ' . l:line
  endfor
  echohl None
endfunction

function! s:start_job(cmds, name, seq) abort
  if len(s:joblist) > 1
    sleep 20m
  endif
  if g:minpac#opt.jobs > 0
    while len(s:joblist) >= g:minpac#opt.jobs
      sleep 500m
    endwhile
  endif

  let l:job = minpac#job#start(s:quote_cmds(a:cmds), {
        \ 'on_stderr': function('s:job_err_cb'),
        \ 'on_exit': function('s:job_exit_cb'),
        \ 'name': a:name, 'seq': a:seq
        \ })
  if l:job > 0
    " It worked!
  else
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
function! s:update_single_plugin(name, force) abort
  if !has_key(g:minpac#pluglist, a:name)
    echoerr 'Plugin not registered: ' . a:name
    call s:decrement_job_count()
    return 1
  endif

  let l:pluginfo = g:minpac#pluglist[a:name]
  let l:dir = l:pluginfo.dir
  let l:url = l:pluginfo.url
  if !isdirectory(l:dir)
    let l:pluginfo.installed = 0
    let l:pluginfo.revision = ''
    call s:echo_verbose('Cloning ' . a:name)

    let l:cmd = [g:minpac#opt.git, 'clone', '--quiet', l:url, l:dir]
    if l:pluginfo.depth > 0
      let l:cmd += ['--depth=' . l:pluginfo.depth]
    endif
    if l:pluginfo.branch != ''
      let l:cmd += ['--branch=' . l:pluginfo.branch]
    endif
  else
    let l:pluginfo.installed = 1
    if l:pluginfo.frozen && !a:force
      call s:echom_verbose('Skipped: ' . a:name)
      call s:decrement_job_count()
      return 0
    endif

    call s:echo_verbose('Updating ' . a:name)
    let l:pluginfo.revision = s:get_plugin_revision(a:name)
    let l:cmd = [g:minpac#opt.git, '-C', l:dir, 'pull', '--quiet', '--ff-only']
  endif
  return s:start_job(l:cmd, a:name, 0)
endfunction

" Update all or specified plugin(s).
function! minpac#impl#update(args) abort
  let l:force = 0
  if len(a:args) == 0
    let l:names = keys(g:minpac#pluglist)
  elseif type(a:args[0]) == v:t_string
    let l:names = [a:args[0]]
    let l:force = 1
  elseif type(a:args[0]) == v:t_list
    let l:names = a:args[0]
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

  " Disable the pager temporarily to avoid jobs being interrupted.
  let s:save_more = &more
  set nomore

  for l:name in l:names
    let ret = s:update_single_plugin(l:name, l:force)
  endfor
endfunction


" Check if the dir matches specified package name and plugin names.
function! s:match_plugin(dir, packname, plugnames) abort
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
function! minpac#impl#clean(args) abort
  let l:plugin_dirs = minpac#getpackages(g:minpac#opt.package_name)

  if len(a:args) > 0
    " Going to remove only specified plugins.
    if type(a:args[0]) == v:t_string
      let l:names = [a:args[0]]
    elseif type(a:args[0]) == v:t_list
      let l:names = a:args[0]
    else
      echoerr 'Wrong parameter type. Must be a String or a List of Strings.'
      return
    endif
    let l:to_remove = filter(l:plugin_dirs,
          \ {-> s:match_plugin(v:val, g:minpac#opt.package_name, l:names)})
  else
    " Remove all plugins that are not registered.
    let l:safelist = map(keys(g:minpac#pluglist),
          \ {-> g:minpac#pluglist[v:val].type . '/' . v:val})
          \ + ['\%(start\|opt\)/minpac']  " Don't remove itself.
    let l:to_remove = filter(l:plugin_dirs,
          \ {-> !s:match_plugin(v:val, g:minpac#opt.package_name, l:safelist)})
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

" vim: set ts=8 sw=2 et:
