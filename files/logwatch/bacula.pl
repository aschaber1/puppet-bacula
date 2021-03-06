#!/usr/bin/perl -w
#
# logwatch filter script for bacula log files
#
# Mon Jan 03 2005
# D. Scott Barninger and Karl Cunningham
#
# Copyright 2005-2006 Free Software Foundation Europe e.V.
# licensed under GPL-v2

use strict;
use POSIX qw(strftime);

my (@JobName,$JobStatus,$ThisName,$ThisStatus,$ThisDate);
my ($Job,$JobId,$JobDate,$Debug,$DebugCounter,%data);

# set debug level
$Debug = $ENV{'LOGWATCH_DEBUG'} || 0;

if ( $Debug >= 5 ) {
        print STDERR "\n\nDEBUG: Inside Bacula Filter \n\n";
        $DebugCounter = 1;
}

while (<STDIN>) {
        chomp;
        if ( $Debug >= 5 ) {
                print STDERR "DEBUG($DebugCounter): $_\n";
                $DebugCounter++;
        }

        # Test the line for a new entry, which is a jobid record
        if (/^\s*JobId:\s+(\d+)/) {
                $JobId = $1;
                next;
        }

        (/^\s*Job:\s*(.*)/) and $Job = $1; 
        (/^\s*Termination:\s*(.*)/) and $JobStatus = $1;
        (/^\s*Job:.*(\d{4}-\d{2}-\d{2})/) and $JobDate = $1;

        if ($JobId and $Job and $JobStatus and $JobDate) {
                $data{$JobId} = { 
                        "Job" => $Job, 
                        "JobStatus" => $JobStatus,
                        "JobDate" => $JobDate,
                };
                $JobId = $Job = $JobStatus = $JobDate = "";
        }
}

# if we have data print it out, otherwise do nothing
if (scalar(keys(%data))) {
        print "\nJobs Run:\n";
        foreach my $Id (sort {$a<=>$b} (keys(%data))) {
                $ThisName = $data{$Id}{Job};
                $ThisStatus = $data{$Id}{JobStatus};
                $ThisDate = $data{$Id}{JobDate};
                $ThisName =~ s/\s//g;
                $ThisStatus =~ s/\s//g;
                print "$ThisDate $Id $ThisName\n     $ThisStatus\n\n";
        }
}

exit(0);

