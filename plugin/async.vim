if exists('g:async_vim')
    finish
endif
let g:async_vim = 1

" :AsyncEmbed path=./autoload/myplugin/job.vim namespace=myplugin#job
command! -nargs=+ AsyncEmbed :call async#embedder#embed(<f-args>)
