#!/usr/bin/python 

import sys
import os
import time
from xml.dom.minidom import parse, getDOMImplementation
from subprocess import call

def main():
	val = "360";
	doc = parse("/etc/sohoFlash.xml")
	set = doc.documentElement.getElementsByTagName("DriveMgr")
	for a in set:
		val1 = a.getAttribute('ProbeTime')
		if (val1 == val):
			a.setAttribute('ProbeTime','60')
	test_file=open("/etc/sohoFlash.xml",'w')
	doc.writexml(test_file)
	test_file.close();
	doc.unlink();



if (__name__ == "__main__"):
        main()
