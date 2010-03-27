" vim:fdm=marker:
"
" Plugin:  perlomni.vim
" Author:  Cornelius
" Email:   cornelius.howl@gmail.com 
" Version: 1.75

runtime 'plugin/perlomni-data.vim'
runtime 'plugin/perlomni-util.vim'



fun! s:FindVarPackageName(var)
  for l in b:file
    if l =~  '\('.escape(a:var,'$\').'\s*=\s*\)\@<=[A-Z][a-z:]*\(->new\)\@='
      return matchstr( l , '\(\s*=\s*\)\@<=[A-Z][a-z:]*\(->new\)\@=' )
    endif
  endfor
endf

fun! s:FindBaseClasses(file)
  let script = 'find_base_classes.pl'
  if ! executable( script )
    echoerr 'can not execute ' . script
    return [ ]
  endif
  let out = system( script . ' ' . a:file  )
  if v:shell_error
    echoerr 'shell error:' . v:shell_error
    echoerr 'syntax error can not parse file:' . a:file 
    return []
  endif
  let classes = [ ]
  for l in split(out,"\n") 
    let [class,refer,path] = split(l,' ',1)  " 1 for keepempty
    call add(classes,[class,refer,path])
  endfor
  return classes
endf

fun! s:parseBaseClassFunction(filepath)
  let base_classes = s:FindBaseClasses( a:filepath ) 
  let result = [ ]
  for [class,class_refer,path] in base_classes
    let class_comp = { 'class': class , 'refer': class_refer , 'functions': [ ] }
    let class_comp.functions = s:GrepFileFunctions( path )
    call add( result , class_comp )
  endfor
  return result
endf

" complete perl built-in functions
fun! s:CompleteBFunctions(base)
  cal extend(b:comp_items,map(filter(copy(g:p5bfunctions),'v:val =~ ''^'.a:base.'''' ),'{ "word" : v:val , "kind": "f" }') )
endf

fun! s:GrepFileFunctions(file)
  let lines = filter(readfile(a:file),'v:val =~ ''^\s*sub\s''')
  let funcs = []
  for l in lines
    cal add(funcs,matchstr(l,'\(^\s*sub\s\+\)\@<=\w\+'))
  endfor
  return funcs
endf

fun! s:CompleteSelfFunctions(file,base)
  if ! exists('g:p5sfunctions')
    let g:p5sfunctions = {}
  endif

  if ! exists('g:p5sfunctions[ a:file ]')
    let g:p5sfunctions[a:file] = s:GrepFileFunctions(a:file)
  endif

  let subs = g:p5sfunctions[a:file]
  cal s:FuncCompAdd( a:base , subs )

  " find base class functions here
  let bases = s:parseBaseClassFunction( a:file )
  for b in bases
    cal s:ClassCompAdd(a:base,b)
  endfor
endf

fun! s:CompletePackageFunctions(file,base)
  " let class_comp = { 'class': class , 'refer': '' , 'functions': [ ] }
  let funcs = s:GrepFileFunctions( a:file )
  cal s:FuncCompAdd( a:base , funcs )
  let bases = s:parseBaseClassFunction( a:file )
  for b in bases
    cal s:ClassCompAdd(a:base,b)
  endfor
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
      cal add( b:comp_items, { 'word' : f , 'kind': 'f' } )
    endif
  endfor
endf

fun! s:PackageCompAdd(base,modules)
  for m in a:modules
    if m =~ '^'. a:base
      cal add(b:comp_items,{ 'word': m , 'kind': 't' } )
    endif
  endfor
endf

fun! s:ClassCompAdd(base,b)
  for f in a:b.functions
    if f =~ '^'.a:base
      cal add(b:comp_items,{ 'word': f , 'kind': 'f' , 'menu': a:b.class } )
    endif
  endfor
endf




" main completion function
" b:context  : whole current line
" b:lcontext : the text before cursor position
" b:colpos   : cursor position - 1
" b:lines    : range of scanning
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

    let b:comp_items = [ ]

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
          return b:comp_items
        endif
      elseif ref_base =~ g:libperl#pkg_token_pattern 
        let f = libperl#get_module_file_path(ref_base)
        if filereadable(f)
          cal s:CompletePackageFunctions( f , a:base )
        endif
      endif
      return b:comp_items
    endif

    " package completion ====================================
    if s:HasCompType('package-use')
      cal s:ClearCompType()
      cal add(b:comp_items,'strict')
      cal add(b:comp_items,'warnings')
      cal s:CompletePackageName( a:base )
      return b:comp_items
    endif

    if s:HasCompType('package')
      cal s:ClearCompType()
      cal s:CompletePackageName( a:base )
      return b:comp_items
    endif
    " =======================================================

    if s:HasCompType('default')
      cal s:ClearCompType()
      cal s:CompleteBFunctions(a:base)
      cal s:CompletePackageName(a:base)
      return b:comp_items
    endif

  endif
  return b:comp_items
endf

fun! PerlComplete2(findstart, base)
  let line = getline('.')
  let lnum = line('.')
  let start = col('.') - 1

  if a:findstart
    let b:comps = [ ]
    "let s_pos = s:FindSpace(start,lnum,line)

    " XXX: read lines from current buffer
    " let b:lines   = 
    let b:context  = getline('.')
    let b:lcontext = strpart(getline('.'),0,col('.')-1)
    let b:colpos   = col('.') - 1

    for rule in s:rules
     " let i = search( b:lcontext , rule.backward ,'bn')
      let match = matchstr( b:lcontext , rule.backward )
      let bwidx   = stridx( b:lcontext , match )
      if bwidx != -1
        let lefttext = strpart(b:lcontext,0,bwidx)
        let basetext = strpart(b:lcontext,bwidx)
        "echo 'leftext:' . lefttext
        "echo 'basetext:'. basetext
        if lefttext =~ rule.context
          cal extend(b:comps,call( rule.comp, [basetext] ))
          return bwidx
        endif
      endif
    endfor
  else 
    echo b:comps
    return b:comps
  endif
endf


let s:rules = [ ]
fun! s:addRule(hash)
  cal add( s:rules , a:hash )
endf

fun! g:p5cRule(hash)
  cal s:addRule(a:hash)
endf


fun! s:Quote(list)
  return map(copy(a:list), '"''".v:val."''"' )
endf

fun! s:CompMooseIs(base)
  return s:Quote(['rw','r','w'])
endf

fun! s:CompMooseIsa(base)
  let l:comps = s:Quote(["'Int'", "'Str'", "'HashRef'"])
  let l:result = [ ]
  for comp in l:comps
    if comp =~ a:base
      cal add(l:result,comp)
    endif
  endfor
  "cal filter(l:comps, 'v:val =~ ''^'.escape(a:base,"'").'''')
  "echo l:comps
  "sleep 1
  "return l:comps
  return l:result
endf

cal s:addRule( { 'context': '\s\+is\s\+$' , 'backward': '\S\+$' , 'comp': function('s:CompMooseIs') } )
cal s:addRule( { 'context': '\s\+isa\s\+$' , 'backward': '\S\+$' , 'comp': function('s:CompMooseIsa') } )

setlocal omnifunc=PerlComplete2


" isa 'HashRef'
" is 'r'
