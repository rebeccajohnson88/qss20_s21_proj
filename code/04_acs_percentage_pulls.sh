#!/usr/bin/python bash
for i in {2014..2019}
do
	python3 04_acs_demographics_percentage.py --dropbox "/Users/euniceliu/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork/" --acsyear $i
done



