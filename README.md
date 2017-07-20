# async.vim
normalize async job control api for vim and neovim

## sample usage

```vim
function! s:handler(job_id, data, event_type)
    echo a:job_id . ' ' . a:event_type
    echo join(a:data, "\n")
endfunction

if has('win32') || has('win64')
    let argv = ['cmd', '/c', 'dir c:\ /b']
else
    let argv = ['bash', '-c', 'ls']
endif

let jobid = async#job#start(argv, {
    \ 'on_stdout': function('s:handler'),
    \ 'on_stderr': function('s:handler'),
    \ 'on_exit': function('s:handler'),
\ })

if jobid > 0
    echom 'job started'
else
    echom 'job failed to start'
endif

" If you want to wait the job:
call async#job#wait([job], 5000)  " timeout: 5 sec

" If you want to stop the job:
call async#job#stop(job)
```

## APIs

APIs are based on neovim's job control APIs.

* [job-control](https://neovim.io/doc/user/job_control.html#job-control)
* [jobsend()](https://neovim.io/doc/user/eval.html#jobsend%28%29)
* [jobstart()](https://neovim.io/doc/user/eval.html#jobstart%28%29)
* [jobstop()](https://neovim.io/doc/user/eval.html#jobstop%28%29)
* [jobwait()](https://neovim.io/doc/user/eval.html#jobwait%28%29)

## Embedding

Async.vim can be either embedded with other plugins or be used as an external plugin.
If you want to embed all you need is to change these 4 function names async#job# to what ever you want. E.g.:

```vim
" public apis {{{
function! yourplugin#job#start(cmd, opts) abort
    return s:job_start(a:cmd, a:opts)
endfunction

function! yourplugin#job#stop(jobid) abort
    call s:job_stop(a:jobid)
endfunction

function! yourplugin#job#send(jobid, data) abort
    call s:job_send(a:jobid, a:data)
endfunction

function! yourplugin#job#wait(jobids, ...) abort
    let l:timeout = get(a:000, 0, -1)
    call s:job_wait(a:jobids, l:timeout)
endfunction
" }}}
```

## Todos
* Fallback to sync `system()` calls in vim that doesn't support `job`
* `job_stop` and `job_send` is treated as noop when using `system()`
* `on_stderr` doesn't work when using `system()`
* Fallback to python/ruby threads and vimproc instead of using `system()` for better compatibility (PRs welcome!!!)

