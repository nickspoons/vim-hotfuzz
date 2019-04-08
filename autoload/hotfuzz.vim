let s:save_cpo = &cpoptions
set cpoptions&vim

function! hotfuzz#find(filename) abort
  if filereadable(a:filename)
    execute 'edit' a:filename
  else
    let s:last_matches = hotfuzz#complete(a:filename, -1, -1)
    if len(s:last_matches) > 0
      if len(s:last_matches) > 1
        echon 'Opening first of '
        echohl Special | echon len(s:last_matches) | echohl None
        echon ' matches: ' . s:last_matches[0]
      endif
      execute 'silent edit' s:last_matches[0]
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
    " TODO: add flags for including -H (hidden) and -I (ignored) flags
    " Perhaps a bang for -I and '.' as the first segment for -H
    let cmd = 'fd ' . flags . ' -H -E /.git/ -t f "' . fuzzy . '"'
    let s:last_matches = split(system(cmd), "\n")
  else
    let sep = '*'
    let fuzzy = sep . join(s:search, sep) . sep
    let s:last_matches = globpath('**', fuzzy, 1, 1)
  endif

  call sort(s:last_matches, 's:sort')

  let matches = s:last_matches

  if len(s:last_matches) && a:cmdline != -1 && len(cmdargs) > 2
    " The command contains segments (i.e. :HotFuzz fo ba) and matches have
    " been found. However, returning results at this point will only replace the
    " last segment, and leave the command looking like this:
    "   :HotFuzz fo foo.bar
    " To work around this strange state, the matches are stored in a temporary
    " variable, and the entire command is cancelled and rebuilt and again
    " tab-completed. This time, however, the previous matches are displayed.
    let s:multi_segment_matches = s:last_matches
    let new_cmd = cmdargs[0] . ' ' . join(s:search, sep)
    let matches = [a:search]
    call feedkeys("\<C-c>:" . new_cmd . nr2char(&wildcharm), 'i')
  endif

  return matches
endfunction

function! hotfuzz#to_args() abort
  if !exists('s:last_matches')
    echohl Special
    echo 'Run :HotFuzz first, then convert the results to an args list'
    echohl None
    return
  endif
  try
    execute 'arglocal' join(s:last_matches)
  catch /E37/
    echohl WarningMsg
    echo 'Vim doesn''t like that - save this buffer first'
    echohl None
  endtry
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
