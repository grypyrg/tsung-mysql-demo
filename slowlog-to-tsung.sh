#!/bin/bash

set -e

inputfile=$1
destdir=$2
skip=$3
max=100000

if [ $# -lt 2 ]; then
	echo "Usage: "
	echo -e "\t$0 slowlog destdir [skip]"
	exit 1
fi

sessionsdir=$destdir/sessions
hashdir=$destdir/hashes/

echo "hashdir=$hashdir"
echo "sessionsdir=$sessionsdir"

if [ "$skip" != "skip" ]; then
    if [ -e $destdir ] ; then
        echo "ERROR: destdir $destdir already exists, please make sure the directory does not exist yet"
        exit 1
    fi

    mkdir $destdir
    mkdir $hashdir
    mkdir $sessionsdir

    ./pt-log-player --split Thread_id --session-files=$max  --max-sessions=$max --base-dir $sessionsdir $inputfile

    for file in `find $sessionsdir -iname 'sessions-*.txt'`
    do
        hash=`cat $file  | sed "s/$/;/g" | ./pt-fingerprint  | md5 | awk '{print $1}'`
        sessionname=`basename $file`
        echo $sessionname >> $hashdir/hash-${hash}
    done


else 
    if [ ! -d $destdir ]; then
        echo "Could not fine destdir $destdir"
        exit 1
    fi
fi


for hash in `find $hashdir -iregex '.*hash-[a-z0-9]*'`
do
    hashbase=`basename $hash`
    echo $hashbase

    cat $destdir/sessions/`head -n 1 $hash` | sed "s/$/;/g" | ./pt-fingerprint > $hashdir/$hashbase.fingerprint

    ./gen-xml.pl $destdir $hashbase

    hashes="$hashes $hashbase"
done



cat > $destdir/tsung.xml << EOF
<?xml version="1.0" ?>
<!DOCTYPE tsung SYSTEM "/usr/share/tsung/tsung-1.0.dtd">
<tsung loglevel="info" >
  <clients>
    <client host="localhost" use_controller_vm="true" maxusers='300000'/>
  </clients>

  <servers>
    <server host="node1" port="3306" type="tcp" weight="1" />
    <!-- <server host="node2" port="3306" type="tcp" weight="1"></server> -->
    <!-- <server host="node3" port="3306" type="tcp" weight="1"></server> -->
    <!-- <server host="node4" port="3306" type="tcp" weight="1"></server> -->
    <!-- <server host="node5" port="3306" type="tcp" weight="1"></server> -->
    <!-- <server host="node6" port="3306" type="tcp" weight="1"></server> -->
    </servers>

<!--
  <monitoring>
    <monitor host="localhost" />
  </monitoring>
 -->

  <load duration="3" unit="minute">
    <arrivalphase phase="1" duration="3" unit="minute">
      <users interarrival="0.005" unit="second"></users>
    </arrivalphase>
  </load>
EOF

### OPTIONS
echo "<options>" >> $destdir/tsung.xml
for hash in $hashes
do
    hashbase=`basename $hash`

    cat $destdir/hashes/$hashbase.options.xml >> $destdir/tsung.xml

done
echo "</options>" >> $destdir/tsung.xml


### SESSIONS
echo "<sessions>" >> $destdir/tsung.xml
for hash in $hashes
do
    hashbase=`basename $hash`

    cat $destdir/hashes/$hashbase.session.xml >> $destdir/tsung.xml
done
echo "</sessions>" >> $destdir/tsung.xml
echo "</tsung>" >> $destdir/tsung.xml
