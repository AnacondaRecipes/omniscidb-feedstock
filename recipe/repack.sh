#!/bin/bash
set -ex

# for subpackages, we have named our extracted locations according to the subpackage name
#    That's what this $PKG_NAME is doing - picking the right subfolder to rsync
src="$SRC_DIR/$PKG_NAME"
cp -rv "$src"/* "$PREFIX/"

# repack dependencies of omniscidbe and pyomniscidbe
if [[ "${target_platform}" == "linux-64" ]]; then
    if [[ "$PKG_NAME" = "omniscidbe" ]] || [[ "$PKG_NAME" = "pyomniscidbe" ]]; then

        TARGET_SO=
        if [[ "$PKG_NAME" = "omniscidbe" ]]; then
            TARGET_SO="$PREFIX/"lib/libDBEngine.so
        fi
        if [[ "$PKG_NAME" = "pyomniscidbe" ]]; then
            PYVER=${PY_VER//[.]/}
            TARGET_SO="$PREFIX/"lib/python$PY_VER/site-packages/omniscidbe.cpython-$PYVER-x86_64-linux-gnu.so
        fi

        # show current rpath
        readelf -d $TARGET_SO | egrep "RPATH|RUNPATH"

        # add repack folder to rpath
        # originally: (RPATH)              Library rpath: [$ORIGIN/../../../lib:$ORIGIN/.]
        mkdir -p "$PREFIX/omniscidb-repack/bin/"
        mkdir -p "$PREFIX/omniscidb-repack/lib/"
        patchelf --force-rpath --add-rpath '$ORIGIN/../../../omniscidb-repack/lib/' $TARGET_SO # used at build time
        patchelf --force-rpath --add-rpath '$ORIGIN/../omniscidb-repack/lib/' $TARGET_SO # used at run time

        # show updated rpath
        readelf -d $TARGET_SO | egrep "RPATH|RUNPATH"

        # repack libclang-cpp
        cp -rv "$SRC_DIR/libclang-cpp"/lib/libclang-cpp.so.* "$PREFIX/omniscidb-repack/lib/"

        # repack boost-cpp
        cp -rv "$SRC_DIR/boost"/lib/libboost*.so.* "$PREFIX/omniscidb-repack/lib/"

        # # repack icu (needed for boost-cpp)
        # cp -rv "$SRC_DIR/icu"/lib/libicu*.so.* "$PREFIX/omniscidb-repack/lib/"

        # repack arrow-cpp
        cp -rv "$SRC_DIR/arrowcpp"/lib/lib*.so.* "$PREFIX/omniscidb-repack/lib/"

        if [[ "$PKG_NAME" = "pyomniscidbe" ]]; then
            # repack pyarrow and rename it to pyarrow6 to avoid conflicts with other pyarrow versions
            mv "$SRC_DIR/pyarrow/lib/python$PY_VER/site-packages/pyarrow" "${SP_DIR}/pyarrow6"
            pushd "${SP_DIR}/pyarrow6"
            patchelf --force-rpath --add-rpath '$ORIGIN/../../../../omniscidb-repack/lib/' plasma-store-server
            patchelf --force-rpath --add-rpath '$ORIGIN/../../omniscidb-repack/lib/' plasma-store-server
            for f in *.so;
            do
                readelf -d $f | egrep "RPATH|RUNPATH"
                patchelf --force-rpath --add-rpath '$ORIGIN/../../../../omniscidb-repack/lib/' $f
                patchelf --force-rpath --add-rpath '$ORIGIN/../../omniscidb-repack/lib/' $f
            done
            popd
        fi

        # for libarchive 3.5.2 conda-forge has interface wrongly set to 13
        patchelf --replace-needed "libarchive.so.13" "libarchive.so.18" $TARGET_SO

        # prefix repacked sonames with REPACK_ to ensure the repack deps are actually used
        # pushd "$PREFIX/omniscidb-repack/"
        # regex='\[(.*)\]'
        # for f in *;
        # do
        #     mv -v -- "$f" "REPACK_$f"
        #     patchelf --set-soname "REPACK_$f" "REPACK_$f"
        #     patchelf --replace-needed "$f" "REPACK_$f" $TARGET_SO
        # done
        # popd
    fi

    if [[ "$PKG_NAME" = "pyomniscidbe" ]]; then
        # source is there to provide the tests of pyomniscidbe.
        # Since pyarrow is repacked to pyarrow6, the tests must be updated to import pyarrow6.
        pushd "$SRC_DIR/source/Embedded/test/"
        for f in *.py;
        do
            sed -i 's/^from pyarrow /from pyarrow6 /g' $f
            sed -i 's/^import pyarrow as/import pyarrow6 as/g' $f
            sed -i 's/^import pyarrow$/import pyarrow6 as pyarrow/g' $f
        done
        popd
    fi
fi

# replace old info folder with our new regenerated one
rm -rf "$PREFIX/info"