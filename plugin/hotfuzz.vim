if exists('g:loaded_hotfuzz')
  finish
endif
let g:loaded_hotfuzz = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

command! -complete=customlist,hotfuzz#complete -nargs=1 HotFuzz
\ call hotfuzz#find(<f-args>)

command! HotFuzzToArgs call hotfuzz#to_args()

if !hasmapto("\<C-d>", 'c')
  cnoremap <expr> <C-d> hotfuzz#ctrld()
endif

let &cpoptions = s:save_cpo
