#! /bin/sh -f
#
# Copyright (c) 2018 Oracle and/or its affiliates. All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v. 2.0, which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# This Source Code may also be made available under the following Secondary
# Licenses when the conditions for such availability set forth in the
# Eclipse Public License v. 2.0 are satisfied: GNU General Public License,
# version 2 with the GNU Classpath Exception, which is available at
# https://www.gnu.org/software/classpath/license.html.
#
# SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
#

#
# usage:  analyseSummaryFiles options files...
#
# options:
#    -h html-file
#	Generate an HTML file listing all the failures and the corresponding
#	test owners
#    -s status-dir status-url
#	Generate a status page containing an entry per test owner for each
#	owner that needs to analyse errors in the build. status-dir should
#	be a directory in which to build the status page; status-url is
#	an equivalent URL.
#    -m 
#	Send mail to each of the test owners that need to analyse failures
#	in the build.
#    -o owners-file
#	A .jto file identifying the owners for different parts of the test suite
#    -t title
#       A title string to be used in the generated files
#    files
#	A list of summary.txt files to be analysed for failures

# Example:
#
# ksh -x analyseSummaryFiles.ksh -h ~/tmp/errors.html -s /home/jjg/public_html/jckstat http://javaweb/~jjg/jckstat -m -o /java/jck/workspaces/kestrel-rc1/build/share/owners.jto /net/mizu/usr/re/jck1.3/src/solaris/JCK-13n/jck-tests-build/test/*/*/report/summary.txt 


script=$0

while [ $# -gt 0 ]; do
    case $1 in
	-h ) htmlFile=$2 ; 	shift ; shift ;;
	-s ) statusDir=$2 ; statusURL=$3 ; shift ; shift ; shift ;;
	-m ) sendMail=1 ; 	shift ;;
	-o ) ownersFile=$2 ;  	shift ; shift ;;
	-t ) title=$2 ; 	shift ; shift ;;
	-* ) echo bad option: $1 ; exit 1 ;;
	* )  break ;;
    esac
done

if [ $# -eq 0 ]; then
    echo no summary files given 
    exit 1
fi


TMPDIR=/tmp/analyseSummaryFiles.$$
mkdir $TMPDIR

# given a test url, scan the owners file to find the first match
# and add the url to that owner's list.
note() {
    url=$1
    cat $ownersFile | egrep -v '(^$|^#)' | while read prefix owner description ; do
	case $url in
	    ${prefix}* ) echo $url >> $TMPDIR/$owner ; return
	esac
    done
}

# write an HTML summary of the failures/owners to stdout
writeHTML() {
    echo "<html>"
    echo "<head><title>${title:-TCK Build Analysis}</title></head>"
    echo "<body>"
    echo "<h3>Build analyzed at `date`</h3>"
    echo "<h4>Test Owners</h4>"
    echo "<ul>"
    find $TMPDIR -type f | sort | while read file ; do 
	echo "<li><a href="#`basename $file`">`basename $file`</a>"
    done
    echo "</ul>"
    echo "<hr>"
    find $TMPDIR -type f | sort | while read file ; do 
	echo "<h4><a name="`basename $file`">`basename $file`</a></h4>"
	cat $file | sort | sed -e 's/$/<br>/'
    done
    echo "</table>"
    echo "<p><hr>Generated by $script at `date`"
    echo "</body>"
    echo "</html>"	
}


# given an owner-errors file name, generate a name for the entry in
# the status page
mkEntryName() {
    echo `basename $1` | sed -e 's/[^A-Za-z0-9.][^A-Za-z0-9.]*/_/g'
}


# given an owner-errors file name, generate the email address for
# the status page
mkEmail() {
    basename $1
}


# given an owner-errors file name, generate a short description for
# the status page
mkDesc() {
    head -3 $1 | sed -e 's/$/<br>/'
    count=`wc -l $1 | awk '{print $1}'`
    if [ "$count" -gt 3 ]; then echo "<em>etc.</em>" ; fi
}

# generate a status page and all the related files
writeStatus() {
    rm -rf $statusDir
    mkdir -p $statusDir
    chmod o+w $statusDir
    cat <<- EOF > $statusDir/template.columns
	owner  s - 		Owner/Tests
	owner  p ./owner 	desc email
	status s unknown 	Status
	status p ./status 	status
	date   s unknown 	Last Updated
	notes  c - 		Notes
	EOF
    cat <<- EOF > $statusDir/template.html
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
	<!-- Automatically generated; do not edit -->
	<html>
	  <head>
	    <title>${title:-TCK Build Analysis}</title>
	    <base href="$statusURL/">
	  </head> 

	Title ${title:-TCK Build Analysis}
	Contact Veronica Veroulis
	Econtact veronica.veroulis@Eng
	Path $statusDir
	Page $statusURL
	Script http://cuenca.eng/cgi-bin/jdk-test/submitstatus.cgi
	<!--Debug jjg@eng.sun.com-->
	<!--Debug Updates jjg@eng.sun.com-->
	Header
	<h3>Build analyzed at `date`</h3>
	<ul>
	<li><a href="failures.html">All test failures</a>
	</ul>
	StartTable
	EOF
    find $TMPDIR -type f | sort | while read file ; do 
    	echo entry `mkEntryName $file` `mkEmail $file` `mkDesc $file` >> $statusDir/template.html
    done
    cat <<- EOF >> $statusDir/template.html
	EndTable
	<p>
	<A HREF="update.html">Update</A> any area in the above tables.
	<hr>
	<small>
	Send comments or questions to
	Comments
	<br>
	Last updated:
	Date
	</small>
	</body>
	</html>
	EOF
    cat <<- EOF > $statusDir/template.form
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
	<HTML>
	Title ${title:-TCK Build Analysis}
	<BODY bgcolor="#eeeeff">
	<CENTER>
	Header
	<h4>
	Update values for
	display area
	</h4>
	<h4>
	Test owner:
	display email
	</h4>
	</CENTER>

	StartForm
	<table bgcolor="#DDDDD0">
	<tr><td>What is the status of the analysis?
	<td align=right>
	input status menu unknown analysing fixing done

	<tr><td colspan=2>Enter any additional notes:
	<tr><td colspan=2>
	input notes comment 10 80
	</table>

	<input name=date type=hidden>
	<SCRIPT Language="JavaScript">
	<!-- hide code from non-JavaScript browsers
	now = new Date();
	document.forms[0].date.value=(1+now.getMonth()) + "/" + now.getDate() + "/" + now.getYear();
	//-->
	</SCRIPT>

	EndForm

	</BODY>
	</HTML>
	EOF
    cat <<- 'EOF' > $statusDir/owner
	#!/bin/sh
	echo hola | nawk -v desc="$1" -v email=$2 '{
	  printf "<TD>"
	  if (email != "-")
	    printf "<a HREF=\"mailto:%s\">%s</a><BR>", email, email
	  printf "%s</TD>\n", desc
	}'
	EOF
    chmod +x $statusDir/owner
    cat <<- 'EOF' > $statusDir/status
	#!/bin/sh
	case $1 in 
	  'unknown' ) echo "<td><font color=red>$1</td>" ;;
	  'analysing' | fixing ) echo "<td><font color=yellow>$1</td>" ;;
	  'done' ) echo "<td><font color=lime>$1</td>" ;;
	  * ) echo "<td>$1</td>" ;;
	esac
	EOF
    chmod +x $statusDir/status
    writeHTML > $statusDir/failures.html
}


# read the summary.txt files, and create the owner/test lists
cat $* | egrep -v '(^#|^[^ 	]*[ 	]*Passed)' | awk '{print $1}' | sort -u |
    while read url ignore ; do 
	note $url 
    done

# write out HTML file if requested
if [ ! -z "$htmlFile" ]; then
    writeHTML > $htmlFile
fi

# write out the status page if requested
if [ ! -z "$statusDir" ]; then
    writeStatus
    /java/jdk/scripts/status/create $statusDir
fi

# send email to each owner if requested
if [ $sendMail ]; then
    find $TMPDIR -type f | sort | while read file ; do 
    	(   echo "Subject: TCK Test Failure Analysis required"
	    echo "To: `basename $file`"
	    echo "Reply-To: jck@nbsp.nsk.su"
	    echo "MIME-Version: 1.0"
	    echo "Content-Type: MULTIPART/mixed; BOUNDARY=Boundary"
	    echo
	    echo "--Boundary"
	    echo "Content-Type: TEXT/plain; charset=us-ascii"
	    echo
	    echo "Analysis of the recent TCK build revealed the following test"
	    echo "failures for which you are listed as the responsible owner in"
	    echo "$ownersFile"
	    echo
	    cat $file | while read f ; do 
	    	echo "    $f" 
	    done
	    echo
	    echo "The files containing these errors are listed in the attachment."
	    echo
	    echo "Please analyse these failures, perform any necessary corrective"
	    echo "action, and report back to the TCK release team,"
	    echo "by sending mail to mailto:jck@nbsp.nsk.su"
	    if [ ! -z "$statusDir" ]; then
	        echo "and/or updating the status pages at $statusURL"
	    fi
	    echo 
	    echo "----------------------"
	    echo "This message was generated by $script"
	    echo 
	    echo
	    echo "--Boundary"
	    echo "Content-Type: TEXT/plain; charset=us-ascii"
	    echo
	    for i in $* ; do
		echo $i
	    done
	    echo "--Boundary--"
	) | /usr/bin/mail jjg
    done
fi



# cleanup
cleanup() {
    rm -rf $TMPDIR
}


trap cleanup 0 INT QUIT KILL TERM
