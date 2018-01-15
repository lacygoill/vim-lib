if exists('g:autoloaded_lg#motion#repeatable#listing')
    finish
endif
let g:autoloaded_lg#motion#repeatable#listing = 1

fu! s:init() abort "{{{1
    let env = lg#motion#repeatable#main#share_env()
    let [s:AXES, s:repeatable_motions] = [env['s:AXES'], env['s:repeatable_motions']]
    let s:N_AXES = len(s:AXES)
endfu
call s:init()

fu! lg#motion#repeatable#listing#complete(arglead, cmdline, _p) abort "{{{1
    let opt = [
    \           '-axis ',
    \           '-mode',
    \           '-scope ',
    \           '-v ',
    \           '-vv ',
    \         ]

    if  a:arglead[0] ==# '-'
    \|| empty(a:arglead)
    \&& a:cmdline !~# '-\%(axis\|scope\)\s\+$'
    \&& a:cmdline !~# '-mode\s\+\w*$'
        " Why not filtering the options?{{{
        "
        " We don't need to, because the command invoking this completion function is
        " defined with the attribute `-complete=custom`, not `-complete=customlist`,
        " which means Vim performs a basic filtering automatically.
        " }}}
        return join(opt, "\n")

    elseif a:cmdline =~# '-axis\s\+$'
        return join(keys(s:AXES), "\n")

    elseif a:cmdline =~# '-mode \w*$'
        let modes = [
        \             'normal',
        \             'visual',
        \             'operator-pending',
        \             'nvo',
        \           ]
        return join(modes, "\n")

    elseif a:cmdline =~# '-scope\s\+\w*$'
        return "local\nglobal"
    endif

    return ''
endfu

fu! s:customize_preview_window() abort "{{{1
    if &l:pvw
        call matchadd('Title', '^Motions on axis:  \d\+$')
        call matchadd('SpecialKey', '^global\|local$')
        " Why?{{{
        "
        " If we  press `gf` on a  filepath, it will replace  the preview buffer.
        " After that, we won't be able  to load the preview buffer back, because
        " we've set 'bt=nofile'.
        "
        " To avoid  this accident, we  remap `gf` so  that it splits  the window
        " before reading another file.
        "}}}
        nno  <buffer><nowait><silent>  gf  <c-w>Fzv
        "                                       │└┤
        "                                       │ └ open possible folds
        "                                       └── go to line number after colon
    endif
endfu

fu! s:get_line_in_listing(m,n,desired_mode) abort "{{{1
    let motion_mode = a:m.bwd.mode
    if !empty(a:desired_mode) && motion_mode !=# a:desired_mode
        return ''
    endif
    let line  = a:m.bwd.mode.'  '
    let line .= a:m.bwd.lhs
    let line .= ' : '.a:m.fwd.lhs
    return line
endfu

fu! lg#motion#repeatable#listing#main(...) abort "{{{1
    let cmd_args = split(a:1)
    let opt = {
    \           'axis':     matchstr(a:1, '-axis\s\+\zs\d\+'),
    \           'mode':     matchstr(a:1, '\v-mode\s+\zs%(\w|-)+'),
    \           'scope':    matchstr(a:1, '\v-scope\s+\zs\w+'),
    \           'verbose1': index(cmd_args, '-v') >= 0,
    \           'verbose2': index(cmd_args, '-vv') >= 0,
    \         }

    let opt.mode = substitute(opt.mode, 'nvo', ' ', '')

    " initialize each listing scoped to a given axis
    for i in range(1, s:N_AXES)
        let s:listing_for_axis_{i} = {'global': [], 'local': []}
    endfor
    call s:populate_listings_for_all_axes(opt)
    let total_listing = s:merge_listings(opt)

    call lg#log#output({'excmd': 'ListRepeatableMotions', 'lines': total_listing})
    call s:customize_preview_window()
endfu

fu! s:merge_listings(opt, ...) abort "{{{1
    " when the function is called for the 1st time, it's not passed any optional argument
    if !a:0
        let total_listing = []

        for n in range(1, s:N_AXES)
            let total_listing += s:merge_listings(a:opt, n, s:listing_for_axis_{n})
            unlet! s:listing_for_axis_{n}
        endfor

        return total_listing
    endif

    " when the function is called afterwards (by itself, i.e. recursively),
    " it's passed 2 additional arguments:
    "
    "     • the index of an axis
    "     • the listing of the latter
    let n = a:1
    let listing_for_this_axis = a:2

    if !empty(a:opt.axis) && n != a:opt.axis
        return []
    endif

    let lines = []
    if n > 1
        let lines += ['']
    endif
    let lines += ['Motions on axis:  '.n]
    if empty(listing_for_this_axis.global) && empty(listing_for_this_axis.local)
        let lines += ['  ∅']
    else
        for scope in ['global', 'local']
            if !empty(listing_for_this_axis[scope])
                let lines += ['', scope]
                for a_line in listing_for_this_axis[scope]
                    let lines += [a_line]
                endfor
            endif
        endfor
    endif
    return lines
endfu

fu! s:populate_listings_for_all_axes(opt) abort "{{{1
    let lists = a:opt.scope ==# 'local'
    \?              [get(b:, 'repeatable_motions', [])]
    \:          a:opt.scope ==# 'global'
    \?              [s:repeatable_motions]
    \:              [get(b:, 'repeatable_motions', []), s:repeatable_motions]

    for a_list in lists
        let scope = a_list is# s:repeatable_motions ? 'global' : 'local'
        for m in a_list
            let n = m.axis
            if !empty(a:opt.axis) && n != a:opt.axis
                continue
            endif
            let line = s:get_line_in_listing(m,n,a:opt.mode)
            if empty(line)
                continue
            endif
            let line .= a:opt.verbose1
            \?              '    '.m['original mapping']
            \:              ''

            let listing = s:listing_for_axis_{n}[scope]
            " populate `motions_on_axis_123`
            call add(listing, '  '.line)
            if a:opt.verbose2
                call extend(listing,
                \                    (!empty(m['original mapping']) ? ['       '.m['original mapping']] : [])
                \                   +['       Made repeatable from '.m['made repeatable from']]
                \                   +[''])
            endif
        endfor
    endfor
endfu