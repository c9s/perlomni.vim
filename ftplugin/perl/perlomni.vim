" vim:fdm=marker:sw=4:et:fdl=0:
"
" Plugin:  perlomni.vim
" Author:  Cornelius
" Email:   cornelius.howl@gmail.com
" Version: 2.5
let s:debug_flag = 0

let s:mod_pattern = '[a-zA-Z][a-zA-Z0-9:]\+'

" Check installed scripts {{{
fun! s:findBin(script)
    let bins = split(globpath(&rtp, 'bin/'.a:script), "\n")
    if len(bins) == 0
        return ''
    endif
    return bins[0][:-len(a:script)-1]
endfunction
let s:vimbin = s:findBin('grep-objvar.pl')
" }}}

" Warning {{{
if len(s:vimbin) == 0
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
            if ext == '.PL' && executable(g:perlomni_perl)
                let cmd = g:perlomni_perl
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
    return s:rule(a:hash)
endf

" Cache Function. {{{
let s:last_cache_ts = localtime()
let s:cache_expiry =  { }
let s:cache_last   =  { }

fun! GetCacheNS(ns,key)
    let key = a:ns . "_" . a:key
    if has_key( s:cache_expiry , key )
        let expiry = s:cache_expiry[ key ]
        let last_ts = s:cache_last[ key ]
    else
        let expiry = g:perlomni_cache_expiry
        let last_ts = s:last_cache_ts
    endif

    if localtime() - last_ts > expiry
        if has_key( s:cache_expiry , key )
            let s:cache_last[ key ] = localtime()
        else
            let s:last_cache_ts = localtime()
        endif
        return 0
    endif

    if ! g:perlomni_use_cache
        return 0
    endif
    if exists('g:perlomni_cache[key]')
        return g:perlomni_cache[key]
    endif
    return 0
endf

fun! SetCacheNSWithExpiry(ns,key,value,exp)
    if ! exists('g:perlomni_cache')
        let g:perlomni_cache = { }
    endif
    let key = a:ns . "_" . a:key
    let g:perlomni_cache[ key ] = a:value
    let s:cache_expiry[ key ] = a:exp
    let s:cache_last[ key ] = localtime()
    return a:value
endf

fun! SetCacheNS(ns,key,value)
    if ! exists('g:perlomni_cache')
        let g:perlomni_cache = { }
    endif
    let key = a:ns . "_" . a:key
    let g:perlomni_cache[ key ] = a:value
    return a:value
endf
com! PerlOmniCacheClear  :unlet g:perlomni_cache

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
        let paths = split( s:system(g:perlomni_perl, '-e', 'print join(",",@INC)') ,',')
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

fun! s:rule(hash)
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


    if ! exists('b:lines')
        " max 200 lines , to '$' will be very slow
        let b:lines = getline( 1, 200 )
    endif

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


            if ( has_key( rule ,'head')
                    \ && b:paragraph_head =~ rule.head
                    \ && lefttext =~ rule.context )
                \ || ( ! has_key(rule,'head') && lefttext =~ rule.context  )

                if has_key( rule ,'contains' )
                    let l:text = rule.contains
                    let l:found = 0
                    " check content
                    for line in b:lines
                        if line =~ rule.contains
                            let l:found = 1
                            break
                        endif
                    endfor
                    if ! l:found
                        " next rule
                        continue
                    endif
                endif

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
    return filter(copy(a:list),"v:val =~ a:pattern")
endf

fun! s:StringFilter(list,string)
    return filter(copy(a:list),"stridx(v:val,a:string) == 0 && v:val != a:string" )
endf

fun! s:ShellQuote(s)
  return &shellxquote == '"' ? "'".a:s."'" : '"'.a:s.'"'
endfunction

" }}}


" Available Rule attributes
"   only:
"       if one rule is matched, then rest rules won't be check.
"   contains:
"       if file contains some string (can be regexp)
"   context:
"       completion context pattern
"   backward:
"       regexp for moving cursor back to the completion position.
"   head:
"       pattern that matches paragraph head.
"   comp:
"       completion function reference.

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
    let efuncs = s:scanCurrentExportFunction()
    let flist = copy(perlomni#data#p5bfunctions())
    cal extend(flist,efuncs)
    return filter(flist,'v:val.word =~ "^".a:base')
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
    let funclist = SetCacheNS('classfunc',class.'_'.a:base,result)
    if g:perlomni_show_hidden_func == 0
        call filter(funclist, 'v:val !~ "^_"')
    endif
    return funclist
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
        let funclist = SetCacheNS('objectMethod',objvarname.'_'.a:base,result)
    endif
    if g:perlomni_show_hidden_func == 0
        call filter(funclist, 'v:val !~ "^_"')
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

    " XXX: prevent waiting too long
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


fun! s:CompUnderscoreTokens(base,context)
    return s:StringFilter( [ 'PACKAGE__' , 'END__' , 'DATA__' , 'LINE__' , 'FILE__' ] , a:base )
endf

fun! s:CompPodSections(base,context)
    return s:StringFilter( [ 'NAME' , 'SYNOPSIS' , 'AUTHOR' , 'DESCRIPTION' , 'FUNCTIONS' ,
        \ 'USAGE' , 'OPTIONS' , 'BUG REPORT' , 'DEVELOPMENT' , 'NOTES' , 'ABOUT' , 'REFERENCES' ] , a:base )
endf

fun! s:CompPodHeaders(base,context)
    return s:StringFilter(
        \ [ 'head1' , 'head2' , 'head3' , 'begin' , 'end',
        \   'encoding' , 'cut' , 'pod' , 'over' ,
        \   'item' , 'for' , 'back' ] , a:base )
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
    let args = ['cat', a:file, '|', 'gzip', '-dc', '|',
      \ 'grep', '-Ev', '^[A-Za-z0-9-]+: ', '|', 'cut', '-d" "', '-f1']
    let data = call(function("s:system"), args)
    cal writefile(split(data, "\n"), g:cpan_mod_cachef)
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
    exec '!curl http://cpan.nctu.edu.tw/modules/02packages.details.txt.gz -o ' . s:ShellQuote(f)
    return f
  elseif executable('wget')
    exec '!wget http://cpan.nctu.edu.tw/modules/02packages.details.txt.gz -O ' . s:ShellQuote(f)
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


fun! s:runPerlEval(mtext,code)
    let cmd = g:perlomni_perl . ' -M' . a:mtext . ' -e "' . escape(a:code,'"') . '"'
    return system(cmd)
endf

" scan exported functions from a module.
fun! s:scanModuleExportFunctions(class)
    let l:cache = GetCacheNS('mef',a:class)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let funcs = []

    " XXX: TOO SLOW, CACHE TO FILE!!!!
    if exists('g:perlomni_export_functions')
        let output = s:runPerlEval( a:class , printf( 'print join " ",@%s::EXPORT_OK' , a:class ))
        cal extend( funcs , split( output ) )
        let output = s:runPerlEval( a:class , printf( 'print join " ",@%s::EXPORT' , a:class ))
        cal extend( funcs , split( output ) )
        echo [a:class,output]
    endif
    return SetCacheNS('mef',a:class,s:toCompHashList(funcs,a:class))
endf
" echo s:scanModuleExportFunctions( 'List::MoreUtils' )
" sleep 1

" util function for building completion hashlist
fun! s:toCompHashList(list,menu)
  return map( a:list , '{ "word": v:val , "menu": "'. a:menu .'" }' )
endf


" Scan export functions in current buffer
" Return functions
fun! s:scanCurrentExportFunction()
    let l:cache = GetCacheNS('cbexf', bufname('%'))
    if type(l:cache) != type(0)
        return l:cache
    endif

    let lines = getline( 1 , '$' )
    cal filter(  lines , 'v:val =~ ''^\s*\(use\|require\)\s''')
    let funcs = [ ]
    for line in lines
        let m = matchstr( line , '\(^use\s\+\)\@<=' . s:mod_pattern )
        if strlen(m) > 0
            cal extend(funcs ,s:scanModuleExportFunctions(m))
        endif
    endfor
    return SetCacheNS('cbexf',bufname('%'),funcs)
endf
" echo s:scanCurrentExportFunction()
" sleep 1


" FUNC: scanClass {{{
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
" }}}
" FUNC: scanObjectVariableLines {{{
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
" }}}

fun! s:scanObjectVariableFile(file)
"     let l:cache = GetCacheNS('objvar', a:file)
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
"     return SetCacheNSWithExpiry('objvar',a:file,b:objvarMapping,60 * 10)
endf
" echo s:scanObjectVariableFile( expand('~/git/bps/jifty-dbi/lib/Jifty/DBI/Collection.pm') )



" XXX: CACHE THIS
fun! s:scanHashVariable(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    return split(s:system(s:vimbin.'grep-pattern.pl', buffile, '%(\w+)', '|', 'sort', '|', 'uniq'),"\n")
endf
" echo s:scanHashVariable( getline(1,'$') )


" XXX: CACHE THIS
fun! s:scanQString(lines)
    let buffile = tempname()
    cal writefile( a:lines, buffile)
    let cmd = s:system(s:vimbin.'grep-pattern.pl', buffile, '[''](.*?)(?<!\\)['']')
    return split( cmd ,"\n")
endf

" XXX: CACHE THIS
fun! s:scanQQString(lines)
    let buffile = tempname()
    cal writefile( a:lines, buffile)
    return split(s:system(s:vimbin.'grep-pattern.pl', buffile, '["](.*?)(?<!\\)["]'),"\n")
endf
" echo s:scanQQStringFile('testfile')



" XXX: CACHE THIS
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

" XXX: provide a dictinoary loader
fun! s:CompDBIxMethod(base,context)
    return s:StringFilter([
        \ "table" , "table_class" , "add_columns" ,
        \ "set_primary_key" , "has_many" ,
        \ "many_to_many" , "belongs_to" , "add_columns" ,
        \ "might_have" ,
        \ "has_one",
        \ "add_unique_constraint",
        \ "resultset_class",
        \ "load_namespaces",
        \ "load_components",
        \ "load_classes",
        \ "resultset_attributes" ,
        \ "result_source_instance" ,
        \ "mk_group_accessors",
        \ "storage"
        \ ],a:base)
endf

fun! s:scanDBIxResultClasses()
    let path = 'lib'
    let l:cache = GetCacheNS('dbix_c',path)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let pms = split(system('find ' . path . ' -iname "*.pm" | grep Result'),"\n")
    cal map( pms, 'substitute(v:val,''^.*lib/\?'',"","")')
    cal map( pms, 'substitute(v:val,"\\.pm$","","")' )
    cal map( pms, 'substitute(v:val,"/","::","g")' )

    return SetCacheNS('dbix_c',path,pms)
endf

fun! s:getResultClassName( classes )
    let classes = copy(a:classes)
    cal map( classes , "substitute(v:val,'^.*::','','')" )
    return classes
endf

fun! s:CompDBIxResultClassName(base,context)
    return s:StringFilter( s:getResultClassName(   s:scanDBIxResultClasses()  )  ,a:base)
endf

fun! s:CompExportFunction(base,context)
    let m = matchstr( a:context , '\(^use\s\+\)\@<=' . s:mod_pattern )
    let l:funcs = s:toCompHashList(s:scanModuleExportFunctions(m),m)
    return filter(copy(l:funcs),'v:val.word =~ a:base')
endf

fun! s:CompModuleInstallExport(base,context)
    let words = perlomni#data#p5_mi_export()
    return filter( copy(words) , 'v:val.word =~ a:base' )
endf

" RULES
" ====================================================================
" MODULE-INSTALL FUNCTIONS ================================={{{


cal s:rule({
    \'contains'  :  'Module::Install',
    \'backward'  :  '\w*$',
    \'context'   :  '^$',
    \'comp'      :  function('s:CompModuleInstallExport') })

cal s:rule(  {
    \'context': '^\(requires\|build_requires\|test_requires\)\s',
    \'backward': '[a-zA-Z0-9:]*$',
    \'comp': function('s:CompClassName') })

" }}}
" UNDERSCORES =================================="{{{
cal s:rule({
    \'context': '__$',
    \'backward': '[A-Z]*$',
    \'comp': function('s:CompUnderscoreTokens') })
"}}}

" DBIX::CLASS::CORE COMPLETION ======================================"{{{
"
"   use contains to check file content, do complete dbix methods if and only
"   if there is a DBIx::Class::Core
"
" because there is a rule take 'only' attribute,
" so the rest rules willn't be check.
" for the reason , put the dbix completion rule before them.
" will take a look later ... (I hope)
cal s:rule({
    \'context': '^__PACKAGE__->$',
    \'contains': 'DBIx::Class::Core',
    \'backward': '\w*$',
    \'comp':    function('s:CompDBIxMethod')
    \})

cal s:rule( {
    \'only': 1,
    \'context': '->resultset(\s*[''"]',
    \'backward': '\w*$',
    \'comp':  function('s:CompDBIxResultClassName') } )

"}}}

" Moose Completion Rules {{{
cal s:rule({
    \'only':1,
    \'head': '^has\s\+\w\+' ,
    \'context': '\s\+is\s*=>\s*$'  ,
    \'backward': '[''"]\?\w*$' ,
    \'comp': function('s:CompMooseIs') } )

cal s:rule({
    \'only':1,
    \'head': '^has\s\+\w\+' ,
    \'context': '\s\+\(isa\|does\)\s*=>\s*$' ,
    \'backward': '[''"]\?\S*$' ,
    \'comp': function('s:CompMooseIsa') } )
cal s:rule({ 'only':1, 'head': '^has\s\+\w\+' ,
    \'context': '\s\+\(reader\|writer\|clearer\|predicate\|builder\)\s*=>\s*[''"]$' ,
    \'backward': '\w*$',
    \'comp': function('s:CompBufferFunction') })

cal s:rule({
    \'only':1,
    \'head': '^has\s\+\w\+' ,
    \'context': '^\s*$' ,
    \'backward': '\w*$',
    \'comp': function('s:CompMooseAttribute') } )

cal s:rule({
    \'only':1,
    \'head': '^with\s\+',
    \'context': '^\s*-$',
    \'backward': '\w\+$',
    \'comp': function('s:CompMooseRoleAttr') } )

cal s:rule({
    \'context': '^\s*$',
    \'backward': '\w\+$',
    \'comp':function('s:CompMooseStatement')})

" }}}
" Core Completion Rules {{{
cal s:rule({'only':1, 'context': '^=$', 'backward': '\w*$', 'comp': function('s:CompPodHeaders') })

cal s:rule({'only':1, 'context': '^=\w\+\s' , 'backward': '\w*$', 'comp': function('s:CompPodSections') })

" export function completion
cal s:rule({
    \'only': 1,
    \'context': '^use\s\+[a-zA-Z0-9:]\+\s\+qw',
    \'backward': '\w*$',
    \'comp': function('s:CompExportFunction') })

" class name completion
"  matches:
"     new [ClassName]
"     use [ClassName]
"     use base qw(ClassName ...
"     use base 'ClassName

cal s:rule({
    \'only':1,
    \'context': '\<\(new\|use\)\s\+\(\(base\|parent\)\s\+\(qw\)\?[''"(/]\)\?$' ,
    \'backward': '\<[A-Z][A-Za-z0-9_:]*$',
    \'comp': function('s:CompClassName') } )


cal s:rule({
    \'only':1,
    \'context': '^extends\s\+[''"]$' ,
    \'backward': '\<\u[A-Za-z0-9_:]*$',
    \'comp': function('s:CompClassName') } )

cal s:rule({
    \'context': '^\s*\(sub\|method\)\s\+'              ,
    \'backward': '\<\w\+$' ,
    \'only':1 ,
    \'comp': function('s:CompCurrentBaseFunction') })

cal s:rule({
    \'only':1,
    \'context': '^\s*my\s\+\$self' ,
    \'backward': '\s*=\s\+shift;',
    \'comp': [ ' = shift;' ] })

" variable completion

cal s:rule({
    \'only':1,
    \'context': '\s*\$$' ,
    \'backward': '\<\U\w*$' ,
    \'comp': function('s:CompVariable') })

cal s:rule({
    \'only':1,
    \'context': '%$',
    \'backward': '\<\U\w\+$',
    \'comp': function('s:CompHashVariable') })

cal s:rule({
    \'only':1,
    \'context': '@$',
    \'backward': '\<\U\w\+$',
    \'comp': function('s:CompArrayVariable') })

cal s:rule({
    \'only':1,
    \'context': '&$',
    \'backward': '\<\U\w\+$',
    \'comp': function('s:CompBufferFunction') })


" function completion
cal s:rule({
    \'context': '\(->\|\$\)\@<!$',
    \'backward': '\<\w\+$' ,
    \'comp': function('s:CompFunction') })

cal s:rule({'context': '\$\(self\|class\)->$'  ,
    \'backward': '\<\w\+$' ,
    \'only':1 ,
    \'comp': function('s:CompBufferFunction') })

cal s:rule({
    \'context': '\$\w\+->$'  ,
    \'backward': '\<\w\+$' ,
    \'comp': function('s:CompObjectMethod') })

cal s:rule({
    \'context': '\<[a-zA-Z0-9:]\+->$'  ,
    \'backward': '\w*$' ,
    \'comp': function('s:CompClassFunction') })

cal s:rule({
    \'context': '$' ,
    \'backward': '\<\u\w*::[a-zA-Z0-9:]*$',
    \'comp': function('s:CompClassName') } )

" string completion
" cal s:rule({'context': '\s''', 'backward': '\_[^'']*$' , 'comp': function('s:CompQString') })

" }}}


" }}}
setlocal omnifunc=PerlComplete

" Configurations
cal s:defopt('perlomni_cache_expiry',30)
cal s:defopt('perlomni_max_class_length',40)
cal s:defopt('perlomni_sort_class_by_lenth',0)
cal s:defopt('perlomni_use_cache',1)
cal s:defopt('perlomni_use_perlinc',1)
cal s:defopt('perlomni_show_hidden_func',0)
cal s:defopt('perlomni_perl','perl')
