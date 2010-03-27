" vim:fdm=marker:sw=4:et:
"
" Plugin:  perlomni.vim
" Author:  Cornelius
" Email:   cornelius.howl@gmail.com 
" Version: 1.75
let s:debug_flag = 1
runtime 'plugin/perlomni-data.vim'
runtime 'plugin/perlomni-util.vim'

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


fun! s:debug(name,var)
    if s:debug_flag
        echo a:name . ":" . a:var
        sleep 1
    endif
endf

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

                cal extend(b:comps,call( rule.comp, [basetext,lefttext] ))
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
fun! s:addRule(hash)
    cal add( s:rules , a:hash )
endf

fun! g:p5cRule(hash)
    cal s:addRule(a:hash)
endf

" Util Functions {{{
fun! s:Quote(list)
    return map(copy(a:list), '"''".v:val."''"' )
endf

fun! s:RegExpFilter(list,pattern)
    let pattern = substitute(a:pattern,"'","''",'g')
    return filter(copy(a:list),"v:val =~ '^".pattern."'")
endf

fun! s:StringFilter(list,string)
    return filter( copy(a:list),"stridx(v:val,'".a:string."') == 0 && v:val != '".a:string."'" )
endf
" }}}

" SIMPLE MOOSE COMPLETION {{{
fun! s:CompMooseIs(base,context)
    return s:Quote(['rw','ro','wo'])
endf

fun! s:CompMooseIsa(base,context)
    let l:comps = s:Quote(["Int", "Str", "HashRef", "HashRef[","Num",'ArrayRef'])
    " XXX: could be class name
    return s:RegExpFilter( l:comps, a:base  )
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
" }}}
" PERL CORE OMNI COMPLETION {{{
fun! s:CompFunction(base,context)
    " return map(filter(copy(g:p5bfunctions),'v:val =~ ''^'.a:base.'''' ),'{ "word" : v:val , "kind": "f" }')
    " return filter(copy(g:p5bfunctions),'v:val =~ ''^'.a:base.'''' )
    " return s:RegExpFilter( g:p5bfunctions , a:base )
    echo 'base:' . a:base
    sleep 1
    return s:StringFilter(g:p5bfunctions,a:base)
endf

fun! s:CompVariable(base,context)
    " scan variables in current buffer
    let lines = getline(1,'$')
    let variables = s:scanVariable(getline(1,'$'))
    return filter( copy(variables),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
endf

fun! s:CompBufferFunction(base,context)
    let lines = getline(1,'$')
    let funclist = s:scanFunctionFromList(getline(1,'$'))
    return filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
endf

fun! s:CompClassFunction(base,context)
    let class = substitute(a:context,'->$','','')
    let funclist = s:scanFunctionFromClass( class )
    return filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
endf

fun! s:CompObjectMethod(base,context)
    let objvarname = substitute(a:context,'->$','','')
    if ! exists('b:objvarMapping') || ! has_key(b:objvarMapping,objvarname)
        " find a small scope
        let minnr = line('.') - 10
        let minnr = minnr < 1 ? 1 : minnr
        let lines = getline( minnr , line('.') )
        cal s:scanObjectVariableLines(lines)
        " cal s:scanObjectVariableFile()
    endif

    let funclist = [ ]
    if has_key(b:objvarMapping,objvarname)
        let classes = b:objvarMapping[ objvarname ]
        for class in classes
            cal extend(funclist,s:scanFunctionFromClass( class ))
        endfor
    endif
    return filter( copy(funclist),"stridx(v:val,'".a:base."') == 0 && v:val != '".a:base."'" )
endf
" }}}
" SCOPE FUNCTIONS {{{
" XXX:
fun! s:getSubScopeLines(nr)
    let curline = getline(a:nr)
endf
" }}}
" SCANNING FUNCTIONS {{{
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
    let list = split(system('grep-objvar.pl ' . a:file . ' '),"\n") 
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
endf
" echo s:scanObjectVariableFile( expand('~/git/bps/jifty-dbi/lib/Jifty/DBI/Collection.pm') )


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
    let paths = split( system("perl -e 'print join(\",\",@INC)'") ,',')
    let filepath = substitute(a:class,'::','/','g') . '.pm'
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
" Moose Completion Rules
cal s:addRule( { 'only':1, 'head': '^has\s\+\w\+' , 'context': '\s\+is\s*=>\s*$'  , 'backward': '\S*$' , 'comp': function('s:CompMooseIs') } )
cal s:addRule( { 'only':1, 'head': '^has\s\+\w\+' , 'context': '\s\+isa\s*=>\s*$' , 'backward': '\S*$' , 'comp': function('s:CompMooseIsa') } )
cal s:addRule( { 'only':1, 'head': '^has\s\+\w\+' , 'context': '^\s*$' , 'backward': '\w*$', 'comp': function('s:CompMooseAttribute') } )
cal s:addRule( { 'only':1, 'head': '^with\s\+', 'context': '^\s*-$', 'backward': '\w\+$', 'comp': function('s:CompMooseRoleAttr') } )


" Core Completion Rules
cal s:addRule({'context': '\s*\$$' , 'backward': '\<\w\+$' , 'comp': function('s:CompVariable') })
cal s:addRule({'context': '\(->\|\$\)\@<!$', 'backward': '\<\w\+$' , 'comp': function('s:CompFunction') })
cal s:addRule({'context': '\$self->$'  , 'backward': '\<\w\+$' , 'only':1 , 'comp': function('s:CompBufferFunction') })
cal s:addRule({'context': '\$\w\+->$'  , 'backward': '\<\w\+$' , 'comp': function('s:CompObjectMethod') })
cal s:addRule({'context': '\<[a-zA-Z0-9:]\+->$'    , 'backward': '\w*$' , 'comp': function('s:CompClassFunction') })
" }}}
setlocal omnifunc=PerlComplete2

finish
" SAMPLES {{{

" complete class methods
Jifty::DBI::Record->

" complete built-in function
seekdir see


" complete current object methods
sub testtest { }
sub foo1 { }
sub foo2 { }

$self->


" smart object method completion
my $var = new Jifty;
$var->


" smart object method completion 2
my $var = Jifty::DBI->new;
$var->


" complete variable
$var1 $var2 $var3 $var_test $var__adfasdf
$var__adfasd  $var1 


" moose complete

has url => (
    metaclass => 'Labeled',
    is        => 'wo',
    isa       => 'HashRef',
    label     => "The site's URL",
);

" role

with 'Restartable' => {
    -alias => {
        stop  => '_stop',
        start => '_start'
    },
    -excludes => [ 'stop', 'start' ],
};

" }}}
