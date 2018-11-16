exit_if_error(){
    if [ "$?" -ne "0" ] ; then
        echo "!!! exit if error triggered !!!"
        exit 1
    fi
}

local_install_dir=`pwd`/___local

git_repo=`pwd`

install_unreleased_psmt2_frontend(){
    opam pin add psmt2-frontend --kind auto https://github.com/Coquera/psmt2-frontend.git ; exit_if_error
}

non_regression(){
    echo "=+= [travis.sh] non-regression tests ... =+="
    echo "which alt-ergo == `which alt-ergo`"
    echo "alt-ergo -version == `alt-ergo -version`"
    here=`pwd`
    cd ../non-regression

    sh ./run_valid.sh "alt-ergo" "0.5" ; exit_if_error

    sh ./run_invalid.sh "alt-ergo" "0.5" ; exit_if_error

    # - make non-regression
    cd $pwd
}

library(){
    lib_path=$1
    echo "=+= [travis.sh] build and test library example ... =+="
    echo "which alt-ergo == `which alt-ergo`"
    echo "alt-ergo -version == `alt-ergo -version`"
    echo "path to lib == $lib_path"
    x=`ls $lib_path`
    echo "content of lib == $x"
    cd $git_repo/sources/examples
    ocamlopt -o lib_usage \
             -I `ocamlfind query num` \
             -I `ocamlfind query zarith` \
             -I `ocamlfind query ocplib-simplex` \
             -I `ocamlfind query psmt2-frontend` \
             -I `ocamlfind query camlzip` \
             -I $lib_path \
             nums.cmxa zarith.cmxa ocplibSimplex.cmxa psmt2Frontend.cmxa \
             unix.cmxa str.cmxa zip.cmxa dynlink.cmxa \
             AltErgoLib.cmxa lib_usage.ml ; exit_if_error
    ./lib_usage ; exit_if_error
    cd $pwd
}

pre_merge_style_checker(){
    cd extra/
    echo "call ./extra/pre_merge_style_checker.sh ...."
    ./pre-merge-style-checker.sh ; exit_if_error
    cd ..
}

check_indentation(){
    echo "call ../extra/check_indentation.sh ...."
    ../extra/check_indentation.sh ; exit_if_error
}

eval `opam config env`
opam update
echo "opam --version == `opam --version`"
# in travis, 'system' compiler is currently < 4.04.0

pre_merge_style_checker

for ocaml_version in 4.04.0 #4.06.0 # 4.05.0
do
    echo "=+= [travis.sh] testing with OCaml version '$ocaml_version' =+="

    opam sw remove $ocaml_version # failure if does not exist accepted !
    opam sw create test_pin $ocaml_version ; exit_if_error
    eval `opam config env`

    cd $git_repo/
    git clean -dfx
    cd $git_repo/sources

    ## A0 ## ocp-indent
    opam install ocp-indent.1.6.1 --y ; exit_if_error
    check_indentation

    ## A1 ## Test with 'opam pin'

    echo "=+= [travis.sh] $ocaml_version' compiler: test with 'opam pin'"

    install_unreleased_psmt2_frontend ; exit_if_error
    opam pin add . --no-action --y ; exit_if_error
    opam install alt-ergo --y ; exit_if_error

    non_regression
    library `ocamlfind query alt-ergo-lib`

    opam remove alt-ergo

    ###########################################################################
    ## B ## Test with Makefile

    echo "=+= [travis.sh] $ocaml_version' compiler: test with Makefile"

    opam sw create test_makefile $ocaml_version ; exit_if_error
    eval `opam config env`

    cd $git_repo/
    git clean -dfx
    cd $git_repo/sources

    install_unreleased_psmt2_frontend ; exit_if_error
    opam pin add . --no-action --y ; exit_if_error
    opam install --deps-only alt-ergo-lib alt-ergo-parsers alt-ergo altgr-ergo --y ; exit_if_error

    ./configure --prefix=$local_install_dir ; exit_if_error

    echo "=+= [travis.sh] building and installing ... =+="

    make bin ; exit_if_error
    make gui ; exit_if_error
    make plugins ; exit_if_error
    make install ; exit_if_error
    make clean ; exit_if_error

    echo "=+= [travis.sh] installed files in $local_install_dir ... =+="
    ls -R $local_install_dir
    export PATH=$PATH:$local_install_dir/bin

    non_regression
    library "$local_install_dir/lib/alt-ergo-lib"

done
