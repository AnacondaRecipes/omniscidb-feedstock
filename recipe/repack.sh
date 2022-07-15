#!/bin/bash
set -ex

# for subpackages, we have named our extracted locations according to the subpackage name
#    That's what this $PKG_NAME is doing - picking the right subfolder to rsync

src="$SRC_DIR/$PKG_NAME"

# # The license files are no longer manually packed but are included via the meta.yaml
# # not all packages have the license file.  Copy it from mkl, where we know it exists
# cp -f "$SRC_DIR/mkl/info/licenses/license.txt" "$SRC_DIR"
# # ro by default.  Makes installations not cleanly removable.
# chmod 664 "$SRC_DIR/license.txt"

cp -rv "$src"/* "$PREFIX/"

# repack dependencies of omniscidbe
if [ "$PKG_NAME" = "omniscidbe" ]; then
    # show current rpath
    readelf -d "$PREFIX/"lib/libDBEngine.so | egrep "RPATH|RUNPATH"

    # add repack folder to rpath
    mkdir -p "$PREFIX/omniscidb-repack/"
    patchelf --force-rpath --add-rpath '$ORIGIN/../../../omniscidb-repack/' "$PREFIX/"lib/libDBEngine.so

    # show updated rpath
    readelf -d "$PREFIX/"lib/libDBEngine.so | egrep "RPATH|RUNPATH"

    # repack boost-cpp
    cp -rv "$SRC_DIR/boost"/lib/libboost*.so.* "$PREFIX/omniscidb-repack/"

    # repack icu (needed for boost-cpp)
    ls -R "$SRC_DIR/icu"
    cp -rv "$SRC_DIR/icu"/lib/libicu*.so.* "$PREFIX/omniscidb-repack/"

    # repack arrow-cpp
    ls -R "$SRC_DIR/arrowcpp"
    cp -rv "$SRC_DIR/arrowcpp"/lib/lib*.so.* "$PREFIX/omniscidb-repack/"
fi

# replace old info folder with our new regenerated one
rm -rf "$PREFIX/info"