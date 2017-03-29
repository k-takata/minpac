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

" call async#job#stop(job)
```

## Todos
* Fallback to sync `system()` calls in vim that doesn't support `job`
* `job_stop` and `job_send` is treated as noop when using `system()`
* `on_stderr` doesn't work when using `system()`
* Fallback to python/ruby threads and vimproc instead of using `system()` for better compatibility (PRs welcome!!!)

