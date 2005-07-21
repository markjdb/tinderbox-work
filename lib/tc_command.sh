#!/bin/sh
#
# Copyright (c) 2005 FreeBSD GNOME Team <freebsd-gnome@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $MCom: portstools/tinderbox/lib/tc_command.sh,v 1.2 2005/07/21 06:40:06 marcus Exp $
#

export defaultCvsupHost="cvsup12.FreeBSD.org"
export cvsupProg="/usr/local/bin/cvsup"

#---------------------------------------------------------------------------
# Generic routines
#---------------------------------------------------------------------------
generateSupFile () {
    echo "*default host=$4"
    echo "*default base=$1"
    echo "*default prefix=$1"
    echo "*default release=cvs tag=$3"
    echo "*default delete use-rel-suffix"

    if [ $5 = 1 ]; then
	echo "*default compress"
    fi

    echo "$2-all"
}

tcExists () {
    list=$(${pb}/scripts/tc list$1 2>/dev/null)
    echo ${list} | grep -qw $2
}

cleanDirs () {
    myname=$1; shift; dirs="$*"

    echo -n "${myname}: cleaning up any previous leftovers... "
    for dir in $*
    do
	# perform the first remove
	rm -rf ${dir} >/dev/null 2>&1

	# this may not have succeeded if there are schg files around
	if [ -d ${dir} ]; then
	    chflags -R noschg ${dir} >/dev/null 2>&1
	    rm -rf ${dir} >/dev/null 2>&1
	    if [ $? != 0 ]; then
		echo "FAILED (rm ${dir})"
		exit 1
	    fi
	fi

	# now recreate the directory
	mkdir -p ${dir} >/dev/null 2>&1
	if [ $? != 0 ]; then
	    echo "FAILED (mkdir ${dir})"
 	    exit 1
	fi
    done
    echo "done."
}

#---------------------------------------------------------------------------
# Jail handling
#---------------------------------------------------------------------------

createJailUsage () {
    if [ ! -z "$*" ]; then
	echo "createJail: $*"
    fi
    echo "usage: create Jail -n <name> -t <tag> [-d <description>]"
    echo "       [-C] [-H <cvsuphost>] [-m <mountsrc>]"
    echo "	 [-u <updatecommand>|CVSUP|NONE]"
    exit 1
}

createJail () {
    # set up defaults
    cvsupHost=${defaultCvsupHost}
    cvsupCompress=0
    descr=""
    mountSrc=""
    name=""
    tag=""
    updateCmd="CVSUP"

    # argument handling
    shift
    while getopts d:m:n:t:u:CH: arg
    do
	case "${arg}" in

	d)	descr="${OPTARG}";;
	m)	mountSrc="${OPTARG}";;
	n)	name="${OPTARG}";;
	t)	tag="${OPTARG}";;
	u)	updateCmd="${OPTARG}";;
	C)	cvsupCompress=1;;
	H)	cvsupHost="${OPTARG}";;
	?)	createJailUsage;;

	esac
    done

    # argument validation
    if [ -z "${name}" ]; then
	createJailUsage "no jail name specified"
    fi

    valid=$(echo ${name} | awk '{if (/^[[:digit:]]/) {print;}}')
    if [ -z "${valid}" ]; then
	createJailUsage \
		"jail name must begin with a FreeBSD major version number"
    fi

    if tcExists Jails ${name}; then
	createJailUsage "jail \"${name}\" already exists"
    fi

    if [ -z "${tag}" ]; then
	createJailUsage "no src tag name specified"
    fi

    # clean out any previous directories
    basedir=${pb}/jails/${name}
    cleanup_mounts -d jail -j ${name}
    cleanDirs ${name} ${basedir}

    # setup the directory and supfile
    echo -n "${name}: set up directory/supfile... "
    mkdir -p ${basedir}/src
    generateSupFile ${basedir} src ${tag} ${cvsupHost} ${cvsupCompress} \
	> ${basedir}/src-supfile
    echo "done."

    # add jail to datastore
    echo -n "${name}: adding Jail to datastore... "

    if [ ! -z "${descr}" ]; then
	descr="-d ${descr}"
    fi
    if [ ! -z "${updateCmd}" ]; then
	updateCmd="-u ${updateCmd}"
    fi
    if [ ! -z "${mountSrc}" ]; then
	mountSrc="-m ${mountSrc}"
    fi

    ${pb}/scripts/tc addJail -n ${name} -t ${tag} \
	${updateCmd} ${mountSrc} "${descr}"
    if [ $? != 0 ]; then
	echo "FAILED."
	exit 1
    fi
    echo "done."

    # mount src/ if required
    if [ ! -z "${mountSrc}" ]; then
	echo -n "${name}: mounting src... "
	request_mount -q -d jail -j ${name}
	echo "done."
    fi

    # now initialize the jail
    echo "${name}: initializing new jail..."
    ${pb}/scripts/mkjail ${name}
    if [ $? != 0 ]; then
	echo "FAILED."
	exit 1
    fi
    echo "done."

    # finished
    exit 0
}

#---------------------------------------------------------------------------
# PortsTree handling
#---------------------------------------------------------------------------

createPortsTreeUsage () {
    if [ ! -z "$*" ]; then
	echo "createPortsTree: $*"
    fi
    echo "usage: create PortsTree -n <name> [-d <description>]"
    echo "       [-C] [-H <cvsuphost>] [-m <mountsrc>]"
    echo "       [-u <updatecommand>|CVSUP|NONE] [-w <cvsweburl>]"
    exit 1
}

createPortsTree () {
    # set up defaults
    cvsupHost=${defaultCvsupHost}
    cvsupCompress=0
    cvswebUrl=""
    descr=""
    mountSrc=""
    name=""
    updateCmd="CVSUP"

    # argument handling
    shift
    while getopts d:m:n:u:w:CH: arg
    do
	case "${arg}" in

	d)	descr="${OPTARG}";;
	m)	mountSrc="${OPTARG}";;
	n)	name="${OPTARG}";;
	u)	updateCmd="${OPTARG}";;
	w)	cvswebUrl="${OPTARG}";;
	C)	cvsupCompress=1;;
	H)	cvsupHost="${OPTARG}";;
	?)	createPortsTreeUsage;;

	esac
    done

    # argument validation
    if [ -z "${name}" ]; then
	createPortsTreeUsage "no portstree name specified"
    fi

    if tcExists PortsTrees ${name}; then
	createPortsTreeUsage "portstree \"${name}\" already exists"
    fi

    # clean out any previous directories
    basedir=${pb}/portstrees/${name}
    cleanup_mounts -d portstree -p ${name}
    cleanDirs ${name} ${basedir}

    # setup the directory and supfile
    echo -n "${name}: set up directory/supfile... "
    mkdir -p ${basedir}/ports
    generateSupFile ${basedir} ports . ${cvsupHost} ${cvsupCompress} \
	> ${basedir}/ports-supfile
    echo "done."

    # add portstree to datastore
    echo -n "${name}: adding PortsTree to datastore... "

    if [ ! -z "${descr}" ]; then
	descr="-d ${descr}"
    fi
    if [ -z "${updateCmd}" -o "${updateCmd}" = "CVSUP" ]; then
	updateProg="${cvsupProg} -g ${basedir}/ports-supfile"
	updateCmd="CVSUP"
    else
	updateProg="${updateCmd}"
    fi
    if [ ! -z "${mountSrc}" ]; then
	mountSrc="-m ${mountSrc}"
    fi
    if [ ! -z "${cvswebUrl}" ]; then
	cvswebUrl="-w ${cvswebUrl}"
    fi

    ${pb}/scripts/tc addPortsTree -n ${name} -u ${updateCmd} \
	${mountSrc} ${cvswebUrl} "${descr}"
    if [ $? != 0 ]; then
	echo "FAILED."
	exit 1
    fi
    echo "done."

    # mount ports/ if required
    if [ ! -z "${mountSrc}" ]; then
	echo -n "${name}: mounting ports... "
	request_mount -q -d portstree -p ${name}
	echo "done."
    fi

    # update ports tree if requested
    if [ "${updateProg}" != "NONE" ]; then
	echo "${name}: updating portstree with ${updateProg}..."
	eval ${updateProg} >/dev/null 2>&1
	if [ $? != 0 ]; then
	    echo "FAILED."
	    exit 1
	fi
	echo "done."
    fi

    # finished
    exit 0
}

#---------------------------------------------------------------------------
# Build handling
#---------------------------------------------------------------------------

createBuildUsage () {
    if [ ! -z "$*" ]; then
	echo "createBuild: $*"
    fi
    echo "usage: create Build -n <name> -j <jailname> -p <portstreename>"
    echo "       [-d <description>] [-i]"
    exit 1
}

createBuild () {
    # set up defaults
    descr=""
    init=0
    jail=""
    name=""
    portstree=""

    # argument handling
    shift
    while getopts d:ij:n:p: arg
    do
	case "${arg}" in

	d)	descr="${OPTARG}";;
	i)	init=1;;
	j)	jail="${OPTARG}";;
	n)	name="${OPTARG}";;
	p)	portstree="${OPTARG}";;
	?)	createBuildUsage;;

	esac
    done

    # argument validation
    if [ -z "${name}" ]; then
	createBuildUsage "no build name specified"
    fi
    if [ -z "${jail}" ]; then
	createBuildUsage "no jail name specified"
    fi
    if [ -z "${portstree}" ]; then
	createBuildUsage "no portstree name specified"
    fi

    if tcExists Builds ${name}; then
	createBuildUsage "build \"${name}\" already exists"
    fi
    if ! tcExists Jails ${jail}; then
	createBuildUsage "jail \"${jail}\" does not exist"
    fi
    if ! tcExists PortsTrees ${portstree}; then
	createBuildUsage "portstree \"${portstree}\" does not exist"
    fi

    # clean out any previous directories
    cleanDirs ${name} ${pb}/builds/${name} ${pb}/${name}

    # add build to datastore
    echo -n "${name}: adding Build to datastore... "

    if [ ! -z "${descr}" ]; then
	descr="-d ${descr}"
    fi

    ${pb}/scripts/tc addBuild -n ${name} \
	-j ${jail} -p ${portstree} "${descr}"
    if [ $? != 0 ]; then
	echo "FAILED."
	exit 1
    fi
    echo "done."

    if [ ${init} = 1 ]; then
	echo -n "${name}: initializing..."
	${pb}/scripts/mkbuild ${name}

	if [ $? != 0 ]; then
	    echo "FAILED."
	    exit 1
	fi
	echo "done."
    fi

    # finished
    exit 0
}

#---------------------------------------------------------------------------
# Main program
#---------------------------------------------------------------------------

createUsage () {
    if [ ! -z "$*" ]; then
	echo "create: $*"
    fi
    echo "usage: create Jail|PortsTree|Build -n <name> [<arguments> ...]"
    exit 1
}

# don't try this at home, folks
if [ `id -u` != 0 ]; then
    echo "create: must run as root"
    exit 1
fi

# find out where we're located, and set prefix accordingly
pb=$0
[ -z "$(echo "${pb}" | sed 's![^/]!!g')" ] && \
pb=$(type "$pb" | sed 's/^.* //g')
pb=$(realpath $(dirname $pb))
pb=${pb%%/scripts}
export pb

# pull in all the helper functions
. ${pb}/scripts/lib/tinderbox_shlib.sh

# and off we go

if [ $# -lt 3 ]; then
    createUsage
fi

# XXX: this probably needs tweaking to handle all the weird and
#      wonderful shell-quoting concepts

case $1 in

[Jj]ail)		createJail ${1+"$@"};;
[Pp]orts[Tt]ree)	createPortsTree ${1+"$@"};;
[Bb]uild)		createBuild ${1+"$@"};;
*)			createUsage "unknown operator: $1"

esac

exit 0