" ---------------------------------------------------------------------
" minpac: A minimal package manager for Vim 8 (and Neovim)
"
" Maintainer:   Ken Takata
" Last Change:  2020-02-01
" License:      VIM License
" URL:          https://github.com/k-takata/minpac
" ---------------------------------------------------------------------

function! s:isabsolute(dir) abort
  return a:dir =~# '^/' || (has('win32') && a:dir =~? '^\%(\\\|[A-Z]:\)')
endfunction

function! s:get_gitdir(dir) abort
  let l:gitdir = a:dir . '/.git'
  if isdirectory(l:gitdir)
    return l:gitdir
  endif
  try
    let l:line = readfile(l:gitdir)[0]
    if l:line =~# '^gitdir: '
      let l:gitdir = l:line[8:]
      if !s:isabsolute(l:gitdir)
        let l:gitdir = a:dir . '/' . l:gitdir
      endif
      if isdirectory(l:gitdir)
        return l:gitdir
      endif
    endif
  catch
  endtry
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
        return readfile(l:gitdir . '/' . l:ref)[0]
      endif
      for l:line in readfile(l:gitdir . '/packed-refs')
        if l:line =~# ' ' . l:ref
          return substitute(l:line, '^\([0-9a-f]*\) ', '\1', '')
        endif
      endfor
    endif
    return l:line
  catch
  endtry
  return v:null
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
