
fun! s:FindMethodCompReferStart(line)
  return searchpos( '\S\+\(->\)\@='  , 'bn' , a:line )
endf

fun! s:FindMethodCompStart(start,line)
  let s = a:start
  while s > 0 && a:line[s - 1] =~ '\a'
    let s -= 1
  endwhile
  return s
endf

fun! PerlComplete(findstart, base)
  let line = getline('.')
  let start = col('.') - 1
  if a:findstart == 1
    return s:FindMethodCompStart(start,line)
  else 
    " hate vim script forgot last position we found 
    " so we need to find a start again ... orz
    let s = s:FindMethodCompStart(start,line)
    let curfile = expand('%')

    " -2 because "->"
    let ref_start = s:FindMethodCompReferStart(line)
    let ref_base = strpart( line , ref_start[1] - 1 , s - 1 - ref_start[1] )

    " $self or class
    let res = [ ]
    if ref_base =~ '\$\(self\|class\)' 
      let res = libperl#grep_file_functions( curfile )
      for token in res 
        cal complete_add( token )
      endfor
      " find base class functions here
    
    elseif ref_base =~ g:libperl#pkg_token_pattern 

    endif
    return [ ]
  endif
endf


" $self->asdfj
set completefunc=PerlComplete
