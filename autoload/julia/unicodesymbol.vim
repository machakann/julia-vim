let s:LaTex_pattern = '\m\\\%([_\^][-+=()[:alnum:]]*\|\d\+\/\d*\|\w\+\|:[-+_[:alnum:]]\+:\)$'

let julia#unicodesymbol#__startcol__ = -1
let julia#unicodesymbol#__matches__ = []

function! julia#unicodesymbol#complete(...) abort
  let fallbackkey = get(a:000, 0, "\<Tab>")
  let line = getline('.')[: col('.')-1]
  if line is# ''
    return fallbackkey
  endif

  let [prefix, startcol, _] = matchstrpos(line, s:LaTex_pattern)
  if startcol < 0
    return fallbackkey
  endif

  if !exists('s:LaTex_list')
    let dict = julia_latex_symbols#get_dict()
    let s:LaTex_list = map(items(dict), '{"word": v:val[1], "menu": v:val[0]}')
  endif
  let pat = '^' . s:escape(prefix)
  let g:julia#unicodesymbol#__startcol__ = startcol + 1
  let g:julia#unicodesymbol#__matches__ = filter(copy(s:LaTex_list), 'v:val.menu =~# pat')
  call complete(g:julia#unicodesymbol#__startcol__, g:julia#unicodesymbol#__matches__)
  return ''
endfunction

function! s:escape(string) abort
    return escape(a:string, '~"\.^$[]*')
endfunction

" vim:set ts=2 sts=2 sw=2 tw=0:
