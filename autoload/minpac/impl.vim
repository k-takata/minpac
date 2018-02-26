" ---------------------------------------------------------------------
" minpac: A minimal package manager for Vim 8 (and Neovim)
"
" Maintainer:	Ken Takata
" Last Change:  2017-04-22
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
  let l:nameonly = get(a:args, 3, 0)

  if l:packname == '' | let l:packname = '*' | endif
  if l:packtype == '' | let l:packtype = '*' | endif
  if l:plugname == '' | let l:plugname = '*' | endif

  if l:packtype ==# 'NONE'
    let l:pat = 'pack/' . l:packname
  else
    let l:pat = 'pack/' . l:packname . '/' . l:packtype . '/' . l:plugname
  endif

  let l:ret = filter(globpath(&packpath, l:pat, 0 , 1), {-> isdirectory(v:val)})
  if l:nameonly
    call map(l:ret, {-> substitute(v:val, '^.*[/\\]', '', '')})
  endif
  return l:ret
endfunction


function! s:echo_verbose(level, msg) abort
  if g:minpac#opt.verbose >= a:level
    echo a:msg
  endif
endfunction

function! s:echom_verbose(level, msg) abort
  if g:minpac#opt.verbose >= a:level
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

" Replacement for system().
" This doesn't open an extra window on MS-Windows.
function! s:system(cmds) abort
  let l:opt = {
        \ 'on_stdout': function('s:system_out_cb'),
        \ 'out': []
        \ }
  let l:job = minpac#job#start(s:quote_cmds(a:cmds), l:opt)
  if l:job > 0
    " It worked!
    let l:ret = minpac#job#wait([l:job])[0]
    sleep 5m    " Wait for out_cb. (not sure this is enough.)
  endif
  return [l:ret, l:opt.out]
endfunction

" Get the revision of the specified plugin.
function! s:get_plugin_revision(name) abort
  let l:pluginfo = g:minpac#pluglist[a:name]
  let l:dir = l:pluginfo.dir
  let l:res = s:system([g:minpac#opt.git, '-C', l:dir, 'rev-parse', 'HEAD'])
  if l:res[0] == 0 && len(l:res[1]) > 0
    return l:res[1][0]
  else
    " Error
    return ''
  endif
endfunction


function! s:decrement_job_count() abort
  let s:remain_jobs -= 1
  if s:remain_jobs == 0
    " `minpac#update()` is finished.
    call s:invoke_hook('finish-update', [s:updated_plugins, s:installed_plugins], s:finish_update_hook)

    if has('nvim') && exists(':UpdateRemotePlugins') == 2
          \ && (s:updated_plugins > 0 || s:installed_plugins > 0)
      UpdateRemotePlugins
    endif

    " Show the status.
    if s:error_plugins != 0
      echohl WarningMsg
      echom 'Error plugins: ' . s:error_plugins
      echohl None
    else
      let l:mes = 'All plugins are up to date.'
      if s:updated_plugins > 0 || s:installed_plugins > 0
        let l:mes .= ' (Updated: ' . s:updated_plugins . ', Newly installed: ' . s:installed_plugins . ')'
      endif
      echom l:mes
    endif

    " Restore the pager.
    if exists('s:save_more')
      let &more = s:save_more
      unlet s:save_more
    endif
  endif
endfunction

function! s:invoke_hook(hooktype, args, hook) abort
  if a:hook == ''
    return
  endif

  if a:hooktype ==# 'post-update'
    let l:name = a:args[0]
    let l:pluginfo = g:minpac#pluglist[l:name]
    let l:cdcmd = haslocaldir() ? 'lcd' : 'cd'
    let l:pwd = getcwd()
    noautocmd execute l:cdcmd fnameescape(l:pluginfo.dir)
  endif
  try
    if type(a:hook) == v:t_func
      call call(a:hook, [a:hooktype] + a:args)
    elseif type(a:hook) == v:t_string
      execute a:hook
    endif
  catch
    echohl ErrorMsg
    echom v:throwpoint
    echom v:exception
    echohl None
  finally
    if a:hooktype ==# 'post-update'
      noautocmd execute l:cdcmd fnameescape(l:pwd)
    endif
  endtry
endfunction

function! s:generate_helptags(dir, force) abort
  if isdirectory(a:dir . '/doc')
    if a:force || len(glob(a:dir . '/doc/tags*', 1, 1)) == 0
      silent! execute 'helptags' a:dir . '/doc'
    endif
  endif
endfunction

function! s:job_exit_cb(id, errcode, event) dict abort
  call filter(s:joblist, {-> v:val != a:id})

  let l:err = 1
  if a:errcode == 0
    let l:pluginfo = g:minpac#pluglist[self.name]
    let l:dir = l:pluginfo.dir
    " Check if the plugin directory is available.
    if isdirectory(l:dir)
      " Check if it is actually updated (or installed).
      let l:updated = 1
      if l:pluginfo.revision != ''
        if l:pluginfo.revision ==# s:get_plugin_revision(self.name)
          let l:updated = 0
        endif
      endif

      if l:updated
        if self.seq == 0 && filereadable(l:dir . '/.gitmodules')
          " Update git submodule.
          let l:cmd = [g:minpac#opt.git, '-C', l:dir, 'submodule', '--quiet',
                \ 'update', '--init', '--recursive']
          call s:echom_verbose(3, 'Updating submodules: ' . self.name)
          call s:start_job(l:cmd, self.name, self.seq + 1)
          return
        endif

        call s:generate_helptags(l:dir, 1)

        if has('nvim') && isdirectory(l:dir . '/rplugin')
          " Required for :UpdateRemotePlugins.
          if empty(&rtp)
            let &rtp = l:dir
          else
            let &rtp .= ',' . l:dir
          endif
        endif

        call s:invoke_hook('post-update', [self.name], l:pluginfo.do)
      else
        " Even the plugin is not updated, generate helptags if it is not found.
        call s:generate_helptags(l:dir, 0)
      endif

      if l:pluginfo.installed
        if l:updated
          let s:updated_plugins += 1
          call s:echom_verbose(1, 'Updated: ' . self.name)
        else
          call s:echom_verbose(3, 'Already up-to-date: ' . self.name)
        endif
      else
        let s:installed_plugins += 1
        call s:echom_verbose(1, 'Installed: ' . self.name)
      endif
      let l:err = 0
    endif
  endif
  if l:err
    let s:error_plugins += 1
    echohl ErrorMsg
    call s:echom_verbose(1, 'Error while updating "' . self.name . '".  Error code: ' . a:errcode)
    echohl None
  endif

  call s:decrement_job_count()
endfunction

function! s:job_err_cb(id, message, event) dict abort
  echohl WarningMsg
  for l:line in a:message
    call s:echom_verbose(2, self.name . ': ' . l:line)
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
    call s:echo_verbose(3, 'Cloning ' . a:name)

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
      call s:echom_verbose(3, 'Skipped: ' . a:name)
      call s:decrement_job_count()
      return 0
    endif

    call s:echo_verbose(3, 'Updating ' . a:name)
    let l:pluginfo.revision = s:get_plugin_revision(a:name)
    let l:cmd = [g:minpac#opt.git, '-C', l:dir, 'pull', '--quiet', '--ff-only']
  endif
  return s:start_job(l:cmd, a:name, 0)
endfunction

" Update all or specified plugin(s).
function! minpac#impl#update(args) abort
  let l:opt = extend(copy(get(a:args, 1, {})),
        \ {'do': ''}, 'keep')

  let l:force = 0
  if len(a:args) == 0 || (type(a:args[0]) == v:t_string && a:args[0] == '')
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
  let s:error_plugins = 0
  let s:updated_plugins = 0
  let s:installed_plugins = 0
  let s:finish_update_hook = l:opt.do

  " Disable the pager temporarily to avoid jobs being interrupted.
  if !exists('s:save_more')
    let s:save_more = &more
  endif
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
  let l:plugname = substitute(l:plugname, '?', '.', 'g')
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
          \ + ['opt/minpac']  " Don't remove itself.
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
    if has('nvim') && exists(':UpdateRemotePlugins') == 2
      UpdateRemotePlugins
    endif
    if err == 0
      echo 'Successfully cleaned.'
    endif
  else
    echo "\n" . 'Not cleaned.'
  endif
endfunction

" vim: set ts=8 sw=2 et:
