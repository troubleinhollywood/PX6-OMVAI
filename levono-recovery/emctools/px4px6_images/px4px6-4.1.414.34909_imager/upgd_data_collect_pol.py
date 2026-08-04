#!/usr/bin/python
#
# upgd_data_collect_pol.py - Set policy for data collection
# Author: Daniel Noguchi <dnoguchi at lenovo.com>
"""
# This script aims to fix the particular case described on bug #27540. It
# verifies a condition wheter or not the user has set Security options on his
# device before upgrading to a newer version. If the used has set Security
# options, then we create the correspondent xml file so the "Allow collection of
# usage statistics" box is shown unchecked when accessing the setup phase of the
# device. In the case where the user has not set the Security options, we leave
# the check box checked.
"""

import xmlrpclib

def get_security_val(ip, version):
	"""
	Get json string from SecurityInfo API and returns the value of the enabled field
	"""
	try:
		srv = xmlrpclib.ServerProxy("http://" + ip + "/cprpc/")
		data = srv.SecurityInfo(version)

		# The xmlrpc call returns a dict. The "enabled" key contains a boolean value
		return data["enabled"]
	except:
		print("(upgd_data_collect_pol.py) Error: Could not get response from SecurityInfo API")
		return False


def create_xml():
	"""
	Creates the system.xml file on /mnt/system/config/system.xml
	"""
	txt =  ('<?xml version="1.0"?>\n'
		'<system NoAnalytics="1"></system>\n')

	try:
		xmlfile = open("/mnt/system/config/system.xml", "w")
		xmlfile.write(txt)
	except:
		print("(upgd_data_collect_pol.py) Could not write XML file on /mnt/system/config/system.xml. Aborting!")
		raise


def update_analytics_info():
	"""
	Checks if the security option is enabled or not and creates the xml file accordingly
	"""
	try:
		if get_security_val("127.0.0.1", "2"):
			create_xml()
			print("(upgd_data_collect_pol.py) Security policy upgrade complete")
		else:
			print("(upgd_data_collect_pol.py) No Security policy update needed")
	except:
		print("(upgd_data_collect_pol.py) Could not update security policy")
		raise


update_analytics_info()

