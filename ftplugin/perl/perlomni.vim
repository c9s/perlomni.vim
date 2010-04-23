" vim:fdm=marker:sw=4:et:fdl=0:
"
" Plugin:  perlomni.vim
" Author:  Cornelius
" Email:   cornelius.howl@gmail.com 
" Version: 1.75
let s:debug_flag = 0
runtime 'plugin/perlomni-data.vim'
runtime 'plugin/perlomni-util.vim'

let s:vimbin = globpath(&rtp, 'bin/')

" Warning {{{
if ! filereadable(s:vimbin.'grep-objvar.pl')
            \ && ! filereadable(s:vimbin.'grep-pattern.pl')
    echo "Please install scripts to ~/.vim/bin"
    finish
endif
" }}}

" Wrapped system() Function. {{{
fun! s:system(...)
    let cmd = ''
    if has('win32')
        let ext = toupper(substitute(a:1, '^.*\.', '.', ''))
        if !len(filter(split($PATHEXT, ';'), 'toupper(v:val) == ext'))
            if ext == '.PL' && executable('perl') 
                let cmd = 'perl'
            elseif ext == '.PY' && executable('python') 
                let cmd = 'python' 
            elseif ext == '.RB' && executable('ruby') 
                let cmd = 'ruby' 
            endif
        endif
        for a in a:000
            if len(cmd) | let cmd .= ' ' | endif
            if substitute(substitute(a, '\\.', '', 'g'), '\([''"]\).*\1', '', 'g') =~ ' ' || (a != '|' && a =~ '|') || a =~ '[()]' | let a = '"' . substitute(a, '"', '"""', 'g') . '"' | endif
            let cmd .= a
        endfor
    else
        for a in a:000
            if len(cmd) | let cmd .= ' ' | endif
            if substitute(substitute(a, '\\.', '', 'g'), '\([''"]\).*\1', '', 'g') =~ ' ' || (a != '|' && a =~ '|') || a =~ '[()]' | let a = shellescape(a) | endif
            let cmd .= a
        endfor
    endif
    return system(cmd)
endfunction
" }}}


" Public API {{{

" Rule
fun! AddPerlOmniRule(hash)
    cal s:addRule(a:hash)
endf

" Cache Function. {{{
let s:last_cache_ts = localtime()
fun! GetCacheNS(ns,key)
    if localtime() - s:last_cache_ts > g:perlomni_cache_expiry
        let s:last_cache_ts = localtime()
        return 0
    endif

    if ! g:perlomni_use_cache
        return 0
    endif
    let key = a:ns . "_" . a:key
    if exists('g:perlomni_cache[key]')
        return g:perlomni_cache[key]
    endif
    return 0
endf

fun! SetCacheNS(ns,key,value)
    if ! exists('g:perlomni_cache')
        let g:perlomni_cache = { }
    endif
    let key = a:ns . "_" . a:key
    let g:perlomni_cache[ key ] = a:value
    return a:value
endf
com! CacheNSClear  :unlet g:perlomni_cache

" }}}

" }}}

" BASE CLASS UTILS {{{
fun! s:baseClassFromFile(file)
    let l:cache = GetCacheNS('clsf_bcls',a:file)
    if type(l:cache) != type(0)
        return l:cache
    endif
    let list = split(s:system(s:vimbin.'grep-pattern.pl', a:file, 
        \ '^(?:use\s+(?:base|parent)\s+|extends\s+)(.*);'),"\n")
    let classes = [ ]
    for i in range(0,len(list)-1)
        let list[i] = substitute(list[i],'^\(qw[(''"\[]\|(\|[''"]\)\s*','','')
        let list[i] = substitute(list[i],'[)''"]$','','')
        let list[i] = substitute(list[i],'[,''"]',' ','g')
        cal extend( classes , split(list[i],'\s\+'))
    endfor
    return SetCacheNS('clsf_bcls',a:file,classes)
endf
" echo s:baseClassFromFile(expand('%'))

fun! s:findBaseClass(class)
    let file = s:locateClassFile(a:class)
    if file == '' 
        return []
    endif
    return s:baseClassFromFile(file)
endf
" echo s:findBaseClass( 'Jifty::Record' )
" }}}

fun! s:findCurrentClassBaseClass()
    let all_mods = [ ]
    for i in range( line('.') , 0 , -1 )
        let line = getline(i)
        if line =~ '^package\s\+'
            break
        elseif line =~ '^\(use\s\+\(base\|parent\)\|extends\)\s\+'
            let args =  matchstr( line , 
                        \ '\(^\(use\s\+\(base\|parent\)\|extends\)\s\+\(qw\)\=[''"(\[]\)\@<=\_.*\([\)\]''"]\s*;\)\@=' )
            let args = substitute( args  , '\_[ ]\+' , ' ' , 'g' )
            let mods = split(  args , '\s' )
            cal extend( all_mods , mods )
        endif
    endfor
    return all_mods
endf


fun! s:locateClassFile(class)
    let l:cache = GetCacheNS('clsfpath',a:class)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let paths = split(&path,',')
    if g:perlomni_use_perlinc || &filetype != 'perl'
        let paths = split( s:system('perl', '-e', 'print join(",",@INC)') ,',')
    endif

    let filepath = substitute(a:class,'::','/','g') . '.pm'
    cal insert(paths,'lib')
    for path in paths
        if filereadable( path . '/' . filepath ) 
            return SetCacheNS('clsfpath',a:class,path .'/' . filepath)
        endif
    endfor
    return ''
endf
" echo s:locateClassFile('Jifty::DBI')
" echo s:locateClassFile('No')

fun! s:addRule(hash)
    cal add( s:rules , a:hash )
endf


fun! s:debug(name,var)
    if s:debug_flag
        echo a:name . ":" . a:var
        sleep 1
    endif
endf

fun! s:defopt(name,value)
    if !exists('g:{a:name}')
        let g:{a:name} = a:value
    endif
endf

fun! s:grepBufferList(pattern)
    redir => bufferlist
    silent buffers
    redir END
    let lines = split(bufferlist,"\n")
    let files = [ ]
    for line in lines
        let buffile = matchstr( line , '\("\)\@<=\S\+\("\)\@=' )
        if buffile =~ a:pattern
            cal add(files,expand(buffile))
        endif
    endfor
    return files
endf
" echo s:grepBufferList('\.pm$')

" main completion function
" b:context  : whole current line
" b:lcontext : the text before cursor position
" b:colpos   : cursor position - 1
" b:lines    : range of scanning

fun! s:parseParagraphHead(fromLine)
    let lnum = a:fromLine
    let b:paragraph_head = getline(lnum)
    for nr in range(lnum-1,lnum-10,-1)
        let line = getline(nr)
        if line =~ '^\s*$' || line =~ '^\s*#'
            break
        endif
        let b:paragraph_head = line
    endfor
    return b:paragraph_head
endf

fun! PerlComplete(findstart, base)
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

        " let b:pcontext
        let b:paragraph_head = s:parseParagraphHead(lnum)

        let first_bwidx = -1

        for rule in s:rules
            let match = matchstr( b:lcontext , rule.backward )
            if strlen(match) > 0
                let bwidx   = strridx( b:lcontext , match )
            else
                " if backward regexp matched is empty, check if context regexp
                " is matched ? if yes, set bwidx to length, if not , set to -1
                if b:lcontext =~ rule.context
                    let bwidx = strlen(b:lcontext)
                else
                    let bwidx = -1
                endif
            endif

            " see if there is first matched index
            if first_bwidx != -1 && first_bwidx != bwidx
                continue
            endif

            if bwidx == -1
                continue
            endif

            " lefttext: context matched text
            " basetext: backward matched text
            
            let lefttext = strpart(b:lcontext,0,bwidx)
            let basetext = strpart(b:lcontext,bwidx)

            cal s:debug( 'function' , string(rule.comp) )
            cal s:debug( 'head'     , b:paragraph_head )
            cal s:debug( 'lefttext' , lefttext )
            cal s:debug( 'regexp'   , rule.context )
            cal s:debug( 'basetext' , basetext )

"             if lefttext =~ rule.context
"                 echo 'Context Match!'
"                 sleep 1
"             endif
"             if has_key(rule,'head') && b:paragraph_head =~ rule.head
"                 echo 'Head Match!'
"                 sleep 1
"             endif
            " echo string(rule.comp) . ' regexp: "' . rule.context . '" ' . "lcontext:'" .lefttext . "'" .  " basetext:'" .basetext . "'"
            " sleep 3

            if ( has_key( rule ,'head') && b:paragraph_head =~ rule.head && lefttext =~ rule.context ) ||
                    \ ( ! has_key(rule,'head') && lefttext =~ rule.context  )

                if type(rule.comp) == type(function('tr'))
                    cal extend(b:comps, call( rule.comp, [basetext,lefttext] ) )
                elseif type(rule.comp) == type([])
                    cal extend(b:comps,rule.comp)
                else
                    echoerr "Unknown completion handle type"
                endif

                if has_key(rule,'only') && rule.only == 1
                    return bwidx
                endif

                " save first backward index
                if first_bwidx == -1
                    let first_bwidx = bwidx
                endif
            endif
        endfor
        return first_bwidx
    else 
        return b:comps
    endif





endf

let s:rules = [ ]

" Util Functions {{{
fun! s:Quote(list)
    return map(copy(a:list), '"''".v:val."''"' )
endf

fun! s:RegExpFilter(list,pattern)
    let pattern = substitute(a:pattern,"'","''",'g')
    return filter(copy(a:list),"v:val =~ '^".pattern."'")
endf

fun! s:StringFilter(list,string)
    let string = substitute(a:string,"'","''",'g')
    return filter(copy(a:list),"stridx(v:val,'".string."') == 0 && v:val != '".string."'" )
endf
" }}}
" SIMPLE MOOSE COMPLETION {{{
fun! s:CompMooseIs(base,context)
    return s:Quote(['rw', 'ro', 'wo'])
endf

fun! s:CompMooseIsa(base,context)
    let l:comps = ['Int', 'Str', 'HashRef', 'HashRef[', 'Num', 'ArrayRef']
    let base = substitute(a:base,'^[''"]','','')
    cal extend(l:comps, s:CompClassName(base,a:context))
    return s:Quote(s:StringFilter( l:comps, base  ))
endf

fun! s:CompMooseAttribute(base,context)
    let values = [ 'default' , 'is' , 'isa' , 
                \ 'label' , 'predicate', 'metaclass', 'label', 
                \ 'expires_after', 
                \ 'refresh_with' , 'required' , 'coerce' , 'does' , 'required',
                \ 'weak_ref' , 'lazy' , 'auto_deref' , 'trigger', 
                \ 'handles' , 'traits' , 'builder' , 'clearer',
                \ 'predicate' , 'lazy_build', 'initializer', 'documentation' ]
    cal map(values,'v:val . " => "')
    return s:StringFilter(values,a:base)
endf

fun! s:CompMooseRoleAttr(base,context)
    let attrs = [ 'alias', 'excludes' ]
    return s:StringFilter(attrs,a:base)
endf
fun! s:CompMooseStatement(base,context)
    let sts = [ 
        \'extends' , 'after' , 'before', 'has' , 
        \'requires' , 'with' , 'override' , 'method',
        \'super', 'around', 'inner', 'augment', 'confess' , 'blessed' ]
    return s:StringFilter(sts,a:base)
endf
" }}}
" PERL CORE OMNI COMPLETION {{{

fun! s:CompVariable(base,context)
    let l:cache = GetCacheNS('variables',a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let lines = getline(1,'$')
    let variables = s:scanVariable(getline(1,'$'))
    cal extend( variables , s:scanArrayVariable(getline(1,'$')))
    cal extend( variables , s:scanHashVariable(getline(1,'$')))
    let result = filter( copy(variables),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
    return SetCacheNS('variables',a:base,result)
endf

fun! s:CompArrayVariable(base,context)
    let l:cache = GetCacheNS('arrayvar',a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let lines = getline(1,'$')
    let variables = s:scanArrayVariable(getline(1,'$'))
    let result = filter( copy(variables),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
    return SetCacheNS('arrayvar',a:base,result)
endf

fun! s:CompHashVariable(base,context)
    let l:cache = GetCacheNS('hashvar',a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif
    let lines = getline(1,'$')
    let variables = s:scanHashVariable(getline(1,'$'))
    let result = filter( copy(variables),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
    return SetCacheNS('hashvar',a:base,result)
endf

" perl builtin functions
fun! s:CompFunction(base,context)
    return s:StringFilter(g:p5bfunctions,a:base)
endf

fun! s:CompCurrentBaseFunction(base,context)
    let all_mods = s:findCurrentClassBaseClass()
    let funcs = [ ] 
    for mod in all_mods 
        let sublist = s:scanFunctionFromClass(mod)
        cal extend(funcs,sublist)
    endfor
    return funcs
endf
" echo s:CompCurrentBaseFunction('','$self->')
" sleep 1

fun! s:CompBufferFunction(base,context)
    let l:cache = GetCacheNS('buf_func',a:base.expand('%'))
    if type(l:cache) != type(0)
        return l:cache
    endif

    let l:cache2 = GetCacheNS('buf_func_all',expand('%'))
    if type(l:cache2) != type(0)
        let funclist = l:cache2
    else
        let lines = getline(1,'$')
        let funclist = SetCacheNS('buf_func_all',expand('%'),s:scanFunctionFromList(getline(1,'$')))
    endif
    let result = filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
    return SetCacheNS('buf_func',a:base.expand('%'),result)
endf

fun! s:CompClassFunction(base,context)
    let class = matchstr(a:context,'[a-zA-Z0-9:]\+\(->\)\@=')
    let l:cache = GetCacheNS('classfunc',class.'_'.a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let l:cache2 = GetCacheNS('class_func_all',class)
    let funclist = type(l:cache2) != type(0) ? l:cache2 : SetCacheNS('class_func_all',class,s:scanFunctionFromClass(class))

    let result = filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
    return SetCacheNS('classfunc',class.'_'.a:base,result)
endf


fun! s:CompObjectMethod(base,context)
    let objvarname = matchstr(a:context,'\$\w\+\(->$\)\@=')
    let l:cache = GetCacheNS('objectMethod',objvarname.'_'.a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    " Scan from current buffer
    " echo 'scan from current buffer' | sleep 100ms
    if ! exists('b:objvarMapping') 
            \ || ! has_key(b:objvarMapping,objvarname)
        let minnr = line('.') - 10
        let minnr = minnr < 1 ? 1 : minnr
        let lines = getline( minnr , line('.') )
        cal s:scanObjectVariableLines(lines)
    endif

    " Scan from other buffers
    " echo 'scan from other buffer' | sleep 100ms
    if ! has_key(b:objvarMapping,objvarname)
        let bufferfiles = s:grepBufferList('\.p[ml]$')
        for file in bufferfiles
            cal s:scanObjectVariableFile( file )
        endfor
    endif

    " echo 'scan functions' | sleep 100ms
    let funclist = [ ]
    if has_key(b:objvarMapping,objvarname)
        let classes = b:objvarMapping[ objvarname ]
        for cls in classes
            cal extend(funclist,s:scanFunctionFromClass( cls ))
        endfor
        let result = filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
        return SetCacheNS('objectMethod',objvarname.'_'.a:base,result)
    endif
    return funclist
endf
" let b:objvarMapping = {  }
" let b:objvarMapping[ '$cgi'  ] = ['CGI']
" echo s:CompObjectMethod( '' , '$cgi->' )
" sleep 1

fun! s:CompClassName(base,context)
    let cache = GetCacheNS('class',a:base)
    if type(cache) != type(0)
        return cache
    endif

    " prevent waiting too long
    if strlen(a:base) == 0
        return [ ]
    endif

    if exists('g:cpan_mod_cache')
        let classnames = g:cpan_mod_cache
    else
        let sourcefile = CPANSourceLists()
        let classnames = CPANParseSourceList( sourcefile )
        let g:cpan_mod_cache = classnames
    endif
    cal extend(classnames, s:scanClass('lib'))

    let result = s:StringFilter(classnames,a:base)

    if len(result) > g:perlomni_max_class_length 
        cal remove(result,0, g:perlomni_max_class_length)

" Find a better way
"         for item in result
"             let parts = split(item,'::')
"             while len(parts) > 0
"                 if len(parts) > 1
"                     cal insert(result,join(parts,'::'))
"                 else
"                     cal insert(result,join(parts,'::').'::')
"                 endif
"                 cal remove(parts,-1)
"             endwhile
"         endfor
    endif
    if g:perlomni_sort_class_by_lenth
        cal sort(result,'s:SortByLength')
    else
        cal sort(result)
    endif
    return SetCacheNS('class',a:base,result)
endf
" echo s:CompClassName('Moose::','')

fun! s:SortByLength(i1, i2)
    return strlen(a:i1) == strlen(a:i2) ? 0 : strlen(a:i1) > strlen(a:i2) ? 1 : -1
endfunc


fun! s:CompPodHeaders(base,context)
    let pods = [ 'head1' , 'head2' , 'head3' , 'begin' , 'end', 'encoding' , 'cut' , 'pod' , 'over' , 'item' , 'for' , 'back' ]
    return s:StringFilter( pods , a:base )
endf

" echo s:CompPodHeaders('h','')

fun! s:CompQString(base,context)
    let lines = getline(1,'$')
    let strings = s:scanQString( lines )
    return s:StringFilter(strings,a:base)
endf

" let sortedlist = sort(mylist, "MyCompare")

" }}}
" PERL CLASS LIST UTILS {{{
" CPANParseSourceList {{{
fun! CPANParseSourceList(file)
  if ! exists('g:cpan_mod_cachef')
    let g:cpan_mod_cachef = expand('~/.vim-cpan-module-cache')
  endif
  if !filereadable(g:cpan_mod_cachef) || getftime(g:cpan_mod_cachef) < getftime(a:file)
    let args = []
    if executable('zcat')
      let args = ['zcat', a:file, '|' , 'grep', '-Ev', '^[A-Za-z0-9-]+: ', '|', 'cut', '-d" "', '-f1', '>', g:cpan_mod_cachef]
    else
      let args = ['cat', a:file, '|', 'gunzip', '|', 'grep', '-Ev', '^[A-Za-z0-9-]+: ', '|', 'cut', '-d" "', '-f1', '>', g:cpan_mod_cachef]
    endif
    call call(function("s:system"), args)
    if v:shell_error 
      echoerr v:shell_error
    endif
  endif
  return readfile( g:cpan_mod_cachef )
endf
" }}}
" CPANSourceLists {{{
" XXX: copied from cpan.vim plugin , should be reused.
" fetch source list from remote
fun! CPANSourceLists()
  let paths = [ 
        \expand('~/.cpanplus/02packages.details.txt.gz'),
        \expand('~/.cpan/sources/modules/02packages.details.txt.gz')
        \]
  if exists('g:cpan_user_defined_sources')
    call extend( paths , g:cpan_user_defined_sources )
  endif

  for f in paths 
    if filereadable( f ) 
      return f
    endif
  endfor

  " not found
  echo "CPAN source list not found."
  let f = expand('~/.cpan/sources/modules/02packages.details.txt.gz')
  " XXX: refactor me !!
  if ! isdirectory( expand('~/.cpan') )
    cal mkdir( expand('~/.cpan') )
  endif

  if ! isdirectory( expand('~/.cpan/sources') )
    cal mkdir( expand('~/.cpan/sources') )
  endif

  if ! isdirectory( expand('~/.cpan/sources/modules') )
    cal mkdir( expand('~/.cpan/sources/modules') )
  endif

  echo "Downloading CPAN source list."
  if executable('curl')
    exec '!curl http://cpan.nctu.edu.tw/modules/02packages.details.txt.gz -o ' . f
    return f
  elseif executable('wget')
    exec '!wget http://cpan.nctu.edu.tw/modules/02packages.details.txt.gz -O ' . f
    return f
  endif
  echoerr "You don't have curl or wget to download the package list."
  return
endf
" let sourcefile = CPANSourceLists()
" let classnames = CPANParseSourceList( sourcefile )
" echo remove(classnames,10)
" }}}
" }}}
" SCOPE FUNCTIONS {{{
" XXX:
fun! s:getSubScopeLines(nr)
    let curline = getline(a:nr)
endf
" }}}
" SCANNING FUNCTIONS {{{
fun! s:scanClass(path)
    let l:cache = GetCacheNS('classpath', a:path)
    if type(l:cache) != type(0)
        return l:cache
    endif
    if ! isdirectory(a:path)
        return [ ]
    endif
    let l:files = split(glob(a:path . '/**'))
    cal filter(l:files, 'v:val =~ "\.pm$"')
    cal map(l:files, 'strpart(v:val,strlen(a:path)+1,strlen(v:val)-strlen(a:path)-4)')
    cal map(l:files, 'substitute(v:val,''/'',"::","g")')
    return SetCacheNS('classpath',a:path,l:files)
endf
" echo s:scanClass(expand('~/aiink/aiink/lib'))

fun! s:scanObjectVariableLines(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    let varlist = split(s:system(s:vimbin.'grep-objvar.pl', buffile),"\n") 
    let b:objvarMapping = { }
    for item in varlist
        let [varname,classname] = split(item)
        if exists('b:objvarMapping[varname]')
            cal add( b:objvarMapping[ varname ] , classname )
        else
            let b:objvarMapping[ varname ] = [ classname ]
        endif
    endfor
    return b:objvarMapping
endf
" echo s:scanObjectVariableLines([])

fun! s:scanObjectVariableFile(file)
"     let l:cache = GetCacheNS('objvar_', a:file)
"     if type(l:cache) != type(0)
"         return l:cache
"     endif

    let list = split(s:system(s:vimbin.'grep-objvar.pl', expand(a:file)),"\n") 
    let b:objvarMapping = { }
    for item in list
        let [varname,classname] = split(item)
        if exists('b:objvarMapping[varname]')
            cal add( b:objvarMapping[ varname ] , classname )
        else
            let b:objvarMapping[ varname ] = [ classname ]
        endif
    endfor
    return b:objvarMapping
"     return SetCacheNS('objvar_',a:file,b:objvarMapping)
endf
" echo s:scanObjectVariableFile( expand('~/git/bps/jifty-dbi/lib/Jifty/DBI/Collection.pm') )


fun! s:scanHashVariable(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    return split(s:system(s:vimbin.'grep-pattern.pl', buffile, '%(\w+)', '|', 'sort', '|', 'uniq'),"\n") 
endf
" echo s:scanHashVariable( getline(1,'$') )


fun! s:scanQString(lines)
    let buffile = tempname()
    cal writefile( a:lines, buffile)
    let cmd = s:system(s:vimbin.'grep-pattern.pl', buffile, '[''](.*?)(?<!\\)['']')
    return split( cmd ,"\n")
endf

fun! s:scanQQString(lines)
    let buffile = tempname()
    cal writefile( a:lines, buffile)
    return split(s:system(s:vimbin.'grep-pattern.pl', buffile, '["](.*?)(?<!\\)["]'),"\n")
endf
" echo s:scanQQStringFile('testfile')

fun! s:scanArrayVariable(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    return split(s:system(s:vimbin.'grep-pattern.pl', buffile, '@(\w+)', '|', 'sort', '|', 'uniq'),"\n")
endf

fun! s:scanVariable(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    return split(s:system(s:vimbin.'grep-pattern.pl', buffile, '\$(\w+)', '|', 'sort', '|', 'uniq'),"\n") 
endf

fun! s:scanFunctionFromList(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    return split(s:system(s:vimbin.'grep-pattern.pl', buffile, '^\s*(?:sub|has)\s+(\w+)', '|', 'sort', '|', 'uniq'),"\n")
endf

fun! s:scanFunctionFromSingleClassFile(file)
    return split(s:system(s:vimbin.'grep-pattern.pl', a:file, '^\s*(?:sub|has)\s+(\w+)', '|', 'sort', '|', 'uniq'),"\n")
endf

fun! s:scanFunctionFromClass(class)
    let classfile = s:locateClassFile(a:class)
    return classfile == '' ? [ ] :
        \ extend( s:scanFunctionFromSingleClassFile(classfile), 
            \ s:scanFunctionFromBaseClassFile(classfile) )
endf
" echo s:scanFunctionFromClass('Jifty::DBI::Record')
" echo s:scanFunctionFromClass('CGI')
" sleep 1

" scan functions from file and parent classes.
fun! s:scanFunctionFromBaseClassFile(file)
    if ! filereadable( a:file )
        return [ ]
    endif

    let l:funcs = s:scanFunctionFromSingleClassFile(a:file)
"     echo 'sub:' . a:file
    let classes = s:baseClassFromFile(a:file)
    for cls in classes
        unlet! l:cache
        let l:cache = GetCacheNS('classfile_funcs',cls)
        if type(l:cache) != type(0)
            cal extend(l:funcs,l:cache)
            continue
        endif

        let clsfile = s:locateClassFile(cls)
        if clsfile != ''
            let bfuncs = s:scanFunctionFromBaseClassFile( clsfile )
            cal SetCacheNS('classfile_funcs',cls,bfuncs)
            cal extend( l:funcs , bfuncs )
        endif
    endfor
    return l:funcs
endf
" let fs = s:scanFunctionFromBaseClassFile(expand('%'))
" echo len(fs)

" }}}
" RULES {{{
" rules have head should be first matched , because of we get first backward position.
"
" Moose Completion Rules {{{
cal s:addRule({ 'only':1, 'head': '^has\s\+\w\+' , 'context': '\s\+is\s*=>\s*$'  , 'backward': '[''"]\?\w*$' , 'comp': function('s:CompMooseIs') } )
cal s:addRule({ 'only':1, 'head': '^has\s\+\w\+' , 'context': '\s\+\(isa\|does\)\s*=>\s*$' , 'backward': '[''"]\?\S*$' , 'comp': function('s:CompMooseIsa') } )
cal s:addRule({ 'only':1, 'head': '^has\s\+\w\+' , 
    \'context': '\s\+\(reader\|writer\|clearer\|predicate\|builder\)\s*=>\s*[''"]$' , 
    \'backward': '\w*$', 'comp': function('s:CompBufferFunction') })

cal s:addRule({ 'only':1, 'head': '^has\s\+\w\+' , 'context': '^\s*$' , 'backward': '\w*$', 'comp': function('s:CompMooseAttribute') } )
cal s:addRule({ 'only':1, 'head': '^with\s\+', 'context': '^\s*-$', 'backward': '\w\+$', 'comp': function('s:CompMooseRoleAttr') } )

cal s:addRule({ 'context': '^\s*$', 'backward': '\w\+$', 'comp':function('s:CompMooseStatement')})
" }}}
" Core Completion Rules {{{
cal s:addRule({'only':1, 'context': '^=$', 'backward': '\w*$', 'comp': function('s:CompPodHeaders') })


" class name completion
cal s:addRule({'only':1, 'context': '\<\(new\|use\)\s\+\(\(base\|parent\)\s\+\(qw\)\?[''"(/]\)\?$' , 'backward': '\<[A-Z][a-z0-9_:]*$', 'comp': function('s:CompClassName') } )
cal s:addRule({'only':1, 'context': '^extends\s\+[''"]$' , 'backward': '\<\u[A-Za-z0-9_:]*$', 'comp': function('s:CompClassName') } )
cal s:addRule({'context': '^\s*\(sub\|method\)\s\+'              , 'backward': '\<\w\+$' , 'only':1 , 'comp': function('s:CompCurrentBaseFunction') })
cal s:addRule({'only':1, 'context': '^\s*my\s\+\$self$' , 'backward': '\s*=\s\+shift;', 'comp': [ ' = shift;' ] })

" variable completion
cal s:addRule({'only':1, 'context': '\s*\$$' , 'backward': '\<\U\w*$' , 'comp': function('s:CompVariable') })
cal s:addRule({'only':1, 'context': '%$', 'backward': '\<\U\w\+$', 'comp': function('s:CompHashVariable') })
cal s:addRule({'only':1, 'context': '@$', 'backward': '\<\U\w\+$', 'comp': function('s:CompArrayVariable') })

cal s:addRule({'only':1, 'context': '&$', 'backward': '\<\U\w\+$', 'comp': function('s:CompBufferFunction') })

" function completion
cal s:addRule({'context': '\(->\|\$\)\@<!$',        'backward': '\<\w\+$' , 'comp': function('s:CompFunction') })
cal s:addRule({'context': '\$\(self\|class\)->$'  , 'backward': '\<\w\+$' , 'only':1 , 'comp': function('s:CompBufferFunction') })
cal s:addRule({'context': '\$\w\+->$'  ,            'backward': '\<\w\+$' , 'comp': function('s:CompObjectMethod') })
cal s:addRule({'context': '\<[a-zA-Z0-9:]\+->$'  ,  'backward': '\w*$' , 'comp': function('s:CompClassFunction') })

cal s:addRule({'context': '$' , 'backward': '\<\u\w*::[a-zA-Z0-9:]*$', 'comp': function('s:CompClassName') } )

" string completion
" cal s:addRule({'context': '\s''', 'backward': '\_[^'']*$' , 'comp': function('s:CompQString') })

" }}}


" }}}
setlocal omnifunc=PerlComplete

" Configurations
cal s:defopt('perlomni_cache_expiry',30)
cal s:defopt('perlomni_max_class_length',40)
cal s:defopt('perlomni_sort_class_by_lenth',0)
cal s:defopt('perlomni_use_cache',1)
cal s:defopt('perlomni_use_perlinc',1)
