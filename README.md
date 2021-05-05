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

" If you want to get the process id of the job
let pid = async#job#pid(jobid)

" If you want to wait the job:
call async#job#wait([jobid], 5000)  " timeout: 5 sec

" If you want to stop the job:
call async#job#stop(jobid)
```

## APIs

APIs are based on neovim's job control APIs.

* [job-control](https://neovim.io/doc/user/job_control.html#job-control)
* [jobsend()](https://neovim.io/doc/user/eval.html#jobsend%28%29)
* [jobstart()](https://neovim.io/doc/user/eval.html#jobstart%28%29)
* [jobstop()](https://neovim.io/doc/user/eval.html#jobstop%28%29)
* [jobwait()](https://neovim.io/doc/user/eval.html#jobwait%28%29)
* [jobpid()](https://neovim.io/doc/user/eval.html#jobpid%28%29)

## Embedding

Async.vim can be either embedded with other plugins or be used as an external plugin.
If you want to embed run the following vim command.

```vim
:AsyncEmbed path=./autoload/myplugin/job.vim namespace=myplugin#job
```

## Todos
* Fallback to sync `system()` calls in vim that doesn't support `job`
* `job_stop` and `job_send` is treated as noop when using `system()`
* `on_stderr` doesn't work when using `system()`
* Fallback to python/ruby threads and vimproc instead of using `system()` for better compatibility (PRs welcome!!!)
