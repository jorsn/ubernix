{ runCommand }:

name: runCommand "impureHostRpm-${name}" {} ''
  PATH=/bin:/usr/bin:$PATH

  files="$(rpm -ql ${name})"
  # install directories from rpm into $out
  echo "$files" | sed -e 's+^/usr++g' -e 's+/[^/]*$++g' -e "s+^+$out+g" | sort -u | xargs install -d
  # link files from installed rpm int $out
  for f in $files; do
    if [ -e $f -a ! -d $f ]; then
      ln -s $f $out/''${f#/usr}
    fi
  done

  libdir=$out/lib64
  test -d $libdir && mv $libdir $out/lib || :
''
