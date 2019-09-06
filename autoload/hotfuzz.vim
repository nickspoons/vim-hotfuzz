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
    let parts = s:split_path(a:search)
  else
    " When tab-completion is used with search segments ('fo ba' for 'foo.bar'),
    " a:search will only include the last segment. Use a:cmdline to find the other
    " segments
    let cmdargs = s:split_path(a:cmdline[:a:cursorpos - 1])
    if len(cmdargs) > 2
      let parts = cmdargs[1:]
    else
      let parts = [a:search]
    endif
  endif

  let fd_flags = get(g:, 'hotfuzz_fd_flags', '') . ' '

  " A '!' argument means include ignored files/dirs from e.g. .gitignore
  let idx = index(parts, '!')
  if idx >= 0
    if index(split(fd_flags), '-I') < 0
      let fd_flags .= '-I '
    endif
    call remove(parts, idx)
  endif

  " A '.' argument means hidden files/dirs should be searched
  let idx = index(parts, '.')
  if idx >= 0
    if index(split(fd_flags), '-H') < 0
      let fd_flags .= '-H '
    endif
    call remove(parts, idx)
  endif

  let file_parts = []
  let path_parts = []
  let in_path = 0
  for part in reverse(parts)
    if !len(part)
      continue
    endif
    if stridx(part, '/') >= 0 || len(path_parts)
      call insert(path_parts, part, 0)
    else
      call insert(file_parts, part, 0)
    endif
  endfor

  if executable('fd')
    let sep = '.*'
    let file_fuzzed = sep . join(file_parts, sep) . sep
    let path_fuzzed = sep . join(path_parts, sep) . sep
    let cmd = 'fd ' . fd_flags . '-t f "' . file_fuzzed . '"'
    let s:last_matches = split(system(cmd), "\n")
    if len(path_parts)
      call filter(s:last_matches, {i,v -> v =~? path_fuzzed})
    endif
  else
    let sep = '*'
    let fuzzed = sep . join(path_parts + file_parts, sep) . sep
    let s:last_matches = globpath('**', fuzzed, 1, 1)
  endif

  let s:search = file_parts
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
    let new_cmd = cmdargs[0] . ' ' . join(path_parts + file_parts, sep)
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

function! s:split_path(search) abort
  return split(substitute(a:search, '/', ' /', 'g'), '\( \|/\zs\)')
endfunction

function! s:sort(p1, p2) abort
  let f1 = fnamemodify(a:p1, ':t')
  let f2 = fnamemodify(a:p2, ':t')
  let search = join(s:search)
  if f1 =~# '^' . search               " f1 is case-sensitive match from start
    return f2 =~# '^' . search ? s:shorterByFileOrPath(f1, a:p1, f2, a:p2) : -1
  elseif f2 =~# '^' . search           " f2 is case-sensitive match from start
    return 1
  elseif f1 =~? '^' . search           " f1 is case-insensitive match from start
    return f2 =~? '^' . search ? s:shorterByFileOrPath(f1, a:p1, f2, a:p2) : -1
  elseif f2 =~? '^' . search           " f2 is case-insensitive match from start
    return 1
  else                                 " length comparison on entire path
    return s:shorterByFileOrPath(f1, a:p1, f2, a:p2)
  endif
endfunction

function! s:shorterByFileOrPath(f1, p1, f2, p2) abort
  if len(a:f1) - len(a:f2) != 0
    return len(a:f1) - len(a:f2)       " length comparison on filenames
  else
    return len(a:p1) - len(a:p2)       " length comparison on entire string
  endif
endfunction

let &cpoptions = s:save_cpo
