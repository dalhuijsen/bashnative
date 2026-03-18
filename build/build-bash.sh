#!/bin/bash
# bashnative/build/build-bash.sh - Copyright 2013 Thijs Dalhuijsen <dalhuijsen@gmail.com>
# This program is distributed under the terms of the GNU General Public License
# (GPLv3) as published by the Free Software Foundation.
# <http://www.gnu.org/licenses/> <https://github.com/dalhuijsen/bashnative>
#
# Builds a patched bash binary with the 'mk' builtin compiled in.
# The 'mk' builtin provides mkdir(2), mkfifo(3), and mknod(2) syscalls
# that are impossible to do in pure bash.
#
# Result: one bash binary, zero external dependencies.
#
# Usage: ./build-bash.sh [--static] [--prefix=/path]
#    or: ./build-bash.sh --help

BASH_VERSION="5.2"
BASH_URL="https://ftp.gnu.org/gnu/bash/bash-${BASH_VERSION}.tar.gz"
BUILDDIR="$(pwd)/_bashbuild"
STATIC=0
PREFIX="/usr/local"
JOBS=

main () {
   parse_args "$@"
   check_tools
   fetch_source
   patch_source
   compile
   echo
   echo "***********************************************************"
   echo "* bashnative bash built successfully!                     *"
   echo "***********************************************************"
   echo
   echo "Binary: ${BUILDDIR}/bash-${BASH_VERSION}/bash"
   echo
   echo "Test it:"
   echo "  ${BUILDDIR}/bash-${BASH_VERSION}/bash -c 'fs mkdir /tmp/bntest && echo it works && fs rmdir /tmp/bntest'"
   echo
   echo "Install it:"
   echo "  cp ${BUILDDIR}/bash-${BASH_VERSION}/bash /your/chroot/bin/bash"
   echo
}


parse_args () {
   while [[ -n "$1" ]]; do
      case "$1" in
         --static)
            STATIC=1
            ;;
         --prefix=*)
            PREFIX="${1#*=}"
            ;;
         -j*)
            JOBS="$1"
            ;;
         --help|-h)
            helpmsg
            exit 0
            ;;
         *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
      esac
      shift
   done
}


check_tools () {
   echo "Checking build tools..."
   local MISSING=0

   for TOOL in cc make; do
      if ! type "$TOOL" >/dev/null 2>&1; then
         # try gcc as fallback for cc
         if [[ "$TOOL" == "cc" ]] && type gcc >/dev/null 2>&1; then
            continue
         fi
         echo "ERROR: '$TOOL' not found. Install a C compiler and make." >&2
         MISSING=1
      fi
   done

   # need curl or wget
   if ! type curl >/dev/null 2>&1 && ! type wget >/dev/null 2>&1; then
      echo "ERROR: need curl or wget to download bash source." >&2
      MISSING=1
   fi

   if (( MISSING )); then
      exit 1
   fi
   echo "OK"
}


fetch_source () {
   if [[ -d "${BUILDDIR}/bash-${BASH_VERSION}" ]]; then
      echo "Source already exists, skipping download."
      return 0
   fi

   echo "Downloading bash ${BASH_VERSION}..."
   mkdir -p "${BUILDDIR}"

   if type curl >/dev/null 2>&1; then
      curl -L -o "${BUILDDIR}/bash-${BASH_VERSION}.tar.gz" "${BASH_URL}"
   else
      wget -O "${BUILDDIR}/bash-${BASH_VERSION}.tar.gz" "${BASH_URL}"
   fi

   if [[ $? -ne 0 ]]; then
      echo "ERROR: download failed." >&2
      exit 1
   fi

   echo "Extracting..."
   tar xzf "${BUILDDIR}/bash-${BASH_VERSION}.tar.gz" -C "${BUILDDIR}"
}


patch_source () {
   local SRCDIR="${BUILDDIR}/bash-${BASH_VERSION}"
   local FSDEF="${SRCDIR}/builtins/fs.def"
   local MAKEFILE="${SRCDIR}/builtins/Makefile.in"

   if [[ -f "$FSDEF" ]]; then
      echo "Already patched, skipping."
      return 0
   fi

   echo "Patching bash with 'fs' builtin..."

   # 1. Copy our .def file into the builtins directory
   cp "$(dirname "$0")/fs.def" "$FSDEF"

   # 2. Add fs.def to DEFSRC (after the mapfile.def line)
   sed -i.bak 's|$(srcdir)/mapfile.def|$(srcdir)/mapfile.def $(srcdir)/fs.def|' "$MAKEFILE"

   # 3. Add fs.o to OFILES (after complete.o which is the last entry)
   sed -i.bak 's|bashgetopt.o complete.o|bashgetopt.o complete.o fs.o|' "$MAKEFILE"

   # 4. Add dependency line for fs.o
   cat >> "$MAKEFILE" << 'DEPS'

# bashnative fs builtin
fs.o: fs.def
fs.o: $(topdir)/command.h ../config.h $(BASHINCDIR)/memalloc.h
fs.o: $(topdir)/error.h $(topdir)/general.h $(topdir)/xmalloc.h
fs.o: $(topdir)/quit.h $(topdir)/dispose_cmd.h $(topdir)/make_cmd.h $(topdir)/sig.h
fs.o: $(topdir)/subst.h $(topdir)/externs.h $(BASHINCDIR)/maxpath.h
fs.o: $(topdir)/shell.h $(topdir)/syntax.h $(topdir)/unwind_prot.h $(topdir)/variables.h $(topdir)/conftypes.h
fs.o: $(topdir)/bashtypes.h ../pathnames.h
fs.o: ${topdir}/bashintl.h ${LIBINTL_H} $(BASHINCDIR)/gettext.h
DEPS

   # Clean up sed backups
   rm -f "${MAKEFILE}.bak"

   echo "Patch applied."
}


compile () {
   local SRCDIR="${BUILDDIR}/bash-${BASH_VERSION}"
   local CONFIGOPTS="--prefix=${PREFIX}"

   # --enable-static-link works on Linux, not on macOS (Apple doesn't ship
   # static libc).  We try it and fall back gracefully.
   if (( STATIC )); then
      CONFIGOPTS="${CONFIGOPTS} --enable-static-link"
   fi

   # /dev/tcp and /dev/udp support -- needed for bashnative curl/wget/nc
   CONFIGOPTS="${CONFIGOPTS} --enable-net-redirections"

   # Disable stuff we don't need to keep the binary small
   CONFIGOPTS="${CONFIGOPTS} --without-bash-malloc"
   CONFIGOPTS="${CONFIGOPTS} --disable-nls"

   echo "Configuring... (${CONFIGOPTS})"
   cd "${SRCDIR}"
   ./configure ${CONFIGOPTS} || {
      echo "ERROR: configure failed." >&2
      exit 1
   }

   echo "Compiling..."
   make ${JOBS} || {
      echo "ERROR: make failed." >&2
      exit 1
   }

   cd - >/dev/null

   # Verify the builtin is there
   echo "Verifying 'fs' builtin..."
   "${SRCDIR}/bash" -c 'type fs' 2>/dev/null
   if [[ $? -ne 0 ]]; then
      echo "ERROR: fs builtin not found in compiled bash!" >&2
      exit 1
   fi
   echo "Verified: 'fs' is a shell builtin."
}


helpmsg () {
echo "Usage: ${0##*/} [OPTIONS]
Build a patched bash binary with the bashnative 'fs' builtin.

The 'fs' builtin provides the missing syscalls:
  fs mkdir [-p] PATH [MODE]                create directories
  fs mkfifo PATH [MODE]                    create FIFOs
  fs mknod PATH {b|c|p} MAJOR MINOR [MODE] create device nodes
  fs chmod MODE PATH                       change permissions
  fs chown UID[:GID] PATH                  change ownership
  fs rm PATH                               remove files
  fs rmdir PATH                            remove directories
  fs ln [-s] TARGET LINKNAME               create links
  fs mv SOURCE DEST                        rename/move

Options:
  --static       Attempt static linking (Linux only; macOS will
                 fall back to dynamic linking silently)
  --prefix=PATH  Set install prefix (default: /usr/local)
  -jN            Parallel make jobs (e.g. -j4)
  -h, --help     Display this help

Requirements: C compiler (cc/gcc/clang), make, curl or wget
"
}


main "$@"
