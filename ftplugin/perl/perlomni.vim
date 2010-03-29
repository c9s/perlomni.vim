" vim:fdm=marker:sw=4:et:fdl=0:
"
" Plugin:  perlomni.vim
" Author:  Cornelius
" Email:   cornelius.howl@gmail.com 
" Version: 1.75
let s:debug_flag = 0
runtime 'plugin/perlomni-data.vim'
runtime 'plugin/perlomni-util.vim'

" Warning {{{
if ! executable('grep-objvar.pl')
            \ && ! executable('grep-pattern.pl')
    echo "Please add ~/.vim/bin to your PATH env variable."
    echo "And make them executable."
    echo "For example:"
    echo ""
    echo "  export PATH=~/.vim/bin/:$PATH"
    echo ""
    echo "And Run:"
    echo ""
    echo "  $ chmod +x ~/.vim/bin/grep-*.pl "
    echo ""
    finish
endif
" }}}
" Cache Function. {{{
fun! GetCacheNS(ns,key)
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
" }}}

" XXX:
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

fun! s:ClassCompAdd(base,b)
    for f in a:b.functions
        if f =~ '^'.a:base
            cal add(b:comp_items,{ 'word': f , 'kind': 'f' , 'menu': a:b.class } )
        endif
    endfor
endf


" ===================================
fun! s:addRule(hash)
    cal add( s:rules , a:hash )
endf

fun! g:p5cRule(hash)
    cal s:addRule(a:hash)
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
                \ 'refresh_with' , 'required' ]
    return s:StringFilter(values,a:base)
endf

fun! s:CompMooseRoleAttr(base,context)
    let attrs = [ 'alias', 'excludes' ]
    return s:StringFilter(attrs,a:base)
endf
fun! s:CompMooseStatement(base,context)
    let sts = [ 'extends' , 'after' , 'before', 'has' , 'requires' , 'with' , 'override' , 'method' ]
    return s:StringFilter(sts,a:base)
endf
" }}}
" PERL CORE OMNI COMPLETION {{{
fun! s:CompFunction(base,context)
    return s:StringFilter(g:p5bfunctions,a:base)
endf

fun! s:CompVariable(base,context)
    let lines = getline(1,'$')
    let variables = s:scanVariable(getline(1,'$'))
    cal extend( variables , s:scanArrayVariable(getline(1,'$')))
    cal extend( variables , s:scanHashVariable(getline(1,'$')))
    return filter( copy(variables),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
endf

fun! s:CompArrayVariable(base,context)
    let lines = getline(1,'$')
    let variables = s:scanArrayVariable(getline(1,'$'))
    return filter( copy(variables),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
endf

fun! s:CompHashVariable(base,context)
    let lines = getline(1,'$')
    let variables = s:scanHashVariable(getline(1,'$'))
    return filter( copy(variables),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
endf

fun! s:CompBufferFunction(base,context)
    let l:cache = GetCacheNS('bufferfunction',a:base.bufnr('%'))
    if type(l:cache) != type(0)
        return l:cache
    endif

    let lines = getline(1,'$')
    let funclist = s:scanFunctionFromList(getline(1,'$'))
    let result = filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
    cal SetCacheNS('classfunc',a:base.bufnr('%'),result)
    return result
endf

fun! s:CompClassFunction(base,context)
    let class = substitute(a:context,'->$','','')
    let l:cache = GetCacheNS('classfunc',class.a:base)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let funclist = s:scanFunctionFromClass(class)
    let result = filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
    cal SetCacheNS('classfunc',class.a:base,result)
    return result
endf

fun! s:CompPodHeaders(base,context)
    let pods = [ 'head1' , 'head2' , 'head3' , 'begin' , 'end', 'encoding' , 'cut' , 'pod' , 'over' , 'item' , 'for' , 'back' ]
    " let result = filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
    " cal SetCacheNS('classfunc',class.a:base,result)
    return s:StringFilter( pods , a:base )
endf
" echo s:CompPodHeaders('h','')

fun! s:CompObjectMethod(base,context)
    let objvarname = substitute(a:context,'->$','','')
    if ! exists('b:objvarMapping') || ! has_key(b:objvarMapping,objvarname)
        let minnr = line('.') - 10
        let minnr = minnr < 1 ? 1 : minnr
        let lines = getline( minnr , line('.') )
        cal s:scanObjectVariableLines(lines)
    endif

    if ! has_key(b:objvarMapping,objvarname)
        let bufferfiles = s:grepBufferList('\.p[ml]$')
        for file in bufferfiles
            cal s:scanObjectVariableFile( file )
        endfor
    endif

    let funclist = [ ]
    if has_key(b:objvarMapping,objvarname)
        let classes = b:objvarMapping[ objvarname ]
        for class in classes
            cal extend(funclist,s:scanFunctionFromClass( class ))
        endfor
        return filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
    endif
    return [ ]
endf

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
        if g:perlomni_sort_class_by_lenth
            cal sort(result,'s:SortByLength')
        else
            cal sort(result)
        endif
    endif
    cal SetCacheNS('class',a:base,result)
    return result
endf

fun! s:SortByLength(i1, i2)
    return strlen(a:i1) == strlen(a:i2) ? 0 : strlen(a:i1) > strlen(a:i2) ? 1 : -1
endfunc

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
  if executable('zcat')
    let cmd = 'zcat ' . a:file . " | grep -v '^[0-9a-zA-Z-]*: '  | cut -d' ' -f1 > " . g:cpan_mod_cachef
  else
    let cmd = 'cat ' . a:file . " | gunzip | grep -v '^[0-9a-zA-Z-]*: '  | cut -d' ' -f1 > " . g:cpan_mod_cachef
  endif
  echo system( cmd )
  if v:shell_error 
    echoerr v:shell_error
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
  cal s:echo("CPAN source list not found.")
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

  cal s:echo("Downloading CPAN source list.")
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
    let l:files = split(glob(a:path . '/**'))
    cal filter(l:files, 'v:val =~ "\.pm$"')
    cal map(l:files, 'strpart(v:val,strlen(a:path))')
    return l:files
endf

fun! s:scanObjectVariableLines(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    let varlist = split(system('grep-objvar.pl ' . buffile . ' '),"\n") 
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
    let l:cache = GetCacheNS('objvar_', a:file)
    if type(l:cache) != type(0)
        return l:cache
    endif

    let list = split(system('grep-objvar.pl ' . expand(a:file) . ' '),"\n") 
    let b:objvarMapping = { }
    for item in list
        let [varname,classname] = split(item)
        if exists('b:objvarMapping[varname]')
            cal add( b:objvarMapping[ varname ] , classname )
        else
            let b:objvarMapping[ varname ] = [ classname ]
        endif
    endfor
    return SetCacheNS('objvar_',a:file,b:objvarMapping)
endf
" echo s:scanObjectVariableFile( expand('~/git/bps/jifty-dbi/lib/Jifty/DBI/Collection.pm') )


fun! s:scanHashVariable(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    return split(system('grep-pattern.pl ' . buffile . ' ''%(\w+)'' | sort | uniq '),"\n") 
endf
" echo s:scanHashVariable( getline(1,'$') )


fun! s:scanQString(lines)
    let buffile = tempname()
    cal writefile( a:lines, buffile)
    let cmd = system('grep-pattern.pl '.buffile.' ''[''](.*?)(?<!\\)['']''')
    return split( cmd ,"\n")
endf

fun! s:scanQQString(lines)
    let buffile = tempname()
    cal writefile( a:lines, buffile)
    return split(system('grep-pattern.pl '.buffile.' ''["](.*?)(?<!\\)["]'''),"\n")
endf
" echo s:scanQQStringFile('testfile')

fun! s:scanArrayVariable(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    return split(system('grep-pattern.pl ' . buffile . ' ''@(\w+)'' | sort | uniq '),"\n") 
endf

fun! s:scanVariable(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    return split(system('grep-pattern.pl ' . buffile . ' ''\$(\w+)'' | sort | uniq '),"\n") 
endf

fun! s:scanFunctionFromList(lines)
    let buffile = tempname()
    cal writefile(a:lines,buffile)
    return split(system('grep-pattern.pl ' . buffile . ' ''^\s*sub\s+(\w+)'' | sort | uniq '),"\n")
endf

fun! s:scanFunctionFromClass(class)
    let paths = split(&path,',')

    " FOR DEBUG
    " let paths = split( system("perl -e 'print join(\",\",@INC)'") ,',')
    let filepath = substitute(a:class,'::','/','g') . '.pm'
    cal insert(paths,'lib')

    let classfile = ''
    for path in paths
        if filereadable( path . '/' . filepath ) 
            let classfile = path .'/' . filepath
            break
        endif
    endfor
    if strlen(classfile) == 0
        return [ ]
    endif
    return split(system('grep-pattern.pl ' . classfile . ' ''^\s*sub\s+(\w+)'' | sort | uniq '),"\n")
endf
" echo s:scanFunctionFromClass('Jifty::DBI::Record')

" }}}
" RULES {{{
" rules have head should be first matched , because of we get first backward position.
"
" Moose Completion Rules {{{
cal s:addRule({ 'only':1, 'head': '^has\s\+\w\+' , 'context': '\s\+is\s*=>\s*$'  , 'backward': '[''"]\?\w*$' , 'comp': function('s:CompMooseIs') } )
cal s:addRule({ 'only':1, 'head': '^has\s\+\w\+' , 'context': '\s\+isa\s*=>\s*$' , 'backward': '[''"]\?\S*$' , 'comp': function('s:CompMooseIsa') } )

cal s:addRule({ 'only':1, 'head': '^has\s\+\w\+' , 'context': '^\s*$' , 'backward': '\w*$', 'comp': function('s:CompMooseAttribute') } )
cal s:addRule({ 'only':1, 'head': '^with\s\+', 'context': '^\s*-$', 'backward': '\w\+$', 'comp': function('s:CompMooseRoleAttr') } )

cal s:addRule({ 'context': '^\s*$', 'backward': '\w\+$', 'comp':function('s:CompMooseStatement')})
" }}}
" Core Completion Rules {{{
cal s:addRule({'only':1, 'context': '^=$', 'backward': '\w*$', 'comp': function('s:CompPodHeaders') })

" class name completion
cal s:addRule({'only':1, 'context': '\<\(new\|use\)\s\+$' , 'backward': '\<[A-Z][a-z0-9_:]*$', 'comp': function('s:CompClassName') } )
cal s:addRule({'only':1, 'context': '^extends\s\+''$' , 'backward': '\<[A-Z][a-z0-9_:]*$', 'comp': function('s:CompClassName') } )
cal s:addRule({'only':1, 'context': '^use \(base\|parent\)\s\+$' , 'backward': '\<[A-Z][a-z0-9_:]*$', 'comp': function('s:CompClassName') } )
cal s:addRule({'only':1, 'context': '^\s*my\s\+\$self$' , 'backward': '\s*=\s\+shift;', 'comp': [ ' = shift;' ] })


" variable completion
cal s:addRule({'only':1, 'context': '\s*\$$' , 'backward': '\<\w\+$' , 'comp': function('s:CompVariable') })
cal s:addRule({'only':1, 'context': '%$', 'backward': '\<\w\+$', 'comp': function('s:CompHashVariable') })
cal s:addRule({'only':1, 'context': '@$', 'backward': '\<\w\+$', 'comp': function('s:CompArrayVariable') })

cal s:addRule({'only':1, 'context': '&$', 'backward': '\<\w\+$', 'comp': function('s:CompBufferFunction') })

" function completion
cal s:addRule({'context': '\(->\|\$\)\@<!$', 'backward': '\<\w\+$' , 'comp': function('s:CompFunction') })
cal s:addRule({'context': '\$self->$'  , 'backward': '\<\w\+$' , 'only':1 , 'comp': function('s:CompBufferFunction') })
cal s:addRule({'context': '\$\w\+->$'  , 'backward': '\<\w\+$' , 'comp': function('s:CompObjectMethod') })
cal s:addRule({'context': '\<[a-zA-Z0-9:]\+->$'    , 'backward': '\w*$' , 'comp': function('s:CompClassFunction') })



" string completion
" cal s:addRule({'context': '\s''', 'backward': '\_[^'']*$' , 'comp': function('s:CompQString') })

" }}}


" }}}
setlocal omnifunc=PerlComplete2

" Configurations
cal s:defopt('perlomni_max_class_length',100)
cal s:defopt('perlomni_sort_class_by_lenth',0)
cal s:defopt('perlomni_use_cache',1)

finish
" SAMPLES {{{

extends 'Moose::Meta::Attribute';
extends 'AAC::Pvoice';

" module compeltion
my $obj = new Jifty::Web;

" complete class methods
Jifty::DBI::Record->
Jifty->

" complete built-in function
seekdir splice 


" $self completion
"   my $self
" to 
"   my $self = shift;
my $self

" complete current object methods
sub testtest { }
sub foo1 { }
sub foo2 { }


$self->testtest

\&fo

" smart object method completion
my $var = new Jifty;
$var->

" smart object method completion 2
my $var = Jifty::DBI->new;
$var->


my %hash = ( );
my @array = ( );


" complete variable
$var1 $var2 $var3 $var_test $var__adfasdf
$var__adfasd  $var1 

" moose complete

has url => (
    metaclass => 'Labeled',
    is        => 'rw',
    label     => "The site's URL",
    isa => 'AFS::Object::Server',
);

" role

with 'Restartable' => {
    -alias => {
        stop  => '_stop',
        start => '_start'
    },
    -excludes => [ 'stop', 'start' ],
};

# 'string' , 'string \' escpae'

new Jifty::View::Declare::Page



" }}}
