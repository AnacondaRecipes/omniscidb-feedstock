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
        mkdir -p "$PREFIX/omniscidb-repack/"
        patchelf --force-rpath --add-rpath '$ORIGIN/../../../omniscidb-repack/' $TARGET_SO

        # show updated rpath
        readelf -d $TARGET_SO | egrep "RPATH|RUNPATH"

        # repack libclang-cpp
        cp -rv "$SRC_DIR/libclang-cpp"/lib/libclang-cpp.so.* "$PREFIX/omniscidb-repack/"

        # repack boost-cpp
        cp -rv "$SRC_DIR/boost"/lib/libboost*.so.* "$PREFIX/omniscidb-repack/"

        # repack icu (needed for boost-cpp)
        cp -rv "$SRC_DIR/icu"/lib/libicu*.so.* "$PREFIX/omniscidb-repack/"

        # repack arrow-cpp
        cp -rv "$SRC_DIR/arrowcpp"/lib/lib*.so.* "$PREFIX/omniscidb-repack/"

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
fi

# replace old info folder with our new regenerated one
rm -rf "$PREFIX/info"