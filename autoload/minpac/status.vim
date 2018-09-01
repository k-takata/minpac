" ---------------------------------------------------------------------
" minpac: A minimal package manager for Vim 8 (and Neovim)
"
" Maintainer:   Ken Takata
" Created By:   Kristijan Husak
" Last Change:  2018-09-01
" License:      VIM License
" URL:          https://github.com/k-takata/minpac
" ---------------------------------------------------------------------

let s:results = []

function! minpac#status#get(opt) abort
  let l:is_update_ran = minpac#impl#is_update_ran()
  let l:update_count = 0
  let l:install_count = 0
  let l:error_count = 0
  let l:result = []
  for l:name in keys(g:minpac#pluglist)
    let l:pluginfo = g:minpac#pluglist[l:name]
    let l:dir = l:pluginfo.dir
    let l:plugin = {'name': l:name, 'lines': [], 'status': ''}

    if !isdirectory(l:dir)
      let l:plugin.status = 'Not installed'
    else
      let l:commits = minpac#impl#system([g:minpac#opt.git, '-C', l:dir, 'log',
            \ '--color=never', '--pretty=format:%h <<<<%D>>>> %s (%cr)', '--no-show-signature', 'HEAD...HEAD@{1}'
            \ ])

      let l:plugin.lines = filter(l:commits[1], {-> v:val !=# ''})
      call map(l:plugin.lines,
            \ {-> substitute(v:val, '^[0-9a-f]\{4,} \zs<<<<\(.*\)>>>> ',
            \   {m -> m[1] =~# '^tag: ' ? '(' . m[1] . ') ' : ''}, '')})

      if !l:is_update_ran
        let l:plugin.status = 'OK'
      elseif l:pluginfo.stat.prev_rev !=# '' && l:pluginfo.stat.prev_rev !=# minpac#impl#get_plugin_revision(l:name)
        let l:update_count += 1
        let l:plugin.status = 'Updated'
      elseif l:pluginfo.stat.installed == 0
        let l:install_count += 1
        let l:plugin.status = 'Installed'
      elseif l:pluginfo.stat.errcode != 0
        let l:error_count += 1
        let l:plugin.status = 'Error (' . l:pluginfo.stat.errcode . ')'
      endif
    endif

    call add(l:result, l:plugin)
  endfor

  " Show items with most lines (commits) first.
  call sort(l:result, {first, second -> len(second.lines) - len(first.lines)})
  let s:results = l:result

  let l:content = []

  if l:is_update_ran
    call add(l:content, l:update_count . ' updated. ' . l:install_count . ' installed. ' . l:error_count . ' failed.')
    call add(l:content, '')
  endif

  for l:item in l:result
    if l:item.status ==# ''
      continue
    endif

    call add(l:content, '- ' . l:item.name . ' - ' . l:item.status)
    if l:item.status =~# '^Error'
      for l:line in g:minpac#pluglist[l:item.name].stat.lines
        call add(l:content, ' msg: ' . l:line)
      endfor
    else
      for l:line in l:item.lines
        call add(l:content, ' * ' . l:line)
      endfor
    endif
    call add(l:content, '')
  endfor
  if len(l:content) > 0 && l:content[-1] ==# ''
    call remove(l:content, -1)
  endif

  if a:opt.open ==# 'vertical'
    vertical topleft new
  elseif a:opt.open ==# 'horizontal'
    topleft new
  elseif a:opt.open ==# 'tab'
    tabnew
  endif
  setf minpac
  call append(1, l:content)
  1delete _
  call s:syntax()
  call s:mappings()
  setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap cursorline nomodifiable nospell
endfunction


function! s:syntax() abort
  syntax clear
  syn match minpacDash /^-/
  syn match minpacName /\(^- \)\@<=.*/ contains=minpacStatus
  syn match minpacStatus /\(-.*\)\@<=-\s.*$/ contained
  syn match minpacStar /^\s\*/ contained
  syn match minpacCommit /^\s\*\s[0-9a-f]\{7,9} .*/ contains=minpacRelDate,minpacSha,minpacStar
  syn match minpacSha /\(\s\*\s\)\@<=[0-9a-f]\{4,}/ contained nextgroup=minpacTag
  syn match minpacTag / (tag: [^)]*)/ contained
  syn match minpacRelDate /([^)]*)$/ contained
  syn match minpacWarning /^ msg: .*/

  hi def link minpacDash    Special
  hi def link minpacStar    Boolean
  hi def link minpacName    Function
  hi def link minpacSha     Identifier
  hi def link minpacTag     PreProc
  hi def link minpacRelDate Comment
  hi def link minpacStatus  Constant
  hi def link minpacWarning WarningMsg
endfunction

function! s:mappings() abort
  nnoremap <silent><buffer> <CR> :call <SID>openSha()<CR>
  nnoremap <silent><buffer> q :q<CR>
  nnoremap <silent><buffer> <C-j> :call <SID>nextPackage()<CR>
  nnoremap <silent><buffer> <C-k> :call <SID>prevPackage()<CR>
endfunction

function! s:nextPackage() abort
  return search('^-\s.*$')
endfunction

function! s:prevPackage() abort
  return search('^-\s.*$', 'b')
endfunction

function! s:openSha() abort
  let l:sha = matchstr(getline('.'), '^\s\*\s\zs[0-9a-f]\{7,9}')
  if empty(l:sha)
    return
  endif

  let l:name = s:find_name_by_sha(l:sha)

  if empty(l:name)
    return
  endif

  let l:pluginfo = g:minpac#pluglist[l:name]
  silent exe 'pedit' l:sha
  wincmd p
  setlocal previewwindow filetype=git buftype=nofile nobuflisted modifiable
  let l:sha_content = minpac#impl#system([g:minpac#opt.git, '-C', l:pluginfo.dir, 'show',
            \ '--no-color', '--pretty=medium', l:sha
            \ ])

  call append(1, l:sha_content[1])
  1delete _
  setlocal nomodifiable
  nnoremap <silent><buffer> q :q<CR>
endfunction

function! s:find_name_by_sha(sha) abort
  for l:result in s:results
    for l:commit in l:result.lines
      if l:commit =~? '^' . a:sha
        return l:result.name
      endif
    endfor
  endfor

  return ''
endfunction

" vim: set ts=8 sw=2 et:
