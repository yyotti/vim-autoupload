scriptencoding utf-8
"=============================================================================
" FILE: scp.vim
" AUTHOR: Y.Tsutsui
"=============================================================================
let s:save_cpo = &cpoptions
set cpoptions&vim

let s:jobs = {}
let s:vim_jobs = {}

function! autoupload#scp#upload(params) abort "{{{
  " TODO 処理をまとめる
  if has('nvim')
    call s:nvim_upload(a:params)
  elseif v:version >= 800 && has('job')
    call s:vim_job_upload(a:params)
  else
    call s:upload(a:params)
  endif
endfunction "}}}

function! s:nvim_upload(params) abort "{{{
  let l:remote = a:params.user . '@' . a:params.host

  let l:mkdir_cmd = [
        \   'ssh',
        \   l:remote,
        \   'mkdir',
        \   '-p',
        \   shellescape(a:params.remote_dir),
        \ ]

  let l:scp_cmd = [ 'scp' ]
  if a:params.timeout > 0
    let l:scp_cmd += [ '-o', 'ConnectTimeout ' . a:params.timeout ]
  endif
  let l:scp_cmd += [
        \   a:params.local_path,
        \   l:remote . ':' . a:params.remote_dir,
        \ ]

  let l:commands = [ l:mkdir_cmd, l:scp_cmd ]

  call s:start_job(l:commands, a:params.on_exit)
endfunction "}}}

function! s:start_job(commands, func) abort "{{{
  if empty(a:commands)
    return
  endif

  let l:cmd = a:commands[0]
  let l:next_commands = copy(a:commands)
  call remove(l:next_commands, 0)

  let l:options = {
        \   'on_stdout': function('s:on_progress'),
        \   'on_stderr': function('s:on_progress'),
        \   'on_exit': function('s:on_exit'),
        \ }

  let l:id = jobstart(l:cmd, l:options)

  let s:jobs[l:id] = {
        \   'id': l:id,
        \   'next_commands': l:next_commands,
        \   'lines': [],
        \   'func': a:func,
        \ }
endfunction "}}}

function! s:on_progress(job_id, data, ...) abort "{{{
  if !has_key(s:jobs, a:job_id)
    return
  endif

  let s:jobs[a:job_id].lines += a:data
endfunction "}}}

function! s:on_exit(job_id, data, ...) abort "{{{
  if !has_key(s:jobs, a:job_id)
    return
  endif

  let l:job = s:jobs[a:job_id]
  unlet s:jobs[a:job_id]

  if a:data != 0
    call l:job.func(join(l:job.lines, "\n"))
    return
  endif

  if empty(l:job.next_commands)
    call l:job.func('')
  else
    call s:start_job(l:job.next_commands, l:job.func)
  endif
endfunction "}}}

function! s:vim_job_upload(params) abort "{{{
  let remote = a:params.user . '@' . a:params.host

  let mkdir_cmd = [
        \   'ssh',
        \   remote,
        \   'mkdir',
        \   '-p',
        \   shellescape(a:params.remote_dir),
        \ ]

  let scp_cmd = [ 'scp' ]
  if a:params.timeout > 0
    let scp_cmd += [ '-o', 'ConnectTimeout ' . a:params.timeout ]
  endif
  let scp_cmd += [
        \   a:params.local_path,
        \   remote . ':' . a:params.remote_dir,
        \ ]

  let commands = [ mkdir_cmd, scp_cmd ]

  call s:start_vim_job(commands, a:params.on_exit)
endfunction "}}}

function! s:start_vim_job(commands, func) abort "{{{
  if empty(a:commands)
    return
  endif

  let cmd = a:commands[0]
  let next_commands = copy(a:commands)
  call remove(next_commands, 0)

  let options = {
        \   'out_cb': function('s:on_job_progress'),
        \   'err_cb': function('s:on_job_progress'),
        \   'exit_cb': function('s:on_job_exit'),
        \ }

  let job = job_start(l:cmd, l:options)

  let key = job_info(job).process
  let s:vim_jobs[key] = {
        \   'id': key,
        \   'next_commands': next_commands,
        \   'lines': [],
        \   'func': a:func,
        \ }
endfunction "}}}

function! s:on_job_progress(ch, data) abort "{{{
  let key = job_info(ch_getjob(a:ch)).status
  if !has_key(s:vim_jobs, key)
    return
  endif

  let s:vim_jobs[key].lines += a:data
endfunction "}}}

function! s:on_job_exit(job, status) abort "{{{
  let key = job_info(a:job).process
  if !has_key(s:vim_jobs, key)
    return
  endif

  let job = s:vim_jobs[key]
  unlet s:vim_jobs[key]
  "
  if a:status != 0
    call job.func(join(job.lines, "\n"))
    return
  endif

  if empty(job.next_commands)
    call job.func('')
  else
    call s:start_vim_job(job.next_commands, job.func)
  endif
endfunction "}}}

function! s:upload(params) abort "{{{
  let l:remote = shellescape(a:params.user) . '@' . shellescape(a:params.host)

  let l:cmd  = 'ssh'
  let l:cmd .= ' '
  let l:cmd .= l:remote
  let l:cmd .= ' '
  let l:cmd .= '"mkdir -p ' . shellescape(a:params.remote_dir) . '"'

  let l:cmd .= ' && '

  let l:cmd .= 'scp'
  if a:params.timeout > 0
    let l:cmd .= ' -o "ConnectTimeout ' . a:params.timeout . '"'
  endif
  let l:cmd .= ' '
  let l:cmd .= shellescape(a:params.local_path)
  let l:cmd .= ' '
  let l:cmd .= l:remote . ':' . shellescape(a:params.remote_dir)

  call autoupload#util#system(l:cmd, a:params.on_exit, a:params.async)
endfunction "}}}

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
