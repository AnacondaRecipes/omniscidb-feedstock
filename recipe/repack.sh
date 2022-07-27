#!/bin/bash
set -ex

# repack omniscidb-common
if [[ "${target_platform}" == "linux-64" ]]; then
    if [[ "$PKG_NAME" = "omniscidb-common" ]]; then
        src="$SRC_DIR/omniscidb-common"
        cp -rv "$src"/* "$PREFIX/"
    fi
fi

# repack omniscidbe and pyomniscidbe and their dependencies
if [[ "${target_platform}" == "linux-64" ]]; then
    if [[ "$PKG_NAME" = "omniscidbe" ]] || [[ "$PKG_NAME" = "pyomniscidbe" ]]; then

        PYVER=${PY_VER//[.]/}
        TARGET_SO=
        if [[ "$PKG_NAME" = "omniscidbe" ]]; then
            src="$SRC_DIR/omniscidbe"
            cp -rv "$src"/* "$PREFIX/"
            TARGET_SO="$PREFIX/"lib/libDBEngine.so
        fi
        if [[ "$PKG_NAME" = "pyomniscidbe" ]]; then
            src="$SRC_DIR/pyomniscidbe_py$PYVER"
            cp -rv "$src"/* "$PREFIX/"
            TARGET_SO="$PREFIX/"lib/python$PY_VER/site-packages/omniscidbe.cpython-*-x86_64-linux-gnu.so
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

        # repack arrow-cpp
        cp -rv "$SRC_DIR/arrowcpp_py$PYVER"/lib/lib*.so.* "$PREFIX/omniscidb-repack/lib/"

        if [[ "$PKG_NAME" = "pyomniscidbe" ]]; then
            # repack pyarrow and rename it to pyarrow6 to avoid conflicts with other pyarrow versions
            mv "$SRC_DIR/pyarrow_py$PYVER/lib/python$PY_VER/site-packages/pyarrow" "${SP_DIR}/pyarrow"
            pushd "${SP_DIR}/pyarrow"
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

    fi

    # This code below is commented because pyomniscidbe cython still looks for pyarrow.
    # Instead, run_constrained pyarrow ==6.0.1 is added to the recipe.
    # if [[ "$PKG_NAME" = "pyomniscidbe" ]]; then
    #       # rename repacked pyarrow to pyarrow6 to avoid conflicts with other pyarrow versions
    #      mv "$SRC_DIR/pyarrow/lib/python$PY_VER/site-packages/pyarrow" "${SP_DIR}/pyarrow"
    #
    #     # Since pyarrow is repacked to pyarrow6, the tests must be updated to import pyarrow6.
    #     # source is there to provide the tests of pyomniscidbe.
    #     pushd "$SRC_DIR/source/Embedded/test/"
    #     for f in *.py;
    #     do
    #         sed -i 's/^from pyarrow /from pyarrow6 /g' $f
    #         sed -i 's/^import pyarrow as/import pyarrow6 as/g' $f
    #         sed -i 's/^import pyarrow$/import pyarrow6 as pyarrow/g' $f
    #     done
    #     popd
    # fi
fi

# replace old info folder with our new regenerated one
rm -rf "$PREFIX/info"