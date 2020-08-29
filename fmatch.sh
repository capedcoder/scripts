#########################################################################################################
#	USAGE : <script> <dir1> <dir2> <output-dir>															#		
#	The script checks if dir1 is a subset of dir2														#
#	Any file that exists in dir1 but not in dir2 is listed in the <output-dir>/missing.txt file			#
#	To skip generating hashes for dir1/dir2 send null instead 											#
#	eg: <script> null <dir2> <output-dir>	-hashes will be generated for dir2 but not for dir1			#
#						-comparison is non-optional														#
#																										#	
#	Comparison takes file name and conent(md5sum hash) into account										#
#	If the script reports no missing files, it is safe to delete dir1 as all its						#
#	As path is not checked in comparison, same file but different paths will be considered same			#
#	If paths are expected to be the same, diff -qr <dir1> <dir2> can be used instead					#
#	data is contained in dir2																			#
#	Copy/move missing files to a dir: sed 's/^ *//' < missing.txt | xargs -d '\n' cp/mv -t missing/		#
#########################################################################################################

#### setup output dirnames & filenames & cleanup environment

dir1=$1
dir2=$2
outputdir=$3
hashoutfile1="$outputdir"/hashes1.txt
hashoutfile2="$outputdir"/hashes2.txt
pathoutfile1="$outputdir"/path1.txt
nomatchout="$outputdir"/nomatch.txt
partialmatchout="$outputdir"/partialmatch.txt
fullmatchout="$outputdir"/fullmatch.txt
tmpfile="$outputdir"/tmpfile.txt
mkdir -p $outputdir

#hashes for dir 1

if [ "$dir1" != "null" ]
then
	echo "Generating Hashes & Paths for $dir1 ..."
	find "$1" -type f | while read file; do
		md5sum=($(md5sum "$file"))
		filename="$(basename "$file")"
		echo $filename ${md5sum[0]} >> $hashoutfile1
		unset md5sum[0]
		echo ${md5sum[@]} >> $pathoutfile1
	done
	count=$(cat $hashoutfile1 | wc -l)
	echo "Found $count files in $dir1"
else
	echo "Skipping generating hashes & paths for dir1."
fi


#hashes for dir 2

if [ "$dir2" != "null" ]
then
	echo "Generating Hashes for $dir2 ..."

	find "$2" -type f | while read file; do	
		md5sum=($(md5sum "$file"))
		filename="$(basename "$file")"
		echo $filename ${md5sum[0]} >> $hashoutfile2
	done
	count=$(cat $hashoutfile2 | wc -l)
	echo "Found $count files in $dir2"
else
	echo "Skipping generating hashes & paths for dir2."
fi

echo "Hash Generation completed. Beginning with comparison."
read -p "Press enter to continue"


#compare hashoutfile1 and hashoutfile2, to find if full/partial/no match


while read line1; do
	match=none #re-initialize match to no-match for every line
	linearray1=($line1)
	hash1=${linearray1[-1]}
	unset linearray1[-1]
	filename1=${linearray1[@]}
	while read line2; do
		linearray2=($line2)
		hash2=${linearray2[-1]}
		unset linearray2[-1]
		filename2=${linearray2[@]}
		if [ "$filename1" == "$filename2" ]
		then
			if [ $hash1 == $hash2 ]
			then
				echo "*** Full Match - Found, Marking for action for $line1 and $line2"
				match=full
				break
			else
				#filename match found but hash comparison failed
				match=partial		
				echo "*** Partial Match - Found, Marking for action $line1 and $line2"
				echo "hash:$hash1 , filename:$filename1";
				echo "hash:$hash2 , filename:$filename2";
			fi		
		fi		
	done < $hashoutfile2	

#take action on line1 on the basis of match
	if [ "$match" == "none" ]
	then
		echo "*** No Match - Taking action for $line1"
		missing=$(head -n 1 $pathoutfile1)
 		echo $missing >> $nomatchout	
		sed -i '1d' $pathoutfile1
	fi
	if [ "$match" == "partial" ]
	then				
		echo "*** Partial Match - Taking action for $line1"
		missing=$(head -n 1 $pathoutfile1)
 		echo $missing >> $partialmatchout			
		sed -i '1d' $pathoutfile1
	fi
	if [ "$match" == "full" ]
	then				
		echo "*** Full Match - Taking action for $line1"
		matchfound=$(head -n 1 $pathoutfile1)
 		echo $matchfound >> $fullmatchout
		sed -i '1d' $pathoutfile1
	fi
done < $hashoutfile1

echo "Files with NO Match : $(cat $nomatchout | wc -l)"
echo "Files with Partial Match : $(cat $partialmatchout | wc -l)"
echo "Files with Full Match : $(cat $fullmatchout | wc -l)"