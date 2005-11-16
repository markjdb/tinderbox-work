#-
# Copyright (c) 2004-2005 FreeBSD GNOME Team <freebsd-gnome@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#	notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#	notice, this list of conditions and the following disclaimer in the
#	documentation and/or other materials provided with the distribution.
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
# $MCom: portstools/tinderbox/lib/tinderlib.sh,v 1.22 2005/11/16 01:07:14 ade Exp $
#

tinderEcho () {
    echo "$1" | /usr/bin/fmt 75 79
}

tinderExit () {
    tinderEcho "$1"

    if [ -n "$2" ] ; then
	exit $2
    else
	exit 255
    fi
}

killMountProcesses () {
    dir=$1

    pids="XXX"
    while [ ! -z "${pids}" ]; do
	pids=$(fstat -f "${dir}" | tail +2 | awk '{print $3}' | sort -u)

	if [ ! -z "${pids}" ]; then
	    echo "Killing off pids in ${dir}"
	    ps -p ${pids}
	    kill -KILL ${pids} 2> /dev/null
	    sleep 2
	fi
    done
}

cleanupMounts () {
    # set up defaults
    _build=""
    _jail=""
    _portstree=""
    _type=""
    _dstloc=""
    _srcloc=""

    # argument processing
    while getopts b:d:j:p:t: arg
    do
	case ${arg} in

	b)	_build=${OPTARG};;
	d)	_dstloc=${OPTARG};;
	j)	_jail=${OPTARG};;
	p)	_portstree=${OPTARG};;
	t)	_type=${OPTARG};;
	?)	return 1;;

	esac
    done

    case ${_type} in

    buildports)
	if [ -z "${_build}" ]; then
	    echo "cleanupMounts: ${_type}: missing build"
	    return 1
	fi
	_dstloc=${_dstloc:-${pb}/${_build}/a/ports}
	;;

    buildsrc)
        if [ -z "${_build}" ]; then
	    echo "cleanupMounts: ${_type}: missing build"
	    return 1
	fi
	_dstloc=${_dstloc:-${pb}/${_build}/usr/src}
	;;

    ccache)
	if [ -z "${_build}" ]; then
	    echo "cleanupMounts: ${_type}: missing build"
	    return 1
	fi
	_dstloc=${_dstloc:-${pb}/${_build}/ccache}
	;;

    distcache)
	if [ -z "${_build}" ]; then
	    echo "cleanupMounts: ${_type}: missing build"
	    return 1
	fi
	_dstloc=${_dstloc:-${pb}/${_build}/distcache}
	;;

    jail)
	if [ -z "${_jail}" ]; then
	    echo "cleanupMounts: ${_type}: missing jail"
	    return 
	fi
	_dstloc=${_dstloc:-${pb}/jails/${_jail}/src}
	_srcloc=$(${pb}/scripts/tc getSrcMount -j ${_jail})
	;;

    portstree)
	if [ -z "${_portstree}" ]; then
	    echo "cleanupMounts: ${_type}: missing portstree"
	    return 1
	fi
	_dstloc=${_dstloc:-${pb}/portstrees/${_portstree}/ports}
	_srcloc=$(${pb}/scripts/tc getPortsMount -p ${_portstree})
	;;

    *)
	echo "cleanupMounts: ${_type}: unknown type"
	return 1
	;;

    esac

    if [ -n "${_dstloc}" ]; then
	mtpt=$(df | awk '$NF == mtpt { print $NF }' mtpt=${_dstloc})
    fi
    if [ -z "${mtpt}" -a -n "${_srcloc}" ]; then
	mtpt=$(df | awk '$1 == mtpt { print $NF }' mtpt=${_srcloc})
    fi

    if [ -n "${mtpt}" ]; then
	killMountProcesses ${mtpt}
	if ! umount ${mtpt}; then
	    echo "cleanupMounts: ${chroot}${mtpt} failed"
	    return 1
	fi
    fi

    return 0
}

requestMount () {
    # set up defaults
    _type=""
    _srcloc=""
    _dstloc=""
    _nullfs=0
    _readonly=0
    _build=""
    _jail=""
    _portstree=""
    _fqsrcloc=0

    # argument processing
    while getopts b:d:j:np:rs:t: arg
    do
	case ${arg} in

	b)	_build=${OPTARG};;
	d)	_dstloc=${OPTARG};;
	j)	_jail=${OPTARG};;
	n)	_nullfs=1;;
	p)	_portstree=${OPTARG};;
	r)	_readonly=1;;
	s)	_srcloc=${OPTARG};;
	t)	_type=${OPTARG};;
	?)	return 1;;

	esac
    done

    case ${_type} in

    buildports)
	if [ -z "${_build}" ] ; then
	    echo "requestMount: ${_type}: missing build"
	    return 1
	fi
	_portstree=$(${pb}/scripts/tc getPortsTreeForBuild -b ${_build})
	_dstloc=${_dstloc:-${pb}/${_build}/a/ports}

	if [ -z "${_srcloc}" ] ; then
	    _srcloc=$(${pb}/scripts/tc getPortsMount -p ${_portstree})
	    if [ -z "${_srcloc}" ] ; then
		_srcloc=${_srcloc:=${pb}/portstrees/${_portstree}/ports}
	    else
		_fqsrcloc=1
	    fi
	fi
	;;

    buildsrc)
	if [ -z "${_build}" ]; then
	    echo "requestMount: ${_type}: missing build"
	    return 1
	fi
	_jail=$(${pb}/scripts/tc getJailForBuild -b ${_build})
	_dstloc=${_dstloc:-${pb}/${_build}/usr/src}

	if [ -z "${_srcloc}" ]; then
	    _srcloc=$(${pb}/scripts/tc getSrcMount -j ${_jail})
	    if [ -z "${_srcloc}" ]; then
		_srcloc=${_srcloc:=${pb}/jails/${_jail}/src}
	    else
		_fqsrcloc=1
	    fi
	fi
	;;

    ccache)
	if [ -z "${_build}" ]; then
	    echo "requestMount: ${_type}: missing build"
	    return 1
	fi
	_dstloc=${_dstloc:-${pb}/${_build}/ccache}
	;;

    distcache)
	if [ -z "${_build}" ]; then
	    echo "requestMount: ${_type}: missing build"
	    return 1
	fi
	_dstloc=${_dstloc:-${pb}/${_build}/distcache}
	_fqsrcloc=1
	;;

    jail)
	if [ -z "${_jail}" ]; then
	    echo "requestMount: ${_type}: missing jail"
	    return 1
	fi
	_dstloc=${_dstloc:-${pb}/jails/${_jail}/src}
	_srcloc=${_srcloc:-$(${pb}/scripts/tc getSrcMount -j ${_jail})}
	_fqsrcloc=1
	;;

    portstree)
	if [ -z "${_portstree}" ] ; then
	    echo "requestMount: ${_type}: missing portstree"
	    return 1
	fi
	_dstloc=${_dstloc:-${pb}/portstrees/${_portstree}/ports}
	_srcloc=${_srcloc:-$(${pb}/scripts/tc getPortsMount -p ${_portstree})}
	_fqsrcloc=1
	;;

    *)
	echo "requestMount: ${_type}: unknown type"
	return 1
	;;

    esac

    if [ -z "${_srcloc}" ]; then
	# we assume that we're running strictly from a local filesystem
	# and that no mounts are required
	return 0
    fi
    if [ -z "${_dstloc}" ]; then
	echo "requestMount: ${_type}: missing destination location"
	return 1
    fi
    
    # is the filesystem already mounted?
    fsys=$(df ${_dstloc} 2>/dev/null | awk '{a=$1}  END {print a}')
    mtpt=$(df ${_dstloc} 2>/dev/null | awk '{a=$NF} END {print a}')

    if [ "${fsys}" = "${_srcloc}" -a "${mtpt}" = "${_dstloc}" ]; then
	return 0
    fi

    # is _nullfs mount specified?
    if [ ${_nullfs} -eq 1 -a ${_fqsrcloc} -ne 1 ] ; then
	_options="-t nullfs"
    else
	# it probably has to be a nfs mount then
	# lets check what kind of _srcloc we have. If it is allready in
	# a nfs format, we don't need to adjust anything
	case ${_srcloc} in

	[a-zA-Z0-9\.-_]*:/*)
		_options="-o nfsv3,intr"
		;;

	*)
		if [ ${_fqsrcloc} -eq 1 ] ; then
		    # some _srcloc's are full qualified sources, means
		    # don't try to detect sth. or fallback to localhost.
		    # The user wants exactly what he specified as _srcloc
		    # don't modify anything. If it's not a nfs mount, it has
		    # to be a nullfs mount.
		    _options="-t nullfs"
		else
		    _options="-o nfsv3,intr"

		    # find out the filesystem the requested source is in
		    fsys=$(df ${_srcloc} | awk '{a=$1}  END {print a}')
		    mtpt=$(df ${_srcloc} | awk '{a=$NF} END {print a}')
		    # determine if the filesystem the requested source
		    # is a nfs mount, or a local filesystem

		    case ${fsys} in

		    [a-zA-Z0-9\.-_]*:/*)
			# maybe our destination is a subdirectory of the
			# mountpoint and not the mountpoint itself.
			# if that is the case, add the subdir to the mountpoint
			_srcloc="${fsys}/$(echo $_srcloc | \
					sed 's|'${mtpt}'||')"
			;;

		    *)
			# not a nfs mount, nullfs not specified, so
			# mount it as nfs from localhost
			_srcloc="localhost:/${_srcloc}"
			;;

		    esac

		fi
		;;
	esac
    fi

    if [ ${_readonly} -eq 1 ] ; then
	options="${_options} -r"
    fi

    # Sanity check, and make sure the destination directory exists
    if [ ! -d ${_dstloc} ]; then
	mkdir -p ${_dstloc}
    fi

    mount ${_options} ${_srcloc} ${_dstloc}
    return ${?}
}

buildenvlist () {
    jail=$1
    portstree=$2
    build=$3

    ${pb}/scripts/tc configGet

    cat ${pb}/scripts/lib/tinderbox.env

    envdir=${pb}/scripts/etc/env

    if [ -f ${envdir}/GLOBAL ]; then
	cat ${envdir}/GLOBAL
    fi
    if [ -n "${jail}" -a -f ${envdir}/jail.${jail} ]; then
	cat ${envdir}/jail.${jail}
    fi
    if [ -n "${portstree}" -a -f ${envdir}/portstree.${portstree} ]; then
	cat ${envdir}/portstree.${portstree}
    fi
    if [ -n "${build}" -a -f ${envdir}/build.${build} ]; then
	cat ${envdir}/build.${build}
    fi
}

buildenv () {
    jail=$1
    portstree=$2
    build=$3

    major_version=$(echo ${jail} | sed -E -e 's|(^.).*$|\1|')
    save_IFS=${IFS}
    IFS='
'
    # Allow SRCBASE to be overridden
    eval "export SRCBASE=${SRCBASE:-`realpath ${pb}/jails/${jail}/src`}" \
	>/dev/null 2>&1

    for _tb_var in $(buildenvlist "${jail}" "${portstree}" "${build}")
    do
	var=$(echo "${_tb_var}" | sed \
		-e "s|^#${major_version}||; \
		    s|##PB##|${pb}|g; \
		    s|##BUILD##|${build}|g; \
		    s|##JAIL##|${jail}|g; \
		    s|##PORTSTREE##|${portstree}|g" \
		-E -e 's|\^\^([^\^]+)\^\^|${\1}|g' -e 's|^#.*$||')

	if [ -n "${var}" ]; then
	    eval "export ${var}" >/dev/null 2>&1
	fi
    done

    IFS=${save_IFS}
}

buildenvNoHost () {
    eval "export LOCALBASE=/nonexistentlocal" >/dev/null 2>&1
    eval "export X11BASE=/nonexistentx" >/dev/null 2>&1
    eval "export PKG_DBDIR=/nonexistentdb" >/dev/null 2>&1
    eval "export PORT_DBDIR=/nonexistentportdb" >/dev/null 2>&1
    eval "export LINUXBASE=/nonexistentlinux" >/dev/null 2>&1
    eval "unset DISPLAY" >/dev/null 2>&1
}

getDbDriver () {
    db_drivers="mysql pgsql"
    finished=0
    db_driver=""

    while [ ${finished} != 1 ]; do
        read -p "Enter database driver (${db_drivers}): " db_driver

	if echo ${db_drivers} | grep -qw "${db_driver}"; then
	    finished=1
	else
	    echo 1>&2 "Invalid database driver, ${db_driver}."
	fi
    done

    echo ${db_driver}
}

getDbInfo () {
    db_driver=$1

    db_host=""
    db_name=""
    db_admin=""

    read -p "Does this host have access to connect to the Tinderbox database as a database administrator? (y/n)" option

    finished=0
    while [ ${finished} != 1 ]; do
        case "${option}" in
            [Yy]|[Yy][Ee][Ss])
	        read -p "Enter database admin user [root]: " db_admin
                read -p "Enter database host [localhost]: " db_host
	        read -p "Enter database name [tinderbox]: " db_name
	        ;;
            *)
	        return 1
	        ;;
        esac

	db_admin=${db_admin:-"root"}
	db_host=${db_host:-"localhost"}
	db_name=${db_name:-"tinderbox"}

	echo 1>&2 "Are these settings corrrect:"
	echo 1>&2 "    Database Administrative User : ${db_admin}"
	echo 1>&2 "    Database Host                : ${db_host}"
	echo 1>&2 "    Database Name                : ${db_name}"
	read -p "(y/n)" option

	case "${option}" in
	    [Yy]|[Yy][Ee][Ss])
	        finished=1
		;;
        esac
	option="YES"
    done

    echo "${db_admin}:${db_host}:${db_name}"

    return 0
}

loadSchema () {
    schema_file=$1
    db_driver=$2
    db_admin=$3
    db_host=$4
    db_name=$5

    MYSQL_LOAD='/usr/local/bin/mysql -u${db_admin} -p -h ${db_host} ${db_name} < "${schema_file}"'
    MYSQL_LOAD_PROMPT='echo "The next prompt will be for ${db_admin}'"'"'s password to the ${db_name} database." | /usr/bin/fmt 75 79'

    PGSQL_LOAD='/usr/local/bin/psql -U ${db_admin} -W -h ${db_host} -d ${db_name} < "${schema_file}"'
    PGSQL_LOAD_PROMPT='echo "The next prompt will be for ${db_admin}'"'"'s password to the ${db_name} database." | /usr/bin/fmt 75 79'

    rc=0
    case "${db_driver}" in
	mysql)
	    eval ${MYSQL_LOAD_PROMPT}
	    eval ${MYSQL_LOAD}
	    rc=$?
	    ;;
	pgsql)
	    eval ${PGSQL_LOAD_PROMPT}
	    eval ${PGSQL_LOAD}
	    rc=$?
	    ;;
	*)
	    echo "Unsupported database driver: ${db_driver}"
	    return 1
	    ;;
    esac

    return ${rc}
}

checkPreReqs () {
    reqs="$@"
    error=0
    missing=""

    for r in ${reqs} ; do
	if [ -z $(pkg_info -Q -O ${r}) ]; then
	    missing="${missing} ${r}"
	    error=1
	fi
    done

    echo "${missing}"

    return ${error}
}

migDb () {
    do_load=$1
    db_driver=$2
    db_host=$3
    db_name=$4
    mig_file=${pb}/scripts/upgrade/mig_${db_driver}_tinderbox-${MIG_VERSION_FROM}_to_${MIG_VERSION_TO}.sql

    if [ -s "${mig_file}" ]; then
	if [ ${do_load} = 1 ]; then
	    tinderEcho "INFO: Migrating database schema from ${MIG_VERSION_FROM} to ${MIG_VERSION_TO} ..."
	    if ! loadSchema "${mig_file}" ${db_driver} ${db_host} ${db_name} ; then
	        tinderEcho "ERROR: Failed to load upgrade database schema."
	        return 2
	    fi
	    tinderEcho "DONE."
	else
	    tinderEcho "WARN: You must load ${mig_file} to complete your upgrade."
	fi
    else
	return 1
    fi

    return 0
}
