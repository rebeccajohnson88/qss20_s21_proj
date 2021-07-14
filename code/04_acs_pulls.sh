#!/usr/bin/env bash
for i in {2014..2019}
do
	python3 04_acs_demographics.py --dropbox "/Users/grantanapolle/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork/" --acsyear $i
done 