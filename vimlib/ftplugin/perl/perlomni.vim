
" Plugin:  perl-completion.vim
" Author:  Cornelius
" Email:   cornelius.howl@gmail.com 
" Version: 1.6


" Options:
" complete builtin functions by default
let g:def_perl_comp_bfunction = 1
" complete package names by default
let g:def_perl_comp_packagen  = 1

let g:plc_window_height = 14
let g:plc_window_position = 'botright'

com! OpenPLCompletionWindow                 :cal g:PLCompletionWindow.open(g:plc_window_position, 'split',g:plc_window_height,getline('.'))
inoremap <silent> <C-x><C-x>                <ESC>:OpenPLCompletionWindow<CR>


fun! s:FindVarPackageName(var)
  for l in b:file
    if l =~  '\('.escape(a:var,'$\').'\s*=\s*\)\@<=[A-Z][a-z:]*\(->new\)\@='
      return matchstr( l , '\(\s*=\s*\)\@<=[A-Z][a-z:]*\(->new\)\@=' )
    endif
  endfor
endf

" complete perl built-in functions
fun! s:CompleteBFunctions(base)

  " find cache
  if !exists('g:p5functions') 
    let g:p5bfunctions = readfile( expand('~/.vim/perl/perl-functions') )
  endif

  for f in g:p5bfunctions
    let idx = stridx(f,' ')
    let f = strpart( f,0,idx )
    if f =~ '^'.a:base
      "cal complete_add( { 'word' : f , 'kind': 'f' } )
      cal add(s:comp_items, { 'word' : f , 'kind': 'f' } )
    endif
  endfor
endf

fun! s:CompleteSelfFunctions(file,base)

  if ! exists('g:p5sfunctions')
    let g:p5sfunctions = {}
  endif

  if ! exists('g:p5sfunctions[ a:file ]')
    let g:p5sfunctions[a:file] = libperl#grep_file_functions( a:file )
  endif

  let subs = g:p5sfunctions[a:file]
  cal s:FuncCompAdd( a:base , subs )

  " find base class functions here
  "  why there is no such complete_add function takes list ? hate;
  if g:plc_complete_base_class_func
    let bases = libperl#parse_base_class_functions( a:file )
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
  let ms = libperl#get_cpan_installed_module_list(0)
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


" ====================== Complete Patterns
fun! s:FindVariableCompStart()

endf

" Package::O
fun! s:FindPackageCompStart()
  return searchpos('[A-Z]\w\+\(::\w\+\)*','bnc')
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
    if f =~ '^' . a:base
      " cal complete_add( { 'word' : f , 'kind': 'f' } )
      cal add( s:comp_items, { 'word' : f , 'kind': 'f' } )
    endif
  endfor
endf

fun! s:PackageCompAdd(base,modules)
  for m in a:modules
    if m =~ '^'. a:base
      "cal complete_add({ 'word': m , 'kind': 't' } )
      cal add(s:comp_items,{ 'word': m , 'kind': 't' } )
    endif
  endfor
endf

fun! s:ClassCompAdd(base,b)
  for f in a:b.functions
    if f =~ '^'.a:base
      "cal complete_add({ 'word': f , 'kind': 'f' , 'menu': a:b.class } )
      cal add(s:comp_items,{ 'word': f , 'kind': 'f' , 'menu': a:b.class } )
    endif
  endfor
endf

fun! PerlComplete(findstart, base)
  let line = getline('.')
  let lnum = line('.')
  let start = col('.') - 1

  if a:findstart
    let s_pos = s:FindSpace(start,lnum,line)

    " XXX: read lines from current buffer
    " let b:lines   = 
    let b:context  = getline('.')
    let b:lcontext = strpart(getline('.'),0,col('.')-1)
    let b:colpos   = col('.') - 1

    let p = s:FindMethodCompStart()
    if s:CompFound(p,s_pos)
      cal s:SetCompType(['method'])
      return p[1] - 1
    endif

    let p = s:FindPackageCompStart()
    if s:CompFound(p,s_pos)
      cal s:SetCompType(['package'])
      return p[1] - 1
    endif

    if line =~ '^use '
      cal s:SetCompType(['package-use'])
      return 4
    endif
    
    " default completion type
    cal s:SetCompType(['default'])
    return start
  else 
    " cache this
    let b:file = getline(1, '$')

    let s:comp_items = [ ]

    " hate vim script forgot last position we found 
    " so we need to find a start again ... orz
    let curfile = expand('%')

    " save space positoin to prevent over searching 
    let s_pos = s:FindSpace(start,lnum,line)
    let p = s:FindMethodCompStart()
    if s:CompFound(p,s_pos)
      cal s:ClearCompType()

      " get method compeltion here
      let ref_start = s:FindMethodCompReferStart()
      let ref_base = strpart( line , ref_start[1] - 1 , p[1] - 2 - ref_start[1] )
      if ref_base =~ '\$\(self\|class\)' 
        cal s:CompleteSelfFunctions( curfile , a:base )

      " XXX: complete special variable if needed.
      elseif ref_base =~ '\$\w\+'
        let var = ref_base
        let pkg = s:FindVarPackageName( var )
        if strlen(pkg) > 0 
          let f = libperl#get_module_file_path(pkg)
          if filereadable(f)
            cal s:CompletePackageFunctions( f , a:base )
          endif
        else
          return s:comp_items
        endif
      elseif ref_base =~ g:libperl#pkg_token_pattern 
        let f = libperl#get_module_file_path(ref_base)
        if filereadable(f)
          cal s:CompletePackageFunctions( f , a:base )
        endif
      endif
      return s:comp_items
    endif

    " package completion ====================================
    if s:HasCompType('package-use')
      cal s:ClearCompType()
      cal add(s:comp_items,'strict')
      cal add(s:comp_items,'warnings')
      "cal complete_add('strict')
      "cal complete_add('warnings')
      cal s:CompletePackageName( a:base )
      return s:comp_items
    endif

    if s:HasCompType('package')
      cal s:ClearCompType()
      cal s:CompletePackageName( a:base )
      return s:comp_items
    endif
    " =======================================================

    if s:HasCompType('default')
      cal s:ClearCompType()
      if g:def_perl_comp_bfunction
        cal s:CompleteBFunctions(a:base)
      endif
      if g:def_perl_comp_packagen
        cal s:CompletePackageName(a:base)
      endif
      return s:comp_items
    endif

  endif
  return s:comp_items
endf


" $self->asdfj
setlocal omnifunc=PerlComplete
