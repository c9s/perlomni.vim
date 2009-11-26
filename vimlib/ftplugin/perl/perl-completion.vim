" vim:fdm=syntax:fdl=1:et:sw=2:
"
" Author:  Cornelius
" Email:   cornelius.howl@gmail.com 
"
"}}}

let g:plc_complete_base_class_func = 1
let g:plc_max_entries_per_class = 5
let g:plc_complete_paren = 0

let g:PLCompletionWindow = copy( swindow#class )

fun! g:PLCompletionWindow.open(pos,type,size,from)
  let self.resource = [ ]
  let self.from = a:from   " self.from = getline('.')
  let self.current_file = expand('%')
  let self.comp_base = libperl#get_method_comp_base()
  let self.comp_start = libperl#get_method_comp_start()
  let self.comp_refer_base = libperl#get_method_comp_refer_base()
  let self.comp_refer_start = libperl#get_method_comp_refer_start()

  " self.pos is [bufnum, lnum, col, off]
  let pos = getpos('.')
  let self.pos = { 'bufnum': pos[0] , 'lnum': pos[1] , 'col': pos[2] }

  " XXX: make sure we have completion items

  " before we create the search window , we should check autocomplpop by our
  " guard.
  cal g:acpguard_class.check()
  cal self.split(a:pos,a:type,a:size)
endf

fun! g:PLCompletionWindow.close()
  bw  " we should clean up buffer in every completion
  cal g:acpguard_class.reveal()
  cal garbagecollect()
  redraw
endf



" XXX: 
"   should save completion base position
"   and do complete from base position
"
fun! g:PLCompletionWindow.init_buffer()
  let from = self.from
  " let pos = match( from , '\S*$' , )
  " \S\+\(->\)\@= is for matching:
  "     Data::Dumper->something
  "     $self->something
  "     $class->something
  " let pos = searchpos( '\S\+\(->\)\@='  , 'bn' , line('.') )
  " let refer = strpart( from , pos )
  " let refer = strpart( from , pos )

  let matches = { }

  " if it's from $self or $class, parse subroutines from current file
  " and parse parent packages , the maxima is by class depth
  if self.comp_refer_base =~ '\$\(self\|class\)' 
    let _self = { 'class': 'self' , 'refer': '' , 'functions': [ ] }
    let _self.functions = libperl#grep_file_functions( self.current_file )
    cal insert(self.resource, _self )

    if g:plc_complete_base_class_func
      let base_functions = libperl#parse_base_class_functions( self.current_file )
      cal extend( self.resource , base_functions )
    endif

  " if it's from PACKAGE::SOMETHING , find the package file , and parse
  " subrouteins from the file , and the parent packages
  elseif self.comp_refer_base =~ g:libperl#pkg_token_pattern 
    let class = self.comp_refer_base
    let filepath = libperl#get_module_file_path(class)

    if ! filereadable(filepath)
      return
    endif

    let class_comp = { 'class': class , 'refer': '' , 'functions': [ ] }
    let class_comp.functions = libperl#grep_file_functions( filepath )
    cal insert( self.resource , class_comp )

    if g:plc_complete_base_class_func
      let base_functions = libperl#parse_base_class_functions( filepath )
      cal extend( self.resource , base_functions )
    endif

  " XXX
  " if it's from $PACKAGE::Some.. , find the PACAKGE file , and parse 
  " the variables from the file . and the parent packages
  else
    self.resource = [ ]
  endif

  setfiletype PLCompletionWindow

  cal append(0, [">> PerlCompletion Window: Complete:<Enter>  Next/Previous Class:<Ctrl-j>/<Ctrl-k>  Next/Previous Entry:<Ctrl-n>/<Ctrl-p> ",""])

  cal self.render_result( self.resource )

  if strlen( self.comp_base ) > 0 
    cal self.render_result( self.resource )
    cal setline( 2 , self.comp_base )
    cal self.update_search()
  endif

  autocmd CursorMovedI <buffer>       cal g:PLCompletionWindow.update_search()
  autocmd BufWinLeave  <buffer>       cal g:PLCompletionWindow.close()
  silent file PerlCompletion
endf

fun! g:PLCompletionWindow.start()
  if strlen( self.comp_base ) > 0
    cal cursor(2, strlen(self.comp_base)+1)
  else 
    cal cursor(2,1)
  endif
  startinsert
endf

" when pattern is empty , should display all entries
fun! g:PLCompletionWindow.grep_entries(entries,pattern) 
  let result = [ ]
  for entry in a:entries
    let entry_result = copy( entry )
    let entry_result.functions = filter( copy( entry_result.functions )  , 'v:val =~ ''' . a:pattern . '''' )

    if strlen( a:pattern ) > 0 && len( entry_result.functions ) > g:plc_max_entries_per_class 
      let entry_result.functions = remove( entry_result.functions , 0 , g:plc_max_entries_per_class )
    endif
    cal add( result , entry_result )
  endfor
  return result
endf


fun! g:PLCompletionWindow.render_result(matches)
  let out = ''
  let f_pad = "\n  "
  for entry in a:matches
    let out .= entry.class 

    if strlen(entry.refer) > 0
      let out .= ' from:' . entry.refer
    endif 

    if len( entry.functions ) > 0 
      let out .= f_pad . join( entry.functions ,  f_pad )
    endif

    let out .= "\n"
  endfor
  silent put=out
endf


fun! g:PLCompletionWindow.update_search()
  let pattern = getline( 2 )
  let matches = self.grep_entries( self.resource , pattern )
  let old = getpos('.')
  silent 3,$delete _
  cal self.render_result( matches )
  cal setpos('.',old)
  startinsert
endf

fun! g:PLCompletionWindow.init_syntax()
  if has("syntax") && exists("g:syntax_on") && !has("syntax_items")
    syn match WindowTitle +^>>.*$+
    syn match EntryHeader +^[a-zA-Z0-9:_]\++
    syn match EntryItem   "^\s\s\w\+"

    hi WindowTitle ctermfg=green guifg=green 
    hi EntryHeader ctermfg=magenta guifg=magenta
    hi EntryItem ctermfg=cyan guifg=cyan
  endif
endf

fun! g:PLCompletionWindow.do_complete()
  let line = getline('.')
  let entry = matchstr( line , '\w\+' )
  if line =~ '^\s\s'   " function entry 
    bw
    cal libperl#clear_method_comp_base()
    if g:plc_complete_paren 
      cal setline( line('.') , getline('.') . entry . '()' )
      startinsert
      cal cursor( line('.') , col('$') - 1 )
    else
      cal setline( line('.') , getline('.') . entry )
      startinsert
      cal cursor( line('.') , col('$')  )
    endif
  endif
endf

fun! g:PLCompletionWindow.do_complete_first()
  cal search('^\s\s\w\+')
  cal self.do_complete()
endf

fun! g:PLCompletionWindow.init_mapping()
  nnoremap <silent> <buffer> <Enter> :cal g:PLCompletionWindow.do_complete()<CR>
  inoremap <silent> <buffer> <Enter> <ESC>:cal g:PLCompletionWindow.do_complete_first()<CR>

  nnoremap <silent> <buffer> <C-j> :cal search('^[a-zA-Z]')<CR>
  nnoremap <silent> <buffer> <C-k> :cal search('^[a-zA-Z]','b')<CR>

  inoremap <silent> <buffer> <C-j> <ESC>:cal search('^[a-zA-Z]')<CR>
  inoremap <silent> <buffer> <C-k> <ESC>:cal search('^[a-zA-Z]','b')<CR>
endf
