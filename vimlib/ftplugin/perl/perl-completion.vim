" vim:fdm=syntax:fdl=1:et:sw=2:
"
"=VERSION 0.5
"
" Perl Completion Features:"{{{
"
" Self Completion:
"
"   when user type '$self->' or '$class->' , press [key] to trigger completion function
"       (or just map '->' key to trigger completion function)
"           
"           the completion should include:
"               function name
"               accessor
"
"   and should complete the '->' and open a completion window 
"   and list all matched items
" 
" when user type $App::Class:: , then press [key] to trigger completion function
"
"           the completion should include:
"               variable name
"
" when user type App::Class:: , then press [key] to trigger completion function
"
"           the completion should include:
"               function name
"               constants
"
" Synopsis For Moose:
"
"   for perl moose program like:
"
"     use Moose;
"
"     has sync_source => 
"         ( isa => 'App::SD::Replica::rt',
"           is => 'rw');
"
"   when user type $self->  then press key to complete:
"     should complete sync_source  and other functions from $self
"
"   when user type $self->sync_source-> , then press key to complete:
"     should complete the methods that sync_source class provided.
"
"
" Other Features:
"   when completion item just found one, should just append the completion ,
"   not to open the completion window
"
"   when user typing, it should automatically update the line (option)
"   and update completion result in the bottom window , and highlight 
"   the matched part
"
" user type C-n , C-p to select item to complete
" then press <Enter> to complete with the selected item.
" after all , the completion window should be closed
"
" type C-j , C-k to jump between package sections
"
" Completion Window:
"
" App::Base::Class
"   [var name]
"   [function name]  (line nn)
"   [function name]  (line nn)
"
" App::Class
"   [var name]
"   [function name]  (line nn)
"       ==review==
"       sub function_name {
"           my $self = shift;
"           my @args = %_;
"
"   [function]       (line nn)
"   [function]       (line nn)
"   [function]       (line nn)
"   [function]       (line nn)
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
      throw 'SKIP: no completions for this package: ' .class 
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








let g:plc_window_height = 14
let g:plc_window_position = 'botright'

com! OpenPLCompletionWindow                 :cal g:PLCompletionWindow.open(g:plc_window_position, 'split',g:plc_window_height,getline('.'))
inoremap <silent> <C-x><C-x>                <ESC>:OpenPLCompletionWindow<CR>

fun! s:CompleteSelfFunctions(file,base)
  let subs = libperl#grep_file_functions( a:file )
  cal s:FuncCompAdd( a:base , subs )

  " find base class functions here
  if g:plc_complete_base_class_func
    let bases = libperl#parse_base_class_functions( a:file )
    "  why there is no such complete_add function takes list ? hate;
    for b in bases
      cal s:ClassCompAdd(a:base,b)
    endfor
  endif
endf

fun! s:CompletePackageFunctions(file,base)
    " let class_comp = { 'class': class , 'refer': '' , 'functions': [ ] }
    let funcs = libperl#grep_file_functions( a:file )
    cal s:FuncCompAdd( a:base , funcs )

    if g:plc_complete_base_class_func
      let bases = libperl#parse_base_class_functions( a:file )
      for b in bases
        cal s:ClassCompAdd(a:base,b)
      endfor
    endif
endf


fun! s:CompletePackageName(base)
  let ms = libperl#get_installed_cpan_module_list(0)
  cal s:PackageCompAdd( a:base , ms )
endf

fun! s:GetCompType()
  return s:found_types
endf

fun! s:AddCompType(type)
  cal add(s:found_types,a:type) 
endf

" which is a list
fun! s:SetCompType(type)
  let s:found_types = a:type
endf

fun! s:HasCompType(type)
  for t in s:found_types 
    if t == a:type
      return 1
    endif
  endfor
  return 0
endf

fun! s:ClearCompType()
  let s:found_types = [ ]
endf

" Pac  
" Package::Orz
fun! s:FindPackageCompStart()
  let p = searchpos('\w\+\(::\w\+\)*','bnc')
  "let p[1] -= 1
  return p
endf

fun! s:FindMethodCompReferStart()
  return searchpos( '\S\+\(->\w*\)\@='  , 'bnc' )
endf

" $self->somet..
fun! s:FindMethodCompStart()
  return searchpos('\(->\)\@<=\w*','bnc')
endf

fun! s:CompFound(pos,over)
  " if searchpos returns [0,0] (pattern not found)
  if a:pos[1] > a:over[1] && a:pos[0] == a:over[0]
    return 1
  else
    return 0
  endif
"  elseif a:pos[0] == 0 && a:pos[1] == 0
"    return 0
"
"  " return false if we found a pattern before a over position
"  " or in a different line.
"  elseif a:pos[1] <= a:over[1] || a:pos[0] != a:over[0]
"    return 0
"
"  else
"    return 1
"  endif
endf

fun! s:FindSpace(col,row,line)
  let s = a:col
  while s > 0 && a:line[s - 1] =~ '\S'
    let s -= 1
  endwhile
  return [a:row,s]
endf

fun! s:FuncCompAdd(base,list)
  for f in a:list
    if f =~ a:base
      cal complete_add( { 'word' : f , 'kind': 'f' } )
    endif
  endfor
endf

fun! s:PackageCompAdd(base,modules)
  for m in a:modules
    if m =~ a:base
      cal complete_add({ 'word': m , 'kind': 't' } )
    endif
  endfor
endf

fun! s:ClassCompAdd(base,b)
  for f in a:b.functions
    if f =~ a:base
      cal complete_add({ 'word': f , 'kind': 'f' , 'menu': a:b.class } )
    endif
  endfor
endf

" XXX add preview to this

fun! PerlComplete(findstart, base)
  let line = getline('.')
  let lnum = line('.')
  let start = col('.') - 1

  if a:findstart == 1
    let s_pos = s:FindSpace(start,lnum,line)

    let p = s:FindMethodCompStart()
    if s:CompFound(p,s_pos)
      cal s:SetCompType(['method'])
      return p[1]
    endif

    let p = s:FindPackageCompStart()
    if s:CompFound(p,s_pos)
      cal s:SetCompType(['package'])
      return p[1]-1
    endif

    if line =~ '^use '
      cal s:SetCompType(['package-use'])
      return 4
    endif
    
    " default completion type
    cal s:SetCompType(['package'])
    return start
  else 

    "echo 'found base:' . a:base
    "sleep 1
    " hate vim script forgot last position we found 
    " so we need to find a start again ... orz
    let curfile = expand('%')

    " save space positoin to prevent over searching 
    let s_pos = s:FindSpace(start,lnum,line)
    let p = s:FindMethodCompStart()
    if s:CompFound(p,s_pos)
      cal s:ClearCompType()

      "echo 'found method completion'
      "sleep 1
      " get method compeltion here
      let ref_start = s:FindMethodCompReferStart()
      let ref_base = strpart( line , ref_start[1] - 1 , p[1] - 2 - ref_start[1] )
      if ref_base =~ '\$\(self\|class\)' 
        cal s:CompleteSelfFunctions( curfile , a:base )
      elseif ref_base =~ g:libperl#pkg_token_pattern 
        let f = libperl#get_module_file_path(ref_base)
        if filereadable(f)
          cal s:CompletePackageFunctions( f , a:base )
        endif
      endif
      return [ ]
    endif

    " package completion ====================================
    if s:HasCompType('package-use')
      cal s:ClearCompType()
      cal complete_add('strict')
      cal complete_add('warnings')
      cal s:CompletePackageName( a:base )
    endif

    if s:HasCompType('package')
      cal s:ClearCompType()
      cal s:CompletePackageName( a:base )
      return [ ]
    endif
    " =======================================================

  endif
  return [ ]
endf


" $self->asdfj
setlocal omnifunc=PerlComplete
