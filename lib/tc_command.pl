#!/usr/bin/perl
#-
# Copyright (c) 2004-2008 FreeBSD GNOME Team <freebsd-gnome@FreeBSD.org>
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
# $MCom: portstools/tinderbox/lib/tc_command.pl,v 1.183 2012/12/14 20:56:32 beat Exp $
#

my $pb;

BEGIN {
        $pb = $ENV{'pb'};

        push @INC, "$pb/scripts";
        push @INC, "$pb/scripts/lib";

        require lib;
        import lib "$pb/scripts";
        import lib "$pb/scripts/lib";
}

use strict;

use Tinderbox::TinderboxDS;
use Tinderbox::MakeCache;
use Getopt::Std;
use Text::Wrap;
use Cwd 'abs_path';
use vars qw(
    %COMMANDS
    $TINDERBOX_HOST
    $SUBJECT
    $SENDER
    $SMTP_HOST
    $LOGS_URI
    $SHOWBUILD_URI
    $SHOWPORT_URI
);

require "tinderbox.ph";
require "tinderlib.pl";

$Text::Wrap::columns = 72;

my $ds = new Tinderbox::TinderboxDS();

%COMMANDS = (
        "init" => {
                help  => "Initialize a tinderbox environment",
                usage => "",
        },
        "dsversion" => {
                func  => \&dsversion,
                help  => "Print the datastore version",
                usage => "",
        },
        "dumpObject" => {
                func => \&dumpObject,
                help => "Dump the contents of a TinderObject",
                usage =>
                    "[-x] {-j <jail name>|-b <build name>|-p <port directory>|-t <ports tree name>}",
                optstr => 'xj:b:p:t:',
        },
        "configGet" => {
                func  => \&configGet,
                help  => "Print current Tinderbox configuration",
                usage => "",
        },
        "configCcache" => {
                func => \&configCcache,
                help => "Configure Tinderbox ccache parameters",
                usage =>
                    "[-d | -e] [-c <cache mount src>] [-s <max cache size>] [-j | -J] [-l <debug logfile> | -L]",
                optstr => 'dec:s:l:LjJ',
        },
        "configDistfile" => {
                func => \&configDistfile,
                help => "Configure Tinderbox distfile parameters",
                usage =>
                    "[-c <distfile cache mount src> | -C] [-u <distfile uri> | -U]",
                optstr => 'c:Cu:U',
        },
        "configOptions" => {
                func   => \&configOptions,
                help   => "Configure Tinderbox port OPTIONS parameters",
                usage  => "[-d | -e] [-o <options mount src>]",
                optstr => 'deo:',
        },
        "configPackage" => {
                func   => \&configPackage,
                help   => "Configure Tinderbox package parameters",
                usage  => "[-u <uri> | -U]",
                optstr => 'u:U',
        },
        "configHost" => {
                func   => \&configHost,
                help   => "Configure Tinderbox Host parameters",
                usage  => "[-w <work directory> | -W]",
                optstr => 'w:W',
        },
        "configTinderd" => {
                func => \&configTinderd,
                help =>
                    "Configure Tinderbox tinder daemon (tinderd) parameters",
                usage  => "[-t <sleep time>] [-l <log file>]",
                optstr => 't:l:',
        },
        "configLog" => {
                func   => \&configLog,
                help   => "Configure Tinderbox logging parameters",
                usage  => "[-d <log directory> | -D] [-c | -C] [-z | -Z]",
                optstr => 'd:DcCzZ',
        },
        "configMd" => {
                func => \&configMd,
                help => "Configure Tinderbox to build against a memory device",
                usage =>
                    "[-s <memory size with optional units>] [-t <filesystem type>]",
                optstr => 's:t:',
        },
        "listJails" => {
                func  => \&listJails,
                help  => "List all jails in the datastore",
                usage => "",
        },
        "listBuilds" => {
                func  => \&listBuilds,
                help  => "List all builds in the datastore",
                usage => "",
        },
        "listPorts" => {
                func  => \&listPorts,
                help  => "List all ports in the datastore",
                usage => "",
        },
        "listPortsTrees" => {
                func  => \&listPortsTrees,
                help  => "List all portstrees in the datastore",
                usage => "",
        },
        "listBuildPortsQueue" => {
                func   => \&listBuildPortsQueue,
                help   => "Lists the Ports to Build Queue",
                usage  => "[-b <build name>] [-r] [-s <status>]",
                optstr => 'b:h:s:r',
        },
        "listPortFailPatterns" => {
                func => \&listPortFailPatterns,
                help =>
                    "List all port failure patterns, their reasons, and regular expressions",
                usage  => "[-i <ID>]",
                optstr => 'i:',
        },
        "listPortFailReasons" => {
                func  => \&listPortFailReasons,
                help  => "List all port failure reasons and their descriptions",
                usage => "[-t <tag>]",
                optstr => 't:',
        },
        "reorgBuildPortsQueue" => {
                func  => \&reorgBuildPortsQueue,
                help  => "Reorganizes the Ports to Build Queue",
                usage => "",
        },
        "addBuild" => {
                func => \&addBuild,
                help => "Add a build to the datastore",
                usage =>
                    "-b <build name> -j <jail name> -p <portstree name> [-d <build description>]",
                optstr => 'b:j:p:d:',
        },
        "addJail" => {
                func => \&addJail,
                help =>
                    "Add a jail to the datastore (do NOT call this directly; use createJail instead)",
                usage =>
                    "-j <jail name> -u CSUP|CVSUP|LFTP|SVN|USER|NONE -t <jail tag> [-d <jail description>] [-m <src mount source>] [-a <arch>]",
                optstr => 'm:j:t:u:d:a:',
        },
        "addPortsTree" => {
                func => \&addPortsTree,
                help => "Add a portstree to the datastore",
                usage =>
                    "-p <portstree name> -u CSUP|CVSUP|SVN|USER|NONE [-d <portstree description>] [-m <ports mount source>] [-w <CVSweb URL>]",
                optstr => 'm:p:u:d:w:',
        },
        "addPort" => {
                help => "Add a port to the datastore",
                usage =>
                    "{-b <build name> | -a} -d <port directory> [-o | -O] [-R]",
                optstr => 'ab:d:oOR',
        },
        "addPortToOneBuild" => {
                func   => \&addPortToOneBuild,
                help   => "INTERNAL function only",
                usage  => "",
                optstr => 'b:d:R',
        },
        "rescanPorts" => {
                help   => "Update properties for all ports in the datastore",
                usage  => "{-b <build name> | -a} [-o] [-O] [-R]",
                optstr => 'ab:oOR',
        },
        "addBuildPortsQueueEntry" => {
                func => \&addBuildPortsQueueEntry,
                help => "Adds a Port to the Ports to Build Queue",
                usage =>
                    "-b <build name> [-d <port directory>] [-p <priority>] [-u <username>]",
                optstr => 'b:d:p:u:',
        },
        "addPortFailPattern" => {
                func => \&addPortFailPattern,
                help => "Add a port failure pattern to the datastore",
                usage =>
                    "-i <ID> -r <reason tag> -e <expression> [-p <parent ID>]",
                optstr => 'i:r:e:p:',
        },
        "addPortFailReason" => {
                func => \&addPortFailReason,
                help => "Add a port failure reason to the datastore",
                usage =>
                    "-t <tag> [-d <description>] [-y COMMON|RARE|TRANSIENT]",
                optstr => 't:d:y:',
        },
        "getDependenciesForPort" => {
                func => \&getDependenciesForPort,
                help => "Get stored dependencies for a given port and build",
                usage =>
                    "-b <build name> -d <port directory> [-t PKG_DEPENDS|EXTRACT_DEPENDS|PATCH_DEPENDS|FETCH_DEPENDS|BUILD_DEPENDS|LIB_DEPENDS|RUN_DEPENDS|TEST_DEPENDS]",
                optstr => 'b:d:t:',
        },
        "listHooks" => {
                func => \&listHooks,
                help =>
                    "List all hooks, their commands, and their descriptions",
                usage  => "[-h <hook name>]",
                optstr => 'h:',
        },
        "getHookCmd" => {
                func   => \&getHookCmd,
                help   => "Get the command for a given hook",
                usage  => "-h <hook name>",
                optstr => 'h:',
        },
        "getJailForBuild" => {
                func   => \&getJailForBuild,
                help   => "Get the jail name associated with a given build",
                usage  => "-b <build name>",
                optstr => 'b:',
        },
        "getPortsTreeForBuild" => {
                func  => \&getPortsTreeForBuild,
                help  => "Get the portstree name assoicated with a given build",
                usage => "-b <build name>",
                optstr => 'b:',
        },
        "getPortsForBuild" => {
                func   => \&getPortsForBuild,
                help   => "Get all the ports associated with a given build",
                usage  => "-b <build name>",
                optstr => 'b:',
        },
        "getTagForJail" => {
                func   => \&getTagForJail,
                help   => "Get the tag for a given jail",
                usage  => "-j <jail name>",
                optstr => 'j:',
        },
        "getJailArch" => {
                func   => \&getJailArch,
                help   => "Get the architecture for a give jail",
                usage  => "-j <jail name>",
                optstr => 'j:',
        },
        "getUpdateCmd" => {
                func   => \&getUpdateCmd,
                help   => "Get the update command for the given object",
                usage  => "-j <jail name>|-p <portstreename>",
                optstr => 'j:p:',
        },
        "getSrcMount" => {
                func   => \&getSrcMount,
                help   => "Get the src mount source for the given jail",
                usage  => "-j <jail name>",
                optstr => 'j:',
        },
        "getPortsMount" => {
                func   => \&getPortsMount,
                help   => "Get the ports mount source for the given portstree",
                usage  => "-p <portstree name>",
                optstr => 'p:',
        },
        "getPackageSuffix" => {
                func   => \&getPackageSuffix,
                help   => "Get the package suffix for a given jail",
                usage  => "-j <jail name>",
                optstr => 'j:',
        },
        "setSrcMount" => {
                func   => \&setSrcMount,
                help   => "Set the src mount source for the given jail",
                usage  => "-j <jail name> -m <mountsource>",
                optstr => 'j:m:',
        },
        "setPortsMount" => {
                func   => \&setPortsMount,
                help   => "Set the ports mount source for the given portstree",
                usage  => "-p <portstree name> -m <mountsource>",
                optstr => 'p:m:',
        },
        "rmBuildPortsQueue" => {
                func  => \&rmBuildPortsQueue,
                help  => "Removes all Ports from the Ports to Build Queue",
                usage => ""
        },
        "rmBuildPortsQueueEntry" => {
                func => \&rmBuildPortsQueueEntry,
                help => "Removes a Port from the Ports to Build Queue",
                usage =>
                    "-i <Build_Ports_Queue_Id> | -b <build name> -d <port directory>",
                optstr => 'i:b:d:',
        },
        "rmPort" => {
                func => \&rmPort,
                help =>
                    "Remove a port from the datastore, and optionally its package and logs from the file system",
                usage  => "-d <port directory> [-b <build name>] [-f] [-c]",
                optstr => 'fb:d:c',
        },
        "rmBuild" => {
                func   => \&rmBuild,
                help   => "Remove a build from the datastore",
                usage  => "-b <build name> [-f]",
                optstr => 'b:f',
        },
        "rmPortsTree" => {
                func   => \&rmPortsTree,
                help   => "Remove a portstree from the datastore",
                usage  => "-p <portstree name> [-f]",
                optstr => 'p:f',
        },
        "rmJail" => {
                func   => \&rmJail,
                help   => "Remove a jail from the datastore",
                usage  => "-j <jail name> [-f]",
                optstr => 'j:f',
        },
        "rmPortFailPattern" => {
                func   => \&rmPortFailPattern,
                help   => "Remove a port failure pattern from the datastore",
                usage  => "-i <ID> [-f]",
                optstr => 'i:f',
        },
        "rmPortFailReason" => {
                func   => \&rmPortFailReason,
                help   => "Remove a port failure reason from the datastore",
                usage  => "-t <tag> [-f]",
                optstr => 't:f',
        },
        "updateBuildPortsQueueEntryCompletionDate" => {
                func => \&updateBuildPortsQueueEntryCompletionDate,
                help =>
                    "Update the specified Build Ports Queue Entry completion time",
                usage  => "-i <id> [-l <completion timestamp>]",
                optstr => 'i:l:',
        },
        "updateJailLastBuilt" => {
                func   => \&updateJailLastBuilt,
                help   => "Update the specified jail's last built time",
                usage  => "-j <jail name> [-l <last built timestamp>]",
                optstr => 'j:l:',
        },
        "updatePortsTreeLastBuilt" => {
                func   => \&updatePortsTreeLastBuilt,
                help   => "Update the specified portstree's last built time",
                usage  => "-p <portstree name> [-l <last built timestamp>]",
                optstr => 'l:p:',
        },
        "updatePortStatus" => {
                func => \&updatePortStatus,
                help => "Update build information about a port",
                usage =>
                    "-d <portdir> -b <build> [-L] [-S] [-s <status>] [-r <reason>] [-v <version>] [-p <dependency port directory>] [-t <total size>]",
                optstr => 'b:d:Lr:Ss:v:p:t:',
        },
        "updateBuildStatus" => {
                func   => \&updateBuildStatus,
                help   => "Update the current status for the specific build",
                usage  => "-b <build name> -s <IDLE|PORTBUILD>",
                optstr => 'b:s:',
        },
        "updateBuildRemakeCount" => {
                func => \&updateBuildRemakeCount,
                help => "Update the count of number of ports needing a rebuild",
                usage  => "-b <build name> {-c <count> | -d}",
                optstr => 'b:c:d',
        },
        "updateBuildPortsQueueEntryStatus" => {
                func => \&updateBuildPortsQueueEntryStatus,
                help =>
                    "Update the current status for the specific queue entry",
                usage  => "-i id -s <ENQUEUED|PROCESSING|SUCCESS|FAIL>",
                optstr => 'i:s:',
        },
        "getPortLastBuiltVersion" => {
                func => \&getPortLastBuiltVersion,
                help =>
                    "Get the last built version for the specified port and build",
                usage  => "-d <port directory> -b <build name>",
                optstr => 'd:b:',
        },
        "getPortLastBuiltStatus" => {
                func => \&getPortLastBuiltStatus,
                help =>
                    "Get the last built status for the specified port and build",
                usage  => "-d <port directory> -b <build name>",
                optstr => 'd:b:',
        },
        "getPortTotalSize" => {
                func => \&getPortTotalSize,
                help =>
                    "Get the total size (in KB) required for the specified port and build",
                usage  => "-d <port directory> -b <build name>",
                optstr => 'd:b:',
        },
        "updateBuildCurrentPort" => {
                func => \&updateBuildCurrentPort,
                help =>
                    "Update the port currently being built for the specify build",
                usage =>
                    "-b <build name> [-d <port directory>] [-n <package name>]",
                optstr => 'b:d:n:',
        },
        "updateHookCmd" => {
                func   => \&updateHookCmd,
                help   => "Update the command for the given hook",
                usage  => "-h <hook name> [-c <hook command>]",
                optstr => 'h:c:',
        },
        "sendBuildCompletionMail" => {
                func => \&sendBuildCompletionMail,
                help =>
                    "Send email to the build interest list when a build completes",
                usage  => "-b <build name> [-u <user>]",
                optstr => 'b:u:',
        },
        "addBuildUser" => {
                func   => \&addBuildUser,
                help   => "Add a user to a given build's interest list",
                usage  => "{-b <build name> | -a} -u <username> [-c] [-e]",
                optstr => 'ab:ceu:',
                ,
        },
        "addUser" => {
                func => \&addUser,
                help => "Add a user to the datastore",
                usage =>
                    "-u <username> [-e <emailaddress>] [-p <password>] [-w]",
                optstr => 'u:e:p:w',
        },
        "updateUser" => {
                func => \&updateUser,
                help => "Update user preferences",
                usage =>
                    "-u <username> [-e <emailaddress>] [-p <password>] [-w]",
                optstr => 'u:e:p:w',
        },
        "updatePortFailReason" => {
                func => \&updatePortFailReason,
                help =>
                    "Update the type or description of a port failure reason",
                usage  => "-t <tag> <[-d <descr>] | [-y <type>]>",
                optstr => 't:d:y:',
        },
        "setWwwAdmin" => {
                func   => \&setWwwAdmin,
                help   => "Defines which user is the www admin",
                usage  => "-u <username>",
                optstr => 'u:',
        },
        "updateBuildUser" => {
                func => \&updateBuildUser,
                help =>
                    "Update email preferences for the given user for the given build",
                usage  => "{-b <build name> | -a} -u <username> [-c] [-e]",
                optstr => 'ab:u:ce',
        },
        "rmUser" => {
                func   => \&rmUser,
                help   => "Remove a user from the datastore",
                usage  => "[-b <build name>] -u <username> [-f]",
                optstr => 'fb:u:',
        },
        "sendBuildErrorMail" => {
                func => \&sendBuildErrorMail,
                help =>
                    "Send email to the build interest list when a port fails to build",
                usage =>
                    "-b <build name> -d <port directory> -p <package name> [-l] [-x extension]",
                optstr => 'b:d:lp:x:',
        },
        "listUsers" => {
                func  => \&listUsers,
                help  => "List all users in the datastore",
                usage => "",
        },
        "listBuildUsers" => {
                func   => \&listBuildUsers,
                help   => "List all users in the interest list for a build",
                usage  => "-b <build name>",
                optstr => 'b:',
        },
        "copyBuildPorts" => {
                func   => \&copyBuildPorts,
                help   => "Copy the ports from one build to another",
                usage  => "-s <src build name> -d <dest build name> [-p]",
                optstr => 's:d:p',
        },
        "processLog" => {
                func   => \&processLog,
                help   => "Analyze a logfile to find the failure reason",
                usage  => "-l <logfile> [-v]",
                optstr => 'vl:',
        },
        "isLogCurrent" => {
                func   => \&isLogCurrent,
                help   => "Determine if a logfile is still relevant",
                usage  => "-b <build name> -l <logfile>",
                optstr => 'b:l:',
        },

        # The following commands are actually handled by shell code, but we put
        # them in here (with a NULL function) to consolidate the usage handling,
        # and niceties such as command listing/completion.

        "Setup" => {
                help  => "Set up a new Tinderbox",
                usage => "",
        },

        "Upgrade" => {
                help  => "Upgrade an existing Tinderbox",
                usage => "[-backup <backup file>]",
        },

        "createJail" => {
                help => "Create a new jail",
                usage =>
                    "-j <jailname> -u CSUP|CVSUP|LFTP|SVN|USER|NONE [-t <tag>] [-d <description>] [-C] [-P <protocol>] [-H <updatehost>] [-D <updatehostdirectory>] [-m <mountsrc>] [-I] [-a <arch>]",
                optstr => 'j:t:d:CP:H:D:m:u:Ia:',
        },

        "createPortsTree" => {
                help => "Create a new portstree",
                usage =>
                    "-p <portstreename> -u CSUP|CVSUP|SVN|USER|NONE [-d <description>] [-C] [-P <protocol>] [-H <updatehost>] [-D <updatehostdirectory>] [-m <mountsrc>] [-w <cvsweburl>] [-I]",
                optstr => 'p:d:CP:H:Im:u:w:',
        },

        "createBuild" => {
                help => "Create a new build",
                usage =>
                    "-b <buildname> -j <jailname> -p <portstreename> [-d <description>]",
                optstr => 'b:j:p:d:',
        },

        "makeJail" => {
                help   => "Update and build an existing jail",
                usage  => "-j <jailname>",
                optstr => 'j:',
        },

        "makeBuild" => {
                help   => "Populate a build prior to tinderbuild",
                usage  => "-b <buildname>",
                optstr => 'b:',
        },

        "resetBuild" => {
                help   => "Cleanup and reset a Build environment",
                usage  => "-b <buildname> [-n]",
                optstr => 'b:n',
        },

        "tinderbuild" => {
                help => "Generate packages from an installed Build",
                usage =>
                    "-b <build name> [-init] [-cleanpackages] [-updateports] [-skipmake] [-noclean] [-noduds] [-plistcheck] [-nullfs] [-cleandistfiles] [-fetch-original] [-onceonly] [portdir/portname [...]]",
                optstr => 'b:',
        },

        "updatePortsTree" => {
                help   => "Update an existing ports tree",
                usage  => "-p <portstreename>",
                optstr => 'p',
        },

        "copyBuild" => {
                help =>
                    "Copy the environment and ports from one build to another",
                usage =>
                    "-s <src build name> -d <dest build name> [-c] [-E] [-O] [-p] [-P]",
                optstr => 's:d:cEOpP',
        },

        "tbcleanup" => {
                help =>
                    "Cleanup old build logs, and prune old database entries for which no package exists",
                usage  => "[-d] [-E] [-p]",
                optstr => 'dEp',
        },

        "tbkill" => {
                help   => "Kill a tinderbuild",
                usage  => "-b <buildname> -s <signal>",
                optstr => 'b:s:',
        },

        "tbversion" => {
                help  => "Display Tinderbox version",
                usage => "",
        },

);

#---------------------------------------------------------------------------
# Helper functions
#---------------------------------------------------------------------------

sub _usageprint {
        my ($cmd, $what) = @_;

        printf STDERR "%s\n%s\n", $cmd,
            wrap("\t", "\t", $COMMANDS{$cmd}->{$what});
}

sub usage {
        my $cmd = shift;

        print STDERR "usage:	tc ";

        if (!defined($cmd) || !defined($COMMANDS{$cmd})) {
                my $match = 0;
                print STDERR "<command>\n";
                print STDERR "Where <command> is one of:\n\n";
                foreach my $key (sort keys %COMMANDS) {
                        if (!defined($cmd)) {
                                _usageprint($key, 'help');
                                $match++;
                        } else {
                                if ($key =~ /^$cmd/) {
                                        _usageprint($key, 'help');
                                        $match++;
                                }
                        }
                }
                if (!$match) {
                        foreach my $key (sort keys %COMMANDS) {
                                _usageprint($key, 'help');
                        }
                }
        } else {
                _usageprint($cmd, 'usage');
        }

        cleanup($ds, 1, undef);
}

sub failedShell {
        my $command = shift;
        usage($command);
        cleanup($ds, 1, undef);
}

sub trimstr {
        my $str = shift;

        $str =~ s/^\s+//;
        $str =~ s/\s+$//;

        return $str;
}

#---------------------------------------------------------------------------
# Main dispatching function
#---------------------------------------------------------------------------

if (!scalar(@ARGV)) {
        usage();
}

my $opts    = {};
my $command = $ARGV[0];
shift;

if (defined($COMMANDS{$command})) {
        if ($COMMANDS{$command}->{'optstr'}) {
                getopts($COMMANDS{$command}->{'optstr'}, $opts)
                    or usage($command);
        }
        if (defined($COMMANDS{$command}->{'func'})) {
                &{$COMMANDS{$command}->{'func'}}();
        } else {
                failedShell($command);
        }
} else {
        usage($command);
}

cleanup($ds, 0, undef);

#---------------------------------------------------------------------------
# Tinderbox commands from here on
#---------------------------------------------------------------------------

sub dsversion {
        my $version = $ds->getDSVersion()
            or cleanup($ds, 1,
                      "Failed to retreive datastore version: "
                    . $ds->getError()
                    . "\n");

        print $version . "\n";
}

sub dumpObject {
        if (!$opts->{'j'} && !$opts->{'b'} && !$opts->{'p'} && !$opts->{'t'}) {
                usage("dumpObject");
        }

        my $object = undef;

        if ($opts->{'j'}) {
                $object = $ds->getJailByName($opts->{'j'});
        } elsif ($opts->{'b'}) {
                $object = $ds->getBuildByName($opts->{'b'});
        } elsif ($opts->{'p'}) {
                $object = $ds->getPortByDirectory($opts->{'p'});
        } elsif ($opts->{'t'}) {
                $object = $ds->getPortsTreeByName($opts->{'t'});
        }

        if (defined($object)) {
                if ($opts->{'x'}) {
                        print $object->toXMLString();
                } else {
                        print $object->toString();
                }
        } else {
                cleanup($ds, 1, "Failed to find object.");
        }
}

sub configGet {
        my $configlet = shift;

        my @config = $ds->getConfig($configlet);

        if (@config) {
                map {
                        print $_->getOptionName() . "="
                            . $_->getOptionValue() . "\n"
                } @config;
        } elsif (defined($ds->getError())) {
                cleanup($ds, 1,
                              "Failed to get configuration: "
                            . $ds->getError()
                            . "\n");
        } else {
                cleanup($ds, 1,
                        "There is no configuration available for this Tinderbox.\n"
                );
        }
}

sub configCcache {
        my @config = ();
        my ($enabled, $logfile, $jail);

        if (       ($opts->{'d'} && $opts->{'e'})
                || ($opts->{'l'} && $opts->{'L'})
                || ($opts->{'j'} && $opts->{'J'}))
        {
                usage("configCcache");
        }

        $enabled = new Tinderbox::Config();
        $enabled->setOptionName("enabled");

        $logfile = new Tinderbox::Config();
        $logfile->setOptionName("logfile");

        $jail = new Tinderbox::Config();
        $jail->setOptionName("jail");

        if ($opts->{'e'}) {
                my $nolink = new Tinderbox::Config();
                $enabled->setOptionValue("1");
                $nolink->setOptionName("nolink");
                $nolink->setOptionValue("1");
                push @config, $enabled;
                push @config, $nolink;
        }

        if ($opts->{'d'}) {
                $enabled->setOptionValue("0");
                push @config, $enabled;
        }

        if ($opts->{'c'}) {
                my $cdir = new Tinderbox::Config();
                $cdir->setOptionName("dir");
                $cdir->setOptionValue($opts->{'c'});
                push @config, $cdir;
        }

        if ($opts->{'s'}) {
                my $size = new Tinderbox::Config();
                $size->setOptionName("max_size");
                $size->setOptionValue($opts->{'s'});
                push @config, $size;
        }

        if ($opts->{'j'}) {
                $jail->setOptionValue("1");
                push @config, $jail;
        }

        if ($opts->{'J'}) {
                $jail->setOptionValue("0");
                push @config, $jail;
        }

        if ($opts->{'L'}) {
                $logfile->setOptionValue(undef);
                push @config, $logfile;
        }

        if ($opts->{'l'}) {
                $logfile->setOptionValue($opts->{'l'});
                push @config, $logfile;
        }

        $ds->updateConfig("ccache", @config)
            or cleanup($ds, 1,
                      "Failed to update ccache configuration: "
                    . $ds->getError()
                    . "\n");
}

sub configDistfile {
        my @config = ();
        my $cache;
        my $uri;

        if ($opts->{'c'} && $opts->{'C'}) {
                usage("configDistfile");
        }
        if ($opts->{'u'} && $opts->{'U'}) {
                usage("configDistfile");
        }

        $cache = new Tinderbox::Config();
        $cache->setOptionName("cache");

        $uri = new Tinderbox::Config();
        $uri->setOptionName("uri");

        if ($opts->{'c'}) {
                $cache->setOptionValue($opts->{'c'});
                push @config, $cache;
        }
        if ($opts->{'C'}) {
                $cache->setOptionValue(undef);
                push @config, $cache;
        }

        if ($opts->{'u'}) {
                $uri->setOptionValue($opts->{'u'});
                push @config, $uri;
        }
        if ($opts->{'U'}) {
                $uri->setOptionValue(undef);
                push @config, $uri;
        }

        $ds->updateConfig("distfile", @config)
            or cleanup($ds, 1,
                      "Failed to update distfile configuration: "
                    . $ds->getError()
                    . "\n");
}

sub configTinderd {
        my @config = ();
        my $sleeptime;
        my $logfile;

        if (scalar(keys %{$opts}) == 0) {
                configGet("tinderd");
                cleanup($ds, 0, undef);
        }

        $sleeptime = new Tinderbox::Config();
        $sleeptime->setOptionName("sleeptime");

        $logfile = new Tinderbox::Config();
        $logfile->setOptionName("logfile");

        if ($opts->{'t'}) {
                $sleeptime->setOptionValue($opts->{'t'});
                push @config, $sleeptime;
        }

        if ($opts->{'l'}) {
                $logfile->setOptionValue($opts->{'l'});
                push @config, $logfile;
        }

        $ds->updateConfig("tinderd", @config)
            or cleanup($ds, 1,
                      "Failed to update tinderd configuration: "
                    . $ds->getError()
                    . "\n");
}

sub configLog {
        my @config = ();
        my $directory;
        my $docopy;
        my $compressLogs;

        if (scalar(keys %{$opts}) == 0) {
                configGet("log");
                cleanup($ds, 0, undef);
        }

        if ($opts->{'c'} && $opts->{'C'}) {
                usage("configLog");
        }

        if ($opts->{'d'} && $opts->{'D'}) {
                usage("configLog");
        }

        if ($opts->{'z'} && $opts->{'Z'}) {
                usage("configLog");
        }

        $directory = new Tinderbox::Config();
        $directory->setOptionName("directory");

        $docopy = new Tinderbox::Config();
        $docopy->setOptionName("docopy");

        $compressLogs = new Tinderbox::Config();
        $compressLogs->setOptionName("compresslogs");

        if ($opts->{'d'}) {
                $directory->setOptionValue($opts->{'d'});
                push @config, $directory;
        }

        if ($opts->{'D'}) {
                $directory->setOptionValue(undef);
                push @config, $directory;
        }

        if ($opts->{'c'}) {
                $docopy->setOptionValue($opts->{'c'});
                push @config, $docopy;
        }

        if ($opts->{'C'}) {
                $docopy->setOptionValue(0);
                push @config, $docopy;
        }

        if ($opts->{'z'}) {
                $compressLogs->setOptionValue(1);
                push @config, $compressLogs;
        }

        if ($opts->{'Z'}) {
                $compressLogs->setOptionValue(0);
                push @config, $compressLogs;
        }

        $ds->updateConfig("log", @config)
            or cleanup($ds, 1,
                      "Failed to update log configuration: "
                    . $ds->getError()
                    . "\n");
}

sub configMd {
        my @config = ();
        my $size;
        my $fstype;

        if (scalar(keys %{$opts}) == 0) {
                configGet("md");
                cleanup($ds, 0, undef);
        }

        $size = new Tinderbox::Config();
        $size->setOptionName("size");

        $fstype = new Tinderbox::Config();
        $fstype->setOptionName("fstype");

        if ($opts->{'s'}) {
                if ($opts->{'s'} !~ /^\d+[\dbkmgt]$/) {
                        cleanup($ds, 1,
                                      "Invalid MD size, "
                                    . $opts->{'s'}
                                    . ".  Size must be all digits and end with either a digit, b, k, m, g, or t.\n"
                        );
                }
                $size->setOptionValue($opts->{'s'});
                push @config, $size;
        }

        if ($opts->{'t'}) {
                $fstype->setOptionValue($opts->{'t'});
                push @config, $fstype;
        }

        $ds->updateConfig("md", @config)
            or cleanup($ds, 1,
                      "Failed to update memory disk configuration: "
                    . $ds->getError()
                    . "\n");
}

sub configOptions {
        my @config = ();
        my $enabled;

        if ($opts->{'d'} && $opts->{'e'}) {
                usage("configOptions");
        }

        if (scalar(keys %{$opts}) == 0) {
                configGet("options");
                cleanup($ds, 0, undef);
        }

        $enabled = new Tinderbox::Config();
        $enabled->setOptionName("enabled");

        if ($opts->{'e'}) {
                $enabled->setOptionValue("1");
                push @config, $enabled;
        }

        if ($opts->{'d'}) {
                $enabled->setOptionValue("0");
                push @config, $enabled;
        }

        if ($opts->{'o'}) {
                my $odir = new Tinderbox::Config();
                $odir->setOptionName("dir");
                $odir->setOptionValue($opts->{'o'});
                push @config, $odir;
        }

        $ds->updateConfig("options", @config)
            or cleanup($ds, 1,
                      "Failed to update options configuration: "
                    . $ds->getError()
                    . "\n");
}

sub configPackage {
        my @config = ();
        my $pkg;

        if ($opts->{'c'} && $opts->{'C'}) {
                usage("configPackage");
        }

        $pkg = new Tinderbox::Config();
        $pkg->setOptionName("uri");

        if ($opts->{'u'}) {
                $pkg->setOptionValue($opts->{'u'});
                push @config, $pkg;
        }

        if ($opts->{'U'}) {
                $pkg->setOptionValue(undef);
                push @config, $pkg;
        }

        $ds->updateConfig("package", @config)
            or cleanup($ds, 1,
                      "Failed to update package configuration: "
                    . $ds->getError()
                    . "\n");
}

sub configHost {
        my @config = ();
        my $workdir;

        if ($opts->{'w'} && $opts->{'W'}) {
                usage("host");
        }

        $workdir = new Tinderbox::Config();
        $workdir->setOptionName("workdir");

        if ($opts->{'w'}) {
                $workdir->setOptionValue($opts->{'w'});
                push @config, $workdir;
        }

        if ($opts->{'W'}) {
                $workdir->setOptionValue(undef);
                push @config, $workdir;
        }

        $ds->updateConfig("host", @config)
            or cleanup($ds, 1,
                      "Failed to update jail configuration: "
                    . $ds->getError()
                    . "\n");
}

sub listJails {
        my @jails = $ds->getAllJails();

        if (@jails) {
                map { print $_->getName() . "\n" } @jails;
        } elsif (defined($ds->getError())) {
                cleanup($ds, 1,
                        "Failed to list jails: " . $ds->getError() . "\n");
        } else {
                cleanup($ds, 1,
                        "There are no jails configured in the datastore.\n");
        }
}

sub listBuilds {
        my @builds = $ds->getAllBuilds();

        if (@builds) {
                map { print $_->getName() . "\n" } @builds;
        } elsif (defined($ds->getError())) {
                cleanup($ds, 1,
                        "Failed to list builds: " . $ds->getError() . "\n");
        } else {
                cleanup($ds, 1,
                        "There are no builds configured in the datastore.\n");
        }
}

sub listPorts {
        my @ports = $ds->getAllPorts();

        if (@ports) {
                map { print $_->getDirectory() . "\n" } @ports;
        } elsif (defined($ds->getError())) {
                cleanup($ds, 1,
                        "Failed to list ports: " . $ds->getError() . "\n");
        } else {
                cleanup($ds, 1,
                        "There are no ports configured in the datastore.\n");
        }
}

sub listPortsTrees {
        my @portstrees = $ds->getAllPortsTrees();

        if (@portstrees) {
                map { print $_->getName() . "\n" } @portstrees;
        } elsif (defined($ds->getError())) {
                cleanup($ds, 1,
                        "Failed to list portstrees: " . $ds->getError() . "\n");
        } else {
                cleanup($ds, 1,
                        "There are no portstrees configured in the datastore.\n"
                );
        }
}

sub listPortFailPatterns {
        if ($opts->{'i'}) {
                my $pattern = $ds->getPortFailPatternById($opts->{'i'});

                if (!defined($pattern)) {
                        cleanup($ds, 1,
                                "Failed to find port failure pattern with the ID "
                                    . $opts->{'i'}
                                    . " in the datastore.\n");
                }

                print "ID        : " . $pattern->getId() . "\n";
                print "Reason    : " . $pattern->getReason() . "\n";
                print "Expression:\n";
                print $pattern->getExpr() . "\n";
        } else {
                my @portFailPatterns = $ds->getAllPortFailPatterns();

                if (@portFailPatterns) {
                        foreach my $pattern (@portFailPatterns) {
                                my $id     = $pattern->getId();
                                my $reason = $pattern->getReason();
                                my $expr   = $pattern->getExpr();
                                format PATTERN_TOP =
ID           Reason                 Expression
-------------------------------------------------------------------------------
.
                                format PATTERN =
@<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$id,         $reason,               $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                    $expr
~                                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
                                    $expr
.
                                $~ = "PATTERN";
                                $^ = "PATTERN_TOP";
                                write;
                        }
                } elsif (defined($ds->getError())) {
                        cleanup($ds, 1,
                                      "Failed to list port failure patterns: "
                                    . $ds->getError()
                                    . "\n");
                } else {
                        cleanup(
                                $ds, 1,
                                "There are no port failure patterns configured in
the datastore.\n"
                        );
                }
        }
}

sub listPortFailReasons {
        if ($opts->{'t'}) {
                my $reason = $ds->getPortFailReasonByTag($opts->{'t'});

                if (!defined($reason)) {
                        cleanup($ds, 1,
                                "Failed to find port failure reason with tag "
                                    . $opts->{'t'}
                                    . " in the datastore.\n");
                }

                print "Tag        : " . $reason->getTag() . "\n";
                print "Type       : " . $reason->getType() . "\n";
                print "Description:\n";
                print $reason->getDescr() . "\n";
        } else {
                my @portFailReasons = $ds->getAllPortFailReasons();

                if (@portFailReasons) {
                        foreach my $reason (@portFailReasons) {
                                my $tag   = $reason->getTag();
                                my $type  = $reason->getType();
                                my $descr = $reason->getDescr();
                                next if $tag =~ /^__.+__$/;
                                format REASON_TOP =
Tag                    Type           Description
-------------------------------------------------------------------------------
.
                                format REASON =
@<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$tag,                  $type,         $descr
~                                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                      $descr
~                                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                      $descr
~                                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                      $descr
~                                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                      $descr
~                                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                      $descr
~                                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                      $descr
~                                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                      $descr
~                                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                                      $descr
~                                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
                                      $descr

.
                                $~ = "REASON";
                                $^ = "REASON_TOP";
                                write;
                        }
                } elsif (defined($ds->getError())) {
                        cleanup($ds, 1,
                                      "Failed to list port failure reasons: "
                                    . $ds->getError()
                                    . "\n");
                } else {
                        cleanup($ds, 1,
                                "There are no port failure reasons configured in the datastore.\n"
                        );
                }
        }
}

sub listHooks {
        if ($opts->{'h'}) {
                my $hook = $ds->getHookByName($opts->{'h'});

                if (!defined($hook)) {
                        cleanup($ds, 1,
                                      "Failed to find hook with name "
                                    . $opts->{'h'}
                                    . " in the datastore.\n");
                }

                print "Name       : " . $hook->getName() . "\n";
                print "Command    : " . $hook->getCmd() . "\n";
                print "Description:\n";
                print $hook->getDescription() . "\n";
        } else {
                my @hooks = $ds->getAllHooks();

                if (@hooks) {
                        foreach my $hook (@hooks) {
                                print
                                    "--------------------------------------------------------------------------------\n";
                                print "Name       : " . $hook->getName() . "\n";
                                print "Command    : " . $hook->getCmd() . "\n";
                                print "Description:\n";
                                print $hook->getDescription() . "\n\n";

                        }
                } elsif (defined($ds->getError())) {
                        cleanup($ds, 1,
                                      "Failed to list hooks: "
                                    . $ds->getError()
                                    . "\n");
                } else {
                        cleanup($ds, 1,
                                "There are no hooks configured in the datastore.\n"
                        );
                }
        }
}

sub getHookCmd {
        if (!$opts->{'h'}) {
                usage("getHookCmd");
        }

        if (!$ds->isValidHook($opts->{'h'})) {
                cleanup($ds, 1, "Unknown hook, " . $opts->{'h'} . "\n");
        }

        my $hook = $ds->getHookByName($opts->{'h'});
        my $cmd  = $hook->getCmd();
        if ($cmd ne "") {
                print $cmd . "\n";
        }
}

sub addBuild {
        if (!$opts->{'b'} || !$opts->{'j'} || !$opts->{'p'}) {
                usage("addBuild");
        }

        my $name      = $opts->{'b'};
        my $jail      = $opts->{'j'};
        my $portstree = $opts->{'p'};

        if ($ds->isValidBuild($name)) {
                cleanup($ds, 1,
                        "A build named $name is already in the datastore.\n");
        }

        if (!$ds->isValidJail($jail)) {
                cleanup($ds, 1, "No such jail, \"$jail\", in the datastore.\n");
        }

        if (!$ds->isValidPortsTree($portstree)) {
                cleanup($ds, 1,
                        "No such portstree, \"$portstree\", in the datastore.\n"
                );
        }

        my $jCls = $ds->getJailByName($jail);
        my $pCls = $ds->getPortsTreeByName($portstree);

        my $build = new Tinderbox::Build();
        $build->setName($name);
        $build->setJailId($jCls->getId());
        $build->setPortsTreeId($pCls->getId());
        if ($opts->{'d'}) {
                my $descr = trimstr($opts->{'d'});

                $build->setDescription($descr);
        }
        my $rc = $ds->addBuild($build);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to add build $name to the datastore: "
                            . $ds->getError()
                            . ".\n");
        }
}

sub addJail {
        my $name = $opts->{'j'};
        my $arch = $opts->{'a'};
        my $ucmd = $opts->{'u'};
        my $tag  = $opts->{'t'};

        if (!$name || !$arch || !$ucmd || !$tag) {
                usage("addJail");
        }

        if ($ds->isValidJail($name)) {
                cleanup($ds, 1,
                        "A jail named $name is already in the datastore.\n");
        }

        if ($name !~ /^\d/) {
                cleanup($ds, 1,
                        "The first character in a jail name must be a FreeBSD major version number.\n"
                );
        }

        my $jail = new Tinderbox::Jail();

        $jail->setName($name);
        $jail->setArch($arch);
        $jail->setTag($tag);
        $jail->setUpdateCmd($ucmd);
        if ($opts->{'d'}) {
                my $descr = trimstr($opts->{'d'});

                $jail->setDescription($descr);
        }
        $jail->setSrcMount($opts->{'m'}) if ($opts->{'m'});

        my $rc = $ds->addJail($jail);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to add jail $name to the datastore: "
                            . $ds->getError()
                            . ".\n");
        }
}

sub addPortsTree {
        my $name = $opts->{'p'};
        my $ucmd = $opts->{'u'};

        if (!$name || !$ucmd) {
                usage("addPortsTree");
        }

        if ($ds->isValidPortsTree($name)) {
                cleanup($ds, 1,
                        "A portstree named $name is already in the datastore.\n"
                );
        }

        my $portstree = new Tinderbox::PortsTree();

        $portstree->setName($name);
        $portstree->setUpdateCmd($ucmd);
        if ($opts->{'d'}) {
                my $descr = trimstr($opts->{'d'});

                $portstree->setDescription($descr);
        }
        $portstree->setPortsMount($opts->{'m'}) if ($opts->{'m'});
        $portstree->setCVSwebURL($opts->{'w'})  if ($opts->{'w'});
        $portstree->setLastBuilt($ds->getTime());

        my $rc = $ds->addPortsTree($portstree);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to add portstree $name to the datastore: "
                            . $ds->getError()
                            . ".\n");
        }
}

# Internal function: do NOT call directly, but only from addPort
# This code assumes its mount points and environment have been set up
sub addPortToOneBuild {
        my $build = $ds->getBuildByName($opts->{'b'});
        my $makecache =
            new Tinderbox::MakeCache($ENV{'PORTSDIR'}, $ENV{'PKGSUFFIX'});
        my @bports = ();

        if (!$opts->{'d'}) {
                foreach my $port ($ds->getPortsForBuild($build)) {
                        push @bports, $port->getDirectory();
                }
        } else {
                push @bports, $opts->{'d'};
        }

        if ($opts->{'R'}) {
                foreach my $pdir (@bports) {
                        addPorts($pdir, $build, $makecache, undef);
                }
        } else {
                my @deps = @bports;
                my %seen = ();
                while (my $port = shift @deps) {
                        if (!$seen{$port}) {
                                my $pCls =
                                    addPorts($port, $build, $makecache, \@deps);
                                if (!defined($pCls)) {
                                        cleanup(
                                                $ds, 1,
                                                "Dependency $port not
						found in tree.\n"
                                        );
                                }
                                $seen{$port} = $pCls;
                        }
                }
                foreach my $port (keys %seen) {
                        my $pCls      = $seen{$port};
                        my %oper_hash = (
                                EXTRACT_DEPENDS => 'ExtractDepends',
                                PATCH_DEPENDS   => 'PatchDepends',
                                FETCH_DEPENDS   => 'FetchDepends',
                                BUILD_DEPENDS   => 'BuildDepends',
                                LIB_DEPENDS     => 'LibDepends',
                                RUN_DEPENDS     => 'RunDepends',
                                TEST_DEPENDS    => 'TestDepends',
                                PKG_DEPENDS     => 'PkgDepends',
                        );

                        $ds->clearDependenciesForPort($pCls, $build, undef);

                        foreach my $deptype (keys %oper_hash) {
                                my $oper = $oper_hash{$deptype};
                                foreach my $depname ($makecache->$oper($port)) {
                                        my $dep =
                                            $ds->getPortByDirectory($depname);
                                        next if (!defined($dep));
                                        if (
                                                !$ds->addDependencyForPort(
                                                        $pCls,    $build,
                                                        $deptype, $dep
                                                )
                                            )
                                        {
                                                warn
                                                    "WARN: Failed to add $deptype entry for $port: "
                                                    . $ds->getError() . "\n";
                                        }
                                }
                        }
                }

        }
}

sub addBuildPortsQueueEntry {
        my $admin;
        my $user;
        my $user_id;

        if (!$opts->{'b'}) {
                usage("addBuildPortsQueueEntry");
        }

        my $priority = defined $opts->{'p'} ? $opts->{'p'} : 10;

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});

        if ($opts->{'u'}) {
                if ($ds->isValidUser($opts->{'u'})) {
                        $user    = $ds->getUserByName($opts->{'u'});
                        $user_id = $user->getId();
                } else {
                        $user_id = 0;
                }
        } else {
                if ($admin = $ds->getWwwAdmin()) {
                        $user_id = $admin->getId();
                } else {
                        $user_id = 0;
                }
        }

        my @portdirs = ();
        if ($opts->{'d'}) {
                push @portdirs, $opts->{'d'};
        } else {
                my @ports = $ds->getPortsForBuild($build);
                foreach my $pObj (@ports) {
                        push @portdirs, $pObj->getDirectory();
                }
        }

        my $errors = 0;
        foreach my $portdir (@portdirs) {
                my $rc =
                    $ds->addBuildPortsQueueEntry($build, $portdir, $priority,
                        $user_id);
                if (!$rc) {
                        warn(         "Failed to add port "
                                    . $portdir
                                    . " to the datastore: "
                                    . $ds->getError()
                                    . ".\n");
                        $errors++;
                }
        }
        if ($errors) {
                cleanup($ds, 1,
                        "Errors were encountered.  See output above for more details."
                );
        }
}

sub addPortFailPattern {
        my $parent;
        my $pattern;

        if (!$opts->{'e'} || !$opts->{'r'} || !$opts->{'i'}) {
                usage("addPortFailPattern");
        }

        $parent = $opts->{'p'} ? $opts->{'p'} : 0;

        if ($opts->{'i'} % 100 == 0) {
                cleanup($ds, 1,
                        "IDs that are evenly divisible by 100 are reserved for system patterns.\n"
                );
        }

        if ($opts->{'i'} > 2147483647 || $opts->{'i'} < 0) {
                cleanup($ds, 1,
                        "IDs must be greater than 0, and less than 2147483647.\n"
                );
        }

        if ($ds->isValidPortFailPattern($opts->{'i'})) {
                cleanup($ds, 1,
                              "A pattern with the ID "
                            . $opts->{'i'}
                            . " already exists in the datastore.\n");
        }

        if (!$ds->isValidPortFailPattern($parent)) {
                cleanup($ds, 1, "No such parent pattern ID, $parent.\n");
        }

        if (!$ds->isValidPortFailReason($opts->{'r'})) {
                cleanup($ds, 1, "No such reason tag, " . $opts->{'r'} . ".\n");
        }

        if (!eval { 'tinderbox' =~ /$opts->{'e'}/, 1 }) {
                cleanup($ds, 1,
                        "Bad regular expression, '" . $opts->{'e'} . "': $@\n");
        }

        $pattern = new Tinderbox::PortFailPattern();
        $pattern->setId($opts->{'i'});
        $pattern->setReason($opts->{'r'});
        $pattern->setParent($parent);
        $pattern->setExpr($opts->{'e'});

        my $rc = $ds->addPortFailPattern($pattern);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to add pattern "
                            . $opts->{'i'}
                            . " to the datastore: "
                            . $ds->getError()
                            . ".\n");
        }
}

sub addPortFailReason {
        my $descr;
        my $type;
        my $reason;

        if (!$opts->{'t'}) {
                usage("addPortFailReason");
        }

        $descr = $opts->{'d'} ? $opts->{'d'} : "";
        $type  = $opts->{'y'} ? $opts->{'y'} : "COMMON";

        if ($ds->isValidPortFailReason($opts->{'t'})) {
                cleanup($ds, 1,
                              "There is already a reason with tag, "
                            . $opts->{'t'}
                            . " in the datastore.\n");
        }

        $reason = new Tinderbox::PortFailReason();
        $reason->setTag($opts->{'t'});
        $reason->setDescr($descr);
        $reason->setType($type);

        my $rc = $ds->addPortFailReason($reason);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to add reason "
                            . $opts->{'t'}
                            . " to the datastore: "
                            . $ds->getError()
                            . ".\n");
        }
}

sub getDependenciesForPort {
        my %depends_hash = (
                EXTRACT_DEPENDS => 0,
                PATCH_DEPENDS   => 1,
                FETCH_DEPENDS   => 2,
                BUILD_DEPENDS   => 3,
                LIB_DEPENDS     => 4,
                RUN_DEPENDS     => 5,
                TEST_DEPEND     => 6,
                PKG_DEPENDS     => 7,
        );

        if (!$opts->{'b'} || !$opts->{'d'}) {
                usage("getDependenciesForPort");
        }

        my $port = $ds->getPortByDirectory($opts->{'d'});
        if (!defined($port)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not in the datastore.\n");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});

        if (!$ds->isPortForBuild($port, $build)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not a valid port for build, "
                            . $opts->{'b'}
                            . "\n");
        }

        my $deptype = undef;
        if ($opts->{'t'}) {
                $deptype = $opts->{'t'};
        }

        if (defined($deptype) && !defined($depends_hash{$deptype})) {
                cleanup($ds, 1, "$deptype is not a valid dependency type\n");
        }

        my @deps = $ds->getDependenciesForPort($port, $build, $deptype);

        if (@deps) {
                map { print $_->getDirectory() . "\n" } @deps;
        } elsif (defined($ds->getError())) {
                cleanup($ds, 1,
                        "Failed to get dependencies for this port from the datastore: "
                            . $ds->getError()
                            . "\n");
        } else {
                cleanup($ds, 0,
                        "There are no dependencies for this port in the datastore.\n"
                );
        }
}

sub listBuildPortsQueue {
        my $build_filter;
        my $raw;
        my $status = $opts->{'s'};

        if ($opts->{'r'}) {
                $raw = 1
        }

        $build_filter = undef;

        if ($opts->{'b'}) {
                if (!$ds->isValidBuild($opts->{'b'})) {
                        cleanup($ds, 1,
                                "Unknown Build, " . $opts->{'b'} . "\n");
                }

                $build_filter = $ds->getBuildByName($opts->{'b'});
        }

        my @buildportsqueue = $ds->getBuildPortsQueueByStatus($status);

        if (@buildportsqueue) {
                if ($raw ne 1) {
                        print
                            "+=====+===========================+=====================================+=====+\n";
                        print
                            "|  Id | Build Name                | Port Directory                      | Pri |\n";
                        print
                            "+=====+===========================+=====================================+=====+\n";
                }
                foreach my $buildport (@buildportsqueue) {
                        if ($buildport) {
                                my $buildname = "N/A";
                                my $build =
                                    $ds->getBuildById($buildport->getBuildId());
                                if ($build) {
                                        $buildname = $build->getName();
                                }

                                if (defined($build_filter)) {
                                        next
                                            if $build->getId() !=
                                            $build_filter->getId();
                                }

                                if ($raw eq 1) {
                                        print $buildport->getId() . ":"
                                            . $buildport->getUserId() . ":"
                                            . $buildname . ":"
                                            . $buildport->getPortDirectory()
                                            . ":"
                                            . $buildport->getEmailOnCompletion()
                                            . "\n";
                                } else {
                                        printf(
                                                "| %3d | %-25s | %-35s | %3d |\n",
                                                $buildport->getId(),
                                                $buildname,
                                                $buildport->getPortDirectory(),
                                                $buildport->getPriority()
                                        );
                                        print
                                            "+-----+---------------------------+-------------------------------------+-----+\n";
                                }
                        }
                }
        } elsif (defined($ds->getError())) {
                cleanup($ds, 1,
                              "Failed to list BuildPortsQueue: "
                            . $ds->getError()
                            . "\n");
        }
}

sub getJailForBuild {
        if (!$opts->{'b'}) {
                usage("getJailForBuild");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});
        my $jail  = $ds->getJailById($build->getJailId());

        print $jail->getName() . "\n";
}

sub getPortsTreeForBuild {
        if (!$opts->{'b'}) {
                usage("getPortsTreeForBuild");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build     = $ds->getBuildByName($opts->{'b'});
        my $portstree = $ds->getPortsTreeById($build->getPortsTreeId());

        print $portstree->getName() . "\n";
}

sub getPortsForBuild {
        if (!$opts->{'b'}) {
                usage("getPortsForBuild");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});
        my @ports = $ds->getPortsForBuild($build);

        if (@ports) {
                map { print $_->getDirectory() . "\n" } @ports;
        }
}

sub getTagForJail {
        if (!$opts->{'j'}) {
                usage("getTagForJail");
        }

        if (!$ds->isValidJail($opts->{'j'})) {
                cleanup($ds, 1, "Unknown jail, " . $opts->{'j'} . "\n");
        }

        my $jail = $ds->getJailByName($opts->{'j'});

        print $jail->getTag() . "\n";
}

sub getJailArch {
        if (!$opts->{'j'}) {
                usage("getJailArch");
        }

        if (!$ds->isValidJail($opts->{'j'})) {
                cleanup($ds, 1, "Unknown jail, " . $opts->{'j'} . "\n");
        }

        my $jail = $ds->getJailByName($opts->{'j'});

        print $jail->getArch() . "\n";
}

sub getUpdateCmd {
        if ($opts->{'j'}) {
                my $jailName = $opts->{'j'};

                cleanup($ds, 1, "Unknown jail, $jailName\n")
                    if (!$ds->isValidJail($jailName));

                my $jail = $ds->getJailByName($jailName);
                print $jail->getUpdateCmd() . "\n";

        } elsif ($opts->{'p'}) {
                my $portsTreeName = $opts->{'p'};

                cleanup($ds, 1, "Unknown portstree, $portsTreeName\n")
                    if (!$ds->isValidPortsTree($portsTreeName));

                my $portsTree = $ds->getPortsTreeByName($portsTreeName);
                print $portsTree->getUpdateCmd() . "\n";

        } else {
                usage("getUpdateCmd");
        }
}

sub getSrcMount {
        if (!$opts->{'j'}) {
                usage("getSrcMount");
        }

        my $jail_name = $opts->{'j'};

        if (!$ds->isValidJail($jail_name)) {
                cleanup($ds, 1, "Unknown jail, $jail_name\n");
        }

        my $jail = $ds->getJailByName($jail_name);

        my $mount_src = $jail->getSrcMount();

        print $mount_src . "\n";
}

sub getPortsMount {
        if (!$opts->{'p'}) {
                usage("getPortsMount");
        }

        my $portstree_name = $opts->{'p'};

        if (!$ds->isValidPortsTree($portstree_name)) {
                cleanup($ds, 1, "Unknown portstree, $portstree_name\n");
        }

        my $portstree = $ds->getPortsTreeByName($portstree_name);

        my $mount_src = $portstree->getPortsMount();

        print $mount_src . "\n";
}

sub setSrcMount {
        if (!$opts->{'j'} || !$opts->{'m'}) {
                usage("setSrcMount");
        }

        my $jail_name = $opts->{'j'};

        if (!$ds->isValidJail($jail_name)) {
                cleanup($ds, 1, "Unknown jail, $jail_name\n");
        }

        my $jail = $ds->getJailByName($jail_name);

        $jail->setSrcMount($opts->{'m'});

        my $rc = $ds->updateJail($jail);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to set the SrcMount for jail "
                            . $jail->getName() . ": "
                            . $ds->getError()
                            . "\n");
        }
}

sub setPortsMount {
        if (!$opts->{'p'} || !$opts->{'m'}) {
                usage("setPortsMount");
        }

        my $portstree_name = $opts->{'p'};

        if (!$ds->isValidPortsTree($portstree_name)) {
                cleanup($ds, 1, "Unknown portstree, $portstree_name\n");
        }

        my $portstree = $ds->getPortsTreeByName($portstree_name);

        $portstree->setPortsMount($opts->{'m'});

        my $rc = $ds->updatePortsTree($portstree);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to set the PortsMount for portstree "
                            . $portstree->getName() . ": "
                            . $ds->getError()
                            . "\n");
        }
}

sub reorgBuildPortsQueue {
        my $rc = $ds->reorgBuildPortsQueue();

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to reorganize BuildPortsQueue: "
                            . $ds->getError()
                            . "\n");
        }
}

sub updateBuildPortsQueueEntryStatus {
        if (!$opts->{'i'} || !$opts->{'s'}) {
                usage("updateBuildPortsQueueEntryStatus");
        }

        if (!$ds->isValidBuildPortsQueueId($opts->{'i'})) {
                cleanup($ds, 1,
                              "Unknown Build Ports Queue Entry, "
                            . $opts->{'i'}
                            . "\n");
        }

        my $rc =
            $ds->updateBuildPortsQueueEntryStatus($opts->{'i'}, $opts->{'s'});

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to update BuildPortsQueueEntryStatus "
                            . $opts->{'i'} . ": "
                            . $ds->getError()
                            . "\n");
        }
}

sub rmBuildPortsQueue {
        my $rc = $ds->removeBuildPortsQueue();

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to remove BuildPortsQueue: "
                            . $ds->getError()
                            . "\n");
        }
}

sub rmBuildPortsQueueEntry {
        my $buildportsqueue;

        if (!$opts->{'i'} && (!$opts->{'b'} || !$opts->{'d'})) {
                usage("rmBuildPortsQueueEntry");
        }

        if ($opts->{'i'}) {
                if (!$ds->isValidBuildPortsQueueId($opts->{'i'})) {
                        cleanup($ds, 1,
                                      "Unknown BuildPortsQueueId "
                                    . $opts->{'i'}
                                    . "\n");
                }

                $buildportsqueue = $ds->getBuildPortsQueueById($opts->{'i'});
        } else {
                if (!$ds->isValidBuild($opts->{'b'})) {
                        cleanup($ds, 1,
                                "Unknown build, " . $opts->{'b'} . "\n");
                }

                my $build = $ds->getBuildByName($opts->{'b'});
                $buildportsqueue =
                    $ds->getBuildPortsQueueByKeys($build, $opts->{'d'});
                if (!$buildportsqueue) {
                        cleanup($ds, 1,
                                      "Unknown BuildPortsQueueEntry "
                                    . $opts->{'d'} . " "
                                    . $opts->{'b'}
                                    . "\n");
                }
        }

        my $rc = $ds->removeBuildPortsQueueEntry($buildportsqueue);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to remove BuildPortsQueue Entry "
                            . $buildportsqueue->getId() . ": "
                            . $ds->getError()
                            . "\n");
        }
}

sub getPackageSuffix {
        if (!$opts->{'j'}) {
                usage("getPackageSuffix");
        }

        if (!$ds->isValidJail($opts->{'j'})) {
                cleanup($ds, 1, "Unknown jail, " . $opts->{'j'} . "\n");
        }

        my $jail = $ds->getJailByName($opts->{'j'});
        my $sufx = $ds->getPackageSuffix($jail);

        print $sufx . "\n";
}

sub rmPort {
        if (!$opts->{'d'}) {
                usage("rmPort");
        }

        if ($opts->{'b'}) {
                if (!$ds->isValidBuild($opts->{'b'})) {
                        cleanup($ds, 1,
                                "Unknown build, " . $opts->{'b'} . "\n");
                }
        }

        my $port = $ds->getPortByDirectory($opts->{'d'});

        if (!defined($port)) {
                cleanup($ds, 1, "Unknown port, " . $opts->{'d'} . "\n");
        }

        unless ($opts->{'f'}) {
                if ($opts->{'b'}) {
                        print "Really remove port "
                            . $opts->{'d'}
                            . " for build "
                            . $opts->{'b'} . "? ";
                } else {
                        print "Really remove port " . $opts->{'d'} . "? ";
                }
                my $response = <STDIN>;
                cleanup($ds, 0, undef) unless ($response =~ /^y/i);
        }

        my @builds = ();
        my $rc;
        if ($opts->{'c'} && !$opts->{'b'}) {
                @builds = $ds->getAllBuilds();
        } elsif ($opts->{'c'} && $opts->{'b'}) {
                push @builds, $ds->getBuildByName($opts->{'b'});
        }
        foreach my $build (@builds) {
                if (my $version = $ds->getPortLastBuiltVersion($port, $build)) {
                        my $jail      = $ds->getJailById($build->getJailId());
                        my $sufx      = $ds->getPackageSuffix($jail);
                        my $buildName = $build->getName();
                        my $pkgdir    = tinderLoc($pb, 'packages', $buildName);
                        my $logpath   = tinderLoc($pb, 'buildlogs',
                                $buildName . "/$version");
                        my $errpath = tinderLoc($pb, 'builderrors',
                                $buildName . "/$version");
                        if (-d $pkgdir) {
                                print
                                    "Removing all packages matching ${version}${sufx} starting from $pkgdir.\n";
                                system(
                                        "/usr/bin/find -H $pkgdir -name ${version}${sufx} -delete"
                                );
                        }
                        if (-f $logpath . ".log") {
                                print "Removing ${logpath}.log.\n";
                                unlink($logpath . ".log");
                        }
                        if (-f $errpath . ".log") {
                                print "Removing ${errpath}.log.\n";
                                unlink($errpath . ".log");
                        }
                }
        }

        if ($opts->{'b'}) {
                $rc =
                    $ds->removePortForBuild($port,
                        $ds->getBuildByName($opts->{'b'}));
        } else {
                $rc = $ds->removePort($port);
        }

        if (!$rc) {
                cleanup($ds, 1,
                        "Failed to remove port: " . $ds->getError() . "\n");
        }
}

sub rmBuild {
        if (!$opts->{'b'}) {
                usage("rmBuild");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build " . $opts->{'b'} . "\n");
        }

        unless ($opts->{'f'}) {
                print "Really remove build " . $opts->{'b'} . "? ";
                my $response = <STDIN>;
                cleanup($ds, 0, undef) unless ($response =~ /^y/i);
        }

        my $rc = $ds->removeBuild($ds->getBuildByName($opts->{'b'}));

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to remove build "
                            . $opts->{'b'} . ": "
                            . $ds->getError()
                            . "\n");
        }
}

sub rmJail {
        if (!$opts->{'j'}) {
                usage("rmJail");
        }

        if (!$ds->isValidJail($opts->{'j'})) {
                cleanup($ds, 1, "Unknown jail " . $opts->{'j'} . "\n");
        }

        my $jail   = $ds->getJailByName($opts->{'j'});
        my @builds = $ds->findBuildsForJail($jail);

        unless ($opts->{'f'}) {
                if (@builds) {
                        print
                            "Removing this jail will also remove the following builds:\n";
                        foreach my $build (@builds) {
                                print "\t" . $build->getName() . "\n";
                        }
                }
                print "Really remove jail " . $opts->{'j'} . "? ";
                my $response = <STDIN>;
                cleanup($ds, 0, undef) unless ($response =~ /^y/i);
        }

        my $rc;
        foreach my $build (@builds) {
                $rc = $ds->removeBuild($build);
                if (!$rc) {
                        cleanup($ds, 1,
                                      "Failed to remove build "
                                    . $build->getName()
                                    . " as part of removing jail "
                                    . $opts->{'j'} . ": "
                                    . $ds->getError()
                                    . "\n");
                }
        }

        $rc = $ds->removeJail($jail);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to remove jail "
                            . $opts->{'j'} . ": "
                            . $ds->getError()
                            . "\n");
        }
}

sub rmPortsTree {
        if (!$opts->{'p'}) {
                usage("rmPortsTree");
        }

        if (!$ds->isValidPortsTree($opts->{'p'})) {
                cleanup($ds, 1, "Unknown portstree " . $opts->{'p'} . "\n");
        }

        my $portstree = $ds->getPortsTreeByName($opts->{'p'});
        my @builds    = $ds->findBuildsForPortsTree($portstree);

        unless ($opts->{'f'}) {
                if (@builds) {
                        print
                            "Removing this portstree will also remove the following builds:\n";
                        foreach my $build (@builds) {
                                print "\t" . $build->getName() . "\n";
                        }
                }
                print "Really remove portstree " . $opts->{'p'} . "? ";
                my $response = <STDIN>;
                cleanup($ds, 0, undef) unless ($response =~ /^y/i);
        }

        my $rc;
        foreach my $build (@builds) {
                $rc = $ds->removeBuild($build);
                if (!$rc) {
                        cleanup($ds, 1,
                                      "Failed to remove build "
                                    . $build->getName()
                                    . " as part of removing portstree "
                                    . $opts->{'p'} . ": "
                                    . $ds->getError()
                                    . "\n");
                }
        }

        $rc = $ds->removePortsTree($portstree);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to remove portstree "
                            . $opts->{'p'} . ": "
                            . $ds->getError()
                            . "\n");
        }
}

sub rmUser {
        if (!$opts->{'u'}) {
                usage("rmUser");
        }

        if ($opts->{'b'}) {
                if (!$ds->isValidBuild($opts->{'b'})) {
                        cleanup($ds, 1,
                                "Unknown build, " . $opts->{'b'} . "\n");
                }
        }

        my $user = $ds->getUserByName($opts->{'u'});

        if (!defined($user)) {
                cleanup($ds, 1, "Unknown user, " . $opts->{'u'} . "\n");
        }

        unless ($opts->{'f'}) {
                if ($opts->{'b'}) {
                        print "Really remove user "
                            . $opts->{'u'}
                            . " for build "
                            . $opts->{'b'} . "? ";
                } else {
                        print "Really remove user " . $opts->{'u'} . "? ";
                }
                my $response = <STDIN>;
                print "\n";
                cleanup($ds, 0, undef) unless ($response =~ /^y/i);
        }

        my $rc;
        if ($opts->{'b'}) {
                $rc =
                    $ds->removeUserForBuild($user,
                        $ds->getBuildByName($opts->{'b'}));
        } else {
                $rc = $ds->removeUser($user);
        }

        if (!$rc) {
                cleanup($ds, 1,
                        "Failed to remove user: " . $ds->getError() . "\n");
        }
}

sub rmPortFailPattern {
        my $pattern;

        if (!$opts->{'i'}) {
                usage("rmPortFailPattern");
        }

        $pattern = $ds->getPortFailPatternById($opts->{'i'});

        if (!defined($pattern)) {
                cleanup($ds, 1,
                              "Unknown port failure pattern ID, "
                            . $opts->{'i'}
                            . ".\n");
        }

        if ($opts->{'i'} % 100 == 0) {
                cleanup($ds, 1,
                              "Cannot remove system defined pattern "
                            . $opts->{'i'}
                            . ".\n");
        }

        unless ($opts->{'f'}) {
                print "Really remove port failure pattern "
                    . $opts->{'i'} . "? ";
                my $response = <STDIN>;
                print "\n";
                cleanup($ds, 0, undef) unless ($response =~ /^y/i);
        }

        my $rc = $ds->removePortFailPattern($pattern);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to remove port failure pattern: "
                            . $ds->getError()
                            . "\n");
        }
}

sub rmPortFailReason {
        my $reason;
        my @patterns;

        if (!$opts->{'t'}) {
                usage("rmPortFailReason");
        }

        $reason = $ds->getPortFailReasonByTag($opts->{'t'});

        if (!defined($reason)) {
                cleanup($ds, 1,
                              "Unknown port failure reason tag, "
                            . $opts->{'t'}
                            . ".\n");
        }

        @patterns = $ds->findPortFailPatternsWithReason($reason);

        foreach my $pattern (@patterns) {
                if (       $pattern->getId() % 100 == 0
                        || $pattern->getId() == 2147483647)
                {
                        cleanup($ds, 1,
                                "This port failure reason is referenced by system-defined port failure patterns, and cannot be removed.\n"
                        );
                }
        }

        unless ($opts->{'f'}) {
                if (@patterns) {
                        print
                            "Removing this port failure reason will also remove the following port failure patterns:\n";
                        foreach my $pattern (@patterns) {
                                print "\t" . $pattern->getId() . "\n";
                        }
                }
                print "Really remove port failure reason "
                    . $opts->{'t'} . "? ";
                my $response = <STDIN>;
                cleanup($ds, 0, undef) unless ($response =~ /^y/i);
        }

        my $rc;
        foreach my $pattern (@patterns) {
                $rc = $ds->removePortFailPattern($pattern);
                if (!$rc) {
                        cleanup($ds, 1,
                                      "Failed to remove port failure pattern "
                                    . $pattern->getId()
                                    . " as part of removing port failure reason "
                                    . $opts->{'t'} . ": "
                                    . $ds->getError()
                                    . "\n");
                }
        }

        $rc = $ds->removePortFailReason($reason);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to remove port failure reason . "
                            . $opts->{'t'} . ": "
                            . $ds->getError()
                            . "\n");
        }
}

sub updateBuildPortsQueueEntryCompletionDate {
        if (!$opts->{'i'}) {
                usage("updateBuildPortsQueueEntryCompletionDate");
        }

        if (!$ds->isValidBuildPortsQueueId($opts->{'i'})) {
                cleanup($ds, 1,
                        "Unknown BuildPortsQueueEntry, " . $opts->{'i'} . "\n");
        }

        my $buildportsqueue = $ds->getBuildPortsQueueById($opts->{'i'});

        $buildportsqueue->setCompletionDate($opts->{'l'});

        $ds->updateBuildPortsQueueEntryCompletionDate($buildportsqueue)
            or cleanup(
                $ds,
                1,
                "Failed to update completion time value in the datastore: "
                    . $ds->getError() . "\n"
            );
}

sub updateJailLastBuilt {
        if (!$opts->{'j'}) {
                usage("updateJailLastBuilt");
        }

        if (!$ds->isValidJail($opts->{'j'})) {
                cleanup($ds, 1, "Unknown jail, " . $opts->{'j'} . "\n");
        }

        my $jail = $ds->getJailByName($opts->{'j'});

        $jail->setLastBuilt($opts->{'l'});

        $ds->updateJailLastBuilt($jail)
            or cleanup($ds, 1,
                      "Failed to update last built value in the datastore: "
                    . $ds->getError()
                    . "\n");
}

sub updatePortsTreeLastBuilt {
        if (!$opts->{'p'}) {
                usage("updatePortsTreeLastBuilt");
        }

        if (!$ds->isValidPortsTree($opts->{'p'})) {
                cleanup($ds, 1, "Unknown portstree, " . $opts->{'p'} . "\n");
        }

        my $portstree = $ds->getPortsTreeByName($opts->{'p'});

        $portstree->setLastBuilt($opts->{'l'});

        $ds->updatePortsTreeLastBuilt($portstree)
            or cleanup($ds, 1,
                      "Failed to update last built value in the datastore: "
                    . $ds->getError()
                    . "\n");
}

sub updatePortStatus {
        if (!$opts->{'d'} || !$opts->{'b'}) {
                usage("updatePortStatus");
        }

        my $port = $ds->getPortByDirectory($opts->{'d'});
        if (!defined($port)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not in the datastore.\n");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});

        if (!$ds->isPortForBuild($port, $build)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not a valid port for build, "
                            . $opts->{'b'}
                            . "\n");
        }

        if (defined($opts->{'L'})) {
                $ds->updatePortLastBuilt($port, $build, '')
                    or cleanup($ds, 1,
                        "FAILED: last_built: " . $ds->getError() . "\n");
        }

        if (defined($opts->{'S'})) {
                $ds->updatePortLastSuccessfulBuilt($port, $build, '')
                    or cleanup(
                        $ds,
                        1,
                        "FAILED: last_successful_built: "
                            . $ds->getError() . "\n"
                    );
        }

        if (defined($opts->{'s'})) {
                $ds->updatePortLastStatus($port, $build, $opts->{'s'})
                    or cleanup($ds, 1,
                        "FAILED: last_status: " . $ds->getError() . "\n");
        }

        if (defined($opts->{'r'})) {
                $ds->updatePortLastFailReason($port, $build, $opts->{'r'})
                    or cleanup($ds, 1,
                        "FAILED: last_fail_reason: " . $ds->getError() . "\n");
        }

        if (defined($opts->{'v'})) {
                $ds->updatePortLastBuiltVersion($port, $build, $opts->{'v'})
                    or cleanup(
                        $ds,
                        1,
                        "FAILED: last_built_version: " . $ds->getError() . "\n"
                    );
        }

        if (defined($opts->{'p'})) {
                $ds->updatePortLastFailedDep($port, $build, $opts->{'p'})
                    or cleanup($ds, 1,
                        "FAILED: last_failed_dep: " . $ds->getError() . "\n");
        } else {
                $ds->updatePortLastFailedDep($port, $build, undef)
                    or cleanup(
                        $ds,
                        1,
                        "FAILED: unset_last_failed_dep: "
                            . $ds->getError() . "\n"
                    );
        }

        if (defined($opts->{'t'})) {
                $ds->updatePortTotalSize($port, $build, $opts->{'t'})
                    or cleanup($ds, 1,
                        "FAILED: total_size: " . $ds->getError() . "\n");
        }
}

sub updateBuildStatus {
        my %status_hash = (
                IDLE      => 0,
                PREPARE   => 1,
                PORTBUILD => 2,
        );

        if (!$opts->{'b'}) {
                usage("updateBuildStatus");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});

        my $build_status;
        if (!defined($status_hash{$opts->{'s'}})) {
                $build_status = "IDLE";
        } else {
                $build_status = $opts->{'s'};
        }
        $build->setStatus($build_status);

        $ds->updateBuildStatus($build)
            or cleanup($ds, 1,
                "Failed to update last build status value in the datastore: "
                    . $ds->getError()
                    . "\n");
}

sub updateBuildRemakeCount {
        if (       !$opts->{'b'}
                || (!defined($opts->{'c'}) && !defined($opts->{'d'}))
                || (defined($opts->{'c'})  && defined($opts->{'d'})))
        {
                usage("updateBuildRemakeCount");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});
        my $count = $build->getRemakeCount();

        if (defined($opts->{'c'})) {
                $count = $opts->{'c'};
                if ($count !~ /^\d+$/) {
                        cleanup($ds, 1,
                                "The count must be a non-negative integer\n");
                }

        } else {
                $count--;
                if ($count < 0) {
                        cleanup($ds, 0, undef);
                }
        }

        $ds->updateBuildRemakeCount($build, $count)
            or cleanup($ds, 1,
                      "Failed to update the remake count in the datastore: "
                    . $ds->getError()
                    . "\n");
}

sub getPortLastBuiltVersion {
        if (!$opts->{'d'} || !$opts->{'b'}) {
                usage("getPortLastBuiltVersion");
        }

        my $port = $ds->getPortByDirectory($opts->{'d'});
        if (!defined($port)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not in the datastore.\n");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});

        if (!$ds->isPortForBuild($port, $build)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not a valid port for build, "
                            . $opts->{'b'}
                            . "\n");
        }

        my $version = $ds->getPortLastBuiltVersion($port, $build);
        if (!defined($version) && $ds->getError()) {
                cleanup($ds, 1,
                              "Failed to get last update version for port "
                            . $opts->{'d'}
                            . " for build "
                            . $opts->{'b'} . ": "
                            . $ds->getError()
                            . "\n");
        }

        print $version . "\n";
}

sub getPortLastBuiltStatus {
        if (!$opts->{'d'} || !$opts->{'b'}) {
                usage("getPortLastBuiltStatus");
        }

        my $port = $ds->getPortByDirectory($opts->{'d'});
        if (!defined($port)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not in the datastore.\n");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});

        if (!$ds->isPortForBuild($port, $build)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not a valid port for build, "
                            . $opts->{'b'}
                            . "\n");
        }

        my $status = $ds->getPortLastBuiltStatus($port, $build);
        if (!defined($status) && $ds->getError()) {
                cleanup($ds, 1,
                              "Failed to get last built status for port "
                            . $opts->{'d'}
                            . " for build "
                            . $opts->{'b'} . ": "
                            . $ds->getError()
                            . "\n");
        }

        print $status . "\n";
}

sub getPortTotalSize {
        if (!$opts->{'d'} || !$opts->{'b'}) {
                usage("getPortTotalSize");
        }

        my $port = $ds->getPortByDirectory($opts->{'d'});
        if (!defined($port)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not in the datastore.\n");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});

        if (!$ds->isPortForBuild($port, $build)) {
                cleanup($ds, 1,
                              "Port, "
                            . $opts->{'d'}
                            . " is not a valid port for build, "
                            . $opts->{'b'}
                            . "\n");
        }

        my $size = $ds->getPortTotalSize($port, $build);
        if (!defined($size) && $ds->getError()) {
                cleanup($ds, 1,
                              "Failed to get total size for port "
                            . $opts->{'d'}
                            . " for build "
                            . $opts->{'b'} . ": "
                            . $ds->getError()
                            . "\n");
        }

        print $size . "\n";
}

sub updateBuildCurrentPort {
        if (!$opts->{'b'}) {
                usage("updateBuildCurrentPort");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});
        my $port  = undef;
        if ($opts->{'d'}) {
                $port = $ds->getPortByDirectory($opts->{'d'});
        }

        $ds->updateBuildCurrentPort($build, $port, $opts->{'n'})
            or cleanup(
                $ds,
                1,
                "Failed to get last update build current port for build "
                    . $opts->{'b'} . ": "
                    . $ds->getError() . "\n"
            );
}

sub updateHookCmd {
        if (!$opts->{'h'}) {
                usage("updateHookCmd");
        }

        if (!$ds->isValidHook($opts->{'h'})) {
                cleanup($ds, 1, "Unknown hook, " . $opts->{'h'} . "\n");
        }

        my $hook = $ds->getHookByName($opts->{'h'});

        $ds->updateHookCmd($hook, $opts->{'c'})
            or cleanup($ds, 1,
                      "Failed to update command for hook "
                    . $opts->{'h'} . ": "
                    . $ds->getError()
                    . "\n");
}

sub sendBuildErrorMail {
        if (!$opts->{'b'} || !$opts->{'d'} || !$opts->{'p'}) {
                usage("sendBuildErrorMail");
        }

        my $buildname = $opts->{'b'};
        my $portdir   = $opts->{'d'};
        my $pkgname   = $opts->{'p'};

        if (!$ds->isValidBuild($buildname)) {
                cleanup($ds, 1, "Unknown build, $buildname\n");
        }

        my $build = $ds->getBuildByName($buildname);
        my $port  = $ds->getPortByDirectory($portdir);
        my $lext  = (defined($opts->{'x'}) ? $opts->{'x'} : '');

        my $subject =
              $SUBJECT . ' '
            . (defined($opts->{'l'}) ? 'leftovers' : 'failed')
            . " $portdir $buildname";
        my $now  = scalar localtime;
        my $data = <<EOD;
Port $portdir failed for build $buildname on $now.  The error log can be
found at:

${TINDERBOX_HOST}${LOGS_URI}/$buildname/${pkgname}.log$lext

EOD
        if (defined($port)) {
                my $portid = $port->getId();
                $data .= <<EOD;
More details can be found at:

${TINDERBOX_HOST}${SHOWPORT_URI}$portid

EOD
        }

        $data .= <<EOD;
Please do not reply to this email.
EOD

        my @users = $ds->getBuildCompletionUsers($build);

        if (scalar(@users)) {

                my @addrs = ();
                foreach my $user (@users) {
                        push @addrs, $user->getEmail();
                }

                my $rc =
                    sendMail($SENDER, \@addrs, $subject, $data, $SMTP_HOST);

                if (!$rc) {
                        cleanup($ds, 1, "Failed to send email.");
                }
        }
}

sub sendBuildCompletionMail {
        my @users;
        if (!$opts->{'b'}) {
                usage("sendBuildCompletionMail");
        }

        my $buildname = $opts->{'b'};

        if (!$ds->isValidBuild($buildname)) {
                cleanup($ds, 1, "Unknown build, $buildname\n");
        }

        my $build = $ds->getBuildByName($buildname);

        my $subject = $SUBJECT . " Build $buildname completed";
        my $now     = scalar localtime;
        my $data    = <<EOD;
Build $buildname completed on $now.  Details can be found at:

${TINDERBOX_HOST}${SHOWBUILD_URI}$buildname

Please do not reply to this email.
EOD

        if ($opts->{'u'}) {
                my $user = $ds->getUserByName($opts->{'u'});
                if (defined($user)) {
                        push @users, $user;
                } else {
                        $user = $ds->getUserById($opts->{'u'});
                        if (defined($user)) {
                                push @users, $user;
                        } else {
                                cleanup($ds, 1,
                                              "User "
                                            . $opts->{'u'}
                                            . " is not in the datastore.");
                        }
                }

        } else {
                @users = $ds->getBuildCompletionUsers($build);
        }

        if (scalar(@users)) {

                my @addrs = ();
                foreach my $user (@users) {
                        push @addrs, $user->getEmail();
                }

                my $rc =
                    sendMail($SENDER, \@addrs, $subject, $data, $SMTP_HOST);

                if (!$rc) {
                        cleanup($ds, 1, "Failed to send email.");
                }
        }
}

sub addUser {
        if (!$opts->{'u'}) {
                usage("addUser");
        }

        my $user = new Tinderbox::User();

        $user->setName($opts->{'u'});
        $user->setEmail($opts->{'e'})    if ($opts->{'e'});
        $user->setPassword($opts->{'p'}) if ($opts->{'p'});
        $opts->{'w'} ? $user->setWwwEnabled(1) : $user->setWwwEnabled(0);

        my $rc = $ds->addUser($user);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to add user to the datastore: "
                            . $ds->getError()
                            . "\n");
        }
}

sub updateUser {
        if (!$opts->{'u'}) {
                usage("updateUser");
        }

        my $username = $opts->{'u'};

        if (!$ds->isValidUser($username)) {
                cleanup($ds, 1, "Unknown user, $username\n");
        }

        my $user = $ds->getUserByName($username);

        $user->setName($username);
        $user->setEmail($opts->{'e'})    if ($opts->{'e'});
        $user->setPassword($opts->{'p'}) if ($opts->{'p'});
        $opts->{'w'} ? $user->setWwwEnabled(1) : $user->setWwwEnabled(0);

        my $rc = $ds->updateUser($user);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to update user preferences: "
                            . $ds->getError()
                            . "\n");
        }
}

sub updatePortFailReason {
        my $reason;

        if (!$opts->{'t'} || (!$opts->{'y'} && !$opts->{'d'})) {
                usage("updatePortFailReason");
        }

        if (!$ds->isValidPortFailReason($opts->{'t'})) {
                cleanup($ds, 1,
                        "Unknown port failure reason, " . $opts->{'t'} . ".\n");
        }

        $reason = $ds->getPortFailReasonByTag($opts->{'t'});

        $reason->setType($opts->{'y'})  if $opts->{'y'};
        $reason->setDescr($opts->{'d'}) if $opts->{'d'};

        my $rc = $ds->updatePortFailReason($reason);

        if (!$rc) {
                cleanup($ds, 1,
                              "Failed to update port failure reason: "
                            . $ds->getError()
                            . "\n");
        }
}

sub setWwwAdmin {
        my $old_admin;
        my $old_id;

        if (!$opts->{'u'}) {
                usage("setWwwAdmin");
        }

        my $username = $opts->{'u'};
        if (!$ds->isValidUser($username)) {
                cleanup($ds, 1, "Unknown user, $username\n");
        }

        if ($old_admin = $ds->getWwwAdmin()) {
                $old_id = $old_admin->getId();
        } else {
                $old_id = 0;
        }

        my $user = $ds->getUserByName($username);

        my $rc = $ds->setWwwAdmin($user);

        if (!$rc) {
                cleanup($ds, 1,
                        "Failed to set www admin: " . $ds->getError() . "\n");
        }

        $rc = $ds->moveBuildPortsQueueFromUserToUser($old_id, $user->getId());
}

sub addBuildUser {
        return _updateBuildUser($opts, "addBuildUser");
}

sub updateBuildUser {
        return _updateBuildUser($opts, "updateBuildUser");
}

sub listUsers {
        my @users = $ds->getAllUsers();

        if (@users) {
                map { print $_->getName() . "\n" } @users;
        } elsif (defined($ds->getError())) {
                cleanup($ds, 1,
                        "Failed to list users: " . $ds->getError() . "\n");
        } else {
                cleanup($ds, 1,
                        "There are no users configured in the datastore.\n");
        }
}

sub listBuildUsers {
        if (!$opts->{'b'}) {
                usage("listBuildUsers");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});
        my @users = $ds->getUsersForBuild($build);

        if (@users) {
                map { print $_->getName() . "\n" } @users;
        } elsif (defined($ds->getError())) {
                cleanup($ds, 1,
                        "Failed to list users: " . $ds->getError() . "\n");
        } else {
                cleanup($ds, 1,
                        "There are no users configured for this build.\n");
        }
}

sub copyBuildPorts {
        if (!$opts->{'s'} && !$opts->{'d'}) {
                usage("copyBuild");
        }

        if (!$ds->isValidBuild($opts->{'s'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'s'} . "\n");
        }

        if (!$ds->isValidBuild($opts->{'d'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'d'} . "\n");
        }

        my $src    = $ds->getBuildByName($opts->{'s'});
        my $dest   = $ds->getBuildByName($opts->{'d'});
        my $doPkgs = 0;
        if ($opts->{'p'}) {
                $doPkgs = 1;
        }

        my @ports = $ds->getPortsForBuild($src);
        foreach my $port (@ports) {
                my $rc = $ds->addPortForBuild($port, $dest);
                if (!$rc) {
                        warn "WARN: Failed to add port "
                            . $port->getName()
                            . " for build, "
                            . $dest->getName() . ": "
                            . $ds->getError() . "\n";
                        next;
                }
                if ($doPkgs) {
                        $rc =
                            $ds->updatePortTotalSize($port, $dest,
                                $ds->getPortTotalSize($port, $src));
                        if (!$rc) {
                                warn
                                    "WARN: Failed to update port total size for port "
                                    . $port->getName() . "\n";
                        }

                        $rc =
                            $ds->updatePortLastBuiltVersion($port, $dest,
                                $ds->getPortLastBuiltVersion($port, $src));
                        if (!$rc) {
                                warn
                                    "WARN: Failed to update port last built version for port "
                                    . $port->getName() . "\n";
                        }

                        $rc =
                            $ds->updatePortLastStatus($port, $dest,
                                $ds->getPortLastBuiltStatus($port, $src));
                        if (!$rc) {
                                warn
                                    "WARN: Failed to update port last built status for port "
                                    . $port->getName() . "\n";
                        }
                }
        }
}

sub processLog {
        my $log_text = "";
        my @patterns;
        my %parents = ();
        my $reason  = '__nofail__';
        my $verbose = 0;
        my $id;
        my $expr;
        my $matchtext;

        if (!$opts->{'l'}) {
                usage("processLog");
        }

        if ($opts->{'v'}) {
                $verbose = 1;
        }

        if ($opts->{'l'} =~ /\.bz2$/) {
                require Compress::Bzip2;

                my $lbuf;
                my $bz = new Compress::Bzip2;
                unless ($bz->bzopen($opts->{'l'}, 'r')) {
                        cleanup(1, $ds,
                                      "Failed to open "
                                    . $opts->{'l'}
                                    . " for reading: $!.\n");
                        while ($bz->bzreadline($lbuf)) {
                                $log_text .= $lbuf;
                        }

                        $bz->bzclose();
                }
        } else {
                unless (open(LOG, $opts->{'l'})) {
                        cleanup($ds, 1,
                                      "Failed to open "
                                    . $opts->{'l'}
                                    . " for reading: $!.\n");
                }

                while (<LOG>) {
                        $log_text .= $_;
                }

                close(LOG);
        }

        @patterns = $ds->getAllPortFailPatterns();
        $parents{'0'} = 1;

        foreach my $pattern (@patterns) {
                next if $pattern->getId() <= 0;
                $expr = $pattern->getExpr();
                if ($log_text =~ /($expr)/m) {
                        if ($pattern->getReason() eq '__parent__') {
                                $parents{$pattern->getId()} = 1;
                        } else {
                                if ($parents{$pattern->getParent()}) {
                                        $reason    = $pattern->getReason();
                                        $id        = $pattern->getId();
                                        $matchtext = $1;
                                        last;
                                }
                        }
                }
        }

        if ($verbose eq 1) {
                print "id:     " . $id . "\n";
                print "expr:   " . $expr . "\n";
                print "reason: " . $reason . "\n";
                print "matching text: " . $matchtext . "\n";
        } else {
                print $reason . "\n";
        }
}

sub _updateBuildUser {
        my $opts     = shift;
        my $function = shift;

        if (       (!$opts->{'b'} && !$opts->{'a'})
                || ($opts->{'b'} && $opts->{'a'})
                || !$opts->{'u'})
        {
                usage($function);
        }

        my $buildname = $opts->{'b'};
        if ($buildname && !$ds->isValidBuild($buildname)) {
                cleanup($ds, 1, "Unknown build, $buildname\n");
        }

        my $username = $opts->{'u'};
        if (!$ds->isValidUser($username)) {
                cleanup($ds, 1, "Unknown user, $username\n");
        }

        my $user = $ds->getUserByName($username);

        if (!$user->getEmail()) {
                cleanup($ds, 1,
                        "User, $username, does not have an email address\n");
        }

        my @builds = ();
        if ($opts->{'a'}) {
                @builds = $ds->getAllBuilds();
        } else {
                push @builds, $ds->getBuildByName($buildname);
        }

        foreach my $build (@builds) {
                if ($ds->isUserForBuild($user, $build)) {
                        $ds->updateBuildUser($build, $user, $opts->{'c'},
                                $opts->{'e'});
                } else {
                        $ds->addUserForBuild($user, $build, $opts->{'c'},
                                $opts->{'e'});
                }
        }
}

sub addPorts {
        my $port  = shift;
        my $build = shift;
        my $cache = shift;
        my $deps  = shift;

        my $portdir = $ENV{'PORTSDIR'} . "/" . $port;
        return undef if (!-d $portdir);

        # Canonicalize the port directory.
        $port = abs_path($portdir);
        $port =~ s|$ENV{'PORTSDIR'}/||;

        if (defined($deps)) {
                my @list;
                push @list, $cache->PkgDependsList($port);
                push @list, $cache->BuildDependsList($port);
                push @list, $cache->RunDependsList($port);
                push @list, $cache->TestDependsList($port);

                my %uniq;
                foreach my $dep (grep { !$uniq{$_}++ } @list) {
                        next unless $dep;
                        push @{$deps}, $dep;
                }
        }

        my $pCls    = $ds->getPortByDirectory($port);
        my $newPort = 0;
        if (!defined($pCls)) {
                $pCls    = new Tinderbox::Port();
                $newPort = 1;
        }

        $pCls->setDirectory($port);
        $pCls->setName($cache->Name($port));
        $pCls->setMaintainer($cache->Maintainer($port));
        $pCls->setComment($cache->Comment($port));

        # Only add the port if it isn't already in the datastore.
        my $rc;
        if ($newPort) {
                $rc = $ds->addPort(\$pCls);
                if (!$rc) {
                        warn "WARN: Failed to add port "
                            . $pCls->getDirectory() . ": "
                            . $ds->getError() . "\n";
                }
        } else {
                $rc = $ds->updatePort(\$pCls);
                if (!$rc) {
                        warn "WARN: Failed to update port "
                            . $pCls->getDirectory() . ": "
                            . $ds->getError() . "\n";
                }
        }

        if (!$ds->isPortInBuild($pCls, $build)) {
                $rc = $ds->addPortForBuild($pCls, $build);
                if (!$rc) {
                        warn "WARN: Failed to add port for build, "
                            . $build->getName() . ": "
                            . $ds->getError() . "\n";
                }
        }

        return $pCls;
}

sub isLogCurrent {
        if (!$opts->{'b'} || !$opts->{'l'}) {
                usage("isLogCurrent");
        }

        if (!$ds->isValidBuild($opts->{'b'})) {
                cleanup($ds, 1, "Unknown build, " . $opts->{'b'} . "\n");
        }

        my $build = $ds->getBuildByName($opts->{'b'});
        my $result = $ds->isLogCurrent($build, $opts->{'l'});

        print $result . "\n";
}
