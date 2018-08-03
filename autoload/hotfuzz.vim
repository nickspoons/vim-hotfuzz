let s:save_cpo = &cpoptions
set cpoptions&vim

function! hotfuzz#find(filename) abort
  if filereadable(a:filename)
    execute 'edit' a:filename
  else
    let matches = hotfuzz#complete(a:filename, -1, -1)
    if len(matches) > 0
      execute 'edit' matches[0]
    else
      echohl Special | echo 'No matches' | echohl None
    endif
  endif
endfunction

function! hotfuzz#complete(search, cmdline, cursorpos) abort
  if exists('s:multi_segment_matches')
    let matches = s:multi_segment_matches
    unlet s:multi_segment_matches
    return matches
  endif

  if a:cmdline == -1
    let s:search = split(a:search, ' ')
  " When tab-completion is used with search segments ('fo ba' for 'foo.bar'),
  " a:search will only include the last segment. Use a:cmdline to find the other
  " segments
  else
    let cmdargs = split(a:cmdline)
    if len(cmdargs) > 2
      let s:search = cmdargs[1:]
    else
      let s:search = [a:search]
    endif
  endif

  if executable('fd')
    let sep = '.*'
    let fuzzy = sep . join(s:search, sep) . sep
    let flags = get(g:, 'hotfuzz_fd_flags', '')
    let cmd = 'fd ' . flags . ' -t f "' . fuzzy . '"'
    let matches = split(system(cmd), "\n")
  else
    let sep = '*'
    let fuzzy = sep . join(s:search, sep) . sep
    let matches = globpath('**', fuzzy, 1, 1)
  endif

  call sort(matches, 's:sort')

  if len(matches) && a:cmdline != -1 && len(cmdargs) > 2
    " The command contains segments (i.e. :HotFuzz fo ba) and matches have
    " been found. However, returning results at this point will only replace the
    " last segment, and leave the command looking like this:
    "   :HotFuzz fo foo.bar
    " To work around this strange state, the matches are stored in a temporary
    " variable, and the entire command is cancelled and rebuilt and again
    " tab-completed. This time, however, the previous matches are displayed.
    let s:multi_segment_matches = matches
    let new_cmd = cmdargs[0] . ' ' . join(s:search, sep)
    echom new_cmd
    call feedkeys("\<C-c>:" . new_cmd . nr2char(&wildcharm), 'i')
  endif

  return matches
endfunction

function! s:sort(s1, s2) abort
  let s1 = fnamemodify(a:s1, ':t')
  let s2 = fnamemodify(a:s2, ':t')
  let search = join(s:search)
  if s1 =~# '^' . search                 " s1 is case-sensitive match from start
    return s2 =~# '^' . search ? len(s1) - len(s2) : -1
  elseif s2 =~# '^' . search             " s2 is case-sensitive match from start
    return 1
  elseif s1 =~? '^' . search           " s1 is case-insensitive match from start
    return s2 =~? '^' . search ? len(s1) - len(s2) : -1
  elseif s2 =~? '^' . search           " s2 is case-insensitive match from start
    return 1
  else                                        " length comparison on entire path
    return len(a:s1) - len(a:s2)
  endif
endfunction

let &cpoptions = s:save_cpo
