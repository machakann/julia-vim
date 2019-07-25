let s:save_cpo = &cpoptions
set cpoptions&vim


function! julia#pkg#test#result(output) abort
  if s:iserrored(a:output)
    " open preview window if any error (not just fail) happens
    call s:write_to_preview_window(a:output, 'JuliaPkgTest: output')
  endif
  call s:setqflist(a:output)
  call s:echo_results(a:output)
endfunction


function! s:iserrored(output) abort
  return filter(copy(a:output), 'v:val =~# ''^\s*ERROR: ''') != []
endfunction


function! s:write_to_preview_window(content, buffername) abort
  " Are we in the preview window from the outset? If not, best to close any
  " preview windows that might exist.
  let pvw = &previewwindow
  if !pvw
    silent! pclose!
  endif
  execute "silent! pedit +setlocal\\ nobuflisted\\ noswapfile\\"
        \ "buftype=nofile\\ bufhidden=wipe" a:buffername
  silent! wincmd P
  if &previewwindow
    setlocal modifiable noreadonly
    silent! %delete _
    call append(0, a:content)
    silent! $delete _
    normal! ggj
    setlocal nomodified readonly nomodifiable
    " Only return to a normal window if we didn't start in a preview window.
    if !pvw
      silent! wincmd p
    endif
  else
    " We couldn't make it to the preview window, so as a fallback we dump the
    " contents in the status area.
    execute printf("echo '%s'", join(a:content, "\n"))
  endif
endfunction


function! s:setqflist(output) abort
  let qflist = s:parse_test_output(a:output)
  if qflist != []
    call setqflist(qflist)
  endif
endfunction


function! s:parse_test_output(output) abort
  let i = 0
  let n = len(a:output)
  let qflist = []
  while i < n
    if a:output[i] =~# '\C: Test Failed at '
      let [qfitem, i] = s:parse_failed(a:output, i)
    elseif a:output[i] =~# '\C: Error During Test at '
      let [qfitem, i] = s:parse_errored(a:output, i)
    else
      let qfitem = {}
    endif
    if qfitem != {}
      call add(qflist, qfitem)
    endif
    let i += 1
  endwhile
  return qflist
endfunction


function! s:parse_failed(output, i) abort
  let failpat = '\C^\(.\{-}\): Test Failed at \(.\{-}\):\(\d*\)$'
  let ret = matchlist(a:output[a:i], failpat)
  if ret == []
    return [{}, a:i]
  endif
  let [title, file, lnum] = ret[1:3]
  if a:output[a:i + 2] =~# '\C^\s*Evaluated: '
    let i = a:i + 2
    let text = a:output[i]
  else
    " failed message in unknown format
    let [lines, i] = s:retrieve_until(a:output, '\m\C^\s*Stacktrace:', a:i)
    let text = join(lines)
  endif
  let qfitem = {
    \   'filename': file,
    \   'module': title,
    \   'lnum': lnum,
    \   'text': text,
    \   'type': 'F',
    \ }
  return [qfitem, i]
endfunction


function! s:parse_errored(output, i) abort
  let errorpat = '\C^\(.\{-}\): Error During Test at \(.\{-}\):\(\d*\)$'
  let ret = matchlist(a:output[a:i], errorpat)
  if ret == []
    return [{}, a:i]
  endif
  let [title, file, lnum] = ret[1:3]
  if a:output[a:i + 2] =~# '\C^\s*Expression: '
    let i = a:i + 3
  else
    " errored message in unknown format
    let i = a:i + 1
  endif
  let [lines, i] = s:retrieve_until(a:output, '\m\C^\s*Stacktrace:', i)
  let text = join(lines)
  let qfitem = {
    \   'filename': file,
    \   'module': title,
    \   'lnum': lnum,
    \   'text': text,
    \   'type': 'E',
    \ }
  return [qfitem, i]
endfunction


function! s:retrieve_until(lines, pat, ...) abort
  let i = get(a:000, 0, 0)
  let n = len(a:lines)
  let output = []
  while i < n
    if a:lines[i] =~# a:pat
      let i -= 1
      break
    endif
    call add(output, a:lines[i])
    let i += 1
  endwhile
  return [output, i]
endfunction


function! s:echo_results(output) abort
  for line in s:extract_results(a:output)
    if line =~# '\m^\S* tests passed$'
      echohl MoreMsg
    else
      echohl ErrorMsg
    endif
    echomsg line
  endfor
  echohl NONE
endfunction


function! s:extract_results(lines) abort
  let pat = '\C^\%(\s*Testing \zs\S* tests passed\ze\s*\|\s*ERROR: .*\)$'
  let output = map(copy(a:lines), 'matchstr(v:val, pat)')
  return filter(output, 'v:val isnot# ""')
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set ts=2 sts=2 sw=2 tw=0:
