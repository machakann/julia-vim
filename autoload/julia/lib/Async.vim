let s:save_cpo = &cpoptions
set cpoptions&vim

if has('nvim')

"===== for neovim (from here) =====
function! s:job_options(dict) abort
  let opt = {}
  if has_key(a:dict, 'out_cb')
    let opt.on_stdout = a:dict.out_cb
  endif
  if has_key(a:dict, 'err_cb')
    let opt.on_stderr = a:dict.err_cb
  endif
  if has_key(a:dict, 'exit_cb')
    let opt.on_exit = a:dict.exit_cb
  endif
  return opt
endfunction

function! s:job_start(cmd, ...) abort
  let opt = get(a:000, 0, {})
  return jobstart(a:cmd, opt)
endfunction

function! s:job_wait(id, ...) abort
  let timeout = get(a:000, 0, 10000)
  call jobwait(a:id, timeout)
endfunction

function! s:read_output(job, id, data, event) abort
  if a:job.output == []
    call add(a:job.output, '')
  endif
  let a:job.output[-1] .= a:data[0]
  call extend(a:job.output, a:data[1:])
endfunction
"===== for neovim (until here) =====

else

"===== for vim (from here) =====
function! s:job_options(dict) abort
  return a:dict
endfunction

function! s:job_start(cmd, ...) abort
  let opt = get(a:000, 0, {})
  return job_start(a:cmd, opt)
endfunction

function! s:job_wait(jobs, ...) abort
  let jobs = copy(a:jobs)
  let timeout = get(a:000, 0, 10000)
  let starttime = reltime()
  while filter(jobs, 'job_status(v:val) ==# "run"') != []
    let elapsed = reltimefloat(reltime(starttime))*1000
    if elapsed > timeout
      break
    endif
    " sleep for callbacks
    sleep 1m
  endwhile
endfunction

function! s:read_output(job, ch, msg) abort
  call add(a:job.output, a:msg)
endfunction
"===== for vim (until here) =====

endif


let s:Job = {
  \   'cmd': [],
  \   'jobopt': {},
  \   'job': 0,
  \   'output': [],
  \ }

function! s:Job.start(...) abort
  let self.jobopt = s:job_options(get(a:000, 0, self.jobopt))
  let self.job = s:job_start(self.cmd, self.jobopt)
  return self
endfunction

function! s:Job.wait(...) abort
  call call('s:job_wait', [[self.job]] + a:000)
  return self
endfunction

function! s:Job.is_started() abort
  return self.job isnot# 0
endfunction


" Job constructor
function! s:Job(cmd, ...) abort
  let job = deepcopy(s:Job)
  let job.cmd = a:cmd
  let job.jobopt = s:job_options(get(a:000, 0, {}))
  return job
endfunction


" run a command asynchronously and exit immediately
" its output can be retrieved by Async.fetch()
" the optional argument is a callback function called when the job finished
function! s:call(cmd, ...) abort
  let job = s:Job(a:cmd)
  let opt = {'out_cb': function('s:read_output', [job]),
           \ 'err_cb': function('s:read_output', [job])}
  if a:0 > 0
    let l:Callback = a:1
    let opt.exit_cb = {-> l:Callback(job)}
  endif
  return job.start(opt)
endfunction


" fetch output of a job started by Async.call()
function! s:fetch(job) abort
  if !a:job.is_started()
    call a:job.start()
  endif
  call a:job.wait()
  return copy(a:job.output)
endfunction


" short-hand of Async.fetch(Async.call(...))
" it works like system(), but without running shell, it avoids cmd.exe
" flickering in windows os
function! s:call_fetch(...) abort
  return s:fetch(call('s:call', a:000))
endfunction


" export
" NOTE: Do not define like 'function s:Async.call(...)' to avoid the ':func-dict' attribute
let s:Async = {}
let s:Async.Job = function('s:Job')
let s:Async.call = function('s:call')
let s:Async.fetch = function('s:fetch')
let s:Async.call_fetch = function('s:call_fetch')
function! julia#lib#Async#import() abort
  return s:Async
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set ts=2 sts=2 sw=2 tw=0:
