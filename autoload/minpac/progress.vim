" ---------------------------------------------------------------------
" minpac: A minimal package manager for Vim 8 (and Neovim)
"
" Maintainer:   Ken Takata
" Last Change:  2020-01-27
" License:      VIM License
" URL:          https://github.com/k-takata/minpac
" ---------------------------------------------------------------------

let s:winid = 0

" Add a message to the minpac progress window
function! minpac#progress#add_msg(type, msg) abort
  let l:wininfo = getwininfo(s:winid)
  if l:wininfo == []
    echom 'warning: minpac progress window not found.'
    return
  endif
  " Goes to the minpac progress window.
  exec l:wininfo[0].winnr . "wincmd w"
  setlocal modifiable
  let l:markers = {'': '  ', 'warning': 'W:', 'error': 'E:'}
  call append(line('$') - 1, l:markers[a:type] . ' ' . a:msg)
  setlocal nomodifiable
endfunction

" Open the minpac progress window
function! minpac#progress#open(msg) abort
  if g:minpac#opt.progress_open ==# 'vertical'
    vertical topleft new
  elseif g:minpac#opt.progress_open ==# 'horizontal'
    topleft new
  elseif g:minpac#opt.progress_open ==# 'tab'
    tabnew
  endif
  let s:winid = win_getid()
  call append(0, a:msg)

  setf minpacprgs
  call s:syntax()
  call s:mappings()
  setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nomodifiable nospell
endfunction

function! s:syntax() abort
  syntax clear
  syn match minpacPrgsError /^E: .*/
  syn match minpacPrgsWarning /^W: .*/

  hi def link minpacPrgsError   ErrorMsg
  hi def link minpacPrgsWarning WarningMsg
endfunction

function! s:mappings() abort
  nnoremap <silent><buffer> q :q<CR>
  nnoremap <silent><buffer> s :call minpac#status()<CR>
endfunction

" vim: set ts=8 sw=2 et:
