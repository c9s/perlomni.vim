
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

    " -2 because "->"
    let ref_start = s:FindMethodCompReferStart(line)
    let ref_base = strpart( line , ref_start[1] - 1 , s - 1 - ref_start[1] )

    echo ref_base
    sleep 1

    " do search
    let res = ['asdf', 'zxcv']
    for m in split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec")
      if m =~ '^' . a:base
        call add(res, m)
      endif
    endfor
    return res
  endif
endf


" $self->asdf
set completefunc=PerlComplete
