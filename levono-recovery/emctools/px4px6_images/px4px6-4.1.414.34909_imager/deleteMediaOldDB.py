#!/usr/bin/python

import sys
import os
from xml.dom.minidom import parse, getDOMImplementation

def main():

	changed = False
        fEx = os.path.isfile("/tmp/sohoRAM.xml")

        if(fEx != True):
                print "No such file in your device"
                return;

        doc = parse("/tmp/sohoRAM.xml")

        procInfo = doc.documentElement.getElementsByTagName("Program")

	for proc in procInfo:
		if (proc.getAttribute("Name") == "twonkymedia" or proc.getAttribute("Name") == "mt-daapd"):
			if (proc.getAttribute("Disable") == "0"):
				proc.setAttribute("Disable", "1");
				changed = True

        if (changed):
                o = open("/tmp/sohoRAM.xml", "w")
                doc.writexml(o);
                o.close()

	if (os.path.exists("/mnt/system/media/db")):
		os.system("pgrep daap | xargs kill -9")
		os.system("rm -rf /mnt/system/media/db")

	if (os.path.exists("/mnt/system/media/twonky/db")):
		os.system("pgrep twonky | xargs kill -9")
		os.system("find  /mnt/system/media/twonky/* -maxdepth 0 ! -name twonkyvision-mediaserver.ini -exec rm -rf {} \;")

if (__name__ == "__main__"):
        main()

