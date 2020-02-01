" ---------------------------------------------------------------------
" minpac: A minimal package manager for Vim 8 (and Neovim)
"
" Maintainer:   Ken Takata
" Last Change:  2020-01-31
" License:      VIM License
" URL:          https://github.com/k-takata/minpac
" ---------------------------------------------------------------------

function! s:isabsolute(dir) abort
  if a:dir =~# '^/' || (has('win32') && a:dir =~? '^\%(\\\|[A-Z]:\)')
    return v:true
  endif
  return v:false
endfunction

function! s:get_gitdir(dir) abort
  let l:gitdir = a:dir . '/.git'
  if isdirectory(l:gitdir)
    return l:gitdir
  elseif filereadable(l:gitdir)
    try
      let l:line = readfile(l:gitdir)[0]
    catch
      return ''
    endtry
    if l:line =~# '^gitdir: '
      let l:dir = l:line[8:]
      if s:isabsolute(l:dir)
        let l:gitdir = l:dir
      else
        let l:gitdir = a:dir . '/' . l:dir
      endif
      if isdirectory(l:gitdir)
        return l:gitdir
      endif
    endif
  endif
  return ''
endfunction

function! minpac#git#get_revision(dir) abort
  let l:gitdir = s:get_gitdir(a:dir)
  if l:gitdir ==# ''
    return v:null
  endif
  try
    let l:line = readfile(l:gitdir . '/HEAD')[0]
    if l:line =~# '^ref: '
      let l:ref = l:line[5:]
      if filereadable(l:gitdir . '/' . l:ref)
        let l:rev = readfile(l:gitdir . '/' . l:ref)[0]
      else
        let l:rev = v:null
        for l:line in readfile(l:gitdir . '/packed-refs')
          if l:line =~# ' ' . l:ref
            let l:rev = substitute(l:line, '^\([0-9a-f]*\) ', '\1', '')
            break
          endif
        endfor
      endif
    else
      let l:rev = l:line
    endif
    return l:rev
  catch
    return v:null
  endtry
endfunction

function! minpac#git#get_branch(dir) abort
  let l:gitdir = s:get_gitdir(a:dir)
  if l:gitdir ==# ''
    return v:null
  endif
  try
    let l:line = readfile(l:gitdir . '/HEAD')[0]
    if l:line =~# '^ref: refs/heads/'
      return l:line[16:]
    endif
    return ''
  catch
    return v:null
  endtry
endfunction

" vim: set ts=8 sw=2 et:
