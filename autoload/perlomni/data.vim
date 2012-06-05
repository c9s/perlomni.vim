fun! s:build_hash(list,menu)
  return map( a:list , '{ "word": v:val , "menu": "'. a:menu .'" }' )
endf

let s:p5bfunctions =
      \ s:build_hash( split('abs accept alarm atan2 bind binmode bless break caller chdir chmod chomp chop chown chr chroot close closedir connect continue cos crypt dbmclose dbmopen defined delete die do dump each endgrent endhostent endnetent endprotoent endpwent endservent eof eval exec exists exit exp fcntl fileno flock fork format formline getc getgrent getgrgid getgrnam gethostbyaddr gethostbyname gethostent getlogin getnetbyaddr getnetbyname getnetent getpeername getpgrp getppid getpriority getprotobyname getprotobynumber getprotoent getpwent getpwnam getpwuid getservbyname getservbyport getservent getsockname getsockopt glob gmtime goto grep hex import index int ioctl join keys kill last lc lcfirst length link listen local localtime lock log lstat m map mkdir msgctl msgget msgrcv msgsnd my next no oct open opendir ord our pack package pipe pop pos print printf prototype push q qq qr quotemeta qw qx rand read readdir readline readlink readpipe recv redo ref rename require reset return reverse rewinddir rindex rmdir s say scalar seek seekdir select semctl semget semop send setgrent sethostent setnetent setpgrp setpriority setprotoent setpwent setservent setsockopt shift shmctl shmget shmread shmwrite shutdown sin sleep socket socketpair sort splice split sprintf sqrt srand stat state study sub substr symlink syscall sysopen sysread sysseek system syswrite tell telldir tie tied time times tr truncate uc ucfirst umask undef unlink unpack unshift untie use utime values vec wait waitpid wantarray warn write y'),
      \ 'built-in' )

function! perlomni#data#p5bfunctions()
  return s:p5bfunctions
endfunction

" XXX: should be automatically build by script ( utils/build_mi_args.pl )
let s:p5_mi_export =
    \ s:build_hash( split( 'resources install_as_vendor keywords bundles write_mymeta_json recommends sign no_index perl_version_from name install_requires provides add_metadata author module_name repository version author_from test_requires_from configure_requires perl_version install_as_cpan all_from version_from feature read write_mymeta_yaml write install_as_site authors requires_from bugtracker_from auto_provides homepage abstract abstract_from test_requires distribution_type installdirs bugtracker dynamic_config license_from requires install_as_core features name_from license import build_requires tests' ) ,
    \ 'Module::Install::Metadata' )

function! perlomni#data#p5_mi_export()
  return s:p5_mi_export
endfunction
