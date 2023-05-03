if exists("g:std_io_loaded")
  finish
endif
let g:std_io_loaded = 1

if !exists('g:std_io_map_default')
  let g:std_io_map_default = 1
endif

if !exists('g:std_io_window_height')
  let g:std_io_window_height = 15
endif

let g:std_io_plugin_dir = expand('<sfile>:p:h')

let g:std_io_run_commands = {'cpp': "'g++ -DLOCAL -Wall -Wextra -O2 -g -fsanitize=address -fsanitize=undefined -D_GLIBCXX_DEBUG --std=c++17 -o ' . expand('%:p:r') . '.o ' . expand('%:p') . ' && ' . expand('%:p:r') . '.o'", 'java': "'javac ' . expand('%:p') . ' && java ' . expand('%:r')", 'python': "'python3 ' . expand('%:p')" }

if exists('g:std_io_user_command')
  let arr = items(g:std_io_user_command)
  for item in arr
    let g:std_io_run_commands[item[0]] = item[1]
  endfor
endif

let g:std_io_input_history = {}
let g:std_io_input_buffer = ""
let g:std_io_output_buffer = ""
let g:std_io_current_file = ""
let g:std_io_current_file_buffer = ""
let g:std_io_command = ""
let g:std_io_input_index = -1

function! s:StdIOput_in_buffer(buffer, content)
  if a:buffer ==# ""
    return
  endif
  execute "sbuffer " . a:buffer
  silent 1,$delete _
  silent put! =a:content
  silent $delete _
endfunction

function! s:StdIOpush(input)
  if !has_key(g:std_io_input_history, g:std_io_current_file)
    let g:std_io_input_history[g:std_io_current_file] = []
  endif
  let temp = g:std_io_input_history[g:std_io_current_file]
  if a:input !=# '' && get(l:temp, -1, '') !=# a:input
    call add(l:temp, a:input)
    let g:std_io_input_history[g:std_io_current_file] = l:temp
  endif
endfunction

function! s:StdIOcreate_buffers(height)
  if g:std_io_input_buffer ==# ""
    let g:std_io_input_buffer = "std-input"
    let g:std_io_output_buffer = "std-output"
    execute a:height . "new ". g:std_io_output_buffer
    setlocal buftype=nofile noswapfile switchbuf=useopen
    execute "leftabove vnew ". g:std_io_input_buffer
    setlocal buftype=nofile noswapfile switchbuf=useopen
    nnoremap <buffer> <silent> <leader>] ggdG"*P
  endif
endfunction

function! s:StdIOdelete_buffers()
  if g:std_io_input_buffer !=# ""
    execute "bdelete " . g:std_io_input_buffer
    execute "bdelete " . g:std_io_output_buffer
    let g:std_io_input_buffer = ""
    let g:std_io_output_buffer = ""
  endif
endfunction

function! s:StdIOprepare()
  let g:std_io_current_file = expand('%:p')
  let g:std_io_current_file_buffer = expand('%')
  execute 'let g:std_io_command = ' . get(g:std_io_run_commands, &filetype, "''")
  call s:StdIOdelete_buffers()
  call s:StdIOcreate_buffers(g:std_io_window_height)
  let l:input = get(get(g:std_io_input_history, g:std_io_current_file, []), -1, '')
  execute "sbuffer " . g:std_io_input_buffer
  silent put! =l:input
  silent $delete _
endfunction

function! s:StdIOrun_case(input)
  silent! let l:output = system(g:std_io_command . " <<<'" . a:input ."'")
  return l:output
endfunction

function! s:StdIOrun(ignore_empty_input)
  if g:std_io_command ==# ""
    return
  endif
  execut "sbuffer " . g:std_io_input_buffer
  let l:input = join(getline(1, "$"), "\n")
  if !a:ignore_empty_input && l:input ==# ''
    return
  endif
  call s:StdIOpush(l:input)
  let g:std_io_input_index = -1
  call s:StdIOput_in_buffer(g:std_io_output_buffer, s:StdIOrun_case(l:input))
  execut "sbuffer " . g:std_io_input_buffer
endfunction

function! s:StdIOrun_all()
  if !has_key(g:std_io_input_history, g:std_io_current_file)
    return
  endif
  if g:std_io_input_buffer !=# expand('%') && g:std_io_output_buffer !=# expand('%')
    call s:StdIOprepare()
  endif
  let o = ""
  let j = 1
  for input in g:std_io_input_history[g:std_io_current_file]
    let l:o .= "<<< " . l:j . "\n"
    let l:o .= input . "\n"
    let l:o .= ">>> " . l:j . "\n"
    let t = s:StdIOrun_case(input)
    let l:o .= l:t . "\n"
    let l:j += 1
  endfor
  call s:StdIOput_in_buffer(g:std_io_output_buffer, l:o)
endfunction

function! s:StdIOgo(offset)
  if g:std_io_input_buffer !=# expand('%') && g:std_io_output_buffer !=# expand('%')
    call s:StdIOprepare()
  endif
  let l:offset = -1
  if a:offset !=# ''
    let l:offset = a:offset
  endif
  let l:input = get(get(g:std_io_input_history, g:std_io_current_file, []), g:std_io_input_index + l:offset, '')
  if g:std_io_input_index + l:offset < 0 && l:input !=# ''
    let g:std_io_input_index += l:offset
    call s:StdIOput_in_buffer(g:std_io_input_buffer, l:input)
  endif
endfunction

function! s:StdIOprepare_and_run(ignore)
  if g:std_io_input_buffer !=# expand('%') && g:std_io_output_buffer !=# expand('%')
    call s:StdIOprepare()
  endif
  call s:StdIOrun(a:ignore)
endfunction

function! s:StdIOOpenFile(file)
  execute 'edit ' . a:file
  if !empty(glob(a:file))
    return
  endif
  write
  let l:template_file = g:std_io_plugin_dir . '/../templates/template.' . &filetype
  if (filereadable(l:template_file))
    let l:template = system('cat ' . l:template_file)
    silent 1,$delete _
    silent put! =l:template
    silent $delete _
    write
  endif
  return
endfunction

function! s:StdIOUpdateTemplate(filetype) 
  let l:ext = a:filetype
  if a:filetype ==# ""
    let l:ext = &filetype
  endif
  let l:template_file = g:std_io_plugin_dir . '/../templates/template.' . l:ext
  execute 'new ' . l:template_file
endfunction

command! -nargs=? IO call s:StdIOprepare_and_run('<args>')
command! -nargs=? GO call s:StdIOgo('<args>')
command! OI call s:StdIOdelete_buffers()
command! IOI call s:StdIOrun_all()
command! -nargs=1 -complete=file OP call s:StdIOOpenFile('<args>')
command! -nargs=? -complete=filetype UT call s:StdIOUpdateTemplate('<args>')

if g:std_io_map_default
  nnoremap <silent> <leader>r :IO<cr>
  nnoremap <silent> <leader>er :IOI<cr>
  nnoremap <silent> <leader>tr :IO 1<cr>
  nnoremap <silent> <leader>i :execute 'sbuffer' g:std_io_input_buffer<cr>
  nnoremap <silent> <leader>o :execute 'sbuffer' g:std_io_output_buffer<cr>
  nnoremap <silent> <leader>f :execute 'sbuffer' g:std_io_current_file_buffer<cr>
  nnoremap <silent> <leader>q :OI<cr>
  nnoremap <silent> <leader>p :GO<cr>
  nnoremap <silent> <leader>n :GO 1<cr>
endif
