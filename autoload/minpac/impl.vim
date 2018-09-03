" ---------------------------------------------------------------------
" minpac: A minimal package manager for Vim 8 (and Neovim)
"
" Maintainer:   Ken Takata
" Last Change:  2018-09-01
" License:      VIM License
" URL:          https://github.com/k-takata/minpac
" ---------------------------------------------------------------------

let s:joblist = []
let s:remain_jobs = 0

" Get a list of package/plugin directories.
function! minpac#impl#getpackages(...) abort
  let l:packname = get(a:000, 0, '')
  let l:packtype = get(a:000, 1, '')
  let l:plugname = get(a:000, 2, '')
  let l:nameonly = get(a:000, 3, 0)

  if l:packname ==# '' | let l:packname = '*' | endif
  if l:packtype ==# '' | let l:packtype = '*' | endif
  if l:plugname ==# '' | let l:plugname = '*' | endif

  if l:packtype ==# 'NONE'
    let l:pat = 'pack/' . l:packname
  else
    let l:pat = 'pack/' . l:packname . '/' . l:packtype . '/' . l:plugname
  endif

  let l:ret = filter(globpath(&packpath, l:pat, 0, 1), {-> isdirectory(v:val)})
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
  function! s:quote_cmds(cmds) abort
    " If space is found, surround the argument with "".
    " Assuming double quotations are not used elsewhere.
    return join(map(a:cmds,
          \ {-> (v:val =~# ' ') ? '"' . v:val . '"' : v:val}), ' ')
  endfunction
else
  function! s:quote_cmds(cmds) abort
    return a:cmds
  endfunction
endif

" Replacement for system().
" This doesn't open an extra window on MS-Windows.
function! minpac#impl#system(cmds) abort
  let l:out = []
  let l:quote_cmds = s:quote_cmds(a:cmds)
  call s:echom_verbose(4, 'system: cmds=' . string(l:quote_cmds))
  let l:job = minpac#job#start(l:quote_cmds,
        \ {'on_stdout': {id, mes, ev -> extend(l:out, mes)}})
  if l:job > 0
    " It worked!
    let l:ret = minpac#job#wait([l:job])[0]
    sleep 5m    " Wait for out_cb. (not sure this is enough.)
  endif
  return [l:ret, l:out]
endfunction

" Execute git command on the specified plugin directory.
function! s:exec_plugin_cmd(name, cmd, mes) abort
  let l:pluginfo = g:minpac#pluglist[a:name]
  let l:dir = l:pluginfo.dir
  let l:res = minpac#impl#system([g:minpac#opt.git, '-C', l:dir] + a:cmd)
  if l:res[0] == 0 && len(l:res[1]) > 0
    call s:echom_verbose(4, a:mes . ': ' . l:res[1][0])
    return l:res[1][0]
  else
    " Error
    return ''
  endif
endfunction

" Get the revision of the specified plugin.
function! minpac#impl#get_plugin_revision(name) abort
  return s:exec_plugin_cmd(a:name, ['rev-parse', 'HEAD'], 'revision')
endfunction

" Get the exact tag name of the specified plugin.
function! s:get_plugin_tag(name) abort
  return s:exec_plugin_cmd(a:name, ['describe', '--tags', '--exact-match'], 'tag')
endfunction

" Get the branch name of the specified plugin.
function! s:get_plugin_branch(name) abort
  return s:exec_plugin_cmd(a:name, ['symbolic-ref', '--short', 'HEAD'], 'branch')
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
  if a:hook ==# ''
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

function! s:is_helptags_old(dir) abort
  let l:txts = glob(a:dir . '/*.{txt,[a-z][a-z]x}', 1, 1)
  let l:tags = glob(a:dir . '/tags{,-[a-z][a-z]}', 1, 1)
  let l:txt_newest = max(map(l:txts, {-> getftime(v:val)}))
  let l:tag_oldest = min(map(l:tags, {-> getftime(v:val)}))
  return l:txt_newest > l:tag_oldest
endfunction

function! s:generate_helptags(dir) abort
  let l:docdir = a:dir . '/doc'
  if s:is_helptags_old(l:docdir)
    silent! execute 'helptags' fnameescape(l:docdir)
  endif
endfunction

function! s:add_rtp(dir) abort
  if empty(&rtp)
    let &rtp = a:dir
  else
    let &rtp .= ',' . a:dir
  endif
endfunction

function! s:job_exit_cb(id, errcode, event) dict abort
  call filter(s:joblist, {-> v:val != a:id})

  let l:err = 1
  let l:pluginfo = g:minpac#pluglist[self.name]
  let l:pluginfo.stat.errcode = a:errcode
  if a:errcode == 0
    let l:dir = l:pluginfo.dir
    " Check if the plugin directory is available.
    if isdirectory(l:dir)
      " Check if it is actually updated (or installed).
      let l:updated = 1
      if l:pluginfo.stat.prev_rev !=# '' && l:pluginfo.stat.upd_method != 2
        if l:pluginfo.stat.prev_rev ==# minpac#impl#get_plugin_revision(self.name)
          let l:updated = 0
        endif
      endif

      if l:updated
        if l:pluginfo.stat.upd_method == 2
          if self.seq == 0
            " Check out the specified revison.
            let l:cmd = [g:minpac#opt.git, '-C', l:dir, 'checkout',
                  \ l:pluginfo.rev, '--']
            call s:echom_verbose(3, 'Checking out the revison: ' . self.name
                  \ . ': ' . l:pluginfo.rev)
            call s:start_job(l:cmd, self.name, self.seq + 1)
            return
          elseif self.seq == 1
                \ && s:get_plugin_branch(self.name) == l:pluginfo.rev
            let l:cmd = [g:minpac#opt.git, '-C', l:dir, 'merge', '--quiet',
                  \ '--ff-only', '@{u}']
            call s:echom_verbose(3, 'Update to the upstream: ' . self.name)
            call s:start_job(l:cmd, self.name, self.seq + 1)
            return
          endif
        endif
        if l:pluginfo.stat.submod == 0
          let l:pluginfo.stat.submod = 1
          if filereadable(l:dir . '/.gitmodules')
            " Update git submodule.
            let l:cmd = [g:minpac#opt.git, '-C', l:dir, 'submodule', '--quiet',
                  \ 'update', '--init', '--recursive']
            call s:echom_verbose(3, 'Updating submodules: ' . self.name)
            call s:start_job(l:cmd, self.name, self.seq + 1)
            return
          endif
        endif

        call s:generate_helptags(l:dir)

        if has('nvim') && isdirectory(l:dir . '/rplugin')
          " Required for :UpdateRemotePlugins.
          call s:add_rtp(l:dir)
        endif

        call s:invoke_hook('post-update', [self.name], l:pluginfo.do)
      else
        " Even the plugin is not updated, generate helptags if it is not found.
        call s:generate_helptags(l:dir)
      endif

      if l:pluginfo.stat.installed
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
  let l:mes = copy(a:message)
  if len(l:mes) > 0 && l:mes[-1] ==# ''
    " Remove the last empty line. It is redundant.
    call remove(l:mes, -1)
  endif
  for l:line in l:mes
    let l:line = substitute(l:line, "\t", '        ', 'g')
    call add(g:minpac#pluglist[self.name].stat.lines, l:line)
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

  let l:quote_cmds = s:quote_cmds(a:cmds)
  call s:echom_verbose(4, 'start_job: cmds=' . string(l:quote_cmds))
  let l:job = minpac#job#start(l:quote_cmds, {
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

function! s:is_same_commit(a, b) abort
  let l:min = min([len(a:a), len(a:b)]) - 1
  return a:a[0 : l:min] ==# a:b[0 : l:min]
endfunction

" Check the status of the plugin.
" return: 0: No need to update.
"         1: Need to update by pull.
"         2: Need to update by fetch & checkout.
function! s:check_plugin_status(name) abort
  let l:pluginfo = g:minpac#pluglist[a:name]
  let l:pluginfo.stat.prev_rev = minpac#impl#get_plugin_revision(a:name)

  if l:pluginfo.rev ==# ''
    " Need to update by pull.
    return 1
  endif
  if s:get_plugin_branch(a:name) == l:pluginfo.rev
    " Same branch. Need to update by pull.
    return 1
  endif
  if s:get_plugin_tag(a:name) == l:pluginfo.rev
    " Same tag. No need to update.
    return 0
  endif
  if s:is_same_commit(l:pluginfo.stat.prev_rev, l:pluginfo.rev)
    " Same commit ID. No need to update.
    return 0
  endif

  " Need to update by fetch & checkout.
  return 2
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
  let l:pluginfo.stat.errcode = 0
  let l:pluginfo.stat.lines = []
  let l:pluginfo.stat.prev_rev = ''
  let l:pluginfo.stat.submod = 0

  if !isdirectory(l:dir)
    if g:minpac#pluglist[a:name].type ==# 'start'
      let l:dirtmp = substitute(l:dir, '/start/\ze[^/]\+$', '/opt/', '')
    else
      let l:dirtmp = substitute(l:dir, '/opt/\ze[^/]\+$', '/start/', '')
    endif

    if !isdirectory(l:dirtmp)
      let l:pluginfo.stat.installed = 0
      if l:pluginfo.rev ==# ''
        let l:pluginfo.stat.upd_method = 1
      else
        let l:pluginfo.stat.upd_method = 2
      endif
      call s:echo_verbose(3, 'Cloning ' . a:name)

      let l:cmd = [g:minpac#opt.git, 'clone', '--quiet', l:url, l:dir, '--no-single-branch']
      if l:pluginfo.depth > 0 && l:pluginfo.rev ==# ''
        let l:cmd += ['--depth=' . l:pluginfo.depth]
      endif
      if l:pluginfo.branch !=# ''
        let l:cmd += ['--branch=' . l:pluginfo.branch]
      endif
    else
      " The type was changed (start <-> opt).
      call rename(l:dirtmp, l:dir)
      let l:pluginfo.stat.installed = 1
    endif
  else
    let l:pluginfo.stat.installed = 1
  endif

  if l:pluginfo.stat.installed == 1
    if l:pluginfo.frozen && !a:force
      call s:echom_verbose(3, 'Skipped: ' . a:name)
      call s:decrement_job_count()
      return 0
    endif

    let l:ret = s:check_plugin_status(a:name)
    let l:pluginfo.stat.upd_method = l:ret
    if l:ret == 0
      " No need to update.
      call s:echom_verbose(3, 'Already up-to-date: ' . a:name)
      call s:decrement_job_count()
      return 0
    elseif l:ret == 1
      " Same branch. Update by pull.
      call s:echo_verbose(3, 'Updating (pull): ' . a:name)
      let l:cmd = [g:minpac#opt.git, '-C', l:dir, 'pull', '--quiet', '--ff-only']
    elseif l:ret == 2
      " Different branch. Update by fetch & checkout.
      call s:echo_verbose(3, 'Updating (fetch): ' . a:name)
      let l:cmd = [g:minpac#opt.git, '-C', l:dir, 'fetch', '--depth', '999999']
    endif
  endif
  return s:start_job(l:cmd, a:name, 0)
endfunction

" Update all or specified plugin(s).
function! minpac#impl#update(...) abort
  let l:opt = extend(copy(get(a:000, 1, {})),
        \ {'do': ''}, 'keep')

  let l:force = 0
  if a:0 == 0 || (type(a:1) == v:t_string && a:1 ==# '')
    let l:names = keys(g:minpac#pluglist)
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
  if l:plugname =~# '/'
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
function! minpac#impl#clean(...) abort
  let l:plugin_dirs = minpac#getpackages(g:minpac#opt.package_name)

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

function! minpac#impl#is_update_ran() abort
  return exists('s:installed_plugins')
endfunction

" vim: set ts=8 sw=2 et:
