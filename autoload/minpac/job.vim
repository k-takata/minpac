" Author: Prabir Shrestha <mail at prabir dot me>
" Website: https://github.com/prabirshrestha/async.vim
" License: The MIT License {{{
"   The MIT License (MIT)
"
"   Copyright (c) 2016 Prabir Shrestha
"
"   Permission is hereby granted, free of charge, to any person obtaining a copy
"   of this software and associated documentation files (the "Software"), to deal
"   in the Software without restriction, including without limitation the rights
"   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"   copies of the Software, and to permit persons to whom the Software is
"   furnished to do so, subject to the following conditions:
"
"   The above copyright notice and this permission notice shall be included in all
"   copies or substantial portions of the Software.
"
"   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
"   SOFTWARE.
" }}}

let s:save_cpo = &cpo
set cpo&vim

let s:jobidseq = 0
let s:jobs = {} " { job, opts, type: 'vimjob|nvimjob'}
let s:job_type_nvimjob = 'nvimjob'
let s:job_type_vimjob = 'vimjob'
let s:job_error_unsupported_job_type = -2 " unsupported job type

function! s:job_supported_types() abort
    let l:supported_types = []
    if has('nvim')
        let l:supported_types += [s:job_type_nvimjob]
    endif
    if !has('nvim') && has('job') && has('channel') && has('lambda')
        let l:supported_types += [s:job_type_vimjob]
    endif
    return l:supported_types
endfunction

function! s:job_supports_type(type) abort
    return index(s:job_supported_types(), a:type) >= 0
endfunction

function! s:out_cb(jobid, opts, job, data) abort
    if has_key(a:opts, 'on_stdout')
        call a:opts.on_stdout(a:jobid, split(a:data, "\n", 1), 'stdout')
    endif
endfunction

function! s:err_cb(jobid, opts, job, data) abort
    if has_key(a:opts, 'on_stderr')
        call a:opts.on_stderr(a:jobid, split(a:data, "\n", 1), 'stderr')
    endif
endfunction

function! s:exit_cb(jobid, opts, job, status) abort
    if has_key(a:opts, 'on_exit')
        call a:opts.on_exit(a:jobid, a:status, 'exit')
    endif
    if has_key(s:jobs, a:jobid)
        call remove(s:jobs, a:jobid)
    endif
endfunction

function! s:on_stdout(jobid, data, event) abort
    if has_key(s:jobs, a:jobid)
        let l:jobinfo = s:jobs[a:jobid]
        if has_key(l:jobinfo.opts, 'on_stdout')
            call l:jobinfo.opts.on_stdout(a:jobid, a:data, a:event)
        endif
    endif
endfunction

function! s:on_stderr(jobid, data, event) abort
    if has_key(s:jobs, a:jobid)
        let l:jobinfo = s:jobs[a:jobid]
        if has_key(l:jobinfo.opts, 'on_stderr')
            call l:jobinfo.opts.on_stderr(a:jobid, a:data, a:event)
        endif
    endif
endfunction

function! s:on_exit(jobid, status, event) abort
    if has_key(s:jobs, a:jobid)
        let l:jobinfo = s:jobs[a:jobid]
        if has_key(l:jobinfo.opts, 'on_exit')
            call l:jobinfo.opts.on_exit(a:jobid, a:status, a:event)
        endif
    endif
endfunction

function! s:job_start(cmd, opts) abort
    let l:jobtypes = s:job_supported_types()
    let l:jobtype = ''

    if has_key(a:opts, 'type')
        if type(a:opts.type) == type('')
            if !s:job_supports_type(a:opts.type)
                return s:job_error_unsupported_job_type
            endif
            let l:jobtype = a:opts.type
        else
            let l:jobtypes = a:opts.type
        endif
    endif

    if empty(l:jobtype)
        " find the best jobtype
        for l:jobtype2 in l:jobtypes
            if s:job_supports_type(l:jobtype2)
                let l:jobtype = l:jobtype2
            endif
        endfor
    endif

    if l:jobtype ==? ''
        return s:job_error_unsupported_job_type
    endif

    if l:jobtype == s:job_type_nvimjob
        let l:job = jobstart(a:cmd, {
            \ 'on_stdout': function('s:on_stdout'),
            \ 'on_stderr': function('s:on_stderr'),
            \ 'on_exit': function('s:on_exit'),
        \})
        if l:job <= 0
            return l:job
        endif
        let l:jobid = l:job " nvimjobid and internal jobid is same
        let s:jobs[l:jobid] = {
            \ 'type': s:job_type_nvimjob,
            \ 'opts': a:opts,
        \ }
        let s:jobs[l:jobid].job = l:job
    elseif l:jobtype == s:job_type_vimjob
        let s:jobidseq = s:jobidseq + 1
        let l:jobid = s:jobidseq
        let l:job  = job_start(a:cmd, {
            \ 'out_cb': function('s:out_cb', [l:jobid, a:opts]),
            \ 'err_cb': function('s:err_cb', [l:jobid, a:opts]),
            \ 'exit_cb': function('s:exit_cb', [l:jobid, a:opts]),
            \ 'mode': 'raw',
        \})
        if job_status(l:job) !=? 'run'
            return -1
        endif
        let s:jobs[l:jobid] = {
            \ 'type': s:job_type_vimjob,
            \ 'opts': a:opts,
            \ 'job': l:job,
            \ 'channel': job_getchannel(l:job),
            \ 'buffer': ''
        \ }
    else
        return s:job_error_unsupported_job_type
    endif

    return l:jobid
endfunction

function! s:job_stop(jobid) abort
    if has_key(s:jobs, a:jobid)
        let l:jobinfo = s:jobs[a:jobid]
        if l:jobinfo.type == s:job_type_nvimjob
            call jobstop(a:jobid)
        elseif l:jobinfo.type == s:job_type_vimjob
            call job_stop(s:jobs[a:jobid].job)
        endif
        if has_key(s:jobs, a:jobid)
            call remove(s:jobs, a:jobid)
        endif
    endif
endfunction

function! s:job_send(jobid, data) abort
    let l:jobinfo = s:jobs[a:jobid]
    if l:jobinfo.type == s:job_type_nvimjob
        call jobsend(a:jobid, a:data)
    elseif l:jobinfo.type == s:job_type_vimjob
        let l:jobinfo.buffer .= a:data
        call s:flush_vim_sendraw(a:jobid, v:null)
    endif
endfunction

function! s:flush_vim_sendraw(jobid, timer) abort
    " https://github.com/vim/vim/issues/2548
    " https://github.com/natebosch/vim-lsc/issues/67#issuecomment-357469091
    let l:jobinfo = s:jobs[a:jobid]
    if len(l:jobinfo.buffer) <= 1024
        call ch_sendraw(l:jobinfo.channel, l:jobinfo.buffer)
        let l:jobinfo.buffer = ''
    else
        let l:to_send = l:jobinfo.buffer[:1023]
        let l:jobinfo.buffer = l:jobinfo.buffer[1024:]
        call ch_sendraw(l:jobinfo.channel, l:to_send)
        call timer_start(1, function('s:flush_vim_sendraw', [a:jobid]))
    endif
endfunction

function! s:job_wait_single(jobid, timeout, start) abort
    if !has_key(s:jobs, a:jobid)
        return -3
    endif

    let l:jobinfo = s:jobs[a:jobid]
    if l:jobinfo.type == s:job_type_nvimjob
        let l:timeout = a:timeout - reltimefloat(reltime(a:start)) * 1000
        return jobwait([a:jobid], float2nr(l:timeout))[0]
    elseif l:jobinfo.type == s:job_type_vimjob
        let l:timeout = a:timeout / 1000.0
        try
            while l:timeout < 0 || reltimefloat(reltime(a:start)) < l:timeout
                let l:info = job_info(l:jobinfo.job)
                if l:info.status ==# 'dead'
                    return l:info.exitval
                elseif l:info.status ==# 'fail'
                    return -3
                endif
                sleep 1m
            endwhile
        catch /^Vim:Interrupt$/
            return -2
        endtry
    endif
    return -1
endfunction

function! s:job_wait(jobids, timeout) abort
    let l:start = reltime()
    let l:exitcode = 0
    let l:ret = []
    for l:jobid in a:jobids
        if l:exitcode != -2  " Not interrupted.
            let l:exitcode = s:job_wait_single(l:jobid, a:timeout, l:start)
        endif
        let l:ret += [l:exitcode]
    endfor
    return l:ret
endfunction

" public apis {{{
function! minpac#job#start(cmd, opts) abort
    return s:job_start(a:cmd, a:opts)
endfunction

function! minpac#job#stop(jobid) abort
    call s:job_stop(a:jobid)
endfunction

function! minpac#job#send(jobid, data) abort
    call s:job_send(a:jobid, a:data)
endfunction

function! minpac#job#wait(jobids, ...) abort
    let l:timeout = get(a:000, 0, -1)
    return s:job_wait(a:jobids, l:timeout)
endfunction
" }}}
