if exists('g:loaded_hotfuzz')
  finish
endif
let g:loaded_hotfuzz = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

command! -complete=customlist,hotfuzz#complete -nargs=1 HotFuzz
\ call hotfuzz#find(<f-args>)

let &cpoptions = s:save_cpo
