let s:save_cpo = &cpoptions
set cpoptions&vim

let s:Async = julia#lib#Async#import()

function! julia#pkg#completion#installed(base, ...) abort
  let commandspec = {
    \   'name'    : 'status',
    \   'args'    : [],
    \   'project' : '@.',
    \ }
  let cmd = julia#pkg#build_command(commandspec)
  let status = s:Async.call_fetch(cmd)
  let compl_list = map(status, 'julia#pkg#split_package_info(v:val)[3]')
  call filter(compl_list, 'v:val isnot# ""')
  return join(compl_list, "\n")
endfunction


function! julia#pkg#completion#remote(base, ...) abort
  if exists('$JULIA_DEPOT_PATH') && isdirectory($JULIA_DEPOT_PATH)
    let registriespath = s:joinpath($JULIA_DEPOT_PATH, 'registries')
  else
    let registriespath = s:joinpath('~', '.julia', 'registries')
  endif
  if a:base is# ''
    " List all items (very slow)
    let candidates = s:dir_including(registriespath, '**', 'Package.toml')
    return join(candidates, "\n")
  endif

  let compl_list = []
  let registries = glob(s:joinpath(registriespath, '*'), 1, 1)
  " Search in General
  let i = match(registries, '\CGeneral$')
  if i != -1
    let General = registries[i]
    let candidates = s:dir_including(General, a:base[0], a:base . '*', 'Package.toml')
    call extend(compl_list, candidates)
    call remove(registries, i)
  endif
  " Search in private registries
  let matchpat = '\m^' . s:escape(a:base)
  for reg in registries
    let candidates = s:dir_including(reg, '**', 'Package.toml')
    call filter(candidates, 'v:val =~# matchpat')
    call extend(compl_list, candidates)
  endfor
  return join(compl_list, "\n")
endfunction


function! julia#pkg#completion#add_dev(base, ...) abort
  let compl_list = []
  " Search package directory under the current directory
  let candidates = s:dir_including('.', '*', 'Project.toml')
  call map(candidates, 'v:val . s:SEPARATOR')
  if candidates == []
    let candidates = s:dir_including('.', '*', 'JuliaProject.toml')
    call map(candidates, 'v:val . s:SEPARATOR')
  endif
  call extend(compl_list, candidates)
  if a:base =~# '\m\\'
    return join(compl_list, "\n")
  endif

  " Append stdlib packages
  let stdlibpath = s:stdlibpath()
  let candidates = s:dir_including(stdlibpath, '*', 'Project.toml')
  let matchpat = '\m^' . s:escape(a:base)
  call filter(candidates, 'v:val =~# matchpat')
  call extend(compl_list, candidates)
  " Add remote packages
  let remotepackages = julia#pkg#completion#remote(a:base)
  call add(compl_list, remotepackages)
  return join(compl_list, "\n")
endfunction


let s:SEPARATOR = has('win32') && !&shellslash ? '\' : '/'
function! s:joinpath(...) abort
  let pat = printf('%s$', escape(s:SEPARATOR, '\'))
  let elements = map(copy(a:000), 'substitute(v:val, pat, "", "")')
  return join(elements, s:SEPARATOR)
endfunction


let s:STDLIBEXPR = 'println(normpath(joinpath(Sys.BINDIR, "..", "share", "julia", "stdlib", "v$(VERSION.major).$(VERSION.minor)")))'
function! s:stdlibpath() abort
  let cmd = [g:julia#pkg#juliapath, '-e', s:STDLIBEXPR]
  let stdlibpath = s:Async.call_fetch(cmd)[0]
  return stdlibpath
endfunction


function! s:dir_including(...) abort
  let globpat = call('s:joinpath', a:000)
  let paths = glob(globpat, 1, 1)
  return map(paths, 's:basedirname(v:val)')
endfunction


function! s:basedirname(filepath) abort
  return fnamemodify(a:filepath, ':p:h:t')
endfunction


" Escape characters which have special meaning in regular expression
function! s:escape(string) abort
  return escape(a:string, '~"\.^$[]*')
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set ts=2 sts=2 sw=2 tw=0:
