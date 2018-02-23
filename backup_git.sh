# February 20, 2018
# Tanium, Inc
#
# This script git clones the Tanium git repo using the GitHub API.
# Then keeps $count number of differential backups and then at the end
# does a rollup into a tar ball.

#!/bin/bash

# Varibles

git_source=/mnt/git_backups/tmp
working_dir=/mnt/git_backups
archive_dir=/mnt/git_backups/ROLLUPS
count=$(cat $working_dir/counter.txt)
max_count=15
pruned_count=$((max_count+1))

# Change to working directory
cd $git_source

# Clone current GitHub repo to ./tmp
curl "https://api.github.com/users/tanium/repos?page=1&per_page=100" | grep -e 'git_url*' | cut -d \" -f 4 | xargs -L1 git clone
git clone https://davidhunterchowdah:818777b33314b2ed8111bef0c7d13145763ec512@github.com/tanium/it-ansible.git

# Check for first time run
for i in $(seq 0 $max_count) ; do
        if [ -d $working_dir/$i.daily_diff ] ; then
                echo "Directory $i.daily_diff exists!"
        else
		echo "Creating directory $i.daily_diff..."
                mkdir $working_dir/$i.daily_diff
		echo "Resetting counter..."
		echo 0 > $working_dir/counter.txt
        fi
done

# Shift directories
for i in $(seq $max_count -1 0) ; do
        j=$((i+1))
	echo "Shifting $i.daily_diff to $j.daily_diff"
        mv $working_dir/$i.daily_diff $working_dir/$j.daily_diff
done

# Create the latest directory
echo "Creating newest 0.daily_diff"
mkdir $working_dir/0.daily_diff

# Copy hard links from previous days run
echo "Hardlinking..."
cp -arl $working_dir/1.daily_diff/* $working_dir/0.daily_diff/ 2>/dev/null

# Rsync changes from the most recent git clone
echo "rsync to from git_source to 0.daily_diff"
rsync -rvWH --delete --size-only $git_source/ $working_dir/0.daily_diff/

# Check to see if we need to do a bi-weekly rollup
echo "Checking for bi-weekly rollup"
if [ $count -eq $max_count ]; then
	echo "Rolling up all the things!"
	tar cf $archive_dir/tanium_git_rollup-$(date +"%m-%d-%y").tar --files-from /dev/null
	for i in $(seq 0 $max_count) ; do
		tar rf $archive_dir/tanium_git_rollup-$(date +"%m-%d-%y").tar $working_dir/$i.daily_diff
	done
	gzip $archive_dir/tanium_git_rollup-$(date +"%m-%d-%y").tar
	echo 0 > $working_dir/counter.txt
else
	echo "Not time for rollups yet..."
	((count++))
	echo $count > $working_dir/counter.txt
fi

# Lop off the oldest directory
echo "Pruning the oldest snapshot"
rm -rf $working_dir/$pruned_count.daily_diff

# Delete temporary files
echo "Deleting temporary files"
rm -rf $working_dir/tmp/*
