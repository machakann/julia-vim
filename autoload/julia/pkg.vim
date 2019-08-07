scriptencoding utf-8
let s:save_cpo = &cpoptions
set cpoptions&vim

let s:Async = julia#lib#Async#import()

" path to the julia binary to communicate with
if has('win32') || has('win64')
  if exists('g:julia#pkg#juliapath')
    " use assigned g:julia#pkg#juliapath
  elseif executable('julia')
    " use julia command in PATH
    let g:julia#pkg#juliapath = 'julia'
  else
    " search julia binary in the default installation paths
    let pathlist = sort(glob($LOCALAPPDATA . '\Julia-*\bin\julia.exe', 1, 1))
    let g:julia#pkg#juliapath = get(pathlist, -1, 'julia')
  endif
else
  let g:julia#pkg#juliapath = get(g:, 'julia#pkg#juliapath', 'julia')
endif


function! julia#pkg#status(...) abort
  let commandspec = {
    \   'name'    : 'status',
    \   'args'    : get(a:000, 0, []),
    \   'project' : get(a:000, 1, '@.'),
    \ }
  let cmd = julia#pkg#build_command(commandspec)
  let output = s:Async.call_fetch(cmd)
  let msglist = s:status_message(output)
  call s:echohl(msglist)
endfunction


function! julia#pkg#add(args, ...) abort
  let commandspec = {
    \   'name'    : 'add',
    \   'args'    : a:args,
    \   'project' : get(a:000, 0, '@.'),
    \ }
  let cmd = julia#pkg#build_command(commandspec)
  call s:Async.call(cmd, {j -> s:result(j, 'Add')})
endfunction


function! julia#pkg#remove(args, ...) abort
  let commandspec = {
    \   'name'    : 'rm',
    \   'args'    : a:args,
    \   'project' : get(a:000, 0, '@.'),
    \ }
  let cmd = julia#pkg#build_command(commandspec)
  call s:Async.call(cmd, {j -> s:result(j, 'Remove')})
endfunction


function! julia#pkg#resolve(...) abort
  let commandspec = {
    \   'name'    : 'resolve',
    \   'args'    : [],
    \   'project' : get(a:000, 0, '@.'),
    \ }
  let cmd = julia#pkg#build_command(commandspec)
  call s:Async.call(cmd, {j -> s:result(j, 'Resolve')})
endfunction


function! julia#pkg#test(...) abort
  let commandspec = {
    \   'name'    : 'test',
    \   'args'    : get(a:000, 0, []),
    \   'project' : get(a:000, 1, '@.'),
    \ }
  let cmd = julia#pkg#build_command(commandspec)
  call s:Async.call(cmd, function('s:test_result'))
endfunction


function! julia#pkg#build_command(commandspec, ...) abort
  let juliapath = get(a:000, 0, g:julia#pkg#juliapath)
  let project = s:project(a:commandspec)
  let arguments = s:arguments(a:commandspec)
  let juliaexprlist = ['import Pkg']
  let juliaexprlist += [printf('Pkg.%s(%s)', a:commandspec.name, arguments)]
  let juliaexpr = join(juliaexprlist, ';')
  if s:iswindows()
    return printf('%s %s %s "%s"', juliapath, project, '-e', escape(juliaexpr, '"'))
  else
    return [juliapath, project, '-e', juliaexpr]
  endif
endfunction


function! s:project(commandspec) abort
  let project = a:commandspec.project
  return project is# '' ? '' : '--project=' . project
endfunction


function! s:arguments(commandspec) abort
  if empty(a:commandspec.args)
    return ''
  elseif type(a:commandspec.args) == type('')
    return '"' . a:commandspec.args . '"'
  elseif type(a:commandspec.args) == type([])
    let packagelist = map(copy(a:commandspec.args), 's:rawquote(v:val)')
    return '[' . join(packagelist, ',') . ']'
  endif
  echoerr 'Invalid type of arguments'
endfunction


function! s:rawquote(str) abort
  return printf('raw"%s"', a:str)
endfunction


function! s:default_higroup() abort
  highlight default JuliaPkgRed          ctermfg=1  guifg=#800000
  highlight default JuliaPkgLightBlack   ctermfg=8  guifg=#808080
  highlight default JuliaPkgLightRed     ctermfg=9  guifg=#cc0000
  highlight default JuliaPkgLightGreen   ctermfg=10 guifg=#00cc00
  highlight default JuliaPkgLightYellow  ctermfg=11 guifg=#cccc00
  highlight default JuliaPkgLightMagenta ctermfg=13 guifg=#cc00cc
  highlight default JuliaPkgLightCyan    ctermfg=14 guifg=#00cccc
endfunction
augroup JuliaPkgDefaultHighlight
  autocmd!
  autocmd ColorScheme * call s:default_higroup()
augroup END
call s:default_higroup()


let s:SIGNDICT = {
  \   ' ': 'Normal',
  \   '+': 'JuliaPkgLightGreen',
  \   '-': 'JuliaPkgLightRed',
  \   '↑': 'JuliaPkgLightYellow',
  \   '~': 'JuliaPkgLightYellow',
  \   '↓': 'JuliaPkgLightMagenta',
  \   '?': 'JuliaPkgRed',
  \ }

let s:PACKAGEPAT  = '^'
" Header sign
let s:PACKAGEPAT .= '\(\s*[ →]\s*\)\?'
" UUID e.g. '[1234abcd]'
let s:PACKAGEPAT .= '\(\[[[:alnum:]]\+\]\s\)'
" Verb sign e.g. '+', '-'
let s:PACKAGEPAT .= '\([' . escape(join(keys(s:SIGNDICT), ''), ']^-\') . ']\s*\)\?'
" Package name
let s:PACKAGEPAT .= '\(\h\w*\s*\)\?'
" Rest parts
let s:PACKAGEPAT .= '\(.*\)'
let s:PACKAGEPAT .= '\s*'
let s:PACKAGEPAT .= '$'


function! s:parse(output) abort
  let parsed = []
  for line in a:output
    if line =~# '^Project\s\+'
      call add(parsed, ['project', matchstr(line, '^Project\s\+\zs.*')])
    elseif line =~# '^    Status\s\+'
      call add(parsed, ['status', matchstr(line, '^    Status\s\+\zs.*')])
    elseif line =~# s:PACKAGEPAT
      call add(parsed, ['package', julia#pkg#split_package_info(line)])
    else
      call add(parsed, ['unknown', line])
    endif
  endfor
  return parsed
endfunction


function! julia#pkg#split_package_info(line) abort
  let parts = matchlist(a:line, s:PACKAGEPAT)[1:5]
  return parts == [] ? ['', '', '', '', ''] : parts
endfunction


function! s:status_message(output) abort
  let msglist = []
  for [typ, parts] in s:parse(a:output)
    if typ is# 'project'
      call add(msglist, [['Project ', 'JuliaPkgLightCyan'],
                       \ [parts, 'Normal']])
    elseif typ is# 'status'
      call add(msglist, [['    Status ', 'JuliaPkgLightGreen'],
                       \ [parts, 'Normal']])
    elseif typ is# 'package'
      let [header, UUID, verb, name, rest] = parts
      let hlgroup = get(s:SIGNDICT, s:trim(verb), 'Normal')
      call add(msglist, [[header, 'JuliaPkgRed'],
                       \ [UUID, 'JuliaPkgLightBlack'],
                       \ [verb . name . rest, hlgroup]])
    else
      call add(msglist, [[parts, 'Normal']])
    endif
  endfor
  return msglist
endfunction


if exists('*trim')
  function! s:trim(str) abort
    return trim(a:str)
  endfunction
else
  function! s:trim(str) abort
    return substitute(a:str, '\%(^[[:space:]]\+\|[[:space:]]\+$\)', '', 'g')
  endfunction
endif


function! s:echohl(lines) abort
  if a:lines == []
    return
  endif
  for lineparts in a:lines
    call s:echohl_line(lineparts)
  endfor
endfunction


function! s:echohl_line(lineparts) abort
  if a:lineparts == []
    return
  endif
  let first = a:lineparts[0]
  execute 'echohl' first[1]
  echo first[0]
  for i in range(1, len(a:lineparts) - 1)
    let [text, higroup] = a:lineparts[i]
    if text is# ''
      continue
    endif
    execute 'echohl' higroup
    echon text
  endfor
  echohl NONE
endfunction


function! s:result(job, name) abort
  call s:doautocmd(a:name)
  let output = s:Async.fetch(a:job)
  call s:echomsgall(output)
endfunction


function! s:test_result(job) abort
  call s:doautocmd('Test')
  let output = s:Async.fetch(a:job)
  call julia#pkg#test#result(output)
endfunction


function! s:doautocmd(name) abort
  let autocmd = printf('JuliaPkg%sDone', a:name)
  if exists('#User#' . autocmd)
    execute 'doautocmd User ' . autocmd
  endif
endfunction


function! s:echomsgall(lines) abort
  for l in a:lines
    echomsg l
  endfor
endfunction


" NOTE: has('win32') is true in any available windows os
let s:ISWINDOWS = has('win32')
function! s:iswindows() abort
  return s:ISWINDOWS
endfunction


" wait until the autocmd triggered (mainly for test)
function! julia#pkg#waitfor(autocmd, timeout) abort
  let g:julia#pkg#signal = 0
  augroup julia-vim-pkg-waitfor
    execute printf('autocmd User %s let g:julia#pkg#signal = 1', a:autocmd)
  augroup END
  let exitcode = 0
  let starttime = reltime()
  while g:julia#pkg#signal == 0
    if reltimefloat(reltime(starttime)) > a:timeout
      let exitcode = 1
      break
    endif
    sleep 1m
  endwhile
  augroup julia-vim-pkg-waitfor
    execute printf('autocmd User %s', a:autocmd)
  augroup END
  return exitcode
endfunction



let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set ts=2 sts=2 sw=2 tw=0:
