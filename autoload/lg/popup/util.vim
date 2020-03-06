if exists('g:autoloaded_lg#popup#util')
    finish
endif
let g:autoloaded_lg#popup#util = 1

" Init {{{1

const s:DEBUG = 1

if has('nvim')
    const s:LOGFILE = '/tmp/.nvim-floating-window.log.vim'
else
    const s:LOGFILE = '/tmp/.vim-popup-window.log.vim'
endif

" Functions {{{1
fu lg#popup#util#get_borderchars() abort "{{{2
    return ['─', '│', '─', '│', '┌', '┐', '┘', '└']
endfu

fu lg#popup#util#set_borderchars(opts) abort "{{{2
    call extend(a:opts, #{borderchars: lg#popup#util#get_borderchars()}, 'keep')
endfu

fu lg#popup#util#is_terminal_buffer(n) abort "{{{2
    return type(a:n) == type(0) && a:n > 0 && getbufvar(a:n, '&bt', '') is# 'terminal'
endfu

fu lg#popup#util#get_lines(what) abort "{{{2
    if type(a:what) == type([])
        let lines = a:what
    elseif type(a:what) == type('')
        let lines = split(a:what, '\n')
    elseif type(a:what) == type(0)
        let lines = getbufline(a:what, 1, '$')
    endif
    return lines
endfu

fu lg#popup#util#get_notification_opts(lines) abort "{{{2
    let longest = s:get_longest_width(a:lines)
    " TODO: `+4`, `-2`... is it reliable?  what if we use a different padding?
    let [width, height] = [longest + 4, len(a:lines) + 2]
    let [row, col] = [2, &columns]
    let opts = {
        \ 'width': width,
        \ 'height': height,
        \ 'row': row,
        \ 'col': col,
        \ 'border': [],
        \ 'highlight': 'WarningMsg',
        "\ only needed in Nvim (Vim highlight the border with 'highlight' if 'borderhighlight' is not specified)
        \ 'borderhighlight': 'WarningMsg',
        \ 'pos': 'topright',
        \ 'time': 3000,
        \ }
    if !has('nvim')
        call extend(opts, #{
            \ tabpage: -1,
            \ zindex: 300,
            \ })
    endif
    return opts
endfu

fu s:get_longest_width(lines) abort
    return max(map(copy(a:lines), {_,v -> strchars(v, 1)}))
endfu

fu lg#popup#util#log(msg) abort "{{{2
    if !s:DEBUG | return | endif
    let time = '" '..strftime('%H:%M:%S')
    call writefile([time, a:msg], s:LOGFILE, 'a')
endfu

